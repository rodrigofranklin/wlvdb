param(
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')]
  [string]$CandidateCommit,
  [Parameter(Mandatory = $true)][string]$HarnessRuntimeRoot,
  [Parameter(Mandatory = $true)][string]$BaselineRuntimeIndex,
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')]
  [string]$BaselineRuntimeCommit,
  [Parameter(Mandatory = $true)][string]$BaselineOverlayPatch,
  [Parameter(Mandatory = $true)][string]$StrictBaselineSmokeSummary,
  [Parameter(Mandatory = $true)][string]$CompatibilityBaselineSmokeSummary,
  [Parameter(Mandatory = $true)][string]$WorktreeRoot,
  [Parameter(Mandatory = $true)][string]$EvidenceRoot,
  [Parameter(Mandatory = $true)][string]$ControlRoot,
  [Parameter(Mandatory = $true)][string]$Output,
  [string]$RepositoryRoot = 'D:\Trabalho\Code\wlvdb',
  [string]$SourceOrigin =
    'D:\Trabalho\Code\wlvdb-issue13-baseline\source_data',
  [Parameter(Mandatory = $true)][string]$CandidateSourceOrigin,
  [string]$Rscript =
    'C:\Users\rodri\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe',
  [string]$RLibrary =
    'D:\Trabalho\Code\wlvdb\renv\library\windows\R-4.6\x86_64-w64-mingw32'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$baselineCommit = 'cc2c86189a06676bcb9f0e05e08033d710a92509'
$baselineProfile = 'compatibility-oracle-cc2'
$expectedBaselineRuntimeCommit =
  'e2f4d6dae9a6d35c966b305fabac52e489faa3e7'
$expectedBaselineTree = '7da19c4f2913e857040ba228280f404b0e54eaab'
$expectedOverlaySha256 =
  '9f9b878f8e557973127e6260a0f224c868a0c4e8dc2db52dd6aa3f7131f28cd9'
$expectedOverlayPatchId = '253ca5f1397132f94e3432264084a37395c60ec3'
$strictSmokeSha256 =
  '973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d'
$strictSmokeHarnessSha256 =
  'a17a187621cdd4aff6f24efd6bf43ffbf9336de0a19189dfc7f5a82758a92c23'
$expectedHarnessFileCount = 39L
$expectedHarnessTotalBytes = 591470L
$expectedHarnessInventorySha256 =
  'd8bfacb36402944796baacc4dfa5df168bb8ff667a7ccc28bc94b46afdfc3ea0'
$methods = @(
  'wiodr13', 'wiodr16', 'alternative_1', 'alternative_2', 'norow_w13',
  'ochoa_1', 'ochoa_2', 'petrovic', 'wiodr13v09', 'wiodr16v09',
  'zerodep_1', 'zerodep_2'
)
$recalculations = @(
  [ordered]@{ stage = 1; variant = 'full'; sea_vars = @() },
  [ordered]@{ stage = 4; variant = 'full'; sea_vars = @() },
  [ordered]@{ stage = 5; variant = 'full'; sea_vars = @() },
  [ordered]@{
    stage = 4
    variant = 'select-gross-output-mv'
    sea_vars = @('gross_output.s.mv')
  },
  [ordered]@{
    stage = 5
    variant = 'select-gross-output-du'
    sea_vars = @('gross_output.s.du')
  }
)
$faults = @(
  'module-execution',
  'preparation-promotion',
  'publication-run-staging',
  'publication-semantic-validation',
  'publication-run-manifest',
  'publication-run-promotion',
  'publication-release-staging',
  'publication-release-manifest',
  'publication-release-promotion',
  'publication-channel-marker'
)
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function ConvertTo-Issue13V5FullPath([string]$Path, [bool]$MustExist) {
  $full = [IO.Path]::GetFullPath($Path)
  if ($MustExist -and -not (Test-Path -LiteralPath $full)) {
    throw "Required V5 path does not exist: $full"
  }
  $full
}

function Assert-Issue13V5FreshRoot([string]$Path, [string]$Label) {
  $full = ConvertTo-Issue13V5FullPath $Path $false
  if ($full -match '(?i)(^|[\\/])[^\\/]*v4(?:r[0-9]+)?[^\\/]*($|[\\/])') {
    throw "$Label must not be a V4/V4R2 root: $full"
  }
  if (Test-Path -LiteralPath $full) {
    throw "$Label already exists; V5 never reuses evidence or worktrees: $full"
  }
  $full
}

function Get-Issue13V5Sha256([string]$Path) {
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Issue13V5HarnessInventory([string]$Root) {
  $harnessDirectory = Join-Path $Root 'issue13-evidence-harness'
  $rootDirectories = @(Get-ChildItem -LiteralPath $Root -Directory -Force)
  $harnessDirectories = @(
    Get-ChildItem -LiteralPath $harnessDirectory -Directory -Recurse -Force)
  if ($rootDirectories.Count -ne 1 -or
      $rootDirectories[0].Name -cne 'issue13-evidence-harness' -or
      $harnessDirectories.Count -ne 0) {
    throw 'V5 harness must be a flat, fully inventoried two-level tree.'
  }
  $files = @(
    @(Get-ChildItem -LiteralPath $Root -File -Force | Where-Object {
      $_.Name -cne 'v5-harness-manifest.json'
    }),
    @(Get-ChildItem -LiteralPath $harnessDirectory -File -Force)
  ) | ForEach-Object { $_ }
  $records = @($files | ForEach-Object {
    [pscustomobject]@{
      relative_path = $_.FullName.Substring($Root.Length + 1).Replace('\', '/')
      size_bytes = [long]$_.Length
      sha256 = Get-Issue13V5Sha256 $_.FullName
    }
  } | Sort-Object relative_path)
  $lines = @($records | ForEach-Object {
    [string]$_.relative_path + '|' + [string]$_.size_bytes + '|' +
      [string]$_.sha256
  })
  $bytes = [Text.Encoding]::UTF8.GetBytes([string]::Join("`n", $lines))
  [pscustomobject]@{
    file_count = [long]$records.Count
    total_bytes = [long](($records | Measure-Object size_bytes -Sum).Sum)
    inventory_sha256 = [Convert]::ToHexString(
      [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
  }
}

# The shared validator is itself one of the eleven candidate-pinned controller
# sources. Reuse its smoke/worktree checks here, before any config is emitted.
. (Join-Path $PSScriptRoot 'issue13-v5-coordinator-lib.ps1')

$repository = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $RepositoryRoot $true)).Path
$harnessRuntime = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $HarnessRuntimeRoot $true)).Path
$harness = Join-Path $harnessRuntime 'issue13-evidence-harness'
$harnessManifestPath = Join-Path $harnessRuntime 'v5-harness-manifest.json'
if (-not (Test-Path -LiteralPath $harness -PathType Container) -or
    -not (Test-Path -LiteralPath $harnessManifestPath -PathType Leaf)) {
  throw 'The materialized V5 harness is incomplete.'
}
$harnessManifest = Get-Content -LiteralPath $harnessManifestPath -Raw |
  ConvertFrom-Json -DateKind String
if ([string]$harnessManifest.schema -cne
      'wlv-issue13-v5-harness-materialization/1' -or
    [string]$harnessManifest.generation -cne 'v5' -or
    -not [bool]$harnessManifest.final_evidence_eligible -or
    [bool]$harnessManifest.reuses_candidate_evidence -or
    [string]$harnessManifest.baseline_commit -cne $baselineCommit -or
    [string]$harnessManifest.baseline_policy -cne
      'authenticated-direct-child-compatibility-oracle' -or
    [string]$harnessManifest.baseline_runtime_commit -cne
      $expectedBaselineRuntimeCommit -or
    [string]$harnessManifest.baseline_runtime_tree -cne
      $expectedBaselineTree -or
    [string]$harnessManifest.baseline_overlay_sha256 -cne
      $expectedOverlaySha256 -or
    [string]$harnessManifest.baseline_overlay_patch_id -cne
      $expectedOverlayPatchId -or
    -not [bool]$harnessManifest.strict_negative_evidence_required) {
  throw 'The V5 harness manifest is not final-evidence eligible.'
}
$harnessInventory = Get-Issue13V5HarnessInventory $harnessRuntime
if ([long]$harnessInventory.file_count -ne $expectedHarnessFileCount -or
    [long]$harnessInventory.total_bytes -ne $expectedHarnessTotalBytes -or
    [string]$harnessInventory.inventory_sha256 -cne
      $expectedHarnessInventorySha256 -or
    [long]$harnessManifest.output_tooling.file_count -ne
      $expectedHarnessFileCount -or
    [long]$harnessManifest.output_tooling.total_bytes -ne
      $expectedHarnessTotalBytes -or
    [string]$harnessManifest.output_tooling.inventory_sha256 -cne
      $expectedHarnessInventorySha256 -or
    [long]$harnessManifest.sealed_output_tooling.file_count -ne
      $expectedHarnessFileCount -or
    [long]$harnessManifest.sealed_output_tooling.total_bytes -ne
      $expectedHarnessTotalBytes -or
    [string]$harnessManifest.sealed_output_tooling.inventory_sha256 -cne
      $expectedHarnessInventorySha256) {
  throw 'The materialized V5 harness changed after authentication.'
}
$pinConfig = [pscustomobject]@{
  repository_root = $repository
  candidate_commit = $CandidateCommit
}
$controllerPins = @(Get-Issue13V5CoordinatorPins $pinConfig)
if ($controllerPins.Count -ne 11 -or
    [string]$harnessManifest.source_controller.candidate_commit -cne
      $CandidateCommit -or
    [long]$harnessManifest.source_controller.file_count -ne 11L -or
    @($harnessManifest.source_controller.records).Count -ne 11) {
  throw 'The V5 harness does not bind all eleven controller sources.'
}
for ($pinIndex = 0; $pinIndex -lt $controllerPins.Count; $pinIndex++) {
  foreach ($field in @('name', 'relative_path', 'sha256', 'git_blob')) {
    if ([string]$harnessManifest.source_controller.records[$pinIndex].$field `
        -cne [string]$controllerPins[$pinIndex].$field) {
      throw "The V5 harness controller binding changed: $($controllerPins[$pinIndex].name)/$field"
    }
  }
}

$runtimeIndex = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $BaselineRuntimeIndex $true)).Path
$index = Get-Content -LiteralPath $runtimeIndex -Raw |
  ConvertFrom-Json -DateKind String
$overlayPatch = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $BaselineOverlayPatch $true)).Path
$strictSmokePath = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $StrictBaselineSmokeSummary $true)).Path
$compatibilitySmokePath = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $CompatibilityBaselineSmokeSummary $true)).Path
$strictSmoke = Get-Content -LiteralPath $strictSmokePath -Raw |
  ConvertFrom-Json -DateKind String
$compatibilitySmoke = Get-Content -LiteralPath $compatibilitySmokePath -Raw |
  ConvertFrom-Json -DateKind String
if ($BaselineRuntimeCommit -cne $expectedBaselineRuntimeCommit -or
    (Get-Issue13V5Sha256 $overlayPatch) -cne $expectedOverlaySha256) {
  throw 'The requested baseline runtime or patch differs from the sealed oracle.'
}
$expectedBaselineScenarios = [Collections.Generic.List[string]]::new()
foreach ($method in $methods) {
  $expectedBaselineScenarios.Add("baseline/calculate/$method/workers1")
  foreach ($recalculation in $recalculations) {
    $expectedBaselineScenarios.Add(
      "baseline/recalculate/$method/stage$($recalculation.stage)/" +
        [string]$recalculation.variant
    )
  }
}
foreach ($method in @('wiodr13', 'wiodr16')) {
  $expectedBaselineScenarios.Add("baseline/calculate/$method/workers2")
}
$expectedBaselineScenarios.Add('baseline/prepare/all')
$expectedBaselineScenarios.Add('baseline/paper/0')
$expectedBaselineIds = @($expectedBaselineScenarios.ToArray() | Sort-Object)
$actualBaselineIds = @($index.scenarios.scenario_id | Sort-Object)
if ([string]$index.schema -cne 'wlv-issue13-baseline-runtime-index/1' -or
    [string]$index.baseline_base_commit -cne $baselineCommit -or
    @($index.profiles).Count -ne 1 -or
    [string]$index.profiles[0].id -cne $baselineProfile -or
    [string]$index.profiles[0].inventory_value -cne $baselineProfile -or
    [string]$index.profiles[0].source_commit -cne $BaselineRuntimeCommit -or
    [string]$index.profiles[0].runtime_commit -cne $BaselineRuntimeCommit -or
    [bool]$index.profiles[0].run_dirty -or
    -not [string]::Equals(
      (ConvertTo-Issue13V5FullPath `
        ([string]$index.profiles[0].overlay_patch_path) $true),
      $overlayPatch, [StringComparison]::OrdinalIgnoreCase) -or
    [string]$index.profiles[0].overlay_patch_sha256 -cne
      (Get-Issue13V5Sha256 $overlayPatch) -or
    [string]$index.profiles[0].overlay_patch_id -cne
      $expectedOverlayPatchId -or
    @($index.scenarios).Count -ne 76 -or
    @($index.scenarios.scenario_id | Sort-Object -Unique).Count -ne 76 -or
    [string]::Join("`n", $actualBaselineIds) -cne
      [string]::Join("`n", $expectedBaselineIds) -or
    @($index.scenarios | Where-Object {
      [string]$_.runtime_commit -cne $BaselineRuntimeCommit -or
      [string]$_.profile_id -cne $baselineProfile
    }).Count -ne 0) {
  throw 'The V5 baseline index is not the authenticated compatibility oracle.'
}
if ([string]$strictSmoke.schema -cne 'wlv-issue13-v5-baseline-smoke/1' -or
    (Get-Issue13V5Sha256 $strictSmokePath) -cne $strictSmokeSha256 -or
    [bool]$strictSmoke.final_evidence_eligible -or
    [string]$strictSmoke.purpose -cne
      'strict-cc2-executability-preflight' -or
    [string]$strictSmoke.baseline_commit -cne $baselineCommit -or
    [bool]$strictSmoke.passed -or [string]$strictSmoke.status -cne 'failed' -or
    [long]$strictSmoke.passed_count -ne 5 -or
    [long]$strictSmoke.failed_count -ne 7 -or
    @($strictSmoke.records).Count -ne 12 -or
    [string]$strictSmoke.source_inventory_sha256 -cne
      'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26' -or
    [string]$strictSmoke.harness_manifest_sha256 -cne
      $strictSmokeHarnessSha256 -or
    [string]::Join("`n", @($strictSmoke.records.method)) -cne
      [string]::Join("`n", $methods) -or
    [string]::Join("`n", @($strictSmoke.records |
        Where-Object status -ceq 'failed' | ForEach-Object method)) -cne
      "alternative_1`nalternative_2`nnorow_w13`nochoa_1`nochoa_2`npetrovic`nwiodr13v09") {
  throw 'The authenticated strict cc2 smoke is not the expected 5/7 evidence.'
}
if ([string]$compatibilitySmoke.schema -cne
      'wlv-issue13-v5-baseline-smoke/1' -or
    [bool]$compatibilitySmoke.final_evidence_eligible -or
    [string]$compatibilitySmoke.purpose -cne
      'compatibility-oracle-executability-preflight' -or
    [string]$compatibilitySmoke.baseline_base_commit -cne $baselineCommit -or
    [string]$compatibilitySmoke.baseline_runtime_commit -cne
      $BaselineRuntimeCommit -or
    -not [bool]$compatibilitySmoke.passed -or
    [string]$compatibilitySmoke.status -cne 'passed' -or
    [long]$compatibilitySmoke.passed_count -ne 12 -or
    [long]$compatibilitySmoke.failed_count -ne 0 -or
    @($compatibilitySmoke.records).Count -ne 12 -or
    [string]$compatibilitySmoke.source_inventory_sha256 -cne
      'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26' -or
    [string]$compatibilitySmoke.harness_manifest_sha256 -cne
      (Get-Issue13V5Sha256 $harnessManifestPath) -or
    [string]::Join("`n", @($compatibilitySmoke.records.method)) -cne
      [string]::Join("`n", $methods) -or
    @($compatibilitySmoke.records | Where-Object status -cne 'passed').Count `
      -ne 0) {
  throw 'The compatibility-oracle smoke did not pass all 12 methods.'
}
$strictFailedMethods = @(
  'alternative_1', 'alternative_2', 'norow_w13', 'ochoa_1', 'ochoa_2',
  'petrovic', 'wiodr13v09'
)
$null = Assert-Issue13V5BaselineSmokeEvidence $pinConfig $strictSmokePath `
  'strict-cc2-executability-preflight' $baselineCommit `
  $strictSmokeHarnessSha256 $false $strictFailedMethods $strictSmokeSha256
$null = Assert-Issue13V5BaselineSmokeEvidence $pinConfig `
  $compatibilitySmokePath 'compatibility-oracle-executability-preflight' `
  $BaselineRuntimeCommit (Get-Issue13V5Sha256 $harnessManifestPath) `
  $true @() (Get-Issue13V5Sha256 $compatibilitySmokePath)

$null = & git -C $repository cat-file -e ($BaselineRuntimeCommit + '^{commit}')
if ($LASTEXITCODE -ne 0) {
  throw "Compatibility runtime commit is unavailable: $BaselineRuntimeCommit"
}
$baselineParent = (& git -C $repository rev-parse `
  ($BaselineRuntimeCommit + '^') 2>$null).Trim()
$baselineTree = (& git -C $repository rev-parse `
  ($BaselineRuntimeCommit + '^{tree}') 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $baselineParent -cne $baselineCommit -or
    $baselineTree -cne $expectedBaselineTree) {
  throw 'The compatibility runtime must be one direct child of cc2.'
}
$null = & git -C $repository cat-file -e ($CandidateCommit + '^{commit}')
if ($LASTEXITCODE -ne 0) {
  throw "Candidate commit is unavailable: $CandidateCommit"
}
$null = & git -C $repository merge-base --is-ancestor `
  $baselineCommit $CandidateCommit
if ($LASTEXITCODE -ne 0 -or $CandidateCommit -ceq $baselineCommit -or
    $CandidateCommit -ceq $BaselineRuntimeCommit) {
  throw 'The candidate must be a strict descendant of the Issue #12 merge.'
}
$null = & git -C $repository merge-base --is-ancestor `
  $BaselineRuntimeCommit $CandidateCommit 2>$null
$oracleAncestorExit = $LASTEXITCODE
if ($oracleAncestorExit -eq 0) {
  throw 'The compatibility oracle must remain outside the candidate history.'
}
if ($oracleAncestorExit -ne 1) {
  throw 'Cannot prove that the compatibility oracle is outside the candidate history.'
}

$source = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $SourceOrigin $true)).Path
$candidateSource = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $CandidateSourceOrigin $true)).Path
$rscriptFull = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $Rscript $true)).Path
$library = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $RLibrary $true)).Path
$worktrees = Assert-Issue13V5FreshRoot $WorktreeRoot 'Worktree root'
$evidence = Assert-Issue13V5FreshRoot $EvidenceRoot 'Evidence root'
$control = Assert-Issue13V5FreshRoot $ControlRoot 'Control root'
$outputFull = ConvertTo-Issue13V5FullPath $Output $false
if (Test-Path -LiteralPath $outputFull) {
  throw "Refusing to overwrite the V5 gate config: $outputFull"
}
foreach ($rootPath in @($worktrees, $evidence, $control)) {
  if ([string]::Equals($outputFull, $rootPath,
      [StringComparison]::OrdinalIgnoreCase) -or
      $outputFull.StartsWith($rootPath.TrimEnd('\') + '\',
        [StringComparison]::OrdinalIgnoreCase) -or
      $rootPath.StartsWith($outputFull.TrimEnd('\') + '\',
        [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The V5 config output must be outside worktree, evidence, and control roots.'
  }
}

$sciencePhases = [Collections.Generic.List[object]]::new()
foreach ($method in $methods) {
  $sciencePhases.Add([ordered]@{
    phase = "calculate/$method/workers1"
    kind = 'calculate'
    method = $method
    workers = 1
    stage = $null
    variant = $null
    sea_vars = @()
  })
  foreach ($recalculation in $recalculations) {
    $sciencePhases.Add([ordered]@{
      phase = "recalculate/$method/stage$($recalculation.stage)/" +
        [string]$recalculation.variant
      kind = 'recalculate'
      method = $method
      workers = 1
      stage = [int]$recalculation.stage
      variant = [string]$recalculation.variant
      sea_vars = @($recalculation.sea_vars)
    })
  }
}
foreach ($method in @('wiodr13', 'wiodr16')) {
  $sciencePhases.Add([ordered]@{
    phase = "calculate/$method/workers2"
    kind = 'calculate'
    method = $method
    workers = 2
    stage = $null
    variant = $null
    sea_vars = @()
  })
}
if ($sciencePhases.Count -ne 74) {
  throw 'The internal V5 science matrix is not exactly 74 phases.'
}

$methodRoots = @($methods | ForEach-Object {
  [ordered]@{
    method = $_
    baseline = Join-Path $worktrees ('baseline-' + $_)
    candidate = Join-Path $worktrees ('candidate-' + $_)
    baseline_runtime_commit = $BaselineRuntimeCommit
    candidate_runtime_commit = $CandidateCommit
    baseline_seed_commit = $BaselineRuntimeCommit
    candidate_seed_commit = $CandidateCommit
  }
})

$persistentCommand =
  '"C:\Users\rodri\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe" --vanilla run-local-panel.R'
$persistentHashBytes = [Text.Encoding]::UTF8.GetBytes($persistentCommand)
$persistentHash = [Convert]::ToHexString(
  [Security.Cryptography.SHA256]::HashData($persistentHashBytes)
).ToLowerInvariant()

$sourceContractBindings = @(
  [ordered]@{
    arm = 'baseline'; source = 'wiodr13'
    runtime_commit = $BaselineRuntimeCommit
    manifest_relative_path = 'wiodr13/normalized/_source_manifest.csv'
    manifest_sha256 =
      'cd3ee98c7b823b1efa9b1272dca660a3977cc4a185b033263c2bef09cc1f73a8'
    source_generation_id =
      '65691585592c9cb6dc628c46606f004113f808e5b74c511c89678fae32032e2d'
    contract_id = 'wiodr13_units_v2'; contract_version = '2'
    contract_sha256 =
      'f7e04664e357d6a334685e48eced6428dfdd410f5b9811785a0ad0f696cc65eb'
    units_relative_path = 'contracts/units/wiodr13_v2-units.csv'
    units_sha256 =
      'ff1ab869e72d18879dc2e69c61c911425d73b612870c06317047accf9520ff11'
    units_git_blob = 'c89f1ca1e463d05a0b0ec683bee16084d39f4ac3'
    aggregations_relative_path =
      'contracts/units/wiodr13_v2-aggregations.csv'
    aggregations_sha256 =
      'e830708911f5b6674f44e51e8625de9a072ccf5cd91395954e1040f81372004a'
    aggregations_git_blob = '4d98444799af4c715f07a3b8a0ea4c1c1570a87c'
  },
  [ordered]@{
    arm = 'baseline'; source = 'wiodr16'
    runtime_commit = $BaselineRuntimeCommit
    manifest_relative_path = 'wiodr16/normalized/_source_manifest.csv'
    manifest_sha256 =
      '091183d74d97f5bc22209e57be0314c5ea5e510ae3573eaf2b342237de903aa9'
    source_generation_id =
      'f135fddb4723ba3cdf29164cf1b7ec006693cc201feaf2063f91fa104e942a7a'
    contract_id = 'wiodr16_units_v2'; contract_version = '2'
    contract_sha256 =
      '94b9f78e8977001fab92e8fa8528aea5b97a3f22809bec58a16a56f413a6acf7'
    units_relative_path = 'contracts/units/wiodr16_v2-units.csv'
    units_sha256 =
      'dfd73aa1e7721a139b04345c1e9fc48dc0a0a875659b8385a73292b2fba90143'
    units_git_blob = 'fcf432fd4ddc6fd54acf88ef809e241b5e3f0cf7'
    aggregations_relative_path =
      'contracts/units/wiodr16_v2-aggregations.csv'
    aggregations_sha256 =
      'bbee477efe375ffee47dc69ad86d9176d3e57d4292461d86423bbe68a9cbc642'
    aggregations_git_blob = '339de049570be34158a5599de05d1eea4175cacd'
  },
  [ordered]@{
    arm = 'candidate'; source = 'wiodr13'
    runtime_commit = $CandidateCommit
    manifest_relative_path = 'wiodr13/normalized/_source_manifest.csv'
    manifest_sha256 =
      'b454f0f05890374cebde8b1b3222da4b4b63b887f67283fe12c97a351adc0bb8'
    source_generation_id =
      'b16a64edd8f3cdf117002fda011e1ba19f17e3fa72936671bb98dffeb0207856'
    contract_id = 'wiodr13_units_v2'; contract_version = '2'
    contract_sha256 =
      '1f2462835e70d5681d7a5b9b29be5f0598cdb35a9abd72d3d147a6636ae5c905'
    units_relative_path = 'contracts/units/wiodr13_v2-units.csv'
    units_sha256 =
      'ff1ab869e72d18879dc2e69c61c911425d73b612870c06317047accf9520ff11'
    units_git_blob = 'c89f1ca1e463d05a0b0ec683bee16084d39f4ac3'
    aggregations_relative_path =
      'contracts/units/wiodr13_v2-aggregations.csv'
    aggregations_sha256 =
      'c5c9779772101380514b6dbb937de48036280e66df382f2eb84f122ec91384d3'
    aggregations_git_blob = '20fbc53bb31261b0a698ae6ac56b0344772e1e6a'
  },
  [ordered]@{
    arm = 'candidate'; source = 'wiodr16'
    runtime_commit = $CandidateCommit
    manifest_relative_path = 'wiodr16/normalized/_source_manifest.csv'
    manifest_sha256 =
      '28dc13d3abb9856fb984b01eb60379e213e6e0cfae58e8fb08c3b882c19c1a35'
    source_generation_id =
      '1f747ab8d53abe8cc674b0842796a5c9b936b036a79b48715b9e04734f949976'
    contract_id = 'wiodr16_units_v2'; contract_version = '2'
    contract_sha256 =
      '3b23ab671df4905dee50b35efd8dff8d4897f65f2b74a2677d7614d9137e801a'
    units_relative_path = 'contracts/units/wiodr16_v2-units.csv'
    units_sha256 =
      'dfd73aa1e7721a139b04345c1e9fc48dc0a0a875659b8385a73292b2fba90143'
    units_git_blob = 'fcf432fd4ddc6fd54acf88ef809e241b5e3f0cf7'
    aggregations_relative_path =
      'contracts/units/wiodr16_v2-aggregations.csv'
    aggregations_sha256 =
      '227c32c390e019a8ccb231db1bca898667bc31d75b599beda083799fa9d27278'
    aggregations_git_blob = '516f2dc29ed594df42605811a18af49bc9328d71'
  }
)

$config = [ordered]@{
  schema = 'wlv-issue13-native-gate-config/3'
  generation = 'v5'
  created_at_utc = [DateTime]::UtcNow.ToString('o')
  final_evidence_eligible = $true
  reuse_policy = [ordered]@{
    v4_evidence_allowed = $false
    candidate_evidence_reuse_allowed = $false
    imported_scenario_evidence_allowed = $false
    fresh_roots_required = $true
  }
  repository_root = $repository
  harness_runtime_root = $harnessRuntime
  harness_root = $harness
  harness_manifest_path = $harnessManifestPath
  harness_manifest_sha256 = Get-Issue13V5Sha256 $harnessManifestPath
  worktree_root = $worktrees
  evidence_root = $evidence
  control_root = $control
  source_origin = $source
  source_inventory = [ordered]@{
    file_count = 84
    directory_count = 5
    total_bytes = 2946498269L
    inventory_sha256 =
      'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26'
    directory_list_sha256 =
      '8b3a622a748f2489fe8cfd2a8273ec98ad4c372b2378d587a5ee2e3c5c916640'
  }
  candidate_source_origin = $candidateSource
  candidate_source_inventory = [ordered]@{
    file_count = 76
    directory_count = 6
    total_bytes = 2035522216L
    inventory_sha256 =
      '22e90e9485d7cee19d1de786c3464106d9a857ad3d85d0c9f2b3d912a0f38026'
    directory_list_sha256 =
      'c75aa417f14cded3c3bb6028effc8acadd64a32e86fddc0f1278079acdb6f114'
  }
  source_contract_bindings = [object[]]$sourceContractBindings
  rscript = $rscriptFull
  r_library = $library
  baseline_commit = $baselineCommit
  baseline_base_commit = $baselineCommit
  baseline_runtime_commit = $BaselineRuntimeCommit
  baseline_profile = $baselineProfile
  baseline_overlay = [ordered]@{
    path = $overlayPatch
    sha256 = Get-Issue13V5Sha256 $overlayPatch
    patch_id = [string]$index.profiles[0].overlay_patch_id
  }
  strict_baseline_smoke = [ordered]@{
    path = $strictSmokePath
    sha256 = Get-Issue13V5Sha256 $strictSmokePath
    passed_count = 5
    failed_count = 7
    final_evidence_eligible = $false
  }
  compatibility_baseline_smoke = [ordered]@{
    path = $compatibilitySmokePath
    sha256 = Get-Issue13V5Sha256 $compatibilitySmokePath
    passed_count = 12
    failed_count = 0
    final_evidence_eligible = $false
  }
  candidate_commit = $CandidateCommit
  candidate_seed_commit = $CandidateCommit
  baseline_runtime_index = $runtimeIndex
  baseline_runtime_index_sha256 = Get-Issue13V5Sha256 $runtimeIndex
  methods = $methodRoots
  supplemental_roots = [ordered]@{
    baseline_preparation = Join-Path $worktrees 'baseline-preparation'
    candidate_preparation = Join-Path $worktrees 'candidate-preparation'
    baseline_paper0 = Join-Path $worktrees 'baseline-paper0'
    candidate_paper0 = Join-Path $worktrees 'candidate-paper0'
    candidate_fault = Join-Path $worktrees 'candidate-fault'
  }
  matrix = [ordered]@{
    method_count = 12
    science_phase_count = 74
    paired_phase_count = 76
    monitored_scenario_count = 162
    authenticated_comparison_count = 202
    fault_count = 10
    science_phases = $sciencePhases.ToArray()
    supplemental_phases = @('prepare/all', 'paper/0')
    faults = $faults
  }
  comparison = [ordered]@{
    numerical_tolerance = 'contract-only-no-new-tolerance'
    compare_dimensions = $true
    compare_dimnames = $true
    compare_finite_values = $true
    distinguish_na_nan_posinf_neginf = $true
    compare_semantic_states = $true
    compare_metadata_and_contracts = $true
    compare_method_matrices = $true
    compare_diagnostics_as_duplicate_preserving_multisets = $true
    compare_unselected_cells = $true
    ignore_only = @('timestamps', 'paths', 'run_id', 'result_id',
      'provenance-dependent-container-bytes')
    candidate_only_artifacts = @(
      '_nonfinite_resolution_diagnostics.csv',
      '_runtime_resources.rds'
    )
    preparation_architecture_projection = @(
      'module', 'aggregation_notes', 'source_generation_id',
      'contract_sha256', '_unit_contract.csv:size_bytes',
      '_unit_contract.csv:sha256', 'm_io.fst.meta:size_bytes',
      'm_io.fst.meta:sha256', 'sea.fst.meta:size_bytes',
      'sea.fst.meta:sha256'
    )
  }
  performance = [ordered]@{
    candidate_time_ratio_maximum = 1.2
    candidate_rss_baseline_ratio_allowance = 0.1
    candidate_rss_minimum_allowance_bytes = 536870912L
    workers2_methods = @('wiodr13', 'wiodr16')
    require_cluster_closed = $true
  }
  preparation = [ordered]@{
    sources = @('wiodr13', 'wiodr16', 'euklems')
    same_official_cache_inventory = $true
    bitwise_arrays = $true
    require_atomic_promotion = $true
  }
  paper0 = [ordered]@{
    methods = @('ochoa_1', 'ochoa_2')
    workbook_semantic_comparison = $true
    unsupported_papers = @(3, 4)
  }
  report = [ordered]@{
    required_path = 'docs/validation/issue-13.md'
    required_fields = @(
      'baseline_commit', 'baseline_base_commit', 'baseline_runtime_commit',
      'strict_baseline_smoke', 'compatibility_baseline_smoke',
      'baseline_overlay_patch', 'candidate_commit', 'source_ids', 'commands',
      'hashes', 'times', 'peak_rss', 'differences', 'fault_results',
      'preparation_results', 'paper0_results'
    )
  }
  allowed_r_processes = @([ordered]@{
    pid = 30272
    command_line_sha256 = $persistentHash
  })
}

$outputParent = Split-Path -Parent $outputFull
if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $outputParent
}
$outputParent = (Resolve-Path -LiteralPath $outputParent).Path
$outputFull = Join-Path $outputParent ([IO.Path]::GetFileName($outputFull))
$temporary = Join-Path $outputParent (
  '.' + [IO.Path]::GetFileName($outputFull) + '-' +
    [Guid]::NewGuid().ToString('N') + '.tmp'
)
$payload = ($config | ConvertTo-Json -Depth 100) + "`n"
[IO.File]::WriteAllText($temporary, $payload, $utf8)
$roundtripText = [IO.File]::ReadAllText($temporary, $utf8)
if (-not [string]::Equals($roundtripText, $payload,
    [StringComparison]::Ordinal)) {
  throw 'V5 config UTF-8 round trip failed.'
}
$roundtrip = $roundtripText | ConvertFrom-Json -DateKind String
if ([string]$roundtrip.generation -cne 'v5' -or
    [string]$roundtrip.baseline_commit -cne $baselineCommit -or
    [string]$roundtrip.baseline_runtime_commit -cne $BaselineRuntimeCommit -or
    @($roundtrip.matrix.science_phases).Count -ne 74) {
  throw 'V5 config JSON round trip changed the contract.'
}
if (Test-Path -LiteralPath $outputFull) {
  throw 'The V5 config target appeared during generation.'
}
Move-Item -LiteralPath $temporary -Destination $outputFull
$installed = [IO.File]::ReadAllText($outputFull, $utf8)
if (-not [string]::Equals($installed, $payload, [StringComparison]::Ordinal)) {
  throw 'Installed V5 config differs from its verified UTF-8 payload.'
}

[pscustomobject][ordered]@{
  status = 'created'
  config_path = (Resolve-Path -LiteralPath $outputFull).Path
  config_sha256 = Get-Issue13V5Sha256 $outputFull
  baseline_commit = $baselineCommit
  baseline_runtime_commit = $BaselineRuntimeCommit
  candidate_commit = $CandidateCommit
  paired_phases = 76
  scenarios = 162
  comparisons = 202
  faults = 10
}
