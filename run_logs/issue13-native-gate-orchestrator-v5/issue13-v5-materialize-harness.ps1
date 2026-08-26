param(
  [Parameter(Mandatory = $true)][string]$Destination,
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')]
  [string]$CandidateCommit,
  [string]$SourceRuntimeRoot = '',
  [switch]$ConfirmMaterialize
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ConfirmMaterialize) {
  throw 'V5 harness materialization requires -ConfirmMaterialize.'
}

$baselineCommit = 'cc2c86189a06676bcb9f0e05e08033d710a92509'
$expectedSourceInventory =
  'f42c94666cd10606176e8fe0f3f2afe9975b58c5b0b914343a267f62724d34f1'
$expectedOutputFileCount = 39L
$expectedOutputTotalBytes = 588671L
$expectedOutputInventory =
  '0d5b7cfd4a9085afd9b9d196d4ac487853b41948981e3436e9d87811ef473ced'
$controllerFiles = @(
  'README.md',
  'issue13-v5-baseline-smoke.ps1',
  'issue13-v5-build-baseline-index.R',
  'issue13-v5-compare-override.R',
  'issue13-v5-compatibility-baseline-override.R',
  'issue13-v5-coordinator-lib.ps1',
  'issue13-v5-coordinator.ps1',
  'issue13-v5-materialize-harness.ps1',
  'issue13-v5-new-config.ps1',
  'issue13-v5-render-report.ps1',
  'issue13-v5-static-verify.ps1'
)
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function ConvertTo-Issue13V5FullPath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) {
    throw 'A V5 path is empty.'
  }
  [IO.Path]::GetFullPath($Path)
}

function Get-Issue13V5Sha256([string]$Path) {
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Issue13V5SourceRuntimeFiles([string]$Root) {
  $harness = Join-Path $Root 'issue13-evidence-harness'
  if (-not (Test-Path -LiteralPath $harness -PathType Container)) {
    throw "The canonical V4 harness directory is absent: $harness"
  }
  $harnessDirectories = @(
    Get-ChildItem -LiteralPath $harness -Directory -Recurse -Force)
  if ($harnessDirectories.Count -ne 0) {
    throw 'The selected canonical V4 harness directory must be flat.'
  }
  @(
    @(Get-ChildItem -LiteralPath $Root -File -Force | Where-Object {
      $_.Name -cne 'v5-harness-manifest.json'
    }),
    @(Get-ChildItem -LiteralPath $harness -File -Force)
  ) | ForEach-Object { $_ }
}

function Get-Issue13V5OutputRuntimeFiles([string]$Root) {
  $harness = Join-Path $Root 'issue13-evidence-harness'
  if (-not (Test-Path -LiteralPath $harness -PathType Container)) {
    throw "The materialized V5 harness directory is absent: $harness"
  }
  $rootDirectories = @(Get-ChildItem -LiteralPath $Root -Directory -Force)
  $harnessDirectories = @(
    Get-ChildItem -LiteralPath $harness -Directory -Recurse -Force)
  if ($rootDirectories.Count -ne 1 -or
      $rootDirectories[0].Name -cne 'issue13-evidence-harness' -or
      $harnessDirectories.Count -ne 0) {
    throw 'V5 output requires one flat issue13-evidence-harness directory.'
  }
  @(
    @(Get-ChildItem -LiteralPath $Root -File -Force | Where-Object {
      $_.Name -cne 'v5-harness-manifest.json'
    }),
    @(Get-ChildItem -LiteralPath $harness -File -Force)
  ) | ForEach-Object { $_ }
}

function Get-Issue13V5Inventory(
  [string]$Root,
  [ValidateSet('source', 'output')][string]$Mode
) {
  $rootFull = (Resolve-Path -LiteralPath $Root).Path
  $files = if ($Mode -ceq 'source') {
    Get-Issue13V5SourceRuntimeFiles $rootFull
  } else {
    Get-Issue13V5OutputRuntimeFiles $rootFull
  }
  $records = @($files | ForEach-Object {
    $relative = $_.FullName.Substring($rootFull.Length + 1).Replace('\', '/')
    [pscustomobject][ordered]@{
      relative_path = $relative
      size_bytes = [long]$_.Length
      sha256 = Get-Issue13V5Sha256 $_.FullName
    }
  } | Sort-Object relative_path)
  $lines = @($records | ForEach-Object {
    [string]$_.relative_path + '|' + [string]$_.size_bytes + '|' +
      [string]$_.sha256
  })
  $payload = [Text.Encoding]::UTF8.GetBytes([string]::Join("`n", $lines))
  [pscustomobject][ordered]@{
    file_count = [long]$records.Count
    total_bytes = [long](($records | Measure-Object size_bytes -Sum).Sum)
    inventory_sha256 = [Convert]::ToHexString(
      [Security.Cryptography.SHA256]::HashData($payload)
    ).ToLowerInvariant()
    records = $records
  }
}

function Set-Issue13V5Utf8Text([string]$Path, [string]$Value) {
  [IO.File]::WriteAllText($Path, $Value, $utf8)
  $observed = [IO.File]::ReadAllText($Path, $utf8)
  if (-not [string]::Equals($observed, $Value, [StringComparison]::Ordinal)) {
    throw "UTF-8 round trip failed: $Path"
  }
}

function Get-Issue13V5ControllerPins(
  [string]$Repository,
  [string]$Commit
) {
  $relativeRoot = $PSScriptRoot.Substring($Repository.Length).
    TrimStart('\').Replace('\', '/')
  @($controllerFiles | ForEach-Object {
    $path = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot $_)).Path
    $relative = $relativeRoot + '/' + $_
    $currentBlob = (& git -C $Repository hash-object -- $path 2>$null).Trim()
    $committedBlob = (& git -C $Repository rev-parse `
      ($Commit + ':' + $relative) 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $currentBlob -cnotmatch '^[0-9a-f]{40}$' -or
        $currentBlob -cne $committedBlob) {
      throw "V5 controller source is not pinned to candidate: $relative"
    }
    [ordered]@{
      name = $_
      relative_path = $relative
      sha256 = Get-Issue13V5Sha256 $path
      git_blob = $currentBlob
    }
  })
}

function Add-Issue13V5ExactSource(
  [string]$Path,
  [string]$Needle,
  [string]$Replacement
) {
  $value = [IO.File]::ReadAllText($Path, $utf8)
  $first = $value.IndexOf($Needle, [StringComparison]::Ordinal)
  if ($first -lt 0 -or
      $value.IndexOf($Needle, $first + $Needle.Length,
        [StringComparison]::Ordinal) -ge 0) {
    throw "V5 patch anchor is absent or ambiguous: $Path"
  }
  $patched = $value.Substring(0, $first) + $Replacement +
    $value.Substring($first + $Needle.Length)
  Set-Issue13V5Utf8Text $Path $patched
}

if ([string]::IsNullOrWhiteSpace($SourceRuntimeRoot)) {
  $SourceRuntimeRoot = Join-Path (Split-Path -Parent $PSScriptRoot) `
    'issue13-evidence-runtime-v4'
}
$repository = (& git -C $PSScriptRoot rev-parse --show-toplevel 2>$null).Trim()
$head = (& git -C $repository rev-parse HEAD 2>$null).Trim()
$trackedStatus = @(& git -C $repository status '--porcelain=v1' `
  '--untracked-files=no' 2>$null)
if ($LASTEXITCODE -ne 0 -or $head -cne $CandidateCommit -or
    $trackedStatus.Count -ne 0) {
  throw 'V5 materialization requires the pinned candidate HEAD and tracked-clean tree.'
}
$controllerPins = @(Get-Issue13V5ControllerPins $repository $CandidateCommit)
if ($controllerPins.Count -ne 11) {
  throw 'V5 controller pin coverage is not exactly 11 files.'
}
$source = (Resolve-Path -LiteralPath $SourceRuntimeRoot).Path
$destinationFull = ConvertTo-Issue13V5FullPath $Destination
$sourceFull = ConvertTo-Issue13V5FullPath $source
if ([string]::Equals($destinationFull, $sourceFull,
    [StringComparison]::OrdinalIgnoreCase) -or
    $destinationFull.StartsWith($sourceFull.TrimEnd('\') + '\',
      [StringComparison]::OrdinalIgnoreCase) -or
    $sourceFull.StartsWith($destinationFull.TrimEnd('\') + '\',
      [StringComparison]::OrdinalIgnoreCase) -or
    [string]::Equals($destinationFull, $repository,
      [StringComparison]::OrdinalIgnoreCase) -or
    $destinationFull.StartsWith($repository.TrimEnd('\') + '\',
      [StringComparison]::OrdinalIgnoreCase) -or
    $destinationFull -match '(?i)(^|[\\/])[^\\/]*v4(?:r[0-9]+)?[^\\/]*($|[\\/])') {
  throw 'The V5 destination must be new, external to the repository, and not V4.'
}
if (Test-Path -LiteralPath $destinationFull) {
  throw "The V5 harness destination already exists: $destinationFull"
}

$sourceInventory = Get-Issue13V5Inventory $source 'source'
if ([long]$sourceInventory.file_count -ne 37 -or
    [long]$sourceInventory.total_bytes -ne 581093 -or
    [string]$sourceInventory.inventory_sha256 -cne $expectedSourceInventory) {
  throw 'The canonical V4 tooling inventory changed; audit before materializing V5.'
}

$parent = Split-Path -Parent $destinationFull
if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $parent
}
$parent = (Resolve-Path -LiteralPath $parent).Path
$staging = Join-Path $parent (
  '.' + [IO.Path]::GetFileName($destinationFull) + '.staging-' +
    [Guid]::NewGuid().ToString('N')
)
$null = New-Item -ItemType Directory -Path $staging
$harnessStaging = Join-Path $staging 'issue13-evidence-harness'
$null = New-Item -ItemType Directory -Path $harnessStaging

foreach ($record in @($sourceInventory.records)) {
  $from = Join-Path $source ([string]$record.relative_path).Replace('/', '\')
  $to = Join-Path $staging ([string]$record.relative_path).Replace('/', '\')
  $toParent = Split-Path -Parent $to
  if (-not (Test-Path -LiteralPath $toParent -PathType Container)) {
    $null = New-Item -ItemType Directory -Path $toParent
  }
  Copy-Item -LiteralPath $from -Destination $to
  if ((Get-Issue13V5Sha256 $to) -cne [string]$record.sha256) {
    throw "V5 harness copy failed authentication: $($record.relative_path)"
  }
}

foreach ($name in @(
    'issue13-v5-compatibility-baseline-override.R',
    'issue13-v5-compare-override.R'
  )) {
  $from = Join-Path $PSScriptRoot $name
  $to = Join-Path $harnessStaging $name
  Copy-Item -LiteralPath $from -Destination $to
  if ((Get-Issue13V5Sha256 $to) -cne (Get-Issue13V5Sha256 $from)) {
    throw "V5 overlay copy failed authentication: $name"
  }
}

$aggregate = Join-Path $harnessStaging 'issue13-aggregate.R'
$baselineSource = @'
sys.source(file.path(script_dir, "issue13-baseline-runtime-index-lib.R"),
  envir = environment()
)
'@
$baselineReplacement = $baselineSource + "`n" + @'
sys.source(file.path(script_dir, "issue13-v5-compatibility-baseline-override.R"),
  envir = environment()
)
'@
Add-Issue13V5ExactSource $aggregate $baselineSource $baselineReplacement

$compareSource =
  'sys.source(file.path(script_dir, "issue13-compare-lib.R"), envir = environment())'
$compareReplacement = $compareSource + "`n" +
  'sys.source(file.path(script_dir, "issue13-v5-compare-override.R"), ' +
  'envir = environment())'
foreach ($name in @('issue13-compare.R', 'issue13-compare-results.R')) {
  Add-Issue13V5ExactSource (Join-Path $harnessStaging $name) `
    $compareSource $compareReplacement
}

$roleSource =
  '      validation$role_match <- identical(descriptor$role, "diagnostic")'
$roleReplacement = @'
      validation$role_match <- if (
        identical(key, "file:_runtime_resources.rds")
      ) {
        identical(descriptor$role, "metadata")
      } else {
        identical(descriptor$role, "diagnostic")
      }
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource `
  (Join-Path $harnessStaging 'issue13-compare-lib.R') `
  $roleSource $roleReplacement

$inventoryModeSource = @'
                                      comparison_mode = c(
                                        "strict", "cross_engine_run_v3"
                                      )) {
'@.TrimEnd("`r", "`n")
$inventoryModeReplacement = @'
                                      comparison_mode = c(
                                        "strict", "cross_engine_run_v3",
                                        "cross_engine_source_v1"
                                      )) {
'@.TrimEnd("`r", "`n")
$compareLibrary = Join-Path $harnessStaging 'issue13-compare-lib.R'
Add-Issue13V5ExactSource $compareLibrary `
  $inventoryModeSource $inventoryModeReplacement

$crossEngineSource = @'
  cross_engine <- identical(comparison_mode, "cross_engine_run_v3")
  if (cross_engine && (!identical(candidate$kind, "run") ||
      !identical(baseline$kind, "run"))) {
    stop("cross_engine_run_v3 accepts only authenticated run inventories.",
      call. = FALSE
    )
  }
'@.TrimEnd("`r", "`n")
$crossEngineReplacement = @'
  cross_engine_run <- identical(comparison_mode, "cross_engine_run_v3")
  cross_engine_source <- identical(
    comparison_mode, "cross_engine_source_v1"
  )
  cross_engine <- cross_engine_run || cross_engine_source
  if (cross_engine_run && (!identical(candidate$kind, "run") ||
      !identical(baseline$kind, "run"))) {
    stop("cross_engine_run_v3 accepts only authenticated run inventories.",
      call. = FALSE
    )
  }
  if (cross_engine_source && (!identical(candidate$kind, "source") ||
      !identical(baseline$kind, "source"))) {
    stop("cross_engine_source_v1 accepts only authenticated source inventories.",
      call. = FALSE
    )
  }
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $crossEngineSource $crossEngineReplacement

$crossEngineRulesSource = @'
  rules <- if (cross_engine) wlv13_cross_engine_run_rules() else NULL
'@.TrimEnd("`r", "`n")
$crossEngineRulesReplacement = @'
  rules <- if (cross_engine_run) {
    wlv13_cross_engine_run_rules()
  } else if (cross_engine_source) {
    list(
      normalized = "file:_unit_contract.csv",
      candidate_only = character()
    )
  } else {
    NULL
  }
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $crossEngineRulesSource $crossEngineRulesReplacement
Add-Issue13V5ExactSource $compareLibrary `
  '    } else if (cross_engine && identical(key, "file:_anomalies.csv")) {' `
  '    } else if (cross_engine_run && identical(key, "file:_anomalies.csv")) {'

$modeChoicesSource =
  '  match.arg(options$comparison_mode, c("strict", "cross_engine_run_v3"))'
$modeChoicesReplacement = @'
  match.arg(options$comparison_mode, c(
    "strict", "cross_engine_run_v3", "cross_engine_source_v1"
  ))
'@.TrimEnd("`r", "`n")
foreach ($name in @('issue13-compare.R', 'issue13-compare-results.R')) {
  Add-Issue13V5ExactSource (Join-Path $harnessStaging $name) `
    $modeChoicesSource $modeChoicesReplacement
}

$preparationCompare = Join-Path $staging 'issue13-preparation-compare.R'
$preparationCsvSource = @'
  csv_names <- c(
    "_normalization_contract.csv",
    "_source_manifest.csv",
    "_unit_contract.csv",
    "countries.csv",
    "demand.csv",
    "sectors.csv"
  )
  csv <- lapply(csv_names, function(name) {
    wlv_gate_compare_csv(
      file.path(baseline, name),
      file.path(candidate, name),
      paste0(source, "/normalized/", name)
    )
  })
  names(csv) <- csv_names
'@.TrimEnd("`r", "`n")
$preparationCsvReplacement = @'
  csv_names <- c(
    "_normalization_contract.csv", "countries.csv", "demand.csv",
    "sectors.csv"
  )
  csv <- lapply(csv_names, function(name) {
    wlv_gate_compare_csv(
      file.path(baseline, name),
      file.path(candidate, name),
      paste0(source, "/normalized/", name)
    )
  })
  names(csv) <- csv_names
  unit_projection <- function(path) {
    value <- wlv_gate_read_character_csv(path)
    value <- value[setdiff(
      names(value), c("module", "aggregation_notes")
    )]
    row.names(value) <- NULL
    value
  }
  unit_contract_equal <- identical(
    unit_projection(file.path(baseline, "_unit_contract.csv")),
    unit_projection(file.path(candidate, "_unit_contract.csv"))
  )
  csv[["_unit_contract.csv"]] <- list(
    passed = unit_contract_equal,
    comparison_mode = "architecture-projected-unit-contract",
    projected_fields = as.list(c("module", "aggregation_notes"))
  )
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $preparationCompare `
  $preparationCsvSource $preparationCsvReplacement

$preparationManifestSource = @'
  manifest_tables_identical <- identical(
    baseline_manifest_table,
    candidate_manifest_table
  )
  passed <- isTRUE(baseline_manifest$passed) &&
    isTRUE(candidate_manifest$passed) && manifest_tables_identical &&
'@.TrimEnd("`r", "`n")
$preparationManifestReplacement = @'
  manifest_projection <- function(value) {
    value <- value[, setdiff(
      names(value), c("source_generation_id", "contract_sha256")
    ), drop = FALSE]
    unit_row <- value$artifact == "_unit_contract.csv"
    if (sum(unit_row) != 1L) {
      stop("Source manifest must contain exactly one unit-contract row.",
        call. = FALSE
      )
    }
    value$size_bytes[unit_row] <- "<architecture-projected>"
    value$sha256[unit_row] <- "<architecture-projected>"
    row.names(value) <- NULL
    value
  }
  manifest_tables_identical <- identical(
    baseline_manifest_table,
    candidate_manifest_table
  )
  manifest_tables_architecture_projected_equal <- identical(
    manifest_projection(baseline_manifest_table),
    manifest_projection(candidate_manifest_table)
  )
  csv[["_source_manifest.csv"]] <- list(
    passed = manifest_tables_architecture_projected_equal,
    comparison_mode = "architecture-projected-source-manifest",
    projected_fields = as.list(c(
      "source_generation_id", "contract_sha256",
      "_unit_contract.csv:size_bytes", "_unit_contract.csv:sha256"
    ))
  )
  passed <- isTRUE(baseline_manifest$passed) &&
    isTRUE(candidate_manifest$passed) &&
    manifest_tables_architecture_projected_equal &&
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $preparationCompare `
  $preparationManifestSource $preparationManifestReplacement
Add-Issue13V5ExactSource $preparationCompare `
  '    manifest_tables_identical = manifest_tables_identical,' `
  @'
    manifest_tables_identical = manifest_tables_identical,
    manifest_tables_architecture_projected_equal =
      manifest_tables_architecture_projected_equal,
'@.TrimEnd("`r", "`n")

Add-Issue13V5ExactSource $preparationCompare `
  '      "wlv-issue13-preparation-rule-matrix/1") ||' `
  '      "wlv-issue13-preparation-rule-matrix/2") ||'

$ruleMatrixPath = Join-Path $staging 'issue13-preparation-rule-matrix.json'
$ruleMatrix = [IO.File]::ReadAllText($ruleMatrixPath, $utf8) |
  ConvertFrom-Json -DateKind String
if ([string]$ruleMatrix.schema -cne
      'wlv-issue13-preparation-rule-matrix/1' -or
    @($ruleMatrix.comparison_modes.preparation_cross_engine.rules).Count -ne
      10 -or
    @($ruleMatrix.comparison_modes.fault_within_engine.rules).Count -ne 5) {
  throw 'Canonical preparation rule matrix differs before V5 projection.'
}
$ruleMatrix.schema = 'wlv-issue13-preparation-rule-matrix/2'
$ruleMatrix.comparison_modes.preparation_cross_engine.candidate =
  'candidate-runtime-pinned-by-v5-config'
$ruleMatrix.comparison_modes.fault_within_engine.candidate =
  'candidate-runtime-pinned-by-v5-config'
$manifestRule = @(
  $ruleMatrix.comparison_modes.preparation_cross_engine.rules |
    Where-Object { [string]$_.id -ceq 'source-manifests' }
)
$contractRule = @(
  $ruleMatrix.comparison_modes.preparation_cross_engine.rules |
    Where-Object { [string]$_.id -ceq 'contracts-and-labels' }
)
if ($manifestRule.Count -ne 1 -or $contractRule.Count -ne 1) {
  throw 'Preparation architecture rules are absent or ambiguous.'
}
$manifestRule[0].comparison =
  'each arm has exact schema and authenticated artifacts; cross-engine projection removes source_generation_id, contract_sha256, and the _unit_contract.csv row size/hash'
$contractRule[0].comparison =
  'exact schema, ordering, labels, and UTF-8 content; only module and aggregation_notes are projected from _unit_contract.csv across engines'
$ruleMatrixPayload = ($ruleMatrix | ConvertTo-Json -Depth 20) + "`n"
Set-Issue13V5Utf8Text $ruleMatrixPath $ruleMatrixPayload

$readme = Join-Path $harnessStaging 'README.md'
$readmeValue = [IO.File]::ReadAllText($readme, $utf8) + @'

## V5 compatibility-oracle cut

This materialized copy is V5 tooling, not V4 evidence. The immutable origin is
`cc2c86189a06676bcb9f0e05e08033d710a92509`. Every final baseline scenario is
bound to one clean direct child authenticated by its complete binary diff. The
strict cc2 smoke is retained separately as negative evidence and is never
imported as final scenario evidence. The candidate-only
`_runtime_resources.rds` is accepted only after the candidate runtime validates
its complete cryptographic and semantic binding.

Baseline and candidate normalized sources are authenticated independently.
Their scientific arrays remain bitwise comparable; only source-generation and
aggregation-routing metadata are projected across the architectural cut.
'@
Set-Issue13V5Utf8Text $readme $readmeValue

$outputInventory = Get-Issue13V5Inventory $staging 'output'
if ([long]$outputInventory.file_count -ne $expectedOutputFileCount -or
    [long]$outputInventory.total_bytes -ne $expectedOutputTotalBytes -or
    [string]$outputInventory.inventory_sha256 -cne $expectedOutputInventory) {
  throw 'Materialized V5 tooling differs from the sealed output inventory.'
}
$manifest = [ordered]@{
  schema = 'wlv-issue13-v5-harness-materialization/1'
  generation = 'v5'
  status = 'materialized'
  materialized_at_utc = [DateTime]::UtcNow.ToString('o')
  baseline_commit = $baselineCommit
  baseline_policy = 'authenticated-direct-child-compatibility-oracle'
  baseline_runtime_commit = 'e2f4d6dae9a6d35c966b305fabac52e489faa3e7'
  baseline_runtime_tree = '7da19c4f2913e857040ba228280f404b0e54eaab'
  baseline_overlay_sha256 =
    '9f9b878f8e557973127e6260a0f224c868a0c4e8dc2db52dd6aa3f7131f28cd9'
  baseline_overlay_patch_id = '253ca5f1397132f94e3432264084a37395c60ec3'
  strict_negative_evidence_required = $true
  final_evidence_eligible = $true
  reuses_candidate_evidence = $false
  source_controller = [ordered]@{
    candidate_commit = $CandidateCommit
    file_count = 11
    records = [object[]]$controllerPins
  }
  source_tooling = [ordered]@{
    root = $source
    file_count = $sourceInventory.file_count
    total_bytes = $sourceInventory.total_bytes
    inventory_sha256 = $sourceInventory.inventory_sha256
  }
  output_tooling = [ordered]@{
    file_count = $outputInventory.file_count
    total_bytes = $outputInventory.total_bytes
    inventory_sha256 = $outputInventory.inventory_sha256
  }
  sealed_output_tooling = [ordered]@{
    file_count = $expectedOutputFileCount
    total_bytes = $expectedOutputTotalBytes
    inventory_sha256 = $expectedOutputInventory
  }
  overlays = @(
    'authenticated-compatibility-oracle-cc2',
    'authenticated-candidate-runtime-sidecar',
    'authenticated-arm-specific-source-contracts'
  )
}
$manifestPath = Join-Path $staging 'v5-harness-manifest.json'
$manifestJson = $manifest | ConvertTo-Json -Depth 20
Set-Issue13V5Utf8Text $manifestPath ($manifestJson + "`n")

if (Test-Path -LiteralPath $destinationFull) {
  throw 'The V5 destination appeared during materialization.'
}
Move-Item -LiteralPath $staging -Destination $destinationFull
$installedManifest = Join-Path $destinationFull 'v5-harness-manifest.json'
if (-not (Test-Path -LiteralPath $installedManifest -PathType Leaf)) {
  throw 'The V5 harness was not installed atomically.'
}
$installedInventory = Get-Issue13V5Inventory $destinationFull 'output'
if ([long]$installedInventory.file_count -ne $expectedOutputFileCount -or
    [long]$installedInventory.total_bytes -ne $expectedOutputTotalBytes -or
    [string]$installedInventory.inventory_sha256 -cne
      $expectedOutputInventory) {
  throw 'Installed V5 tooling differs from the sealed output inventory.'
}

[pscustomobject][ordered]@{
  status = 'materialized'
  destination = (Resolve-Path -LiteralPath $destinationFull).Path
  manifest_path = (Resolve-Path -LiteralPath $installedManifest).Path
  manifest_sha256 = Get-Issue13V5Sha256 $installedManifest
  baseline_commit = $baselineCommit
  source_inventory_sha256 = $sourceInventory.inventory_sha256
  output_inventory_sha256 = $outputInventory.inventory_sha256
}
