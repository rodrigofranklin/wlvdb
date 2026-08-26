param(
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')]
  [string]$CandidateCommit,
  [string]$HarnessRuntimeRoot =
    'D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5',
  [string]$RepositoryRoot = 'D:\Trabalho\Code\wlvdb'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$bootstrapSourceSha256 = @{
  'issue13-v5-attest-delivery.ps1' =
    'A22D1EAEF94B3378EF71C2DD8575B43347DDB7EE6B3769D8533C4A7DF10B795A'
  'issue13-v5-baseline-smoke.ps1' =
    '039795827BFBECC53EBAEFE80C9543804CF020C5F3CC59DA5771C253B52258A8'
  'issue13-v5-capture-clean-bridge-evidence.ps1' =
    '07681896F30BE95E806D2BB8693C185AEDAAA7C0C5B35CC07CBF52722E58EF98'
  'issue13-v5-capture-clean-stage5-evidence.ps1' =
    '4A204A46A351D9273A64C989911F577D3D47DFE97B9CCBD55274EEACFC048CA4'
  'issue13-v5-coordinator-lib.ps1' =
    '95B2DF1E2F1C74AD00379FDECA57ED3739E525C49C77D2F54B72F2845640A4A5'
  'issue13-v5-coordinator.ps1' =
    'B5A22EE893EDB63EBE5280643ED02A21320754F64C138DBBEB7E351AA46C7521'
  'issue13-v5-materialize-harness.ps1' =
    'FF4655D96832B395710AB2C11F75777F39C4B86F920C4C41CD83FDA8912E4BCE'
  'issue13-v5-new-config.ps1' =
    'D69192FF0BDC5EC64E1ECBA4669B52E12F4CE16B82175E323EB16FFCCBD87950'
  'issue13-v5-oracle-effect-generate.ps1' =
    '09984E2B6A1812AAF3ECD98BB026B04A66352EA8660C6DD76AB26BB043A5B462'
  'issue13-v5-oracle-effect-lib.ps1' =
    '395D7E43178857014B952D36E0DB0DF7DBD204905E2F21E22177B7FB14237213'
  'issue13-v5-oracle-effect-validate.ps1' =
    '2E70D8D7B2AB4150403D8C17CE5B4C7F32FC35C8E2823709C841DA8F1D93108A'
  'issue13-v5-render-report.ps1' =
    '92B228A7F9099F114807A6683C62D84BBA1A62AEF42553B4625850C4477C5D68'
}
$bootstrapSourceTexts = @{}
$bootstrapSourceAsts = @{}
$bootstrapSourceFileSha256 = @{}
$bootstrapEncoding = [Text.UTF8Encoding]::new($false, $true)
foreach ($bootstrapName in @($bootstrapSourceSha256.Keys | Sort-Object)) {
  $bootstrapPath = Join-Path $root $bootstrapName
  $bootstrapBytes = [IO.File]::ReadAllBytes($bootstrapPath)
  $bootstrapHash = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($bootstrapBytes))
  if ($bootstrapHash -cne [string]$bootstrapSourceSha256[$bootstrapName]) {
    throw "Static bootstrap source is not byte-authenticated: $bootstrapName"
  }
  $bootstrapSourceTexts[$bootstrapName] =
    $bootstrapEncoding.GetString($bootstrapBytes)
  $bootstrapTokens = $null
  $bootstrapErrors = $null
  $bootstrapSourceAsts[$bootstrapName] =
    [Management.Automation.Language.Parser]::ParseInput(
      $bootstrapSourceTexts[$bootstrapName],
      [ref]$bootstrapTokens, [ref]$bootstrapErrors)
  if ($bootstrapErrors.Count -ne 0) {
    throw "Static bootstrap parser rejected: $bootstrapName"
  }
  $bootstrapSourceFileSha256[$bootstrapName] = $bootstrapHash
}
$bootstrapStaticName = 'issue13-v5-static-verify.ps1'
$bootstrapStaticPath = Join-Path $root $bootstrapStaticName
$bootstrapStaticBytes = [IO.File]::ReadAllBytes($bootstrapStaticPath)
$bootstrapStaticText = $bootstrapEncoding.GetString($bootstrapStaticBytes)
$bootstrapStaticAst = $MyInvocation.MyCommand.ScriptBlock.Ast
if ($null -eq $bootstrapStaticAst -or
    $bootstrapStaticText -cne $bootstrapStaticAst.Extent.Text) {
  throw 'Executing static verifier differs from its on-disk source.'
}
$bootstrapSourceTexts[$bootstrapStaticName] = $bootstrapStaticText
$bootstrapSourceAsts[$bootstrapStaticName] = $bootstrapStaticAst
$bootstrapSourceFileSha256[$bootstrapStaticName] = [Convert]::ToHexString(
  [Security.Cryptography.SHA256]::HashData($bootstrapStaticBytes))
$bootstrapCoordinatorScript = [scriptblock]::Create(
  '$PSScriptRoot = $root' + "`n" +
    $bootstrapSourceTexts['issue13-v5-coordinator-lib.ps1'])
$bootstrapOracleScript = [scriptblock]::Create(
  '$PSScriptRoot = $root' + "`n" +
    $bootstrapSourceTexts['issue13-v5-oracle-effect-lib.ps1'])
. $bootstrapCoordinatorScript
. $bootstrapOracleScript
if (-not [string]::Equals(
      [string]$script:Issue13V5CoordinatorRoot, $root,
      [StringComparison]::OrdinalIgnoreCase) -or
    -not [string]::Equals(
      [string]$script:Issue13OracleEffectControllerRoot, $root,
      [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Authenticated static bootstrap resolved an unexpected controller root.'
}
function Get-Issue13V5BootstrapDeliveryResolverDefinitions(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  @($Ast.FindAll({
    param($node)
    if ($node -isnot
        [Management.Automation.Language.FunctionDefinitionAst]) {
      return $false
    }
    $leaf = @(([string]$node.Name).Split('\'))[-1]
    $leaf = @($leaf.Split(':'))[-1]
    $leaf -ieq 'Resolve-Issue13V5DeliveryOutput'
  }, $true))
}
$bootstrapDeliveryResolverDefinitions = @(
  Get-Issue13V5BootstrapDeliveryResolverDefinitions `
    $bootstrapSourceAsts['issue13-v5-attest-delivery.ps1']
)
if ($bootstrapDeliveryResolverDefinitions.Count -ne 1 -or
    $bootstrapDeliveryResolverDefinitions[0].Name -cne
      'Resolve-Issue13V5DeliveryOutput' -or
    $bootstrapDeliveryResolverDefinitions[0].Parent -isnot
      [Management.Automation.Language.NamedBlockAst] -or
    -not [object]::ReferenceEquals(
      $bootstrapDeliveryResolverDefinitions[0].Parent.Parent,
      $bootstrapSourceAsts['issue13-v5-attest-delivery.ps1'])) {
  throw 'Authenticated delivery resolver definition is missing or nested.'
}
$bootstrapDeliveryResolverScript = [scriptblock]::Create(
  [string]$bootstrapDeliveryResolverDefinitions[0].Extent.Text)
. $bootstrapDeliveryResolverScript
$bootstrapDeliveryMutantTokens = $null
$bootstrapDeliveryMutantErrors = $null
$bootstrapDeliveryMutantAst =
  [Management.Automation.Language.Parser]::ParseInput(
    ('function Resolve-Issue13V5DeliveryOutput {}' + "`n" +
      'function local:rEsOlVe-IsSuE13v5dElIvErYoUtPuT {}'),
    [ref]$bootstrapDeliveryMutantTokens,
    [ref]$bootstrapDeliveryMutantErrors)
if ($bootstrapDeliveryMutantErrors.Count -ne 0 -or
    @(Get-Issue13V5BootstrapDeliveryResolverDefinitions `
      $bootstrapDeliveryMutantAst).Count -ne 2) {
  throw 'Authenticated delivery resolver matcher ignored a scoped/case collision.'
}
foreach ($bootstrapName in @($bootstrapSourceSha256.Keys | Sort-Object)) {
  $bootstrapPath = Join-Path $root $bootstrapName
  $bootstrapHash = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
      [IO.File]::ReadAllBytes($bootstrapPath)))
  if ($bootstrapHash -cne [string]$bootstrapSourceSha256[$bootstrapName]) {
    throw "Static bootstrap source changed while loading: $bootstrapName"
  }
}

$scripts = @(
  'issue13-v5-baseline-smoke.ps1',
  'issue13-v5-materialize-harness.ps1',
  'issue13-v5-new-config.ps1',
  'issue13-v5-coordinator-lib.ps1',
  'issue13-v5-coordinator.ps1',
  'issue13-v5-render-report.ps1',
  'issue13-v5-static-verify.ps1'
)
$oracleEffectFiles = @(
  'issue13-v5-oracle-effect-README.md',
  'issue13-v5-oracle-effect-generate.ps1',
  'issue13-v5-oracle-effect-lib.ps1',
  'issue13-v5-oracle-effect-proof.schema.json',
  'issue13-v5-oracle-effect-spec.json',
  'issue13-v5-oracle-effect-validate.ps1'
)
$expectedControllerFiles = @(
  'README.md',
  'issue13-v5-aggregate-hardening.R',
  'issue13-v5-attest-delivery.ps1',
  'issue13-v5-baseline-smoke.ps1',
  'issue13-v5-build-baseline-index.R',
  'issue13-v5-build-diagnostic-bridges.R',
  'issue13-v5-build-metadata-equivalence.R',
  'issue13-v5-build-preparation-equivalence.R',
  'issue13-v5-build-stage5-profiles.R',
  'issue13-v5-capture-clean-bridge-evidence.ps1',
  'issue13-v5-capture-clean-stage5-evidence.ps1',
  'issue13-v5-compare-override.R',
  'issue13-v5-compatibility-baseline-override.R',
  'issue13-v5-coordinator-lib.ps1',
  'issue13-v5-coordinator.ps1',
  'issue13-v5-diagnostic-module-bridges.csv',
  'issue13-v5-diagnostics-override.R',
  'issue13-v5-difference-fingerprint.R',
  'issue13-v5-materialize-harness.ps1',
  'issue13-v5-metadata-equivalence.json',
  'issue13-v5-new-config.ps1',
  'issue13-v5-oracle-effect-README.md',
  'issue13-v5-oracle-effect-generate.ps1',
  'issue13-v5-oracle-effect-lib.ps1',
  'issue13-v5-oracle-effect-proof.schema.json',
  'issue13-v5-oracle-effect-spec.json',
  'issue13-v5-oracle-effect-validate.ps1',
  'issue13-v5-preparation-equivalence.R',
  'issue13-v5-preparation-equivalence.json',
  'issue13-v5-render-report.ps1',
  'issue13-v5-run-stage5-evidence.R',
  'issue13-v5-stage5-multiplicity-profiles.csv',
  'issue13-v5-static-verify.ps1',
  'issue13-v5-verify-diagnostic-evidence.R'
)
$forbiddenAbsoluteEvidenceSeed =
  'issue13-v5-diagnostic-bridge-evidence.csv'
$diagnosticEvidenceControllers = @(
  'issue13-v5-build-diagnostic-bridges.R',
  'issue13-v5-capture-clean-bridge-evidence.ps1',
  'issue13-v5-verify-diagnostic-evidence.R',
  'issue13-v5-build-stage5-profiles.R',
  'issue13-v5-run-stage5-evidence.R',
  'issue13-v5-capture-clean-stage5-evidence.ps1'
)
$diagnosticsOverride = 'issue13-v5-diagnostics-override.R'
$diagnosticBridges = 'issue13-v5-diagnostic-module-bridges.csv'
$stage5Profiles = 'issue13-v5-stage5-multiplicity-profiles.csv'
$preparationEquivalenceFiles = @(
  'issue13-v5-build-preparation-equivalence.R',
  'issue13-v5-preparation-equivalence.R',
  'issue13-v5-preparation-equivalence.json'
)
if ($expectedControllerFiles.Count -ne 34 -or
    @($expectedControllerFiles | Sort-Object -Unique).Count -ne 34 -or
    @($script:Issue13V5ControllerFiles | Sort-Object -Unique).Count -ne 34 -or
    [string]::Join("`n", $script:Issue13V5ControllerFiles) -cne
      [string]::Join("`n", $expectedControllerFiles) -or
    $forbiddenAbsoluteEvidenceSeed -cin $expectedControllerFiles -or
    $forbiddenAbsoluteEvidenceSeed -cin $script:Issue13V5ControllerFiles -or
    @($oracleEffectFiles | Where-Object {
      $_ -cnotin $script:Issue13V5ControllerFiles
    }).Count -ne 0 -or
    @($diagnosticEvidenceControllers | Where-Object {
      $_ -cnotin $script:Issue13V5ControllerFiles
    }).Count -ne 0 -or
    $diagnosticsOverride -cnotin $script:Issue13V5ControllerFiles -or
    $diagnosticBridges -cnotin $script:Issue13V5ControllerFiles -or
    $stage5Profiles -cnotin $script:Issue13V5ControllerFiles -or
    @($preparationEquivalenceFiles | Where-Object {
      $_ -cnotin $script:Issue13V5ControllerFiles
    }).Count -ne 0) {
  throw 'V5 exact 34-file controller inventory changed or adopted absolute evidence.'
}
foreach ($name in $expectedControllerFiles) {
  if (-not $bootstrapSourceFileSha256.ContainsKey($name) -and
      -not (Test-Path -LiteralPath (Join-Path $root $name) -PathType Leaf)) {
    throw "V5 controller source is missing: $name"
  }
}
$legacyGeneration = 'v' + '4'
$legacyPathNeedles = @(
  'issue13-native-gate-orchestrator-' + $legacyGeneration,
  'final-evidence-' + $legacyGeneration,
  'final-control-' + $legacyGeneration
)
$records = [Collections.Generic.List[object]]::new()
foreach ($name in $scripts) {
  $path = Join-Path $root $name
  $tokens = @()
  $errors = @()
  $ast = $bootstrapSourceAsts[$name]
  if ($errors.Count -ne 0) {
    throw "PowerShell parser rejected $name`: $($errors[0].Message)"
  }
  $commands = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst]
  }, $true))
  $dangerous = @($commands | Where-Object {
    $commandName = [string]$_.GetCommandName()
    $leaf = @($commandName.Split('\'))[-1]
    $leaf = @($leaf.Split(':'))[-1]
    $leaf -iin @(
      'Invoke-Expression', 'iex',
      'Remove-Item', 'ri', 'rm', 'del', 'erase', 'rd', 'rmdir',
      'Stop-Process', 'spps', 'kill',
      'Start-Job', 'sajb', 'Start-ThreadJob'
    )
  })
  if ($dangerous.Count -ne 0) {
    throw "Forbidden coordinator command appears in $name."
  }
  $text = [string]$bootstrapSourceTexts[$name]
  $legacyMatches = @($legacyPathNeedles | Where-Object {
    $text.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0
  })
  if ($legacyMatches.Count -ne 0) {
    throw "Coordinator depends on a legacy V4 path: $name"
  }
  $records.Add([ordered]@{
    name = $name
    sha256 = [string]$bootstrapSourceFileSha256[$name]
    command_ast_count = [long]$commands.Count
  })
}

foreach ($name in $oracleEffectFiles) {
  $path = Join-Path $root $name
  $sourceIsCached = $bootstrapSourceFileSha256.ContainsKey($name)
  $sourceExists = $sourceIsCached -or
    (Test-Path -LiteralPath $path -PathType Leaf)
  $sourceSha256 = if ($sourceIsCached) {
    ([string]$bootstrapSourceFileSha256[$name]).ToLowerInvariant()
  } else {
    Get-Issue13V5Sha256 $path
  }
  if (-not $sourceExists -or
      $name -cnotin $script:Issue13V5ControllerFiles -or
      $sourceSha256 -cnotmatch '^[0-9a-f]{64}$') {
    throw "Oracle-effect controller source is missing or unpinned: $name"
  }
  $oracleCommandCount = 0L
  if ([IO.Path]::GetExtension($name) -ceq '.ps1') {
    $tokens = @()
    $errors = @()
    $oracleAst = $bootstrapSourceAsts[$name]
    if ($errors.Count -ne 0) {
      throw "PowerShell parser rejected oracle-effect source $name`: $($errors[0].Message)"
    }
    $oracleCommandCount = [long]@($oracleAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst]
    }, $true)).Count
  }
  $records.Add([ordered]@{
    name = $name
    sha256 = $sourceSha256
    command_ast_count = $oracleCommandCount
  })
}
$diagnosticsOverridePath = Join-Path $root $diagnosticsOverride
$diagnosticsOverrideText = [IO.File]::ReadAllText(
  $diagnosticsOverridePath, [Text.UTF8Encoding]::new($false, $true))
if ($diagnosticsOverride -cnotin $script:Issue13V5ControllerFiles -or
    (Get-Issue13V5Sha256 $diagnosticsOverridePath) -cnotmatch
      '^[0-9a-f]{64}$' -or
    -not $diagnosticsOverrideText.Contains(
      'wlv13_cross_engine_validate_nonfinite <- function') -or
    -not $diagnosticsOverrideText.Contains(
      'wlv13_cross_engine_compare_anomalies <- function') -or
    -not $diagnosticsOverrideText.Contains('wlv13_v5d_selftest <- function') -or
    -not $diagnosticsOverrideText.Contains(
      'wlv13_v5d_compare_source_unit_contract <- function') -or
    -not $diagnosticsOverrideText.Contains(
      'wlv13_v5d_read_stage5_profiles <- function')) {
  throw 'V5 diagnostic override is missing, unpinned or structurally incomplete.'
}
$records.Add([ordered]@{
  name = $diagnosticsOverride
  sha256 = Get-Issue13V5Sha256 $diagnosticsOverridePath
  command_ast_count = 0L
})

$diagnosticControllerText = @{}
foreach ($name in $diagnosticEvidenceControllers) {
  $path = Join-Path $root $name
  $sourceIsCached = $bootstrapSourceFileSha256.ContainsKey($name)
  $sourceExists = $sourceIsCached -or
    (Test-Path -LiteralPath $path -PathType Leaf)
  $sourceSha256 = if ($sourceIsCached) {
    ([string]$bootstrapSourceFileSha256[$name]).ToLowerInvariant()
  } else {
    Get-Issue13V5Sha256 $path
  }
  if (-not $sourceExists -or
      $sourceSha256 -cnotmatch '^[0-9a-f]{64}$') {
    throw "Diagnostic evidence controller is missing or unpinned: $name"
  }
  $textValue = if ($bootstrapSourceTexts.ContainsKey($name)) {
    [string]$bootstrapSourceTexts[$name]
  } else {
    [IO.File]::ReadAllText(
      $path, [Text.UTF8Encoding]::new($false, $true))
  }
  if ($textValue.Contains([char]0xfffd)) {
    throw "Diagnostic evidence controller is not strict UTF-8: $name"
  }
  $diagnosticControllerText[$name] = $textValue
  $commandCount = 0L
  if ([IO.Path]::GetExtension($name) -ceq '.ps1') {
    $tokens = @()
    $errors = @()
    $diagnosticAst = $bootstrapSourceAsts[$name]
    if ($errors.Count -ne 0) {
      throw "PowerShell parser rejected diagnostic controller $name`: $($errors[0].Message)"
    }
    $commandCount = [long]@($diagnosticAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst]
    }, $true)).Count
  }
  $records.Add([ordered]@{
    name = $name
    sha256 = $sourceSha256
    command_ast_count = $commandCount
  })
}
foreach ($required in @(
    'wlv13_v5d_generate_bridge_manifest <- function',
    'wlv13_v5d_scientific_profile_from_commit <- function',
    'wlv13_v5d_historical_profile_binding_selftest <- function',
    'identical(profile_selftest$assertions, 26L)'
  )) {
  if (-not $diagnosticControllerText[
      'issue13-v5-build-diagnostic-bridges.R'].Contains($required)) {
    throw "Diagnostic bridge builder lacks authenticated freeze: $required"
  }
}
foreach ($required in @(
    'schema=issue13-v5-clean-bridge-capture/2',
    'tool_records=$($toolRecordsBefore.Count)',
    'harness_inventory_sha256=$harnessInventoryBefore',
    'harness_runtime_inventory_before_sha256=$harnessRuntimeInventoryBefore',
    'harness_runtime_inventory_after_sha256=$harnessRuntimeInventoryAfter',
    'rscript_sha256=$rscriptSha256',
    'fsutil_sha256=$fsutilSha256',
    '([Environment]::SystemDirectory)',
    'r_library_path=$($script:rLibrary.Replace',
    'r_library_inventory_before_sha256=$rLibraryInventoryBefore',
    'r_library_inventory_after_sha256=$rLibraryInventoryAfter',
    'Invoke-SealedRscript',
    '"R_LIBS_USER"',
    '"TZ", "UTC"',
    'metadata_equivalence = Resolve-PhysicalExistingFile',
    'source_wiodr13_inventory_before_sha256=',
    'source_wiodr16_inventory_after_sha256=',
    'Copy-Issue13V5PhysicalDirectorySnapshot',
    'source_data_origin_physical_path=',
    'source_data_snapshot_physical_path=',
    'source_data_independence_after_sha256=',
    'source_data_origin_inventory_before_sha256=',
    'source_data_origin_inventory_after_sha256=',
    'source_data_snapshot_inventory_before_sha256=',
    'source_data_snapshot_inventory_after_sha256=',
    '"--vanilla"',
    'Write-Output "captured_runs=7"'
  )) {
  if (-not $diagnosticControllerText[
      'issue13-v5-capture-clean-bridge-evidence.ps1'].Contains($required)) {
    throw "Clean diagnostic bridge capturer lacks tooling seal: $required"
  }
}
foreach ($required in @(
    'wlv13_v5d_bridge_authenticate_run(',
    '"evidence_record",',
    'issue13-v5-build-diagnostic-bridges.R'
  )) {
  if (-not $diagnosticControllerText[
      'issue13-v5-verify-diagnostic-evidence.R'].Contains($required)) {
    throw "Diagnostic evidence verifier lacks run authentication: $required"
  }
}
foreach ($required in @(
    'wlv13_v5d_validate_stage5_capture <- function',
    'wlv13_v5d_stage5_capture_mutation_selftest <- function',
    'wlv13_v5d_live_validation_structure_selftest <- function',
    'identical(capture_assertions, 46L)',
    'identical(live_structure_assertions, 7L)',
    'requested_verify_live <- verify_live',
    'lockBinding("requested_verify_live", environment())',
    'd7fc0ba48bed304cf3975f2189ee975b14c16522443b28379d26329ea661b97a',
    'lockBinding("official_source_inventory_sha256", environment())',
    'stats::setNames(c(1L, 1L, 6L, 1L, 1L, 6L)',
    'live_structure_assertions=%d',
    'wlv13_v5d_physical_snapshot_attest <- function',
    'external_inventories, verify_live = TRUE',
    'utils::readRegistry(',
    'Bridge capture fsutil is not independently authenticated.',
    'coherent fsutil executable',
    'harness_runtime_inventory_before_sha256',
    'harness_runtime_inventory_after_sha256',
    'r_library_inventory_before_sha256',
    'r_library_inventory_after_sha256',
    'length(stage_header) + 10L + 6L + 6L + 12L + 36L + 36L'
  )) {
  if (-not $diagnosticControllerText[
      'issue13-v5-build-stage5-profiles.R'].Contains($required)) {
    throw "Stage-five profile builder lacks exact capture freeze: $required"
  }
}
foreach ($required in @(
    'capture_role = "stage5-parent-alias"',
    'The stage-five capture parent is not a calculate run.'
  )) {
  if (-not $diagnosticControllerText[
      'issue13-v5-run-stage5-evidence.R'].Contains($required)) {
    throw "Stage-five native launcher lacks parent binding: $required"
  }
}
foreach ($required in @(
    'schema=issue13-v5-clean-stage5-capture/2',
    '$stageRows.Count -ne 36',
    '$seedRecords.Count -ne 36',
    '$targetRecords.Count -ne 36',
    'recipe_records=$($recipeRecords.Count)',
    '$recipeRecordsBefore = @(',
    '$recipeRecordsAfter = @(',
    'Stage-five capture recipes changed during execution.',
    'harness_inventory_sha256=$harnessInventoryBefore',
    'harness_runtime_inventory_before_sha256=$harnessRuntimeInventoryBefore',
    'harness_runtime_inventory_after_sha256=$harnessRuntimeInventoryAfter',
    'rscript_sha256=$rscriptSha256',
    'fsutil_sha256=$fsutilSha256',
    '([Environment]::SystemDirectory)',
    'r_library_path=$($script:rLibrary.Replace',
    'r_library_inventory_before_sha256=$rLibraryInventoryBefore',
    'r_library_inventory_after_sha256=$rLibraryInventoryAfter',
    'Copy-Issue13V5PhysicalDirectorySnapshot',
    'source_snapshot_records=$($sourceSnapshotRecords.Count)',
    'source_data_origin_inventory_before_sha256=',
    'source_data_origin_inventory_after_sha256=',
    'bridge_source_data_snapshot_inventory_before_sha256=',
    'bridge_source_data_snapshot_inventory_after_sha256=',
    'source_data_origin_physical_path=',
    'bridge_source_data_snapshot_physical_path=',
    'bridge_source_data_independence_after_sha256=',
    'Invoke-SealedRscript',
    '"R_LIBS_USER"',
    '"TZ", "UTC"',
    'metadata_equivalence = Resolve-PhysicalExistingFile',
    'Write-Output "baseline_recalculations=36"'
  )) {
  if (-not $diagnosticControllerText[
      'issue13-v5-capture-clean-stage5-evidence.ps1'].Contains($required)) {
    throw "Clean stage-five capturer lacks exhaustive tooling seal: $required"
  }
}

function Get-Issue13V5PowerShellCommandLeaf(
  [AllowNull()][string]$Name
) {
  if ([string]::IsNullOrWhiteSpace($Name)) { return '' }
  $leaf = $Name
  $separator = $leaf.LastIndexOf('\')
  if ($separator -ge 0) { $leaf = $leaf.Substring($separator + 1) }
  $scope = $leaf.LastIndexOf(':')
  if ($scope -ge 0) { $leaf = $leaf.Substring($scope + 1) }
  $leaf
}
function Test-Issue13V5TypeExpression(
  [Management.Automation.Language.Ast]$Expression,
  [string]$ExpectedFullName
) {
  if ($Expression -isnot
      [Management.Automation.Language.TypeExpressionAst]) {
    return $false
  }
  $resolved = $Expression.TypeName.GetReflectionType()
  if ($null -ne $resolved) {
    return $resolved.FullName -ieq $ExpectedFullName
  }
  $Expression.TypeName.FullName -ieq $ExpectedFullName
}
function Test-Issue13V5TypeConstraint(
  [Management.Automation.Language.TypeConstraintAst]$Constraint,
  [string]$ExpectedFullName
) {
  $resolved = $Constraint.TypeName.GetReflectionType()
  if ($null -ne $resolved) {
    return $resolved.FullName -ieq $ExpectedFullName
  }
  $Constraint.TypeName.FullName -ieq $ExpectedFullName
}
function Test-Issue13V5CanonicalCriticalCommands(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string[]]$CriticalNames
) {
  $criticalAliases = @{
    'gcm' = 'Get-Command'
    'mi' = 'Move-Item'
    'move' = 'Move-Item'
    'mv' = 'Move-Item'
    'cat' = 'Get-Content'
    'gc' = 'Get-Content'
    'type' = 'Get-Content'
  }
  $providerWrites = @($Ast.FindAll({
    param($node)
    $target = if ($node -is
        [Management.Automation.Language.AssignmentStatementAst]) {
      $node.Left
    } elseif ($node -is [Management.Automation.Language.UnaryExpressionAst] -and
        $node.TokenKind -in @(
          [Management.Automation.Language.TokenKind]::PlusPlus,
          [Management.Automation.Language.TokenKind]::MinusMinus,
          [Management.Automation.Language.TokenKind]::PostfixPlusPlus,
          [Management.Automation.Language.TokenKind]::PostfixMinusMinus)) {
      $node.Child
    } elseif ($node -is
        [Management.Automation.Language.ForEachStatementAst]) {
      $node.Variable
    } elseif ($node -is
        [Management.Automation.Language.ConvertExpressionAst] -and
        $node.Type.TypeName.FullName -ieq 'ref') {
      $node.Child
    } else {
      $null
    }
    $directProviderWrite = $null -ne $target -and
      $target -is [Management.Automation.Language.VariableExpressionAst] -and
      $target.VariablePath.UserPath -imatch '^(?:function|alias):'
    $nestedProviderWrite = $null -ne $target -and @($target.FindAll({
        param($variable)
        $variable -is
          [Management.Automation.Language.VariableExpressionAst] -and
          $variable.VariablePath.UserPath -imatch '^(?:function|alias):'
      }, $true)).Count -ne 0
    if ($directProviderWrite -or $nestedProviderWrite) {
      return $true
    }
    $node -is [Management.Automation.Language.FileRedirectionAst] -and
      $node.Location -is
        [Management.Automation.Language.StringConstantExpressionAst] -and
      $node.Location.Value -imatch '^(?:function|alias):'
  }, $true))
  $aliasCommands = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -iin @(
        'Set-Alias', 'sal', 'New-Alias', 'nal',
        'Import-Alias', 'ipal', 'Remove-Alias', 'ral'
      )
  }, $true))
  $providerMutationCommands = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -iin @(
        'Set-Item', 'si', 'New-Item', 'ni',
        'Copy-Item', 'cpi', 'cp', 'copy',
        'Rename-Item', 'rni', 'ren',
        'Clear-Item', 'cli', 'Remove-Item', 'ri', 'rm', 'del', 'erase',
        'rd', 'rmdir', 'Set-Content', 'sc', 'Clear-Content', 'clc',
        'Out-File'
      ) -and
      $node.Extent.Text -imatch '(?:function|alias)\s*:'
  }, $true))
  if ($providerWrites.Count -ne 0 -or $aliasCommands.Count -ne 0 -or
      $providerMutationCommands.Count -ne 0) {
    return $false
  }
  $collisions = @($Ast.FindAll({
    param($node)
    if ($node -is [Management.Automation.Language.CommandAst]) {
      $leaf = Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())
      $semanticLeaf = if ($criticalAliases.ContainsKey($leaf)) {
        [string]$criticalAliases[$leaf]
      } else {
        $leaf
      }
      return $CriticalNames -icontains $semanticLeaf
    }
    if ($node -is [Management.Automation.Language.FunctionDefinitionAst]) {
      $leaf = Get-Issue13V5PowerShellCommandLeaf $node.Name
      $semanticLeaf = if ($criticalAliases.ContainsKey($leaf)) {
        [string]$criticalAliases[$leaf]
      } else {
        $leaf
      }
      return $CriticalNames -icontains $semanticLeaf
    }
    $false
  }, $true))
  foreach ($node in $collisions) {
    $raw = if ($node -is [Management.Automation.Language.CommandAst]) {
      [string]$node.GetCommandName()
    } else {
      [string]$node.Name
    }
    $leaf = Get-Issue13V5PowerShellCommandLeaf $raw
    $semanticLeaf = if ($criticalAliases.ContainsKey($leaf)) {
      [string]$criticalAliases[$leaf]
    } else {
      $leaf
    }
    $expected = @($CriticalNames | Where-Object { $_ -ieq $semanticLeaf })
    if ($expected.Count -ne 1 -or $raw -cne $expected[0]) {
      return $false
    }
    if ($node -is [Management.Automation.Language.CommandAst] -and
        ($node.InvocationOperator -ne
          [Management.Automation.Language.TokenKind]::Unknown -or
          $node.CommandElements.Count -lt 1 -or
          $node.CommandElements[0].Extent.Text -cne $expected[0])) {
      return $false
    }
  }
  $true
}
function Test-Issue13V5ForbiddenVariableMutationCommand(
  [Management.Automation.Language.CommandAst]$Command
) {
  $leaf = Get-Issue13V5PowerShellCommandLeaf ($Command.GetCommandName())
  if ($leaf -iin @(
    'Set-Variable', 'sv', 'set',
    'New-Variable', 'nv',
    'Clear-Variable', 'clv',
    'Remove-Variable', 'rv',
    'Set-Alias', 'sal', 'New-Alias', 'nal',
    'Import-Alias', 'ipal', 'Remove-Alias', 'ral'
  )) { return $true }
  $parameters = @($Command.CommandElements | Where-Object {
    $_ -is [Management.Automation.Language.CommandParameterAst]
  } | ForEach-Object { $_.ParameterName })
  $commonVariableParameters = @(
    'OutVariable',
    'PipelineVariable',
    'ErrorVariable',
    'WarningVariable',
    'InformationVariable'
  )
  if (@($parameters | Where-Object {
      $parameter = $_
      $parameter -iin @('ov', 'pv', 'ev', 'wv', 'iv') -or
        @($commonVariableParameters | Where-Object {
          $parameter.Length -gt 0 -and
            $_.StartsWith(
              $parameter, [StringComparison]::OrdinalIgnoreCase)
        }).Count -ne 0
    }).Count -ne 0 -or
      ($leaf -iin @('Tee-Object', 'tee') -and
        @($parameters | Where-Object {
          $_.Length -gt 0 -and
            'Variable'.StartsWith(
              $_, [StringComparison]::OrdinalIgnoreCase)
        }).Count -ne 0)) {
    return $true
  }
  if ($leaf -iin @(
      'Set-Item', 'si', 'New-Item', 'ni',
      'Copy-Item', 'cpi', 'cp', 'copy',
      'Rename-Item', 'rni', 'ren',
      'Set-Content', 'sc',
      'Clear-Item', 'cli', 'Clear-Content', 'clc',
      'Remove-Item', 'ri', 'rm', 'del', 'erase', 'rd', 'rmdir',
      'Out-File') -and
      $Command.Extent.Text -imatch '(?:variable|function|alias)\s*:') {
    return $true
  }
  $false
}
function Test-Issue13V5ForbiddenProtectedScopeCommand(
  [Management.Automation.Language.CommandAst]$Command,
  [string[]]$AllowedMutationSignatures = @()
) {
  $signature = [string]::Join('|', @($Command.CommandElements |
      ForEach-Object { $_.Extent.Text }))
  if ($AllowedMutationSignatures -ccontains $signature) {
    return $false
  }
  if (Test-Issue13V5ForbiddenVariableMutationCommand $Command) {
    return $true
  }
  $splats = @($Command.FindAll({
    param($node)
    $node -is [Management.Automation.Language.VariableExpressionAst] -and
      $node.Splatted
  }, $true))
  if ($splats.Count -ne 0) { return $true }
  if ($Command.InvocationOperator -ne
      [Management.Automation.Language.TokenKind]::Unknown) {
    return $AllowedMutationSignatures -cnotcontains $signature
  }
  $name = [string]$Command.GetCommandName()
  if ([string]::IsNullOrWhiteSpace($name)) {
    return $AllowedMutationSignatures -cnotcontains $signature
  }
  $leaf = Get-Issue13V5PowerShellCommandLeaf $name
  if ($leaf -iin @('Invoke-Expression', 'iex', 'Invoke-Command', 'icm')) {
    return $true
  }
  if ($leaf -iin @(
      'Set-Item', 'si', 'New-Item', 'ni',
      'Copy-Item', 'cpi', 'cp', 'copy',
      'Rename-Item', 'rni', 'ren',
      'Clear-Item', 'cli', 'Remove-Item', 'ri', 'rm', 'del', 'erase',
      'rd', 'rmdir', 'Set-Content', 'sc', 'Clear-Content', 'clc',
      'Out-File')) {
    return $AllowedMutationSignatures -cnotcontains $signature
  }
  $false
}
function Test-Issue13V5ForbiddenProtectedScopeRedirection(
  [Management.Automation.Language.Ast]$Ast,
  [string[]]$AllowedSignatures = @()
) {
  @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FileRedirectionAst] -and
      $AllowedSignatures -cnotcontains $node.Extent.Text
  }, $true)).Count -ne 0
}
function Get-Issue13V5UnscopedVariableName(
  [Management.Automation.Language.VariableExpressionAst]$Variable
) {
  $name = [string]$Variable.VariablePath.UserPath
  $separator = $name.IndexOf(':')
  if ($separator -ge 0 -and $name.Substring(0, $separator) -iin @(
      'script', 'local', 'private', 'global', 'variable')) {
    $name = $name.Substring($separator + 1)
  }
  '$' + $name
}
function Test-Issue13V5ForbiddenSessionStateMutation(
  [Management.Automation.Language.Ast]$Ast
) {
  $forbiddenReferences = @($Ast.FindAll({
    param($node)
    ($node -is [Management.Automation.Language.VariableExpressionAst] -and
      (Get-Issue13V5UnscopedVariableName $node) -iin @(
        '$ExecutionContext', '$PSDefaultParameterValues'
      )) -or
      ($node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -iin @(
          'Get-Variable', 'gv'
        )) -or
      ($node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        ($node.Extent.Text -imatch 'PSVariable' -or
          @($node.FindAll({
            param($variable)
            $variable -is
              [Management.Automation.Language.VariableExpressionAst] -and
              (Get-Issue13V5UnscopedVariableName $variable) -iin @(
                '$ExecutionContext', '$PSDefaultParameterValues'
              )
          }, $true)).Count -ne 0 -or
          ($node.Static -and
            (Test-Issue13V5TypeExpression $node.Expression `
              'System.Management.Automation.ScriptBlock'))))
  }, $true))
  $forbiddenReferences.Count -ne 0
}
function Get-Issue13V5AstSurfaceDigest(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [ValidateSet('command', 'redirection')][string]$Kind
) {
  $nodes = @(if ($Kind -ieq 'command') {
    $Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst]
    }, $true) | Sort-Object { $_.Extent.StartOffset }
  } else {
    $Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.FileRedirectionAst]
    }, $true) | Sort-Object { $_.Extent.StartOffset }
  })
  $records = @()
  foreach ($node in $nodes) {
    $owner = '<script>'
    $current = $node.Parent
    while ($null -ne $current -and
        -not [object]::ReferenceEquals($current, $Ast)) {
      if ($current -is
          [Management.Automation.Language.FunctionDefinitionAst]) {
        $owner = [string]$current.Name
        break
      }
      $current = $current.Parent
    }
    $types = @()
    $current = $node
    while ($null -ne $current -and
        -not [object]::ReferenceEquals($current, $Ast)) {
      $types += $current.GetType().Name
      $current = $current.Parent
    }
    if ($null -eq $current) {
      throw 'AST surface node does not belong to the supplied root.'
    }
    $chain = [string]::Join('>', [string[]]$types)
    $fields = if ($Kind -ieq 'command') {
      @(
        'C',
        $owner,
        $node.InvocationOperator.ToString(),
        [string]$node.GetCommandName(),
        [string]::Join('|', @($node.CommandElements | ForEach-Object {
          $_.Extent.Text
        })),
        $chain
      )
    } else {
      @('R', $owner, $node.Extent.Text, $chain)
    }
    $record = ''
    foreach ($field in $fields) {
      $value = [string]$field
      $record += ([string]$value.Length) + ':' + $value
    }
    $records += $record
  }
  $payload = [string]::Join("`n", [string[]]$records)
  $encoding = [Text.UTF8Encoding]::new($false, $true)
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = $algorithm.ComputeHash($encoding.GetBytes($payload))
  } finally {
    $algorithm.Dispose()
  }
  [pscustomobject]@{
    count = [int]$nodes.Count
    sha256 = [Convert]::ToHexString($hash)
  }
}
function Test-Issue13V5AstSurface(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [Collections.IDictionary]$Expected
) {
  $commands = Get-Issue13V5AstSurfaceDigest $Ast 'command'
  $redirections = Get-Issue13V5AstSurfaceDigest $Ast 'redirection'
  $commands.count -eq [int]$Expected.command_count -and
    $commands.sha256 -ceq [string]$Expected.command_sha256 -and
    $redirections.count -eq [int]$Expected.redirection_count -and
    $redirections.sha256 -ceq [string]$Expected.redirection_sha256
}
function Get-Issue13V5ControllerSourceSha256(
  [string]$Text,
  [string]$FileName
) {
  $canonical = $Text
  if ($FileName -ceq 'issue13-v5-static-verify.ps1') {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput(
      $Text, [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) {
      throw 'Cannot canonicalize the static verifier source digest.'
    }
    $assignments = @($ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is
          [Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.UserPath -ieq
          'issue13ExpectedControllerSourceSha256'
    }, $true))
    if ($assignments.Count -ne 1 -or
        $assignments[0].Left.Extent.Text -cne
          '$issue13ExpectedControllerSourceSha256') {
      throw 'Static verifier source-digest map is not singular.'
    }
    $tables = @($assignments[0].Right.FindAll({
      param($node)
      $node -is [Management.Automation.Language.HashtableAst]
    }, $true))
    if ($tables.Count -ne 1) {
      throw 'Static verifier source-digest hashtable is not singular.'
    }
    $selfPairs = @($tables[0].KeyValuePairs | Where-Object {
      $_.Item1 -is
        [Management.Automation.Language.StringConstantExpressionAst] -and
        $_.Item1.Value -ceq 'issue13-v5-static-verify.ps1'
    })
    if ($selfPairs.Count -ne 1) {
      throw 'Static verifier self-digest entry is not singular.'
    }
    $valuePipeline = $selfPairs[0].Item2
    $pipelineElements = @($valuePipeline.PipelineElements)
    if ($valuePipeline -isnot [Management.Automation.Language.PipelineAst] -or
        $pipelineElements.Count -ne 1 -or
        $pipelineElements[0] -isnot
          [Management.Automation.Language.CommandExpressionAst] -or
        $pipelineElements[0].Expression -isnot
          [Management.Automation.Language.StringConstantExpressionAst]) {
      throw 'Static verifier self digest must be one literal string.'
    }
    $valueLiteral = $pipelineElements[0].Expression
    if ($valueLiteral.StringConstantType -ne
          [Management.Automation.Language.StringConstantType]::SingleQuoted -or
        $valueLiteral.Value -cnotmatch '^[0-9A-F]{64}$' -or
        $valuePipeline.Extent.StartOffset -ne
          $pipelineElements[0].Extent.StartOffset -or
        $valuePipeline.Extent.EndOffset -ne
          $pipelineElements[0].Extent.EndOffset -or
        $pipelineElements[0].Extent.StartOffset -ne
          $valueLiteral.Extent.StartOffset -or
        $pipelineElements[0].Extent.EndOffset -ne
          $valueLiteral.Extent.EndOffset -or
        $valueLiteral.Extent.Text -cne ("'" + $valueLiteral.Value + "'")) {
      throw 'Static verifier self digest is not a canonical SHA-256 literal.'
    }
    $valueExtent = $valueLiteral.Extent
    $canonical = $Text.Remove(
      $valueExtent.StartOffset,
      $valueExtent.EndOffset - $valueExtent.StartOffset).Insert(
        $valueExtent.StartOffset, "'<SELF-SHA256>'")
  }
  $encoding = [Text.UTF8Encoding]::new($false, $true)
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = $algorithm.ComputeHash($encoding.GetBytes($canonical))
  } finally {
    $algorithm.Dispose()
  }
  [Convert]::ToHexString($hash)
}

$issue13CriticalPowerShellNames = @(
  'Copy-Issue13V5PhysicalDirectorySnapshot',
  'Get-Issue13V5PhysicalSnapshotProof',
  'Get-Issue13V5PhysicalItemIdentity',
  'Get-Issue13V5TreeInventory',
  'Set-Issue13V5ScriptConstant',
  'Assert-Issue13V5OfficialSourceDataInventory',
  'Assert-Issue13V5BaselineSmokeRscriptSeal',
  'Invoke-Issue13V5DeliveryAttestation',
  'Resolve-Issue13V5DeliveryOutput',
  'ConvertTo-Issue13V5PhysicalPath',
  'Test-Issue13V5PathContained',
  'Assert-Issue13V5PathsDisjoint',
  'Assert-Issue13V5NoReparseAncestors',
  'Assert-Issue13V5AliasFreeLocalPath',
  'ConvertTo-Issue13V5CanonicalPath',
  'Assert-Issue13V5Config',
  'Assert-Issue13V5ConfigPathIsolation',
  'Assert-Issue13V5OracleComparisonIsolation',
  'Assert-Issue13V5FreshRoot',
  'Assert-Issue13OracleEffectProofPathIsolation',
  'Assert-Issue13OracleEffectComparisonIsolation',
  'Assert-Issue13OracleEffectPathsDisjoint',
  'ConvertTo-Issue13OracleEffectPhysicalPath',
  'Write-Issue13OracleEffectJsonOnce',
  'Write-Issue13V5Json',
  'Assert-Issue13V5PhysicalCopy',
  'Resolve-Issue13OracleEffectFile',
  'Read-Issue13OracleEffectJson',
  'Get-Issue13OracleEffectInputContext',
  'Get-Issue13OracleEffectEvidence',
  'Add-Type',
  'Add-Member',
  'Get-Command',
  'Move-Item',
  'Get-Content'
)
$issue13CriticalDefinitionOwners = @{
  'issue13-v5-attest-delivery.ps1' = @(
    'Resolve-Issue13V5DeliveryOutput',
    'Invoke-Issue13V5DeliveryAttestation'
  )
  'issue13-v5-baseline-smoke.ps1' = @(
    'Assert-Issue13V5BaselineSmokeRscriptSeal',
    'Write-Issue13V5Json'
  )
  'issue13-v5-coordinator-lib.ps1' = @(
    'Set-Issue13V5ScriptConstant',
    'ConvertTo-Issue13V5PhysicalPath',
    'Test-Issue13V5PathContained',
    'Assert-Issue13V5PathsDisjoint',
    'Assert-Issue13V5ConfigPathIsolation',
    'Assert-Issue13V5NoReparseAncestors',
    'Get-Issue13V5PhysicalItemIdentity',
    'Get-Issue13V5PhysicalSnapshotProof',
    'Copy-Issue13V5PhysicalDirectorySnapshot',
    'Write-Issue13V5Json',
    'Get-Issue13V5TreeInventory',
    'Assert-Issue13V5OfficialSourceDataInventory',
    'Assert-Issue13V5OracleComparisonIsolation',
    'Assert-Issue13V5PhysicalCopy',
    'Assert-Issue13V5Config'
  )
  'issue13-v5-materialize-harness.ps1' = @(
    'Assert-Issue13V5AliasFreeLocalPath',
    'ConvertTo-Issue13V5CanonicalPath',
    'Assert-Issue13V5NoReparseAncestors'
  )
  'issue13-v5-new-config.ps1' = @('Assert-Issue13V5FreshRoot')
  'issue13-v5-oracle-effect-lib.ps1' = @(
    'Resolve-Issue13OracleEffectFile',
    'ConvertTo-Issue13OracleEffectPhysicalPath',
    'Assert-Issue13OracleEffectPathsDisjoint',
    'Assert-Issue13OracleEffectProofPathIsolation',
    'Read-Issue13OracleEffectJson',
    'Get-Issue13OracleEffectInputContext',
    'Assert-Issue13OracleEffectComparisonIsolation',
    'Get-Issue13OracleEffectEvidence',
    'Write-Issue13OracleEffectJsonOnce'
  )
}
$issue13ExpectedAstSurfaces = @{
  'issue13-v5-attest-delivery.ps1' = @{
    command_count = 76
    command_sha256 = '3E47102656361250D29A197FA97C9CF50A7049F2891B082E8D808C448F576D2F'
    redirection_count = 1
    redirection_sha256 = '2637588ECE5D0693F068560BB7ADDA69DBE15A91B08B1853C82B7A2B046ECFD0'
  }
  'issue13-v5-baseline-smoke.ps1' = @{
    command_count = 158
    command_sha256 = 'AC5600B5F40995C59DBDBAC29575343911BD7E0F0E87144399E00258E360BC88'
    redirection_count = 4
    redirection_sha256 = 'D102BB197FD8FD8C167D08D8E9FA3410202D097B35EB2E121C617244CD6D7232'
  }
  'issue13-v5-capture-clean-bridge-evidence.ps1' = @{
    command_count = 145
    command_sha256 = 'ED8C52E653F185770F4C129529EA53EDD06CF6093CA57C1AE02EFAB2C4909B3A'
    redirection_count = 0
    redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-v5-capture-clean-stage5-evidence.ps1' = @{
    command_count = 243
    command_sha256 = 'D218805FF7AE35F0FB5C95DDCB3733E2C0773857524F5086AFECCE8986A68851'
    redirection_count = 0
    redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-v5-coordinator-lib.ps1' = @{
    command_count = 819
    command_sha256 = '9850A5F70B67F85783D25DB52B45646CDDC0D8857864ACF7900F75DDC240BB7F'
    redirection_count = 19
    redirection_sha256 = 'BBCDC766E66B39B17B6D1D8BFD22A123CE24090CEF3E5204E542D73FB1B9DDF8'
  }
  'issue13-v5-coordinator.ps1' = @{
    command_count = 396
    command_sha256 = '2F94231D456F9E2B1BF8652D026B2D7D50C9FDF174585AAB34C19E59A14F893C'
    redirection_count = 0
    redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-v5-materialize-harness.ps1' = @{
    command_count = 199
    command_sha256 = '14F7F5B06ADB84163D84800C91752E61B76F3C0970DDB958A855BC628E8D2C2D'
    redirection_count = 4
    redirection_sha256 = '5FE6646416132F2444D3AC9C63EBDF8DCEAE6E18DC5242C675574BC026FF9352'
  }
  'issue13-v5-new-config.ps1' = @{
    command_count = 171
    command_sha256 = '604236AD73FB0DDE444FCC89C3C53CD6187DC9184ABE71A2B95B418BAA2470FA'
    redirection_count = 3
    redirection_sha256 = 'F5308A7B6632030C8FB84F968127215DAEBCBFF41DA11F9D9F9E7D902B8D4F47'
  }
  'issue13-v5-oracle-effect-generate.ps1' = @{
    command_count = 48
    command_sha256 = 'D24C5869269521FE3EF29DEE97C117F9C6F298B1C262DDA1AF88CC407B8228D6'
    redirection_count = 0
    redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-v5-oracle-effect-lib.ps1' = @{
    command_count = 683
    command_sha256 = '8A1C87A4E052F7EF542753A9C5C5709E43BE247AF00006B2311216C3EF766659'
    redirection_count = 0
    redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-v5-oracle-effect-validate.ps1' = @{
    command_count = 19
    command_sha256 = '7352E758DB2334E186DBA6478CEC61BBC0C0B603018E43434A1DF5D1BBFF8ADA'
    redirection_count = 0
    redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-v5-render-report.ps1' = @{
    command_count = 183
    command_sha256 = 'F8FF6B64665873733001CA2F1200AB1AB5F52763A6DE94CE9F9B5F070CF8351D'
    redirection_count = 2
    redirection_sha256 = '21CB16D1E32E69D36B73456196A55A9B5112989825180286122E76CE745B03D5'
  }
  'issue13-v5-static-verify.ps1' = @{
    command_count = 544
    command_sha256 = '0A05E310405D267191DDD288A3FA901DC287056365BD2375EE7294378C6C8A34'
    redirection_count = 0
    redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
}
$issue13ExpectedControllerSourceSha256 = @{
  'issue13-v5-attest-delivery.ps1' = 'A22D1EAEF94B3378EF71C2DD8575B43347DDB7EE6B3769D8533C4A7DF10B795A'
  'issue13-v5-baseline-smoke.ps1' = '039795827BFBECC53EBAEFE80C9543804CF020C5F3CC59DA5771C253B52258A8'
  'issue13-v5-capture-clean-bridge-evidence.ps1' = '07681896F30BE95E806D2BB8693C185AEDAAA7C0C5B35CC07CBF52722E58EF98'
  'issue13-v5-capture-clean-stage5-evidence.ps1' = '4A204A46A351D9273A64C989911F577D3D47DFE97B9CCBD55274EEACFC048CA4'
  'issue13-v5-coordinator-lib.ps1' = '95B2DF1E2F1C74AD00379FDECA57ED3739E525C49C77D2F54B72F2845640A4A5'
  'issue13-v5-coordinator.ps1' = 'B5A22EE893EDB63EBE5280643ED02A21320754F64C138DBBEB7E351AA46C7521'
  'issue13-v5-materialize-harness.ps1' = 'FF4655D96832B395710AB2C11F75777F39C4B86F920C4C41CD83FDA8912E4BCE'
  'issue13-v5-new-config.ps1' = 'D69192FF0BDC5EC64E1ECBA4669B52E12F4CE16B82175E323EB16FFCCBD87950'
  'issue13-v5-oracle-effect-generate.ps1' = '09984E2B6A1812AAF3ECD98BB026B04A66352EA8660C6DD76AB26BB043A5B462'
  'issue13-v5-oracle-effect-lib.ps1' = '395D7E43178857014B952D36E0DB0DF7DBD204905E2F21E22177B7FB14237213'
  'issue13-v5-oracle-effect-validate.ps1' = '2E70D8D7B2AB4150403D8C17CE5B4C7F32FC35C8E2823709C841DA8F1D93108A'
  'issue13-v5-render-report.ps1' = '92B228A7F9099F114807A6683C62D84BBA1A62AEF42553B4625850C4477C5D68'
  'issue13-v5-static-verify.ps1' = '94CF84AE0A48E5D8C02A08156DFA2E164A544194EC5FD2EBE585C22BC6E9D6C8'
}
$issue13ExpectedDotSourceSignatures = @{
  'issue13-v5-attest-delivery.ps1' = @(
    "(Join-Path `$scriptRoot 'issue13-v5-coordinator-lib.ps1')"
  )
  'issue13-v5-baseline-smoke.ps1' = @(
    "(Join-Path `$PSScriptRoot 'issue13-v5-coordinator-lib.ps1')"
  )
  'issue13-v5-capture-clean-bridge-evidence.ps1' = @(
    '(Join-Path $PSScriptRoot "issue13-v5-coordinator-lib.ps1")'
  )
  'issue13-v5-capture-clean-stage5-evidence.ps1' = @(
    '(Join-Path $PSScriptRoot "issue13-v5-coordinator-lib.ps1")'
  )
  'issue13-v5-coordinator.ps1' = @(
    "(Join-Path `$scriptRoot 'issue13-v5-coordinator-lib.ps1')"
  )
  'issue13-v5-new-config.ps1' = @(
    "(Join-Path `$PSScriptRoot 'issue13-v5-coordinator-lib.ps1')"
  )
  'issue13-v5-oracle-effect-generate.ps1' = @(
    "(Join-Path `$PSScriptRoot 'issue13-v5-oracle-effect-lib.ps1')"
  )
  'issue13-v5-oracle-effect-validate.ps1' = @(
    "(Join-Path `$PSScriptRoot 'issue13-v5-oracle-effect-lib.ps1')"
  )
  'issue13-v5-render-report.ps1' = @(
    "(Join-Path `$scriptRoot 'issue13-v5-coordinator-lib.ps1')"
  )
  'issue13-v5-static-verify.ps1' = @(
    '$bootstrapCoordinatorScript',
    '$bootstrapOracleScript',
    '$bootstrapDeliveryResolverScript'
  )
}
function Test-Issue13V5CriticalDefinitionOwnership(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string[]]$ExpectedNames
) {
  $actual = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      $issue13CriticalPowerShellNames -icontains
        (Get-Issue13V5PowerShellCommandLeaf $node.Name)
  }, $true) | ForEach-Object { $_.Name })
  [string]::Join("`n", [string[]]@($actual)) -ceq
    [string]::Join("`n", [string[]]@($ExpectedNames))
}
function Test-Issue13V5BootstrapImports(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string[]]$ExpectedDotSourceSignatures
) {
  $imports = @($Ast.FindAll({
    param($node)
    ($node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -iin @(
        'Import-Module', 'ipmo', 'Import-PSSession', 'ipsn'
      )) -or
      ($node -is [Management.Automation.Language.UsingStatementAst] -and
        $node.UsingStatementKind.ToString() -iin @('Module', 'Assembly'))
  }, $true))
  $dotSources = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      $node.InvocationOperator -eq
        [Management.Automation.Language.TokenKind]::Dot
  }, $true))
  $actual = @($dotSources | ForEach-Object {
    [string]::Join('|', @($_.CommandElements | ForEach-Object {
      $_.Extent.Text
    }))
  })
  $requirements = $Ast.ScriptRequirements
  $requirementsClean = $null -eq $requirements -or
    (@($requirements.RequiredModules).Count -eq 0 -and
      @($requirements.RequiredAssemblies).Count -eq 0)
  @($imports).Count -eq 0 -and
    $requirementsClean -and
    [string]::Join("`n", [string[]]@($actual)) -ceq
      [string]::Join("`n", [string[]]@($ExpectedDotSourceSignatures))
}
$issue13ControllerPowerShellAsts = @{}
$issue13ControllerPowerShellTexts = @{}
$issue13ControllerPowerShellFileSha256 = @{}
foreach ($controllerPowerShellName in @($expectedControllerFiles |
    Where-Object { $_ -like '*.ps1' })) {
  $criticalTokens = $null
  $criticalErrors = @()
  $criticalPath = Join-Path $root $controllerPowerShellName
  $criticalText = [string]$bootstrapSourceTexts[$controllerPowerShellName]
  $criticalFileSha256 =
    [string]$bootstrapSourceFileSha256[$controllerPowerShellName]
  $criticalAst = $bootstrapSourceAsts[$controllerPowerShellName]
  $issue13ControllerPowerShellAsts[$controllerPowerShellName] = $criticalAst
  $issue13ControllerPowerShellTexts[$controllerPowerShellName] = $criticalText
  $issue13ControllerPowerShellFileSha256[$controllerPowerShellName] =
    $criticalFileSha256
  $expectedDefinitions = if (
      $issue13CriticalDefinitionOwners.ContainsKey($controllerPowerShellName)) {
    @($issue13CriticalDefinitionOwners[$controllerPowerShellName])
  } else {
    @()
  }
  $expectedDotSources = if (
      $issue13ExpectedDotSourceSignatures.ContainsKey(
        $controllerPowerShellName)) {
    @($issue13ExpectedDotSourceSignatures[$controllerPowerShellName])
  } else {
    @()
  }
  if ($criticalErrors.Count -ne 0 -or
      -not $issue13ExpectedControllerSourceSha256.ContainsKey(
        $controllerPowerShellName) -or
      (Get-Issue13V5ControllerSourceSha256 `
        $criticalText $controllerPowerShellName) -cne
        [string]$issue13ExpectedControllerSourceSha256[
          $controllerPowerShellName] -or
      -not $issue13ExpectedAstSurfaces.ContainsKey(
        $controllerPowerShellName) -or
      -not (Test-Issue13V5AstSurface $criticalAst `
        $issue13ExpectedAstSurfaces[$controllerPowerShellName]) -or
      -not (Test-Issue13V5CanonicalCriticalCommands `
        $criticalAst $issue13CriticalPowerShellNames) -or
      -not (Test-Issue13V5CriticalDefinitionOwnership `
        $criticalAst $expectedDefinitions) -or
      -not (Test-Issue13V5BootstrapImports `
        $criticalAst $expectedDotSources)) {
    throw "Critical command is qualified, case-variant, or dynamic: $controllerPowerShellName"
  }
  $criticalBytesAfter = [IO.File]::ReadAllBytes($criticalPath)
  $criticalHashAfter = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($criticalBytesAfter))
  if ($criticalHashAfter -cne $criticalFileSha256) {
    throw "Controller source changed while authenticating: $controllerPowerShellName"
  }
}
$surfaceControlName = 'issue13-v5-attest-delivery.ps1'
$surfaceControlAst = $issue13ControllerPowerShellAsts[$surfaceControlName]
$surfaceControlText = $surfaceControlAst.Extent.Text
$surfaceMutants = @(
  ($surfaceControlText + "`n" +
    '$p = ''function:Write-Issue13V5Json''; ' +
    'Set-Item -Path $p -Value { throw }'),
  ($surfaceControlText + "`n" +
    '& (''Write-Issue13'' + ''V5Json'')'),
  ($surfaceControlText + "`n" +
    '''x'' > (''VaRiAbLe:\DeLiVeRyPrOtEcTeDrOoTs'')'),
  ($surfaceControlText + "`n" +
    '$p = ''variable:\deliveryProtectedRoots''; ' +
    '$h = Get-Item -LiteralPath $p; $h.Value = ''changed'''),
  ($surfaceControlText + "`n" +
    'Invoke-Expression ''$deliveryProtectedRoots = @()'''),
  ($surfaceControlText + "`n" +
    '$sb = [scriptblock]::(''Cr'' + ''eate'')(''$x = 1''); ' +
    '1 | ForEach-Object $sb')
)
foreach ($surfaceMutantText in $surfaceMutants) {
  $surfaceMutantTokens = $null
  $surfaceMutantErrors = $null
  $surfaceMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $surfaceMutantText, [ref]$surfaceMutantTokens,
      [ref]$surfaceMutantErrors)
  if ($surfaceMutantErrors.Count -ne 0 -or
      (Test-Issue13V5AstSurface $surfaceMutantAst `
        $issue13ExpectedAstSurfaces[$surfaceControlName])) {
    throw 'Controller AST surface accepted a command/provider mutant.'
  }
}
$sourceOnlyMutants = @(
  ($surfaceControlText + "`n" +
    '$h = $deliveryProtectedRoots; $h.Clear()'),
  ($surfaceControlText + "`n" +
    '$h = $deliveryProtectedRoots; $h[0] = ''changed'''),
  ($surfaceControlText + "`n" +
    '$CoNfIg.repository_root = ''C:\unprotected''')
)
foreach ($sourceOnlyMutantText in $sourceOnlyMutants) {
  if ((Get-Issue13V5ControllerSourceSha256 `
      $sourceOnlyMutantText $surfaceControlName) -ceq
      [string]$issue13ExpectedControllerSourceSha256[$surfaceControlName]) {
    throw 'Controller source seal accepted an assignment/member mutant.'
  }
}
$staticSourceText =
  [string]$bootstrapSourceTexts['issue13-v5-static-verify.ps1']
$selfMapMarker = '$issue13ExpectedControllerSourceSha256 = @{'
$selfCaseMutantText = $staticSourceText.Replace(
  $selfMapMarker, '$IsSuE13eXpEcTeDcOnTrOlLeRsOuRcEsHa256 = @{')
$selfCaseAccepted = $false
try {
  $null = Get-Issue13V5ControllerSourceSha256 `
    $selfCaseMutantText 'issue13-v5-static-verify.ps1'
  $selfCaseAccepted = $true
} catch {
  $selfCaseAccepted = $false
}
if ($selfCaseMutantText -ceq $staticSourceText -or $selfCaseAccepted) {
  throw 'Static verifier source seal accepted a case-variant self map.'
}
$selfExpressionMutantText = [regex]::Replace(
  $staticSourceText,
  "(?m)^  'issue13-v5-static-verify\.ps1' = '[0-9A-F]{64}'$",
  "  'issue13-v5-static-verify.ps1' = " +
    '$([string]::Concat(''00000000000000000000000000000000'', ' +
    '''00000000000000000000000000000000''))',
  1)
$selfExpressionAccepted = $false
try {
  $null = Get-Issue13V5ControllerSourceSha256 `
    $selfExpressionMutantText 'issue13-v5-static-verify.ps1'
  $selfExpressionAccepted = $true
} catch {
  $selfExpressionAccepted = $false
}
if ($selfExpressionMutantText -ceq $staticSourceText -or
    $selfExpressionAccepted) {
  throw 'Static verifier source seal accepted an executable self value.'
}
$criticalMutantTokens = $null
$criticalMutantErrors = $null
$criticalMutantAst = [Management.Automation.Language.Parser]::ParseInput(
  "EvilModule\Assert-Issue13V5ConfigPathIsolation `$a `$b`n" +
    'function local:wRiTe-IsSuE13oRaClEeFfEcTjSoNoNcE {}',
  [ref]$criticalMutantTokens, [ref]$criticalMutantErrors)
if ($criticalMutantErrors.Count -ne 0 -or
    (Test-Issue13V5CanonicalCriticalCommands `
      $criticalMutantAst $issue13CriticalPowerShellNames)) {
  throw 'Critical-command canonicalization accepted a qualified mutant.'
}
$criticalProviderMutantTokens = $null
$criticalProviderMutantErrors = $null
$criticalProviderMutantAst =
  [Management.Automation.Language.Parser]::ParseInput(
    '${FuNcTiOn:Assert-Issue13V5ConfigPathIsolation} = { throw }' + "`n" +
      '${AlIaS:Move-Item} = ''Write-Output''',
    [ref]$criticalProviderMutantTokens,
    [ref]$criticalProviderMutantErrors)
if ($criticalProviderMutantErrors.Count -ne 0 -or
    (Test-Issue13V5CanonicalCriticalCommands `
      $criticalProviderMutantAst $issue13CriticalPowerShellNames)) {
  throw 'Critical-command canonicalization accepted a provider rebind.'
}
$criticalItemProviderMutantTokens = $null
$criticalItemProviderMutantErrors = $null
$criticalItemProviderMutantAst =
  [Management.Automation.Language.Parser]::ParseInput(
    'New-Item -Path function:Write-Issue13V5Json -Value { throw }',
    [ref]$criticalItemProviderMutantTokens,
    [ref]$criticalItemProviderMutantErrors)
if ($criticalItemProviderMutantErrors.Count -ne 0 -or
    (Test-Issue13V5CanonicalCriticalCommands `
      $criticalItemProviderMutantAst $issue13CriticalPowerShellNames)) {
  throw 'Critical-command canonicalization accepted an item-provider rebind.'
}
$criticalAliasMutantTokens = $null
$criticalAliasMutantErrors = $null
$criticalAliasMutantAst =
  [Management.Automation.Language.Parser]::ParseInput(
    "gcm pwsh`nGCM git`nmv `$a `$b`nMOVE `$a `$b`n" +
      "gc `$p`nTYPE `$p",
    [ref]$criticalAliasMutantTokens, [ref]$criticalAliasMutantErrors)
if ($criticalAliasMutantErrors.Count -ne 0 -or
    (Test-Issue13V5CanonicalCriticalCommands `
      $criticalAliasMutantAst $issue13CriticalPowerShellNames)) {
  throw 'Critical-command canonicalization accepted a built-in alias.'
}
$protectedMutationTokens = $null
$protectedMutationErrors = $null
$protectedMutationAst = [Management.Automation.Language.Parser]::ParseInput(
  '$p = ''var'' + ''iable:resolvedProof''' + "`n" +
    'Set-Item -Path $p -Value $ProofPath' + "`n" +
    '$m = ''Set-Variable''' + "`n" +
    '& $m -Name resolvedProof -Value $ProofPath' + "`n" +
    '$s = @{ OutVariable = ''resolvedProof'' }' + "`n" +
    'Write-Output $ProofPath @s',
  [ref]$protectedMutationTokens, [ref]$protectedMutationErrors)
$protectedMutationCommands = @($protectedMutationAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst]
}, $true))
if ($protectedMutationErrors.Count -ne 0 -or
    $protectedMutationCommands.Count -ne 3 -or
    @($protectedMutationCommands | Where-Object {
      -not (Test-Issue13V5ForbiddenProtectedScopeCommand $_)
    }).Count -ne 0) {
  throw 'Protected-scope command guard missed a constructed mutation.'
}
$abbreviatedMutationTokens = $null
$abbreviatedMutationErrors = $null
$abbreviatedMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    'Write-Output x -Pi roots | Out-Null' + "`n" +
      '''x'' | Tee-Object -V roots | Out-Null' + "`n" +
      '& Write-Output x -OuTv roots' + "`n" +
      'Invoke-Expression ''$roots = @()''' + "`n" +
      '''x'' > (''VaRiAbLe:\roots'')' + "`n" +
      '$sb = [scriptblock]::(''Cr'' + ''eate'')(''$roots = @()'')',
    [ref]$abbreviatedMutationTokens,
    [ref]$abbreviatedMutationErrors)
$abbreviatedMutationCommands = @($abbreviatedMutationAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    ($node.Extent.Text -cmatch '-Pi(?:\s|$)' -or
      $node.Extent.Text -cmatch 'Tee-Object\s+-V(?:\s|$)' -or
      $node.Extent.Text -cmatch '-OuTv(?:\s|$)')
}, $true))
$invokeExpressionMutants = @($abbreviatedMutationAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Invoke-Expression'
}, $true))
if ($abbreviatedMutationErrors.Count -ne 0 -or
    $abbreviatedMutationCommands.Count -ne 3 -or
    @($abbreviatedMutationCommands | Where-Object {
      -not (Test-Issue13V5ForbiddenVariableMutationCommand $_)
    }).Count -ne 0 -or
    $invokeExpressionMutants.Count -ne 1 -or
    -not (Test-Issue13V5ForbiddenProtectedScopeCommand `
      $invokeExpressionMutants[0]) -or
    -not (Test-Issue13V5ForbiddenProtectedScopeRedirection `
      $abbreviatedMutationAst) -or
    -not (Test-Issue13V5ForbiddenSessionStateMutation `
      $abbreviatedMutationAst)) {
  throw 'Protected-scope guard accepted an abbreviated/dynamic mutation.'
}
$sessionScopeMutants = @(
  ('$GLOBAL:eXeCuTiOnCoNtExT.SessionState.' +
    '(''PS'' + ''Variable'').Set(''roots'', @())')
  '$script:PSDefaultParameterValues[''*:OutVariable''] = ''roots'''
  '$GLOBAL:pSdEfAuLtPaRaMeTeRvAlUeS[''*:PipelineVariable''] = ''roots'''
)
foreach ($sessionScopeMutantText in $sessionScopeMutants) {
  $sessionScopeMutantTokens = $null
  $sessionScopeMutantErrors = $null
  $sessionScopeMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $sessionScopeMutantText, [ref]$sessionScopeMutantTokens,
      [ref]$sessionScopeMutantErrors)
  if ($sessionScopeMutantErrors.Count -ne 0 -or
      -not (Test-Issue13V5ForbiddenSessionStateMutation `
        $sessionScopeMutantAst)) {
    throw 'Protected-scope guard accepted a scoped session-state mutation.'
  }
}
$criticalOwnerMutantTokens = $null
$criticalOwnerMutantErrors = $null
$criticalOwnerMutantAst =
  [Management.Automation.Language.Parser]::ParseInput(
    'function Assert-Issue13V5ConfigPathIsolation { throw }',
    [ref]$criticalOwnerMutantTokens, [ref]$criticalOwnerMutantErrors)
if ($criticalOwnerMutantErrors.Count -ne 0 -or
    (Test-Issue13V5CriticalDefinitionOwnership `
      $criticalOwnerMutantAst @())) {
  throw 'Critical-function ownership accepted a local shadow definition.'
}
$criticalImportMutantTokens = $null
$criticalImportMutantErrors = $null
$criticalImportMutantAst =
  [Management.Automation.Language.Parser]::ParseInput(
    '. $evil', [ref]$criticalImportMutantTokens,
    [ref]$criticalImportMutantErrors)
if ($criticalImportMutantErrors.Count -ne 0 -or
    (Test-Issue13V5BootstrapImports $criticalImportMutantAst @())) {
  throw 'Critical bootstrap allowlist accepted an extra dot-source.'
}

$captureLibraryPath = Join-Path $root 'issue13-v5-coordinator-lib.ps1'
$captureTokens = @()
$captureErrors = @()
$captureLibraryAst =
  $issue13ControllerPowerShellAsts['issue13-v5-coordinator-lib.ps1']
$physicalCopyDefinitions = @($captureLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Copy-Issue13V5PhysicalDirectorySnapshot'
}, $true))
$physicalProofDefinitions = @($captureLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Get-Issue13V5PhysicalSnapshotProof'
}, $true))
$runtimeCopyDefinitions = @($captureLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5PhysicalCopy'
}, $true))
if ($captureErrors.Count -ne 0 -or $physicalCopyDefinitions.Count -ne 1 -or
    $physicalProofDefinitions.Count -ne 1 -or
    $runtimeCopyDefinitions.Count -ne 1) {
  throw 'Native physical-copy definitions are missing or ambiguous.'
}
$physicalFileCopies = @($physicalCopyDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
    $node.Static -and $node.Member.Extent.Text -ieq 'Copy' -and
    (Test-Issue13V5TypeExpression $node.Expression 'System.IO.File')
}, $true))
$physicalProofCalls = @($physicalCopyDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Get-Issue13V5PhysicalSnapshotProof'
}, $true))
$proofIdentityCalls = @($physicalProofDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Get-Issue13V5PhysicalItemIdentity'
}, $true))
$runtimeIdentityCalls = @($runtimeCopyDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Get-Issue13V5PhysicalItemIdentity'
}, $true))
$officialSourceDefinitions = @($captureLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5OfficialSourceDataInventory'
}, $true))
$officialSourceInventoryCalls = @()
if ($officialSourceDefinitions.Count -eq 1) {
  $officialSourceInventoryCalls = @($officialSourceDefinitions[0].FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Get-Issue13V5TreeInventory'
  }, $true))
}
$officialSourceConstantDefinitions = @($captureLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Set-Issue13V5ScriptConstant'
}, $true))
$officialSourceConstantCalls = @($captureLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Set-Issue13V5ScriptConstant'
}, $true))
$officialSourceConstantSignatures = @($officialSourceConstantCalls |
  ForEach-Object {
    [string]::Join(' ', @($_.CommandElements | ForEach-Object {
      $_.Extent.Text
    }))
  } | Sort-Object)
$expectedOfficialSourceConstantSignatures = @(
  'Set-Issue13V5ScriptConstant Issue13V5SourceDirectoryCount 5L',
  "Set-Issue13V5ScriptConstant Issue13V5SourceDirectorySha256 '8b3a622a748f2489fe8cfd2a8273ec98ad4c372b2378d587a5ee2e3c5c916640'",
  'Set-Issue13V5ScriptConstant Issue13V5SourceFileCount 84L',
  "Set-Issue13V5ScriptConstant Issue13V5SourceInventorySha256 'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26'",
  "Set-Issue13V5ScriptConstant Issue13V5SourceOrdinalInventorySha256 'd7fc0ba48bed304cf3975f2189ee975b14c16522443b28379d26329ea661b97a'",
  'Set-Issue13V5ScriptConstant Issue13V5SourceTotalBytes 2946498269L'
)
$expectedOfficialSourceConstantHelper = @'
function Set-Issue13V5ScriptConstant(
  [Parameter(Mandatory)][string]$Name,
  [Parameter(Mandatory)][object]$Value
) {
  $existing = Get-Variable -Name $Name -Scope Script `
    -ErrorAction SilentlyContinue
  if ($null -eq $existing) {
    New-Variable -Name $Name -Scope Script -Option Constant -Value $Value
    return
  }
  if ($existing.Options -ne
      [Management.Automation.ScopedItemOptions]::Constant -or
      -not [object]::Equals($existing.Value, $Value)) {
    throw "Script constant is already bound differently: $Name"
  }
}
'@
$actualOfficialSourceConstantHelper = if (
    $officialSourceConstantDefinitions.Count -eq 1) {
  [regex]::Replace(
    $officialSourceConstantDefinitions[0].Extent.Text.Trim(), '\r\n?', "`n")
} else { '' }
$expectedOfficialSourceConstantHelper = [regex]::Replace(
  $expectedOfficialSourceConstantHelper.Trim(), '\r\n?', "`n")
$officialSourceOrdinalSortCalls = @($officialSourceDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
    $node.Static -and
    (Test-Issue13V5TypeExpression $node.Expression 'System.Array') -and
    $node.Member.Extent.Text -ieq 'Sort'
}, $true))
$officialSourceAddMemberCalls = @($officialSourceDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Add-Member'
}, $true))
if ($physicalFileCopies.Count -ne 1 -or
    $physicalFileCopies[0].Arguments.Count -ne 3 -or
    $physicalProofCalls.Count -ne 1 -or $proofIdentityCalls.Count -ne 2 -or
    $runtimeIdentityCalls.Count -ne 2 -or
    $officialSourceDefinitions.Count -ne 1 -or
    $officialSourceInventoryCalls.Count -ne 1 -or
    $actualOfficialSourceConstantHelper -cne
      $expectedOfficialSourceConstantHelper -or
    [string]::Join("`n", $officialSourceConstantSignatures) -cne
      [string]::Join("`n", $expectedOfficialSourceConstantSignatures) -or
    $officialSourceDefinitions[0].Extent.Text.IndexOf(
      '$script:Issue13V5SourceFileCount',
      [StringComparison]::Ordinal) -lt 0 -or
    $officialSourceDefinitions[0].Extent.Text.IndexOf(
      '$script:Issue13V5SourceDirectoryCount',
      [StringComparison]::Ordinal) -lt 0 -or
    $officialSourceDefinitions[0].Extent.Text.IndexOf(
      '$script:Issue13V5SourceTotalBytes',
      [StringComparison]::Ordinal) -lt 0 -or
    $officialSourceDefinitions[0].Extent.Text.IndexOf(
      '$script:Issue13V5SourceInventorySha256',
      [StringComparison]::Ordinal) -lt 0 -or
    $officialSourceDefinitions[0].Extent.Text.IndexOf(
      '$script:Issue13V5SourceOrdinalInventorySha256',
      [StringComparison]::Ordinal) -lt 0 -or
    $officialSourceDefinitions[0].Extent.Text.IndexOf(
      '$script:Issue13V5SourceDirectorySha256',
      [StringComparison]::Ordinal) -lt 0 -or
    $officialSourceOrdinalSortCalls.Count -ne 1 -or
    [string]::Join("`n", @(
      $officialSourceOrdinalSortCalls[0].Arguments | ForEach-Object {
        $_.Extent.Text
      })) -cne "`$ordinalLines`n[StringComparer]::Ordinal" -or
    $officialSourceAddMemberCalls.Count -ne 1 -or
    [string]::Join("`n", @(
      $officialSourceAddMemberCalls[0].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
      "-NotePropertyName`nordinal_inventory_sha256`n" +
        "-NotePropertyValue`n`$ordinalInventorySha256" -or
    $physicalCopyDefinitions[0].Extent.Text.IndexOf(
      'HardLink', [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
    $physicalCopyDefinitions[0].Extent.Text.IndexOf(
      'Junction', [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
    $captureLibraryAst.Extent.Text.IndexOf(
      'fsutil.exe', [StringComparison]::OrdinalIgnoreCase) -ge 0) {
  throw 'Native physical-copy implementation is no longer exact or isolated.'
}
$officialSourceRuntimePins = [ordered]@{
  Issue13V5SourceFileCount = 84L
  Issue13V5SourceDirectoryCount = 5L
  Issue13V5SourceTotalBytes = 2946498269L
  Issue13V5SourceInventorySha256 =
    'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26'
  Issue13V5SourceOrdinalInventorySha256 =
    'd7fc0ba48bed304cf3975f2189ee975b14c16522443b28379d26329ea661b97a'
  Issue13V5SourceDirectorySha256 =
    '8b3a622a748f2489fe8cfd2a8273ec98ad4c372b2378d587a5ee2e3c5c916640'
}
foreach ($pinName in $officialSourceRuntimePins.Keys) {
  $pin = Get-Variable -Name $pinName -Scope Script -ErrorAction Stop
  if ($pin.Options -ne [Management.Automation.ScopedItemOptions]::Constant -or
      -not [object]::Equals(
        $pin.Value, $officialSourceRuntimePins[$pinName])) {
    throw "Official source pin is not an exact script constant: $pinName"
  }
  Set-Issue13V5ScriptConstant $pinName $officialSourceRuntimePins[$pinName]
  $caseVariantMutationRejected = $false
  try {
    Set-Variable -Name $pinName.ToUpperInvariant() -Scope Script `
      -Value '__issue13_mutant__' -Force -ErrorAction Stop
  } catch {
    $caseVariantMutationRejected = $true
  }
  if (-not $caseVariantMutationRejected -or
      -not [object]::Equals(
        (Get-Variable -Name $pinName -Scope Script).Value,
        $officialSourceRuntimePins[$pinName])) {
    throw "Official source script constant accepted mutation: $pinName"
  }
}
$mismatchedPinRejected = $false
try {
  Set-Issue13V5ScriptConstant Issue13V5SourceInventorySha256 `
    '__issue13_mutant__'
} catch {
  $mismatchedPinRejected = $true
}
if (-not $mismatchedPinRejected) {
  throw 'Idempotent source-pin bootstrap accepted a mismatched value.'
}

function Get-Issue13V5AstAncestorChain(
  [Management.Automation.Language.Ast]$Node,
  [Management.Automation.Language.Ast]$RootAst
) {
  $types = @()
  $current = $Node
  while ($null -ne $current -and
      -not [object]::ReferenceEquals($current, $RootAst)) {
    $types += $current.GetType().Name
    $current = $current.Parent
  }
  if ($null -eq $current) { return '' }
  [string]::Join('>', [string[]]$types)
}
function Get-Issue13V5AssignmentBaseVariableName(
  [Management.Automation.Language.Ast]$Left
) {
  $current = $Left
  while ($null -ne $current) {
    if ($current -is
        [Management.Automation.Language.VariableExpressionAst]) {
      $name = [string]$current.VariablePath.UserPath
      $scope = $name.IndexOf(':')
      if ($scope -ge 0 -and $name.Substring(0, $scope) -iin @(
          'script', 'local', 'private', 'global', 'variable')) {
        $name = $name.Substring($scope + 1)
      }
      return '$' + $name
    }
    if ($current -is [Management.Automation.Language.MemberExpressionAst]) {
      $current = $current.Expression
      continue
    }
    if ($current -is [Management.Automation.Language.IndexExpressionAst]) {
      $current = $current.Target
      continue
    }
    if ($current -is [Management.Automation.Language.ConvertExpressionAst] -or
        $current -is
          [Management.Automation.Language.AttributedExpressionAst]) {
      $current = $current.Child
      continue
    }
    if ($current -is [Management.Automation.Language.ParenExpressionAst] -and
        $current.Pipeline.PipelineElements.Count -eq 1 -and
        $current.Pipeline.PipelineElements[0] -is
          [Management.Automation.Language.CommandExpressionAst]) {
      $current = $current.Pipeline.PipelineElements[0].Expression
      continue
    }
    $variables = @($current.FindAll({
      param($node)
      $node -is [Management.Automation.Language.VariableExpressionAst]
    }, $true))
    if ($variables.Count -eq 1) {
      $current = $variables[0]
      continue
    }
    return ''
  }
  ''
}
function Test-Issue13V5AstReferencesVariable(
  [Management.Automation.Language.Ast]$Ast,
  [string]$VariableName
) {
  if ($Ast -is [Management.Automation.Language.VariableExpressionAst] -and
      (Get-Issue13V5AssignmentBaseVariableName $Ast) -ieq $VariableName) {
    return $true
  }
  @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.VariableExpressionAst] -and
      (Get-Issue13V5AssignmentBaseVariableName $node) -ieq $VariableName
  }, $true)).Count -ne 0
}
function Get-Issue13V5VariableWriteBaseName(
  [Management.Automation.Language.Ast]$Node
) {
  if ($Node -is
      [Management.Automation.Language.AssignmentStatementAst]) {
    return Get-Issue13V5AssignmentBaseVariableName $Node.Left
  }
  if ($Node -is [Management.Automation.Language.UnaryExpressionAst] -and
      $Node.TokenKind -in @(
        [Management.Automation.Language.TokenKind]::PlusPlus,
        [Management.Automation.Language.TokenKind]::MinusMinus,
        [Management.Automation.Language.TokenKind]::PostfixPlusPlus,
        [Management.Automation.Language.TokenKind]::PostfixMinusMinus)) {
    return Get-Issue13V5AssignmentBaseVariableName $Node.Child
  }
  if ($Node -is [Management.Automation.Language.ForEachStatementAst]) {
    return Get-Issue13V5AssignmentBaseVariableName $Node.Variable
  }
  if ($Node -is [Management.Automation.Language.ConvertExpressionAst] -and
      $Node.Type.TypeName.FullName -ieq 'ref') {
    return Get-Issue13V5AssignmentBaseVariableName $Node.Child
  }
  if ($Node -is [Management.Automation.Language.FileRedirectionAst] -and
      $Node.Location -is
        [Management.Automation.Language.StringConstantExpressionAst] -and
      $Node.Location.Value -imatch '^variable:') {
    $name = $Node.Location.Value.Substring('variable:'.Length).
      TrimStart([char]'\', [char]'/')
    return '$' + $name
  }
  ''
}
function Get-Issue13V5VariableWriteAsts(
  [Management.Automation.Language.Ast]$Ast,
  [string]$VariableName
) {
  @($Ast.FindAll({
    param($node)
    if ((Get-Issue13V5VariableWriteBaseName $node) -ieq $VariableName) {
      return $true
    }
    $target = if ($node -is
        [Management.Automation.Language.AssignmentStatementAst]) {
      $node.Left
    } elseif ($node -is [Management.Automation.Language.UnaryExpressionAst] -and
        $node.TokenKind -in @(
          [Management.Automation.Language.TokenKind]::PlusPlus,
          [Management.Automation.Language.TokenKind]::MinusMinus,
          [Management.Automation.Language.TokenKind]::PostfixPlusPlus,
          [Management.Automation.Language.TokenKind]::PostfixMinusMinus)) {
      $node.Child
    } elseif ($node -is
        [Management.Automation.Language.ForEachStatementAst]) {
      $node.Variable
    } elseif ($node -is
        [Management.Automation.Language.ConvertExpressionAst] -and
        $node.Type.TypeName.FullName -ieq 'ref') {
      $node.Child
    } else {
      $null
    }
    if ($null -eq $target) { return $false }
    @($target.FindAll({
      param($variable)
      $variable -is
        [Management.Automation.Language.VariableExpressionAst] -and
        (Get-Issue13V5AssignmentBaseVariableName $variable) -ieq
          $VariableName
    }, $true)).Count -ne 0
  }, $true))
}
function Test-Issue13V5SingularDirectAssignment(
  [Management.Automation.Language.Ast]$Ast,
  [string]$VariableName,
  [string]$ExpectedChain,
  [AllowNull()][string]$ExpectedRight = $null
) {
  $assignments = @(Get-Issue13V5VariableWriteAsts $Ast $VariableName)
  $checksRight = $PSBoundParameters.ContainsKey('ExpectedRight')
  if ($assignments.Count -ne 1 -or
      $assignments[0].Left.Extent.Text -cne $VariableName -or
      $assignments[0].Operator -ne
        [Management.Automation.Language.TokenKind]::Equals -or
      (Get-Issue13V5AstAncestorChain $assignments[0] $Ast) -cne
        $ExpectedChain -or
      ($checksRight -and
        $assignments[0].Right.Extent.Text -cne $ExpectedRight)) {
    return $false
  }
  $true
}
function Test-Issue13V5OfficialSourcePinsWriteFree(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  foreach ($pinName in $officialSourceRuntimePins.Keys) {
    if (@(Get-Issue13V5VariableWriteAsts `
        $Ast ('$' + $pinName)).Count -ne 0) {
      return $false
    }
  }
  $true
}
function Test-Issue13V5DeliveryBindingAst(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $definitions = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
        'Invoke-Issue13V5DeliveryAttestation'
  }, $true))
  if ($definitions.Count -ne 1) { return $false }
  $definition = $definitions[0]
  if ($definition.Name -cne 'Invoke-Issue13V5DeliveryAttestation') {
    return $false
  }
  $assignments = @(Get-Issue13V5VariableWriteAsts `
    $definition '$deliveryProtectedRoots')
  $outputAssignments = @(Get-Issue13V5VariableWriteAsts `
    $definition '$outputPath')
  $calls = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Resolve-Issue13V5DeliveryOutput'
  }, $true))
  $dynamicMutators = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Test-Issue13V5ForbiddenProtectedScopeCommand $node)
  }, $true))
  $memberMutators = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      (Test-Issue13V5AstReferencesVariable `
        $node '$deliveryProtectedRoots')
  }, $true))
  $writeCalls = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Write-Issue13V5Json'
  }, $true))
  if ($assignments.Count -ne 1 -or
      $assignments[0].Left.Extent.Text -cne '$deliveryProtectedRoots' -or
      (Get-Issue13V5AstAncestorChain $assignments[0] $definition) -cne
        'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' -or
      $outputAssignments.Count -ne 1 -or
      $outputAssignments[0].Left.Extent.Text -cne '$outputPath' -or
      (Get-Issue13V5AstAncestorChain $outputAssignments[0] $definition) -cne
        'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' -or
      $calls.Count -ne 2 -or
      [string]::Join("`n", @($calls[0].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
        "`$Output`n`$deliveryProtectedRoots" -or
      (Get-Issue13V5AstAncestorChain $calls[0] $definition) -cne
        'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' -or
      -not [object]::ReferenceEquals(
        $calls[0].Parent.Parent, $outputAssignments[0]) -or
      [string]::Join("`n", @($calls[1].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
        "`$outputPath`n`$deliveryProtectedRoots" -or
      (Get-Issue13V5AstAncestorChain $calls[1] $definition) -cne
        'CommandAst>PipelineAst>ParenExpressionAst>CommandAst>PipelineAst>' +
          'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' -or
      $writeCalls.Count -ne 1 -or
      -not [object]::ReferenceEquals(
        $calls[1].Parent.Parent.Parent, $writeCalls[0]) -or
      $writeCalls[0].CommandElements[1].Extent.Text -cne '$attestation') {
    return $false
  }
  if ($dynamicMutators.Count -ne 0 -or
      (Test-Issue13V5ForbiddenProtectedScopeRedirection $definition) -or
      (Test-Issue13V5ForbiddenSessionStateMutation $definition) -or
      $memberMutators.Count -ne 0) {
    return $false
  }
  $expectedRoots = '@([string]$config.repository_root,' +
    '[string]$config.worktree_root,' +
    '[string]$config.evidence_root,' +
    '[string]$config.control_root,' +
    '[string]$config.harness_runtime_root,' +
    '[string]$config.source_origin,' +
    '[string]$config.candidate_source_origin,' +
    '[string]$config.r_library,' +
    '[string]$config.rscript,' +
    '[string]$config.oracle_effect.comparisons.primary.root,' +
    '[string]$config.oracle_effect.comparisons.replay.root)'
  [regex]::Replace(
    $assignments[0].Right.Extent.Text, '\s+', '') -ceq $expectedRoots
}

$deliveryTokens = @()
$deliveryErrors = @()
$deliveryAst =
  $issue13ControllerPowerShellAsts['issue13-v5-attest-delivery.ps1']
$deliveryOutputDefinitions = @($deliveryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Resolve-Issue13V5DeliveryOutput'
}, $true))
$deliveryInvokeDefinitions = @($deliveryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Invoke-Issue13V5DeliveryAttestation'
}, $true))
if ($deliveryErrors.Count -ne 0 -or $deliveryOutputDefinitions.Count -ne 1 -or
    $deliveryInvokeDefinitions.Count -ne 1) {
  throw 'Delivery-output resolver AST is missing or ambiguous.'
}
$deliveryPhysicalCalls = @($deliveryOutputDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'ConvertTo-Issue13V5PhysicalPath'
}, $true))
$deliveryContainmentCalls = @($deliveryOutputDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Test-Issue13V5PathContained'
}, $true))
$deliveryDisjointCalls = @($deliveryOutputDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5PathsDisjoint'
}, $true))
$deliveryAncestorCalls = @($deliveryOutputDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5NoReparseAncestors'
}, $true))
if ($deliveryPhysicalCalls.Count -ne 2 -or
    $deliveryContainmentCalls.Count -ne 0 -or
    $deliveryDisjointCalls.Count -ne 1 -or
    (Get-Issue13V5AstAncestorChain `
      $deliveryDisjointCalls[0] $deliveryOutputDefinitions[0]) -cne
      'CommandAst>PipelineAst>StatementBlockAst>ForEachStatementAst>NamedBlockAst>ScriptBlockAst' -or
    $deliveryAncestorCalls.Count -ne 2 -or
    $deliveryOutputDefinitions[0].Extent.Text.Contains('.StartsWith(') -or
    $deliveryOutputDefinitions[0].Extent.Text.Contains(
      'Test-Issue13V5DeliveryPathWithin')) {
  throw 'Delivery output is no longer physically isolated.'
}
$deliveryProtectedAssignments = @(Get-Issue13V5VariableWriteAsts `
  $deliveryInvokeDefinitions[0] '$deliveryProtectedRoots')
$deliveryProtectedVariables = if ($deliveryProtectedAssignments.Count -eq 1) {
  @($deliveryProtectedAssignments[0].Right.FindAll({
    param($node)
    $node -is [Management.Automation.Language.VariableExpressionAst]
  }, $true) | ForEach-Object { '$' + $_.VariablePath.UserPath })
} else { @() }
$deliveryResolverCalls = @($deliveryInvokeDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Resolve-Issue13V5DeliveryOutput'
}, $true))
if ($deliveryProtectedAssignments.Count -ne 1 -or
    $deliveryProtectedAssignments[0].Left.Extent.Text -cne
      '$deliveryProtectedRoots' -or
    (Get-Issue13V5AstAncestorChain $deliveryProtectedAssignments[0] `
      $deliveryInvokeDefinitions[0]) -cne
      'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' -or
    [string]::Join("`n", $deliveryProtectedVariables) -cne
      [string]::Join("`n", @(
        '$config', '$config', '$config', '$config', '$config', '$config',
        '$config', '$config', '$config', '$config', '$config'
      )) -or
    $deliveryResolverCalls.Count -ne 2 -or
    -not (Test-Issue13V5DeliveryBindingAst $deliveryAst)) {
  throw 'Delivery protected-root binding is incomplete or bypassable.'
}
$deliveryText = $deliveryAst.Extent.Text
$deliveryResolverOwner = $deliveryResolverCalls[0].Parent
while ($null -ne $deliveryResolverOwner -and
    $deliveryResolverOwner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
  $deliveryResolverOwner = $deliveryResolverOwner.Parent
}
$deliveryResolverStatement = [string]$deliveryResolverOwner.Extent.Text
$deliveryConditionalStatement = '$outputPath = if ($false) {' + "`n" +
  [string]$deliveryResolverOwner.Right.Extent.Text + "`n} else { `$null }"
$deliveryConditionalText = $deliveryText.Replace(
  $deliveryResolverStatement, $deliveryConditionalStatement)
$deliveryConditionalTokens = $null
$deliveryConditionalErrors = $null
$deliveryConditionalAst = [Management.Automation.Language.Parser]::ParseInput(
  $deliveryConditionalText, [ref]$deliveryConditionalTokens,
  [ref]$deliveryConditionalErrors)
if ($deliveryConditionalErrors.Count -ne 0 -or
    (Test-Issue13V5DeliveryBindingAst $deliveryConditionalAst)) {
  throw 'Delivery binding accepted a conditional resolver call.'
}
$deliverySubassignmentText = $deliveryText.Replace(
  [string]$deliveryProtectedAssignments[0].Extent.Text,
  [string]$deliveryProtectedAssignments[0].Extent.Text +
    "`n  [string[]]`$DeLiVeRyPrOtEcTeDrOoTs = @(`$repository)")
$deliverySubassignmentTokens = $null
$deliverySubassignmentErrors = $null
$deliverySubassignmentAst = [Management.Automation.Language.Parser]::ParseInput(
  $deliverySubassignmentText, [ref]$deliverySubassignmentTokens,
  [ref]$deliverySubassignmentErrors)
if ($deliverySubassignmentErrors.Count -ne 0 -or
    (Test-Issue13V5DeliveryBindingAst $deliverySubassignmentAst)) {
  throw 'Delivery binding accepted a protected-root subassignment.'
}
$deliveryDynamicMutationText = $deliveryText.Replace(
  [string]$deliveryProtectedAssignments[0].Extent.Text,
  [string]$deliveryProtectedAssignments[0].Extent.Text +
    "`n  Microsoft.PowerShell.Utility\Set-Variable " +
      "-Name deliveryProtectedRoots -Value @(`$repository)")
$deliveryDynamicMutationTokens = $null
$deliveryDynamicMutationErrors = $null
$deliveryDynamicMutationAst = [Management.Automation.Language.Parser]::ParseInput(
  $deliveryDynamicMutationText, [ref]$deliveryDynamicMutationTokens,
  [ref]$deliveryDynamicMutationErrors)
if ($deliveryDynamicMutationErrors.Count -ne 0 -or
    (Test-Issue13V5DeliveryBindingAst $deliveryDynamicMutationAst)) {
  throw 'Delivery binding accepted a dynamic protected-root mutation.'
}
$deliveryRootWrapperText = $deliveryText.Replace(
  '[string]$config.repository_root',
  '[System.String]([string]$config.repository_root + ''\x'')')
$deliveryRootWrapperTokens = $null
$deliveryRootWrapperErrors = $null
$deliveryRootWrapperAst = [Management.Automation.Language.Parser]::ParseInput(
  $deliveryRootWrapperText, [ref]$deliveryRootWrapperTokens,
  [ref]$deliveryRootWrapperErrors)
if ($deliveryRootWrapperErrors.Count -ne 0 -or
    (Test-Issue13V5DeliveryBindingAst $deliveryRootWrapperAst)) {
  throw 'Delivery binding accepted a wrapped protected root.'
}
$deliveryWriteCalls = @($deliveryInvokeDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Write-Issue13V5Json'
}, $true))
$deliveryWriteOwner = $deliveryWriteCalls[0].Parent
while ($null -ne $deliveryWriteOwner -and
    $deliveryWriteOwner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
  $deliveryWriteOwner = $deliveryWriteOwner.Parent
}
$deliveryOutputMutationText = $deliveryText.Replace(
  [string]$deliveryWriteOwner.Extent.Text,
  "  `$OuTpUtPaTh = Join-Path `$repository 'issue13-mutant.json'`n" +
    [string]$deliveryWriteOwner.Extent.Text)
$deliveryOutputMutationTokens = $null
$deliveryOutputMutationErrors = $null
$deliveryOutputMutationAst = [Management.Automation.Language.Parser]::ParseInput(
  $deliveryOutputMutationText, [ref]$deliveryOutputMutationTokens,
  [ref]$deliveryOutputMutationErrors)
if ($deliveryOutputMutationErrors.Count -ne 0 -or
    (Test-Issue13V5DeliveryBindingAst $deliveryOutputMutationAst)) {
  throw 'Delivery binding accepted a post-check output mutation.'
}

$materializerTokens = @()
$materializerErrors = @()
$materializerAst =
  $bootstrapSourceAsts['issue13-v5-materialize-harness.ps1']
function Test-Issue13V5MaterializerTargetDataflow(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $definitions = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
        'Assert-Issue13V5AliasFreeLocalPath'
  }, $true))
  if ($definitions.Count -ne 1) { return $false }
  $definition = $definitions[0]
  $calls = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      $node.Static -and
      (Test-Issue13V5TypeExpression `
        $node.Expression 'Issue13V5.NativePath') -and
      $node.Member.Extent.Text -ieq 'DriveTarget'
  }, $true))
  $assignments = @(Get-Issue13V5VariableWriteAsts $definition '$target')
  $dynamicMutators = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Test-Issue13V5ForbiddenProtectedScopeCommand $node)
  }, $true))
  if ($calls.Count -ne 1 -or $assignments.Count -ne 1 -or
      $dynamicMutators.Count -ne 0 -or
      (Test-Issue13V5ForbiddenProtectedScopeRedirection $definition) -or
      (Test-Issue13V5ForbiddenSessionStateMutation $definition)) {
    return $false
  }
  $owner = $calls[0].Parent
  while ($null -ne $owner -and $owner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
    $owner = $owner.Parent
  }
  if ($null -eq $owner -or
      -not [object]::ReferenceEquals($owner, $assignments[0]) -or
      -not [object]::ReferenceEquals(
        $assignments[0].Parent, $definition.Body.EndBlock)) {
    return $false
  }
  $callChain = @()
  $current = $calls[0]
  while ($null -ne $current) {
    $callChain += $current.GetType().Name
    if ([object]::ReferenceEquals($current, $owner)) { break }
    $current = $current.Parent
  }
  if ([string]::Join('>', [string[]]$callChain) -cne
      'InvokeMemberExpressionAst>CommandExpressionAst>AssignmentStatementAst') {
    return $false
  }
  $true
}
$materializerAliasDefinitions = @($materializerAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5AliasFreeLocalPath'
}, $true))
$materializerCanonicalDefinitions = @($materializerAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'ConvertTo-Issue13V5CanonicalPath'
}, $true))
$materializerAliasCalls = @($materializerAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5AliasFreeLocalPath'
}, $true))
$materializerDriveTargetCalls = @($materializerAliasDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
    $node.Static -and
    (Test-Issue13V5TypeExpression `
      $node.Expression 'Issue13V5.NativePath') -and
    $node.Member.Extent.Text -ieq 'DriveTarget'
}, $true))
$materializerDriveTargetAssignment = if (
    $materializerDriveTargetCalls.Count -eq 1) {
  $value = $materializerDriveTargetCalls[0].Parent
  while ($null -ne $value -and $value -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
    $value = $value.Parent
  }
  $value
} else {
  $null
}
$materializerTargetAssignments = @(Get-Issue13V5VariableWriteAsts `
  $materializerAliasDefinitions[0] '$target')
$materializerTargetChecks = @($materializerAliasDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
    -not $node.Static -and $node.Expression.Extent.Text -ieq '$target' -and
    $node.Member.Extent.Text -ieq 'StartsWith'
}, $true))
$materializerAddTypeCalls = @($materializerAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Add-Type'
}, $true))
$materializerText = $materializerAst.Extent.Text
$materializerAliasText = $materializerAliasDefinitions[0].Extent.Text
if ($materializerErrors.Count -ne 0 -or
    $materializerAliasDefinitions.Count -ne 1 -or
    $materializerCanonicalDefinitions.Count -ne 1 -or
    $materializerAliasCalls.Count -ne 4 -or
    -not (Test-Issue13V5MaterializerTargetDataflow $materializerAst) -or
    $materializerDriveTargetCalls.Count -ne 1 -or
    $materializerTargetAssignments.Count -ne 1 -or
    $null -eq $materializerDriveTargetAssignment -or
    -not [object]::ReferenceEquals(
      $materializerDriveTargetAssignment, $materializerTargetAssignments[0]) -or
    $materializerDriveTargetAssignment.Left.Extent.Text -cne '$target' -or
    $materializerDriveTargetCalls[0].Arguments.Count -ne 1 -or
    $materializerDriveTargetCalls[0].Arguments[0].Extent.Text -cne
      '$root.Substring(0, 2)' -or
    $materializerTargetChecks.Count -ne 4 -or
    $materializerAddTypeCalls.Count -ne 1 -or
    $materializerAddTypeCalls[0].CommandElements.Count -ne 3 -or
    $materializerText.IndexOf(
      'QueryDosDevice', [StringComparison]::Ordinal) -lt 0 -or
    $materializerAliasText.IndexOf(
      '[IO.DriveType]::Fixed', [StringComparison]::Ordinal) -lt 0 -or
    $materializerAliasText.IndexOf(
      "'\??\'", [StringComparison]::Ordinal) -lt 0 -or
    $materializerAliasText.IndexOf(
      "'\Device\Mup\'", [StringComparison]::Ordinal) -lt 0) {
  throw 'Harness materializer lacks fixed alias-free root isolation.'
}
$materializerNativeSource =
  [string]$materializerAddTypeCalls[0].CommandElements[2].Value
$materializerTargetStatement =
  [string]$materializerTargetAssignments[0].Extent.Text
if ($materializerText.IndexOf(
      $materializerTargetStatement, [StringComparison]::Ordinal) -ne
    $materializerText.LastIndexOf(
      $materializerTargetStatement, [StringComparison]::Ordinal)) {
  throw 'Harness materializer target assignment is not textually unique.'
}
$materializerDeadBranchText = $materializerText.Replace(
  $materializerTargetStatement,
  "if (`$false) {`n$materializerTargetStatement`n  }" +
    "`n  `$target = '\Device\HarddiskVolume3'")
$materializerDeadBranchTokens = $null
$materializerDeadBranchErrors = $null
$materializerDeadBranchAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $materializerDeadBranchText, [ref]$materializerDeadBranchTokens,
    [ref]$materializerDeadBranchErrors)
if ($materializerDeadBranchErrors.Count -ne 0 -or
    (Test-Issue13V5MaterializerTargetDataflow $materializerDeadBranchAst)) {
  throw 'Harness materializer accepted a dead DriveTarget branch mutant.'
}
$materializerConditionalRhsText = $materializerText.Replace(
  $materializerTargetStatement,
  '$target = if ($false) { ' +
    [string]$materializerTargetAssignments[0].Right.Extent.Text +
    " } else { '\Device\HarddiskVolume3' }")
$materializerConditionalRhsTokens = $null
$materializerConditionalRhsErrors = $null
$materializerConditionalRhsAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $materializerConditionalRhsText, [ref]$materializerConditionalRhsTokens,
    [ref]$materializerConditionalRhsErrors)
if ($materializerConditionalRhsErrors.Count -ne 0 -or
    (Test-Issue13V5MaterializerTargetDataflow $materializerConditionalRhsAst)) {
  throw 'Harness materializer accepted a conditional DriveTarget RHS mutant.'
}
$materializerPropertyMutationText = $materializerText.Replace(
  $materializerTargetStatement,
  $materializerTargetStatement + "`n  `$target[0] = 'X'")
$materializerPropertyMutationTokens = $null
$materializerPropertyMutationErrors = $null
$materializerPropertyMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $materializerPropertyMutationText,
    [ref]$materializerPropertyMutationTokens,
    [ref]$materializerPropertyMutationErrors)
if ($materializerPropertyMutationErrors.Count -ne 0 -or
    (Test-Issue13V5MaterializerTargetDataflow `
      $materializerPropertyMutationAst)) {
  throw 'Harness materializer accepted a target subassignment mutant.'
}

$expectedCaptureHeaders = @{
  'issue13-v5-capture-clean-bridge-evidence.ps1' = @(
    'schema', 'baseline_base_commit', 'baseline_base_tree',
    'baseline_runtime_commit', 'baseline_runtime_tree', 'harness_path',
    'harness_inventory_sha256', 'harness_runtime_path',
    'harness_runtime_inventory_before_sha256',
    'harness_runtime_inventory_after_sha256', 'rscript_path',
    'rscript_sha256', 'fsutil_path', 'fsutil_sha256', 'r_library_path',
    'r_library_inventory_before_sha256',
    'r_library_inventory_after_sha256', 'tool_records', 'baseline_worktree',
    'captured_methods', 'verified_records', 'seed_evidence_index_sha256',
    'source_data_origin_path', 'source_data_snapshot_path',
    'source_data_origin_inventory_before_sha256',
    'source_data_origin_inventory_after_sha256',
    'source_data_snapshot_inventory_before_sha256',
    'source_data_snapshot_inventory_after_sha256',
    'source_data_origin_physical_path',
    'source_data_snapshot_physical_path', 'source_data_physical_file_count',
    'source_data_physical_directory_count',
    'source_data_origin_physical_before_sha256',
    'source_data_origin_physical_after_sha256',
    'source_data_snapshot_physical_before_sha256',
    'source_data_snapshot_physical_after_sha256',
    'source_data_independence_before_sha256',
    'source_data_independence_after_sha256',
    'source_wiodr13_manifest_sha256', 'source_wiodr16_manifest_sha256',
    'source_wiodr13_inventory_before_sha256',
    'source_wiodr13_inventory_after_sha256',
    'source_wiodr16_inventory_before_sha256',
    'source_wiodr16_inventory_after_sha256', 'evidence_index',
    'evidence_index_sha256'
  )
  'issue13-v5-capture-clean-stage5-evidence.ps1' = @(
    'schema', 'baseline_base_commit', 'baseline_base_tree',
    'baseline_runtime_commit', 'baseline_runtime_tree', 'harness_path',
    'harness_inventory_sha256', 'harness_runtime_path',
    'harness_runtime_inventory_before_sha256',
    'harness_runtime_inventory_after_sha256', 'rscript_path',
    'rscript_sha256', 'fsutil_path', 'fsutil_sha256', 'r_library_path',
    'r_library_inventory_before_sha256',
    'r_library_inventory_after_sha256', 'methods', 'stages',
    'bridge_capture_record_sha256', 'bridge_evidence_index_sha256',
    'bridge_manifest_sha256', 'stage5_evidence_index_sha256',
    'source_data_origin_path',
    'source_data_origin_inventory_before_sha256',
    'source_data_origin_inventory_after_sha256',
    'bridge_source_data_snapshot_path',
    'bridge_source_data_snapshot_inventory_before_sha256',
    'bridge_source_data_snapshot_inventory_after_sha256',
    'source_data_origin_physical_path', 'source_data_physical_file_count',
    'source_data_physical_directory_count',
    'source_data_origin_physical_before_sha256',
    'source_data_origin_physical_after_sha256',
    'bridge_source_data_snapshot_physical_path',
    'bridge_source_data_snapshot_physical_before_sha256',
    'bridge_source_data_snapshot_physical_after_sha256',
    'bridge_source_data_independence_before_sha256',
    'bridge_source_data_independence_after_sha256',
    'source_wiodr13_inventory_before_sha256',
    'source_wiodr13_inventory_after_sha256',
    'source_wiodr16_inventory_before_sha256',
    'source_wiodr16_inventory_after_sha256', 'recipe_records',
    'reference_records', 'seed_records', 'target_records',
    'worktree_records', 'source_snapshot_records'
  )
}
$expectedPhysicalCaptureCalls = @{
  'issue13-v5-capture-clean-bridge-evidence.ps1' = @(
    '$sourceDataPhysicalBefore|Copy-Issue13V5PhysicalDirectorySnapshot|$sourceData|$sourceSnapshot|"Bridge source-data snapshot"',
    '$sourceDataPhysicalAfter|Get-Issue13V5PhysicalSnapshotProof|$sourceData|$sourceSnapshot|"Bridge source-data snapshot"'
  )
  'issue13-v5-capture-clean-stage5-evidence.ps1' = @(
    '$bridgeSourcePhysicalBefore|Get-Issue13V5PhysicalSnapshotProof|$sourceData|$bridgeSourceSnapshotPath|"Bridge source-data snapshot"',
    '$sourceSnapshotPhysical|Copy-Issue13V5PhysicalDirectorySnapshot|$sourceData|$sourceSnapshot|"Stage-$stage source-data snapshot"',
    '$physicalAfter|Get-Issue13V5PhysicalSnapshotProof|$sourceData|$before.path|"Stage source-data snapshot $key"',
    '$bridgeSourcePhysicalAfter|Get-Issue13V5PhysicalSnapshotProof|$sourceData|$bridgeSourceSnapshotPath|"Bridge source-data snapshot"'
  )
}
$expectedPhysicalAssignmentChains = @{
  'issue13-v5-capture-clean-bridge-evidence.ps1' = @{
    '$sourceDataPhysicalBefore' = 'AssignmentStatementAst>NamedBlockAst'
    '$sourceDataPhysicalAfter' = 'AssignmentStatementAst>NamedBlockAst'
  }
  'issue13-v5-capture-clean-stage5-evidence.ps1' = @{
    '$bridgeSourcePhysicalBefore' = 'AssignmentStatementAst>NamedBlockAst'
    '$sourceSnapshotPhysical' =
      'AssignmentStatementAst>StatementBlockAst>ForEachStatementAst>' +
      'StatementBlockAst>ForEachStatementAst>NamedBlockAst'
    '$physicalAfter' =
      'AssignmentStatementAst>StatementBlockAst>ForEachStatementAst>' +
      'AssignmentStatementAst>NamedBlockAst'
    '$bridgeSourcePhysicalAfter' = 'AssignmentStatementAst>NamedBlockAst'
  }
}
function Test-Issue13V5CapturePhysicalDataflow(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string[]]$ExpectedSignatures,
  [Collections.IDictionary]$ExpectedChains
) {
  $calls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -iin @(
        'Copy-Issue13V5PhysicalDirectorySnapshot',
        'Get-Issue13V5PhysicalSnapshotProof')
  }, $true))
  $records = @($calls | ForEach-Object {
    $assignment = $_.Parent
    while ($null -ne $assignment -and $assignment -isnot
        [Management.Automation.Language.AssignmentStatementAst]) {
      $assignment = $assignment.Parent
    }
    if ($null -eq $assignment) { return }
    [pscustomobject]@{
      assignment = $assignment
      call = $_
      signature = [string]$assignment.Left.Extent.Text + '|' +
        [string]::Join('|', @($_.CommandElements | ForEach-Object {
          [string]$_.Extent.Text
        }))
    }
  })
  if ($records.Count -ne $ExpectedSignatures.Count -or
      [string]::Join("`n", @($records.signature)) -cne
        [string]::Join("`n", $ExpectedSignatures)) {
    return $false
  }
  $allowedNativeParameterSignatures = @(
    'git|-C|$repository|cat-file|-e|($baselineBaseCommit + "^{commit}")',
    'git|-C|$repository|cat-file|-e|($baselineRuntimeCommit + "^{commit}")'
  )
  $dynamicMutators = @($Ast.FindAll({
    param($node)
    if ($node -isnot [Management.Automation.Language.CommandAst] -or
        -not (Test-Issue13V5ForbiddenVariableMutationCommand $node)) {
      return $false
    }
    $signature = [string]::Join('|', @($node.CommandElements |
        ForEach-Object { $_.Extent.Text }))
    $allowedNativeParameterSignatures -cnotcontains $signature
  }, $true))
  if ($dynamicMutators.Count -ne 0 -or
      (Test-Issue13V5ForbiddenSessionStateMutation $Ast)) {
    return $false
  }
  foreach ($target in @($ExpectedChains.Keys)) {
    $assignments = @(Get-Issue13V5VariableWriteAsts $Ast $target)
    if ($assignments.Count -ne 1 -or
        (Get-Issue13V5AstAncestorChain $assignments[0] $Ast) -cne
          [string]$ExpectedChains[$target]) {
      return $false
    }
    $owners = @($records | Where-Object {
      $_.assignment.Extent.StartOffset -eq
        $assignments[0].Extent.StartOffset -and
      $_.assignment.Extent.EndOffset -eq $assignments[0].Extent.EndOffset
    })
    if ($owners.Count -ne 1) { return $false }
    $callChain = @()
    $current = $owners[0].call
    while ($null -ne $current) {
      $callChain += $current.GetType().Name
      if ([object]::ReferenceEquals($current, $assignments[0])) { break }
      $current = $current.Parent
    }
    if ([string]::Join('>', [string[]]$callChain) -cne
        'CommandAst>PipelineAst>AssignmentStatementAst') {
      return $false
    }
  }
  $true
}
$validatedCaptureAsts = @{}
foreach ($captureName in @($expectedCaptureHeaders.Keys | Sort-Object)) {
  $capturePath = Join-Path $root $captureName
  $captureTokens = @()
  $captureErrors = @()
  $captureAst = $bootstrapSourceAsts[$captureName]
  $validatedCaptureAsts[$captureName] = $captureAst
  $captureAssignments = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
      (Get-Issue13V5AssignmentBaseVariableName $node.Left) -ieq
        '$captureRecord'
  }, $true))
  $sharedCopyCalls = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Copy-Issue13V5PhysicalDirectorySnapshot'
  }, $true))
  $coordinatorDotSources = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      $node.InvocationOperator -eq
        [Management.Automation.Language.TokenKind]::Dot -and
      $node.Extent.Text.IndexOf(
        'issue13-v5-coordinator-lib.ps1',
        [StringComparison]::Ordinal) -ge 0
  }, $true))
  $systemDirectoryReads = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.MemberExpressionAst] -and
      $node.Static -and
      (Test-Issue13V5TypeExpression `
        $node.Expression 'System.Environment') -and
      $node.Member.Extent.Text -ieq 'SystemDirectory'
  }, $true))
  $pathResolvedFsutil = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Get-Command' -and
      $node.Extent.Text.IndexOf(
        'fsutil', [StringComparison]::OrdinalIgnoreCase) -ge 0
  }, $true))
  $localSnapshotDefinitions = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      $node.Name -match '(?i)Copy.*DirectorySnapshot'
  }, $true))
  $officialSourceCalls = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5OfficialSourceDataInventory'
  }, $true))
  $sourceOriginHashAssignments = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
      (Get-Issue13V5AssignmentBaseVariableName $node.Left) -ieq
        '$sourceDataOriginInventoryBefore'
  }, $true))
  if ($captureErrors.Count -ne 0 -or $captureAssignments.Count -ne 1 -or
      -not (Test-Issue13V5SingularDirectAssignment $captureAst `
        '$captureRecord' 'AssignmentStatementAst>NamedBlockAst') -or
      $sharedCopyCalls.Count -ne 1 -or $coordinatorDotSources.Count -ne 1 -or
      $systemDirectoryReads.Count -ne 1 -or $pathResolvedFsutil.Count -ne 0 -or
      $localSnapshotDefinitions.Count -ne 0 -or
      $officialSourceCalls.Count -ne 1 -or
      [string]::Join("`n", @($officialSourceCalls[0].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
        '$sourceData' -or
      (Get-Issue13V5AstAncestorChain $officialSourceCalls[0] $captureAst) -cne
        'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst' -or
      $officialSourceCalls[0].Parent.Parent.Left.Extent.Text -cne
        '$officialSourceInventoryBefore' -or
      -not (Test-Issue13V5SingularDirectAssignment $captureAst `
        '$officialSourceInventoryBefore' `
        'AssignmentStatementAst>NamedBlockAst') -or
      $officialSourceCalls[0].Extent.StartOffset -ge
        $sharedCopyCalls[0].Extent.StartOffset -or
      $sourceOriginHashAssignments.Count -ne 1 -or
      -not (Test-Issue13V5SingularDirectAssignment $captureAst `
        '$sourceDataOriginInventoryBefore' `
        'AssignmentStatementAst>NamedBlockAst' `
        '[string]$officialSourceInventoryBefore.ordinal_inventory_sha256') -or
      $officialSourceCalls[0].Extent.EndOffset -ge
        $sourceOriginHashAssignments[0].Extent.StartOffset -or
      $sourceOriginHashAssignments[0].Extent.EndOffset -ge
        $sharedCopyCalls[0].Extent.StartOffset -or
      -not (Test-Issue13V5OfficialSourcePinsWriteFree $captureAst)) {
    throw "Capture AST does not use one shared physical copy: $captureName"
  }
  $headerKeys = @($captureAssignments[0].Right.FindAll({
    param($node)
    ($node -is [Management.Automation.Language.StringConstantExpressionAst] -or
      $node -is
        [Management.Automation.Language.ExpandableStringExpressionAst]) -and
      $node.Value -cmatch '^[a-z][a-z0-9_]*='
  }, $true) | ForEach-Object {
    ([string]$_.Value) -replace '=.*$', ''
  })
  if ([string]::Join("`n", $headerKeys) -cne [string]::Join(
      "`n", [string[]]$expectedCaptureHeaders[$captureName])) {
    throw "Capture record AST has an invalid exact header: $captureName"
  }
  if (-not (Test-Issue13V5CapturePhysicalDataflow $captureAst `
      ([string[]]$expectedPhysicalCaptureCalls[$captureName]) `
      $expectedPhysicalAssignmentChains[$captureName])) {
    throw "Capture before/after physical proof AST changed: $captureName"
  }
}
foreach ($captureName in @($validatedCaptureAsts.Keys | Sort-Object)) {
  $captureAst = $validatedCaptureAsts[$captureName]
  $captureText = $captureAst.Extent.Text
  foreach ($target in @(
      $expectedPhysicalAssignmentChains[$captureName].Keys | Sort-Object)) {
    $assignments = @(Get-Issue13V5VariableWriteAsts $captureAst $target)
    if ($assignments.Count -ne 1) {
      throw "Capture physical target is not singular: $captureName $target"
    }
    $statement = [string]$assignments[0].Extent.Text
    if ($captureText.IndexOf($statement, [StringComparison]::Ordinal) -ne
        $captureText.LastIndexOf($statement, [StringComparison]::Ordinal)) {
      throw "Capture physical statement is not textually unique: $target"
    }
    $deadBranchText = $captureText.Replace(
      $statement,
      "if (`$false) {`n$statement`n}" + "`n$target = `$null")
    $deadBranchTokens = $null
    $deadBranchErrors = $null
    $deadBranchAst = [Management.Automation.Language.Parser]::ParseInput(
      $deadBranchText, [ref]$deadBranchTokens, [ref]$deadBranchErrors)
    if ($deadBranchErrors.Count -ne 0 -or
        (Test-Issue13V5CapturePhysicalDataflow $deadBranchAst `
          ([string[]]$expectedPhysicalCaptureCalls[$captureName]) `
          $expectedPhysicalAssignmentChains[$captureName])) {
      throw "Capture accepted a dead physical-proof branch: $captureName $target"
    }
    $conditionalRhsStatement = $target + ' = if ($false) {' + "`n" +
      [string]$assignments[0].Right.Extent.Text + "`n} else { `$null }"
    $conditionalRhsText = $captureText.Replace(
      $statement, $conditionalRhsStatement)
    $conditionalRhsTokens = $null
    $conditionalRhsErrors = $null
    $conditionalRhsAst = [Management.Automation.Language.Parser]::ParseInput(
      $conditionalRhsText, [ref]$conditionalRhsTokens,
      [ref]$conditionalRhsErrors)
    if ($conditionalRhsErrors.Count -ne 0 -or
        (Test-Issue13V5CapturePhysicalDataflow $conditionalRhsAst `
          ([string[]]$expectedPhysicalCaptureCalls[$captureName]) `
          $expectedPhysicalAssignmentChains[$captureName])) {
      throw "Capture accepted a conditional physical-proof RHS: $captureName $target"
    }
    $subassignmentText = $captureText.Replace(
      $statement,
      $statement + "`n$target.__issue13_mutant = `$null")
    $subassignmentTokens = $null
    $subassignmentErrors = $null
    $subassignmentAst = [Management.Automation.Language.Parser]::ParseInput(
      $subassignmentText, [ref]$subassignmentTokens,
      [ref]$subassignmentErrors)
    if ($subassignmentErrors.Count -ne 0 -or
        (Test-Issue13V5CapturePhysicalDataflow $subassignmentAst `
          ([string[]]$expectedPhysicalCaptureCalls[$captureName]) `
          $expectedPhysicalAssignmentChains[$captureName])) {
      throw "Capture accepted a physical-proof subassignment: $captureName $target"
    }
  }
}

if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
  if (-not ('Issue13V5.NativePath' -as [type])) {
    Add-Type -TypeDefinition $materializerNativeSource
  }
  $physicalSelftestParent = [IO.Path]::GetFullPath(
    [IO.Path]::GetTempPath()).TrimEnd('\')
  $physicalSelftestRoot = Join-Path $physicalSelftestParent (
    'issue13-v5-physical-selftest-' + [Guid]::NewGuid().ToString('N'))
  $physicalSelftestSource = Join-Path $physicalSelftestRoot 'source'
  $physicalSelftestSnapshot = Join-Path $physicalSelftestRoot 'snapshot'
  $sourceJunction = Join-Path $physicalSelftestRoot 'source-junction'
  $snapshotJunction = Join-Path $physicalSelftestRoot 'snapshot-junction'
  $null = [IO.Directory]::CreateDirectory(
    (Join-Path $physicalSelftestSource 'nested'))
  $selftestUtf8 = [Text.UTF8Encoding]::new($false)
  [IO.File]::WriteAllText(
    (Join-Path $physicalSelftestSource 'alpha.txt'), 'alpha', $selftestUtf8)
  [IO.File]::WriteAllText(
    (Join-Path $physicalSelftestSource 'nested\beta.txt'),
    'beta', $selftestUtf8)
  $unofficialSourceRejected = $false
  try {
    $null = Assert-Issue13V5OfficialSourceDataInventory `
      $physicalSelftestSource
  } catch {
    $unofficialSourceRejected = $_.Exception.Message.Contains(
      'Official source_data inventory differs:')
  }
  if (-not $unofficialSourceRejected) {
    throw 'Official source_data assertion accepted a synthetic tree.'
  }
  try {
    $usedDriveLetters = @([IO.DriveInfo]::GetDrives() | ForEach-Object {
      $_.Name.Substring(0, 2).ToUpperInvariant()
    })
    $deliveryAliasDrive = @(
      90..68 | ForEach-Object { ([char]$_).ToString() + ':' } |
        Where-Object { $_ -cnotin $usedDriveLetters }
    )[0]
    if ([string]::IsNullOrWhiteSpace($deliveryAliasDrive)) {
      throw 'No free drive letter exists for delivery alias self-test.'
    }
    $substPath = Join-Path ([Environment]::SystemDirectory) 'subst.exe'
    $deliveryAliasCreated = $false
    try {
      $null = & $substPath $deliveryAliasDrive $RepositoryRoot
      if ($LASTEXITCODE -ne 0) {
        throw 'Could not create delivery SUBST negative fixture.'
      }
      $deliveryAliasCreated = $true
      $materializerAliasTarget =
        [Issue13V5.NativePath]::DriveTarget($deliveryAliasDrive)
      if (-not $materializerAliasTarget.StartsWith(
          '\??\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Materializer native helper did not expose the SUBST target.'
      }
      $deliveryAliasRejected = $false
      try {
        $null = Resolve-Issue13V5DeliveryOutput `
          (Join-Path ($deliveryAliasDrive + '\run_logs') (
            'issue13-delivery-alias-' +
              [Guid]::NewGuid().ToString('N') + '.json')) `
          @($RepositoryRoot, $HarnessRuntimeRoot)
      } catch {
        $deliveryAliasRejected = $true
      }
      if (-not $deliveryAliasRejected) {
        throw 'Delivery output accepted a SUBST alias into the repository.'
      }
      $deliveryProtectedRootRejected = $false
      try {
        $null = Resolve-Issue13V5DeliveryOutput `
          (Join-Path $HarnessRuntimeRoot (
            'issue13-delivery-protected-' +
              [Guid]::NewGuid().ToString('N') + '.json')) `
          @($RepositoryRoot, $HarnessRuntimeRoot)
      } catch {
        $deliveryProtectedRootRejected = $_.Exception.Message.Contains(
          'Delivery attestation/protected-root isolation paths overlap:')
      }
      if (-not $deliveryProtectedRootRejected) {
        throw 'Delivery output accepted a protected harness descendant.'
      }
      $oracleProofAliasRejected = $false
      try {
        $null = Assert-Issue13OracleEffectProofPathIsolation `
          (Join-Path ($deliveryAliasDrive + '\run_logs') (
            'issue13-oracle-proof-alias-' +
              [Guid]::NewGuid().ToString('N') + '.json')) `
          @($RepositoryRoot, $HarnessRuntimeRoot)
      } catch {
        $oracleProofAliasRejected = $true
      }
      if (-not $oracleProofAliasRejected) {
        throw 'Oracle proof output accepted a SUBST repository alias.'
      }
    } finally {
      if ($deliveryAliasCreated) {
        $null = & $substPath $deliveryAliasDrive '/D'
        if ($LASTEXITCODE -ne 0) {
          throw 'Could not remove delivery SUBST negative fixture.'
        }
      }
    }
    $firstPhysicalProof = Copy-Issue13V5PhysicalDirectorySnapshot `
      $physicalSelftestSource $physicalSelftestSnapshot `
      'Static physical-copy self-test'
    if ($firstPhysicalProof.file_count -ne 2L -or
        $firstPhysicalProof.directory_count -ne 1L) {
      throw 'Static physical-copy self-test has invalid topology.'
    }
    $runtimePhysicalInventory = Get-Issue13V5TreeInventory `
      $physicalSelftestSnapshot
    if (-not (Assert-Issue13V5PhysicalCopy `
        $physicalSelftestSource $physicalSelftestSnapshot `
        $runtimePhysicalInventory)) {
      throw 'Runtime physical-copy assertion rejected an exact copy.'
    }
    $externalHardlink = Join-Path $physicalSelftestRoot 'external-hardlink.txt'
    $null = New-Item -ItemType HardLink -Path $externalHardlink -Target (
      Join-Path $physicalSelftestSnapshot 'alpha.txt')
    $hardlinkRejected = $false
    $runtimeHardlinkRejected = $false
    try {
      $null = Get-Issue13V5PhysicalSnapshotProof `
        $physicalSelftestSource $physicalSelftestSnapshot `
        'Static hard-link mutation'
    } catch {
      $hardlinkRejected = $true
    }
    try {
      $null = Assert-Issue13V5PhysicalCopy `
        $physicalSelftestSource $physicalSelftestSnapshot `
        $runtimePhysicalInventory
    } catch {
      $runtimeHardlinkRejected = $true
    } finally {
      if ([IO.File]::Exists($externalHardlink)) {
        [IO.File]::Delete($externalHardlink)
      }
    }
    if (-not $hardlinkRejected -or -not $runtimeHardlinkRejected) {
      throw 'Physical-copy proof accepted an external hard link.'
    }
    $null = New-Item -ItemType Junction -Path $sourceJunction -Target `
      $physicalSelftestSource
    $sourceJunctionRejected = $false
    try {
      $null = Get-Issue13V5PhysicalSnapshotProof `
        $sourceJunction $physicalSelftestSnapshot `
        'Static source-junction mutation'
    } catch {
      $sourceJunctionRejected = $true
    }
    if ([IO.Directory]::Exists($sourceJunction)) {
      [IO.Directory]::Delete($sourceJunction)
    }
    $null = New-Item -ItemType Junction -Path $snapshotJunction -Target `
      $physicalSelftestSnapshot
    $snapshotJunctionRejected = $false
    try {
      $null = Get-Issue13V5PhysicalSnapshotProof `
        $physicalSelftestSource $snapshotJunction `
        'Static snapshot-junction mutation'
    } catch {
      $snapshotJunctionRejected = $true
    }
    if ([IO.Directory]::Exists($snapshotJunction)) {
      [IO.Directory]::Delete($snapshotJunction)
    }
    if (-not $sourceJunctionRejected -or -not $snapshotJunctionRejected) {
      throw 'Physical-copy proof accepted a junction root.'
    }
    if (-not (Test-Issue13V5PathContained `
        $physicalSelftestSnapshot $physicalSelftestRoot)) {
      throw 'Static snapshot cleanup target escaped its self-test root.'
    }
    [IO.Directory]::Delete($physicalSelftestSnapshot, $true)
    $secondPhysicalProof = Copy-Issue13V5PhysicalDirectorySnapshot `
      $physicalSelftestSource $physicalSelftestSnapshot `
      'Static physical-copy recreation self-test'
    if ($firstPhysicalProof.source_physical_inventory_sha256 -cne
          $secondPhysicalProof.source_physical_inventory_sha256 -or
        $firstPhysicalProof.snapshot_physical_inventory_sha256 -ceq
          $secondPhysicalProof.snapshot_physical_inventory_sha256 -or
        $firstPhysicalProof.independence_sha256 -ceq
          $secondPhysicalProof.independence_sha256) {
      throw 'Physical recreation did not change snapshot identity.'
    }
  } finally {
    if ([IO.Directory]::Exists($sourceJunction)) {
      [IO.Directory]::Delete($sourceJunction)
    }
    if ([IO.Directory]::Exists($snapshotJunction)) {
      [IO.Directory]::Delete($snapshotJunction)
    }
    if ([IO.Directory]::Exists($physicalSelftestRoot)) {
      if ([IO.Path]::GetFileName($physicalSelftestRoot) -cnotmatch
          '^issue13-v5-physical-selftest-[0-9a-f]{32}$' -or
          -not (Test-Issue13V5PathContained `
            $physicalSelftestRoot $physicalSelftestParent)) {
        throw 'Unsafe static physical-copy self-test cleanup target.'
      }
      [IO.Directory]::Delete($physicalSelftestRoot, $true)
    }
  }
}

$oracleProofProtectedRejected = $false
try {
  $null = Assert-Issue13OracleEffectProofPathIsolation `
    (Join-Path $RepositoryRoot (
      'issue13-oracle-proof-protected-' +
        [Guid]::NewGuid().ToString('N') + '.json')) `
    @($RepositoryRoot, $HarnessRuntimeRoot)
} catch {
  $oracleProofProtectedRejected = $_.Exception.Message.Contains(
    'oracle-effect proof/protected-root isolation paths overlap:')
}
if (-not $oracleProofProtectedRejected) {
  throw 'Oracle proof output accepted a repository descendant.'
}

$diagnosticBridgePath = Join-Path $root $diagnosticBridges
$expectedBridgeColumns = @(
  'schema_version', 'bridge_id', 'artifact_name', 'method', 'source',
  'artifact', 'indicator', 'checkpoint', 'stage', 'action', 'output',
  'original_value', 'policy_id', 'level', 'strategy', 'baseline_module',
  'candidate_module', 'candidate_producer_id', 'candidate_write_action',
  'evidence_baseline_run_id', 'evidence_baseline_artifact_sha256',
  'evidence_baseline_request_sha256', 'evidence_baseline_source_sha256',
  'evidence_baseline_commit', 'evidence_baseline_tree',
  'evidence_candidate_run_id', 'evidence_candidate_artifact_sha256',
  'evidence_candidate_request_sha256', 'evidence_candidate_source_sha256',
  'evidence_candidate_commit', 'evidence_candidate_tree',
  'expected_baseline_evidence_rows', 'expected_candidate_evidence_rows',
  'derivation_sha256'
)
$bridgeLines = [IO.File]::ReadAllLines(
  $diagnosticBridgePath, [Text.UTF8Encoding]::new($false, $true))
$observedBridgeColumns = [string[]]@(
  $bridgeLines[0].Split(';') | ForEach-Object { $_.Trim('"') })
$bridgeRows = @(Import-Csv -LiteralPath $diagnosticBridgePath -Delimiter ';')
$expectedMethods = @(
  'wiodr13', 'wiodr16', 'alternative_1', 'alternative_2', 'norow_w13',
  'ochoa_1', 'ochoa_2', 'petrovic', 'wiodr13v09', 'wiodr16v09',
  'zerodep_1', 'zerodep_2'
)
if ($bridgeLines.Count -le 1 -or $bridgeRows.Count -le 0 -or
    [string]::Join("`n", $observedBridgeColumns) -cne
      [string]::Join("`n", $expectedBridgeColumns) -or
    @($bridgeRows.bridge_id | Sort-Object -Unique).Count -ne
      $bridgeRows.Count -or
    [string]::Join("`n", @($bridgeRows.method | Sort-Object -Unique)) -cne
      [string]::Join("`n", @($expectedMethods | Sort-Object)) -or
    @($bridgeRows | Where-Object {
      [string]$_.schema_version -cne
        'issue13-v5-diagnostic-module-bridge/1' -or
      [string]$_.bridge_id -cnotmatch '^bridge-[0-9a-f]{24}$' -or
      [string]$_.artifact_name -cnotin @(
        '_unit_contract.csv', '_anomalies.csv') -or
      [string]$_.derivation_sha256 -cnotmatch '^[0-9a-f]{64}$'
    }).Count -ne 0) {
  throw 'The sealed diagnostic-module bridge CSV is empty or invalid.'
}
foreach ($method in $expectedMethods) {
  $methodArtifacts = @($bridgeRows | Where-Object method -ceq $method |
    ForEach-Object artifact_name | Sort-Object -Unique)
  if ([string]::Join("`n", $methodArtifacts) -cne
      "_anomalies.csv`n_unit_contract.csv") {
    throw "Diagnostic-module bridges lack exact artifact coverage: $method"
  }
}
foreach ($row in $bridgeRows) {
  foreach ($field in @(
      'evidence_baseline_artifact_sha256',
      'evidence_baseline_request_sha256',
      'evidence_baseline_source_sha256',
      'evidence_candidate_artifact_sha256',
      'evidence_candidate_request_sha256',
      'evidence_candidate_source_sha256', 'derivation_sha256'
    )) {
    if ([string]$row.$field -cnotmatch '^[0-9a-f]{64}$') {
      throw "Diagnostic-module bridge hash is invalid: $field"
    }
  }
}
$records.Add([ordered]@{
  name = $diagnosticBridges
  sha256 = Get-Issue13V5Sha256 $diagnosticBridgePath
  command_ast_count = 0L
})

$stage5ProfilePath = Join-Path $root $stage5Profiles
$expectedStage5Columns = @(
  'schema_version', 'profile_id', 'scenario_id', 'method', 'mode',
  'at_stage', 'sea_vars_sha256', 'workers', 'request_sha256',
  'candidate_stage5_rows', 'candidate_stage5_sha256',
  'baseline_stage5_rows', 'baseline_stage5_sha256',
  'difference_key_count', 'difference_sha256',
  'evidence_candidate_reference_run_id',
  'evidence_candidate_reference_anomalies_sha256',
  'evidence_candidate_reference_request_sha256',
  'evidence_candidate_reference_commit',
  'evidence_candidate_reference_tree',
  'evidence_candidate_reference_source_sha256',
  'evidence_candidate_reference_run_manifest_sha256',
  'evidence_candidate_reference_run_inventory_sha256',
  'evidence_baseline_reference_run_id',
  'evidence_baseline_reference_anomalies_sha256',
  'evidence_baseline_reference_request_sha256',
  'evidence_baseline_reference_commit',
  'evidence_baseline_reference_tree',
  'evidence_baseline_reference_source_sha256',
  'evidence_baseline_reference_run_manifest_sha256',
  'evidence_baseline_reference_run_inventory_sha256',
  'evidence_baseline_target_run_id',
  'evidence_baseline_target_anomalies_sha256',
  'evidence_baseline_target_request_sha256',
  'evidence_baseline_target_commit', 'evidence_baseline_target_tree',
  'evidence_baseline_target_source_sha256',
  'evidence_baseline_target_run_manifest_sha256',
  'evidence_baseline_target_run_inventory_sha256',
  'evidence_capture_record_sha256', 'reference_stage5_sha256',
  'derivation_sha256'
)
$stage5Lines = [IO.File]::ReadAllLines(
  $stage5ProfilePath, [Text.UTF8Encoding]::new($false, $true))
$observedStage5Columns = [string[]]@(
  $stage5Lines[0].Split(';') | ForEach-Object { $_.Trim('"') })
$stage5Rows = @(Import-Csv -LiteralPath $stage5ProfilePath -Delimiter ';')
if ($stage5Lines.Count -le 1 -or $stage5Rows.Count -le 0 -or
    [string]::Join("`n", $observedStage5Columns) -cne
      [string]::Join("`n", $expectedStage5Columns) -or
    @($stage5Rows.profile_id | Sort-Object -Unique).Count -ne
      $stage5Rows.Count -or
    @($stage5Rows | Where-Object {
      [string]$_.schema_version -cne
        'issue13-v5-stage5-multiplicity-profile/1' -or
      [string]$_.profile_id -cnotmatch '^stage5-[0-9a-f]{24}$' -or
      [string]$_.method -cnotin $expectedMethods -or
      [string]$_.mode -cne 'recalculate' -or
      [string]$_.at_stage -cnotin @('1', '4', '5') -or
      [long]$_.difference_key_count -le 0L -or
      [string]$_.derivation_sha256 -cnotmatch '^[0-9a-f]{64}$'
    }).Count -ne 0) {
  throw 'The sealed stage-five multiplicity-profile CSV is empty or invalid.'
}
foreach ($row in $stage5Rows) {
  foreach ($field in @($expectedStage5Columns | Where-Object {
      $_.EndsWith('sha256', [StringComparison]::Ordinal)
    })) {
    if ([string]$row.$field -cnotmatch '^[0-9a-f]{64}$') {
      throw "Stage-five profile hash is invalid: $field"
    }
  }
}
$records.Add([ordered]@{
  name = $stage5Profiles
  sha256 = Get-Issue13V5Sha256 $stage5ProfilePath
  command_ast_count = 0L
})
$preparationBuildText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-build-preparation-equivalence.R'),
  [Text.UTF8Encoding]::new($false, $true))
$preparationEquivalenceText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-preparation-equivalence.R'),
  [Text.UTF8Encoding]::new($false, $true))
$preparationEquivalence = Read-Issue13V5Json (
  Join-Path $root 'issue13-v5-preparation-equivalence.json')
if (-not $preparationBuildText.Contains('no field, row, wildcard, tolerance or row-order projection.') -or
    -not $preparationEquivalenceText.Contains('wlv13_v5p_compare_source <- function') -or
    -not $preparationEquivalenceText.Contains('wlv13_v5p_exact_table <- function') -or
    -not $preparationEquivalenceText.Contains(
      'sealed-exhaustive-unit-contract-equivalence') -or
    -not $preparationEquivalenceText.Contains(
      'sealed-exhaustive-source-manifest-equivalence') -or
    -not $preparationEquivalenceText.Contains('wlv13_v5p_selftest <- function') -or
    [string]$preparationEquivalence.schema -cne
      'wlv-issue13-preparation-equivalence/1' -or
    @($preparationEquivalence.sources).Count -ne 2 -or
    @($preparationEquivalence.artifacts).Count -ne 2 -or
    @($preparationEquivalence.profiles).Count -ne 2 -or
    [string]$preparationEquivalence.derivation -cne
      'Exact authenticated normalized-source tables paired by source and arm; no field, row, wildcard, tolerance or row-order projection.' -or
    $preparationEquivalence.PSObject.Properties.Name -ccontains
      'architecture_projection') {
  throw 'V5 exhaustive preparation equivalence sources are incomplete.'
}
foreach ($name in $preparationEquivalenceFiles) {
  $path = Join-Path $root $name
  $records.Add([ordered]@{
    name = $name
    sha256 = if ($bootstrapSourceFileSha256.ContainsKey($name)) {
      [string]$bootstrapSourceFileSha256[$name]
    } else {
      Get-Issue13V5Sha256 $path
    }
    command_ast_count = 0L
  })
}
$materializerText = [string]
  $bootstrapSourceTexts['issue13-v5-materialize-harness.ps1']
$materializerTokens = @()
$materializerErrors = @()
$materializerAst =
  $bootstrapSourceAsts['issue13-v5-materialize-harness.ps1']
$materializerControllerAssignments = @($materializerAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.AssignmentStatementAst] -and
    (Get-Issue13V5AssignmentBaseVariableName $node.Left) -ieq
      '$controllerFiles'
}, $true))
$materializerControllerFiles = if ($materializerControllerAssignments.Count `
    -eq 1) {
  [string[]]@($materializerControllerAssignments[0].Right.FindAll({
    param($node)
    $node -is [Management.Automation.Language.StringConstantExpressionAst]
  }, $true) | ForEach-Object Value)
} else {
  [string[]]@()
}
if ($materializerErrors.Count -ne 0 -or
    [string]::Join("`n", $materializerControllerFiles) -cne
      [string]::Join("`n", $expectedControllerFiles) -or
    $forbiddenAbsoluteEvidenceSeed -cin $materializerControllerFiles) {
  throw 'V5 materializer does not pin the exact 34 controller files.'
}
foreach ($required in @(
    "'issue13-v5-diagnostic-module-bridges.csv'",
    "'issue13-v5-diagnostics-override.R'",
    "'issue13-v5-stage5-multiplicity-profiles.csv'",
    "'issue13-v5-preparation-equivalence.R'",
    "'issue13-v5-preparation-equivalence.json'",
    'sys.source(file.path(script_dir, "issue13-v5-diagnostics-override.R")',
    'metadata_assertions <- wlv13_v5_metadata_selftest()',
    'identical(metadata_assertions, 626L)',
    'wlv13_v5d_selftest()', 'identical(diagnostic_assertions, 226L)',
    'wlv13_v5p_selftest(file.path(',
    'identical(preparation_assertions, 173L)',
    'source_equivalence <- wlv13_v5p_compare_source(',
    'source_unit_contract_bridge <- wlv13_v5d_compare_source_unit_contract(',
    'source_equivalence$unit_contract$cross_engine_bridge <-',
    'isTRUE(source_unit_contract_bridge$passed)'
  )) {
  if (-not $materializerText.Contains($required)) {
    throw "V5 materializer lacks terminal diagnostic/preparation binding: $required"
  }
}
$oracleSpec = Read-Issue13V5Json (
  Join-Path $root 'issue13-v5-oracle-effect-spec.json')
$oracleSchema = Read-Issue13V5Json (
  Join-Path $root 'issue13-v5-oracle-effect-proof.schema.json')
$oracleValidateText = [string]
  $bootstrapSourceTexts['issue13-v5-oracle-effect-validate.ps1']
$oracleLibraryText = [string]
  $bootstrapSourceTexts['issue13-v5-oracle-effect-lib.ps1']
$oracleGenerateText = [string]
  $bootstrapSourceTexts['issue13-v5-oracle-effect-generate.ps1']
$oracleSchemaSha256 = Get-Issue13V5Sha256 (
  Join-Path $root 'issue13-v5-oracle-effect-proof.schema.json')
$oracleTerminal = $oracleSpec.terminal_comparison_runtime
$expectedOracleCleared = [string[]]@(
  'LANG', 'LC_ALL', 'LC_CTYPE',
  'R_ARCH', 'R_DEFAULT_PACKAGES', 'R_ENVIRON', 'R_ENVIRON_USER', 'R_HOME',
  'R_LIBS', 'R_LIBS_SITE', 'R_PROFILE', 'R_PROFILE_USER', 'R_STARTUP_DEBUG',
  'RENV_CONFIG_AUTOLOADER_ENABLED', 'RENV_PATHS_LIBRARY', 'RENV_PATHS_ROOT'
)
$expectedOraclePackages = [string[]]@('fst', 'jsonlite', 'openssl')
if ([string]$oracleSpec.schema -cne 'wlv-issue13-v5-oracle-effect-spec/2' -or
    [string]$oracleSpec.status -cne
      'requires-terminal-primary-and-replay-comparisons' -or
    -not (Test-Issue13V5ExactBoolean $oracleSpec.final_evidence_eligible $false) -or
    @($oracleSpec.method_partition.strict_common).Count -ne 5 -or
    @($oracleSpec.method_partition.recovered).Count -ne 7 -or
    [long]$oracleSpec.comparison_contract.required_comparison_count -ne 5L -or
    [long]$oracleSpec.comparison_contract.required_execution_count -ne 10L -or
    [long]$oracleSpec.comparison_contract.approved_run_count -ne 17L -or
    [string]::Join("`n", @(
      $oracleSpec.comparison_contract.required_phases)) -cne
      "primary`nreplay" -or
    [string]$oracleSpec.oracle.canonical_patch_sha256 -cne
      $script:Issue13V5BaselineOverlaySha256 -or
    [string]$oracleSpec.oracle.stable_patch_id -cne
      $script:Issue13V5BaselineOverlayPatchId -or
    [string]$oracleTerminal.generation -cne 'v5-terminal' -or
    [string]$oracleTerminal.source_controller_commit_field -cne
      'commit_sha256' -or
    [string]$oracleTerminal.sealed_inventory.status -cne
      'requires-terminal-reseal' -or
    [long]$oracleTerminal.sealed_inventory.file_count -ne 39L -or
    [long]$oracleTerminal.sealed_inventory.total_bytes -ne 594386L -or
    [string]$oracleTerminal.sealed_inventory.inventory_sha256 -cne
      '9f50c978ffc5f1f2d69d70ca8e5a7205eca39ec8441843cd5fa43b959eaf03c1' -or
    [string]::Join("`n", @(
      $oracleTerminal.required_controller_files)) -cne
      [string]::Join("`n", $expectedControllerFiles) -or
    [string]$oracleTerminal.r_library_environment_variable -cne
      'R_LIBS_USER' -or
    [string]$oracleTerminal.r_environment_set.R_LIBS_USER -cne
      'configured-r-library' -or
    [string]$oracleTerminal.r_environment_set.TZ -cne 'UTC' -or
    [string]::Join("`n", @($oracleTerminal.r_environment_cleared)) -cne
      [string]::Join("`n", $expectedOracleCleared) -or
    [string]::Join("`n", @($oracleTerminal.required_r_packages)) -cne
      [string]::Join("`n", $expectedOraclePackages) -or
    [string]$oracleSpec.proof_schema_sha256 -cne $oracleSchemaSha256 -or
    [string]$oracleSchema.properties.schema.const -cne
      'wlv-issue13-v5-oracle-effect-proof/2' -or
    [string]$oracleSchema.properties.status.const -cne 'passed' -or
    -not (Test-Issue13V5ExactBoolean `
      $oracleSchema.properties.passed.const $true) -or
    -not (Test-Issue13V5ExactBoolean `
      $oracleSchema.properties.final_evidence_eligible.const $false) -or
    [string]::Join("`n", @($oracleSchema.required)) -cne
      "schema`nstatus`npassed`nfinal_evidence_eligible`npurpose`ngenerated_at_utc`nevidence`nconclusion" -or
    [string]$oracleSchema.properties.evidence.'$ref' -cne
      '#/$defs/evidence' -or
    [string]$oracleSchema.'$defs'.evidence.properties.terminal_runtime.'$ref' `
      -cne '#/$defs/terminalRuntime' -or
    [string]$oracleSchema.'$defs'.terminalRuntime.properties.
      comparison_harness.'$ref' -cne '#/$defs/harness' -or
    [string]$oracleSchema.'$defs'.terminalRuntime.properties.r_library.'$ref' `
      -cne '#/$defs/rLibrary' -or
    [string]$oracleSchema.'$defs'.terminalRuntime.properties.
      runtime_immutability.'$ref' -cne '#/$defs/runtimeImmutability' -or
    [string]::Join("`n", @(
      $oracleSchema.'$defs'.runtimeImmutability.required)) -cne
      "before`nafter`nimmutable" -or
    [string]::Join("`n", @(
      $oracleSchema.'$defs'.sourceController.required)) -cne
      "commit_sha256`nfile_count`ninventory_sha256`nrecords" -or
    [string]::Join("`n", @(
      $oracleSchema.'$defs'.rEnvironment.required)) -cne "set`ncleared" -or
    [string]::Join("`n", @(
      $oracleSchema.'$defs'.rLibrary.required)) -cne
      "path`nenvironment_variable`nenvironment`nr_version`nplatform`nlib_paths`nrequired_packages`nloaded_packages`ninventory_sha256" -or
    [string]::Join("`n", @(
      $oracleSchema.'$defs'.comparisonWorkflow.required)) -cne
      "primary_root`nreplay_root`ngenerator_created_both_roots`nmethods`ncommands`ncomparisons" -or
    [long]$oracleSchema.'$defs'.comparisonWorkflow.properties.commands.
      minItems -ne 10L -or
    [long]$oracleSchema.'$defs'.comparisonWorkflow.properties.commands.
      maxItems -ne 10L -or
    -not $oracleValidateText.Contains('Get-Issue13OracleEffectEvidence') -or
    -not $oracleValidateText.Contains('Test-Issue13OracleEffectProofObject') -or
    -not $oracleValidateText.Contains(
      'source_controller_inventory_sha256') -or
    -not $oracleValidateText.Contains('r_runtime_inventory_sha256') -or
    -not $oracleLibraryText.Contains('Get-Issue13OracleEffectEvidence') -or
    -not $oracleLibraryText.Contains('Test-Issue13OracleEffectProofObject') -or
    -not $oracleLibraryText.Contains(
      'Test-Issue13OracleEffectExactBoolean') -or
    -not $oracleLibraryText.Contains(
      'ConvertTo-Issue13OracleEffectPhysicalPath') -or
    -not $oracleLibraryText.Contains(
      'Test-Issue13OracleEffectForbiddenDriveTarget') -or
    -not $oracleLibraryText.Contains('VolumeNameGuid') -or
    -not $oracleLibraryText.Contains('QueryDosDevice') -or
    -not $oracleLibraryText.Contains(
      'must not use a SUBST or mapped-drive alias') -or
    -not $oracleLibraryText.Contains("'--vanilla'") -or
    -not $oracleLibraryText.Contains('$commands.Count -eq 10') -or
    -not $oracleLibraryText.Contains('$approved.Count -eq 17') -or
    -not $oracleLibraryText.Contains(
      '$externalInventory.status -ceq ''sealed''') -or
    -not $oracleLibraryText.Contains('source_controller = $expectedController') -or
    -not $oracleLibraryText.Contains('runtime_immutability =') -or
    -not $oracleLibraryText.Contains(
      'function Assert-Issue13OracleEffectProofPathIsolation') -or
    -not $oracleLibraryText.Contains(
      'oracle-effect proof/protected-root isolation') -or
    -not $oracleLibraryText.Contains(
      '[Parameter(Mandatory = $true)][string[]]$ProtectedRoots') -or
    -not $oracleGenerateText.Contains(
      'Assert-Issue13OracleEffectComparisonIsolation') -or
    -not $oracleGenerateText.Contains('$proofProtectedRoots = @(') -or
    -not $oracleGenerateText.Contains(
      'Assert-Issue13OracleEffectProofPathIsolation') -or
    -not $oracleGenerateText.Contains(
      '-ProtectedRoots $proofProtectedRoots') -or
    -not $oracleValidateText.Contains('$proofProtectedRoots = @(') -or
    -not $oracleValidateText.Contains(
      'Assert-Issue13OracleEffectProofPathIsolation') -or
    -not $oracleGenerateText.Contains(
      'terminal harness/Rscript/RLibrary changed during primary/replay execution.')) {
  throw 'Oracle-effect static /2 terminal 5+7 proof contract changed.'
}

$coordinatorText = [string]
  $bootstrapSourceTexts['issue13-v5-coordinator.ps1']
foreach ($required in @(
    "'ValidateConfig'", "'PrepareWorktrees'", "'RunNext'", "'RunAll'",
    "'Aggregate'", "'Report'", 'Get-Issue13V5WorktreeBindings',
    'issue13-build-calculate-bundle.R', 'issue13-build-recalc-bundle.R',
    'issue13-build-paper-bundle.R', 'issue13-build-prep-fault-specs.R',
    'issue13-aggregate-prep-fault.R', 'issue13-aggregate.R',
    'issue13-v5-render-report.ps1', '162', '202',
    'Planned comparison output already exists:',
    'Planned prep/fault aggregate output already exists.',
    'Planned final aggregate output already exists.',
    'Assert-Issue13V5PhaseEvidenceState',
    'Assert-Issue13V5CompletedEvidenceState',
    'Test-Issue13V5ExactBoolean',
    'pair_result_sha256', 'aggregate_sha256'
  )) {
  if (-not $coordinatorText.Contains($required)) {
    throw "Coordinator lacks required closed-gate binding: $required"
  }
}

$newConfigText = [string]
  $bootstrapSourceTexts['issue13-v5-new-config.ps1']
foreach ($required in @(
    '[Parameter(Mandatory = $true)][string]$OracleEffectSmokeSummary',
    '[Parameter(Mandatory = $true)][string]$ProofPath',
    '[Parameter(Mandatory = $true)][string]$ComparisonRoot',
    '[Parameter(Mandatory = $true)][string]$ReplayRoot',
    'Invoke-Issue13V5OracleEffectValidation',
    'oracle_effect = $oracleEffect', 'required_by_final_gate = $true',
    'final_evidence_eligible = $false',
    "schema = 'wlv-issue13-v5-oracle-effect-binding/2'",
    "schema = 'wlv-issue13-v5-oracle-effect-proof/2'",
    'primary = [ordered]@{', 'replay = [ordered]@{',
    'source_controller = $oracleProof.evidence.terminal_runtime.',
    'r_library = $oracleProof.evidence.terminal_runtime.r_library',
    'Assert-Issue13V5PathsDisjoint $oraclePrimaryRoot $oracleReplayRoot',
    'preparation_equivalence_profile = $preparationEquivalenceBinding',
    'all_rows_fields_and_order_exact = $true',
    'architecture_projection = @()',
    "source_unit_contract_bridge = 'exhaustive-source-unit-contract-bridge'",
    'Test-Issue13V5ExactBoolean'
  )) {
  if (-not $newConfigText.Contains($required)) {
    throw "V5 config generator lacks oracle-effect binding: $required"
  }
}

$reportText = [string]
  $bootstrapSourceTexts['issue13-v5-render-report.ps1']
foreach ($required in @(
    '$oracle.Count -ne 60',
    'wlv-issue13-complete-recalculation-delta/1',
    'complete_delta_equal', 'baseline_delta_sha256',
    'candidate_delta_sha256',
    'rss_recomputed_from_authenticated_samples',
    '$performance.scenario', 'Sort-Object scenario',
    'baseline_rss_sample_count', 'candidate_rss_sample_count',
    'baseline_samples_sha256', 'candidate_samples_sha256',
    '$expectedPerformanceScenarios', '$expectedOraclePhases',
    'oracle_effect_proof', '$oracleDeltaInventorySha256',
    '$rssEvidenceInventorySha256', '$oracleValidationCommandLine',
    '$oracleSourceController', '$oracleRLibrary',
    '$oracleRuntimeImmutability',
    '$oracleSourceController.file_count -ne 34L',
    "@(`$_.arguments) -cnotcontains '--vanilla'",
    '$oracleRuntimeImmutability.immutable',
    '$config.comparison.preparation_equivalence_profile',
    '$preparationEquivalenceBinding.architecture_projection',
    "'exhaustive-source-unit-contract-bridge'",
    '$unitComparison.cross_engine_bridge',
    'Test-Issue13V5ExactBoolean'
  )) {
  if (-not $reportText.Contains($required)) {
    throw "V5 report lacks fail-closed oracle/RSS evidence: $required"
  }
}

$smokeText = [string]
  $bootstrapSourceTexts['issue13-v5-baseline-smoke.ps1']
foreach ($required in @(
    "'R.exe'", "'Rscript.exe'", "'Rterm.exe'", "'Rgui.exe'",
    "'Rcmd.exe'", "'Rfe.exe'",
    "throw 'The V5 baseline smoke is Windows-only.'",
    'VolumeNameGuid',
    'DriveTarget',
    'must not use a SUBST or mapped-drive alias',
    'Assert-Issue13V5NoReparseAncestors $SmokeRoot',
    'ConvertTo-Issue13V5BaselineSmokePhysicalPath',
    'Test-Issue13V5BaselineSmokePhysicalOverlap',
    'Assert-Issue13V5BaselineSmokeRscriptSeal',
    'Rscript executable changed after its physical seal.',
    'rscript_physical_path = [string]$rscriptIdentity.physical_path',
    'rscript_item_id = [string]$rscriptIdentity.item_id',
    'rscript_link_count = [uint64]$rscriptIdentity.link_count',
    'rscript_sha256 = $rscriptSha256',
    'physically overlaps the',
    'The created V5 smoke root changed physical identity.',
    '$localeEnvironmentNames = @(''LANG'', ''LC_ALL'', ''LC_CTYPE'')',
    'Set-Item -LiteralPath (''Env:'' + $name) -Value $null',
    'environment_removed = [object[]]$localeEnvironmentNames',
    'Test-Issue13V5ExactBoolean'
  )) {
  if (-not $smokeText.Contains($required)) {
    throw "Baseline smoke lacks required R-process guard: $required"
  }
}
$smokeTokens = @()
$smokeErrors = @()
$smokeAst = $bootstrapSourceAsts['issue13-v5-baseline-smoke.ps1']
function Test-Issue13V5BaselineSmokeRscriptPhysicalAst(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $sealDefinitions = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
        'Assert-Issue13V5BaselineSmokeRscriptSeal'
  }, $true))
  if ($sealDefinitions.Count -ne 1 -or
      $sealDefinitions[0].Name -cne
        'Assert-Issue13V5BaselineSmokeRscriptSeal') {
    return $false
  }
  $sealDefinition = $sealDefinitions[0]
  $inputWrites = @(Get-Issue13V5VariableWriteAsts $Ast '$Rscript')
  $pathWrites = @(Get-Issue13V5VariableWriteAsts `
    $sealDefinition '$Path')
  $expectedIdentityWrites = @(Get-Issue13V5VariableWriteAsts `
    $sealDefinition '$ExpectedIdentity')
  $expectedShaWrites = @(Get-Issue13V5VariableWriteAsts `
    $sealDefinition '$ExpectedSha256')
  $fullWrites = @(Get-Issue13V5VariableWriteAsts $Ast '$rscriptFull')
  $identityWrites = @(Get-Issue13V5VariableWriteAsts `
    $Ast '$rscriptIdentity')
  $shaWrites = @(Get-Issue13V5VariableWriteAsts $Ast '$rscriptSha256')
  $protectedWrites = @(Get-Issue13V5VariableWriteAsts `
    $Ast '$protectedPhysicalPaths')
  $noReparseCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5NoReparseAncestors' -and
      [string]::Join('|', @($node.CommandElements | ForEach-Object {
        $_.Extent.Text
      })) -ceq
        "Assert-Issue13V5NoReparseAncestors|`$Rscript|'Rscript executable'"
  }, $true))
  $physicalCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'ConvertTo-Issue13V5BaselineSmokePhysicalPath' -and
      [string]::Join('|', @($node.CommandElements | ForEach-Object {
        $_.Extent.Text
      })) -ceq
        "ConvertTo-Issue13V5BaselineSmokePhysicalPath|`$rscriptFull|" +
          "'Rscript executable'"
  }, $true))
  $sealCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5BaselineSmokeRscriptSeal'
  }, $true))
  $rscriptInvocations = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      $node.InvocationOperator -eq
        [Management.Automation.Language.TokenKind]::Ampersand -and
      $node.CommandElements.Count -gt 0 -and
      $node.CommandElements[0].Extent.Text -ceq '$rscriptFull'
  }, $true))
  $monitorInvocations = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      $node.InvocationOperator -eq
        [Management.Automation.Language.TokenKind]::Ampersand -and
      $node.CommandElements.Count -gt 0 -and
      $node.CommandElements[0].Extent.Text -ceq '$monitor'
  }, $true))
  $sealChains = @($sealCalls | ForEach-Object {
    Get-Issue13V5AstAncestorChain $_ $Ast
  })
  $expectedSealChains = @(
    ('CommandAst>PipelineAst>AssignmentStatementAst>StatementBlockAst>' +
      'TryStatementAst>StatementBlockAst>ForEachStatementAst>' +
      'StatementBlockAst>TryStatementAst>NamedBlockAst'),
    ('CommandAst>PipelineAst>AssignmentStatementAst>StatementBlockAst>' +
      'TryStatementAst>StatementBlockAst>TryStatementAst>' +
      'StatementBlockAst>ForEachStatementAst>StatementBlockAst>' +
      'TryStatementAst>NamedBlockAst'),
    ('CommandAst>PipelineAst>AssignmentStatementAst>StatementBlockAst>' +
      'TryStatementAst>StatementBlockAst>ForEachStatementAst>' +
      'StatementBlockAst>TryStatementAst>NamedBlockAst'),
    ('CommandAst>PipelineAst>AssignmentStatementAst>StatementBlockAst>' +
      'TryStatementAst>StatementBlockAst>TryStatementAst>' +
      'StatementBlockAst>ForEachStatementAst>StatementBlockAst>' +
      'TryStatementAst>NamedBlockAst'),
    ('CommandAst>PipelineAst>AssignmentStatementAst>StatementBlockAst>' +
      'TryStatementAst>NamedBlockAst'),
    'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst'
  )
  if ($inputWrites.Count -ne 0 -or $pathWrites.Count -ne 0 -or
      $expectedIdentityWrites.Count -ne 0 -or $expectedShaWrites.Count -ne 0 -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$rscriptFull' 'AssignmentStatementAst>NamedBlockAst' `
        '(Resolve-Path -LiteralPath $Rscript).Path') -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$rscriptIdentity' 'AssignmentStatementAst>NamedBlockAst') -or
      [regex]::Replace($identityWrites[0].Right.Extent.Text, '[\s`]', '') -cne
        "Get-Issue13V5PhysicalItemIdentity`$rscriptFull'Rscriptexecutable'" -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$rscriptSha256' 'AssignmentStatementAst>NamedBlockAst' `
        'Get-Issue13V5Sha256 $rscriptFull') -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$protectedPhysicalPaths' 'AssignmentStatementAst>NamedBlockAst') -or
      $noReparseCalls.Count -ne 1 -or $physicalCalls.Count -ne 1 -or
      $sealCalls.Count -ne 6 -or $rscriptInvocations.Count -ne 1 -or
      $monitorInvocations.Count -ne 1 -or
      [string]::Join("`n", $sealChains) -cne
        [string]::Join("`n", $expectedSealChains) -or
      (Get-Issue13V5AstAncestorChain $rscriptInvocations[0] $Ast) -cne
        ('CommandAst>PipelineAst>StatementBlockAst>TryStatementAst>' +
          'StatementBlockAst>TryStatementAst>StatementBlockAst>' +
          'ForEachStatementAst>StatementBlockAst>TryStatementAst>' +
          'NamedBlockAst') -or
      (Get-Issue13V5AstAncestorChain $monitorInvocations[0] $Ast) -cne
        ('CommandAst>PipelineAst>StatementBlockAst>TryStatementAst>' +
          'StatementBlockAst>TryStatementAst>StatementBlockAst>' +
          'ForEachStatementAst>StatementBlockAst>TryStatementAst>' +
          'NamedBlockAst') -or
      @($sealCalls | Where-Object {
        [string]::Join('|', @($_.CommandElements | ForEach-Object {
          $_.Extent.Text
        })) -cne
          'Assert-Issue13V5BaselineSmokeRscriptSeal|$rscriptFull|' +
            '$rscriptIdentity|$rscriptSha256'
      }).Count -ne 0) {
    return $false
  }
  $physicalOwner = $physicalCalls[0].Parent
  while ($null -ne $physicalOwner -and $physicalOwner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
    $physicalOwner = $physicalOwner.Parent
  }
  $rscriptElements = @($rscriptInvocations[0].CommandElements |
    ForEach-Object { $_.Extent.Text })
  $rscriptOption = [Array]::IndexOf(
    [string[]]$rscriptElements, '--rscript')
  if (-not [object]::ReferenceEquals($physicalOwner, $protectedWrites[0]) -or
      $rscriptOption -lt 0 -or
      $rscriptOption + 1 -ge $rscriptElements.Count -or
      $rscriptElements[$rscriptOption + 1] -cne '$rscriptFull' -or
      $noReparseCalls[0].Extent.EndOffset -ge
        $fullWrites[0].Extent.StartOffset -or
      $fullWrites[0].Extent.EndOffset -ge
        $identityWrites[0].Extent.StartOffset -or
      $identityWrites[0].Extent.EndOffset -ge
        $physicalCalls[0].Extent.StartOffset -or
      $physicalCalls[0].Extent.EndOffset -ge
        $sealCalls[0].Extent.StartOffset -or
      $sealCalls[0].Extent.EndOffset -ge
        $rscriptInvocations[0].Extent.StartOffset -or
      $rscriptInvocations[0].Extent.EndOffset -ge
        $sealCalls[1].Extent.StartOffset -or
      $sealCalls[1].Extent.EndOffset -ge
        $sealCalls[2].Extent.StartOffset -or
      $sealCalls[2].Extent.EndOffset -ge
        $monitorInvocations[0].Extent.StartOffset -or
      $monitorInvocations[0].Extent.EndOffset -ge
        $sealCalls[3].Extent.StartOffset -or
      $sealCalls[3].Extent.EndOffset -ge
        $sealCalls[4].Extent.StartOffset -or
      $sealCalls[4].Extent.EndOffset -ge
        $sealCalls[5].Extent.StartOffset) {
    return $false
  }
  $true
}
if ($smokeErrors.Count -ne 0 -or
    -not (Test-Issue13V5BaselineSmokeRscriptPhysicalAst $smokeAst)) {
  throw 'Baseline smoke Rscript is not physically sealed end-to-end.'
}
$smokeText = $smokeAst.Extent.Text
$smokeSealCalls = @($smokeAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5BaselineSmokeRscriptSeal'
}, $true))
$smokePhysicalCalls = @($smokeAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'ConvertTo-Issue13V5BaselineSmokePhysicalPath' -and
    [string]::Join('|', @($node.CommandElements | ForEach-Object {
      $_.Extent.Text
    })) -ceq
      "ConvertTo-Issue13V5BaselineSmokePhysicalPath|`$rscriptFull|" +
        "'Rscript executable'"
}, $true))
$smokeRscriptInvocations = @($smokeAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    $node.InvocationOperator -eq
      [Management.Automation.Language.TokenKind]::Ampersand -and
    $node.CommandElements.Count -gt 0 -and
    $node.CommandElements[0].Extent.Text -ceq '$rscriptFull'
}, $true))
$smokeFullWrites = @(Get-Issue13V5VariableWriteAsts `
  $smokeAst '$rscriptFull')
$smokeIdentityWrites = @(Get-Issue13V5VariableWriteAsts `
  $smokeAst '$rscriptIdentity')
$smokeShaWrites = @(Get-Issue13V5VariableWriteAsts `
  $smokeAst '$rscriptSha256')
if ($smokeSealCalls.Count -ne 6 -or $smokePhysicalCalls.Count -ne 1 -or
    $smokeRscriptInvocations.Count -ne 1 -or $smokeFullWrites.Count -ne 1 -or
    $smokeIdentityWrites.Count -ne 1 -or $smokeShaWrites.Count -ne 1) {
  throw 'Cannot construct the baseline Rscript negative self-tests.'
}
$deadSeal = $smokeSealCalls[1]
$physicalCall = $smokePhysicalCalls[0]
$rscriptElement = $smokeRscriptInvocations[0].CommandElements[0]
$smokeRscriptMutants = @(
  $smokeText.Remove(
    $deadSeal.Extent.StartOffset,
    $deadSeal.Extent.EndOffset - $deadSeal.Extent.StartOffset).Insert(
      $deadSeal.Extent.StartOffset,
      'if ($false) { ' + $deadSeal.Extent.Text + ' }'),
  $smokeText.Remove(
    $physicalCall.Extent.StartOffset,
    $physicalCall.Extent.EndOffset - $physicalCall.Extent.StartOffset).Insert(
      $physicalCall.Extent.StartOffset,
      $physicalCall.Extent.Text.Replace('$rscriptFull', '$library')),
  $smokeText.Remove(
    $rscriptElement.Extent.StartOffset,
    $rscriptElement.Extent.EndOffset - $rscriptElement.Extent.StartOffset).
      Insert($rscriptElement.Extent.StartOffset, '$Rscript'),
  $smokeText.Insert(
    $smokeFullWrites[0].Extent.EndOffset,
    "`n`$rscriptFull = [string]`$rscriptFull"),
  $smokeText.Insert(
    $smokeIdentityWrites[0].Extent.EndOffset,
    "`n`$rscriptIdentity = [pscustomobject]`$rscriptIdentity"),
  $smokeText.Insert(
    $smokeShaWrites[0].Extent.EndOffset,
    "`n`$rscriptSha256 = `$rscriptSha256.ToLowerInvariant()")
)
foreach ($smokeRscriptMutantText in $smokeRscriptMutants) {
  $smokeRscriptMutantTokens = $null
  $smokeRscriptMutantErrors = $null
  $smokeRscriptMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $smokeRscriptMutantText, [ref]$smokeRscriptMutantTokens,
      [ref]$smokeRscriptMutantErrors)
  if ($smokeRscriptMutantErrors.Count -ne 0 -or
      (Test-Issue13V5BaselineSmokeRscriptPhysicalAst `
        $smokeRscriptMutantAst)) {
    throw 'Baseline Rscript seal accepted a dataflow/placement mutant.'
  }
}

$libraryText = [string]
  $bootstrapSourceTexts['issue13-v5-coordinator-lib.ps1']
foreach ($required in @(
    "'R.exe'", "'Rscript.exe'", "'Rterm.exe'", "'Rgui.exe'",
    "'Rcmd.exe'", "'Rfe.exe'", 'Assert-Issue13V5ReportBinding',
    'Worktree/evidence/control isolation', '$process.Kill($true)',
    '$environmentRemoved = @(''LANG'', ''LC_ALL'', ''LC_CTYPE'')',
    '$info.Environment.Remove($name)',
    'environment_removed = [object[]]$environmentRemoved',
    'V5 commands cannot override sanitized locale variable',
    'Get-Issue13V5ConfiguredPaths', 'Test-Issue13V5LegacyPath',
    'Get-Issue13V5SourceBinding', 'Get-Issue13V5SourceContractSha256',
    'Assert-Issue13V5SourceContractBindings', 'candidate_source_origin',
    'wlv-issue13-native-gate-config/3',
    'Invoke-Issue13V5OracleEffectValidation',
    'Assert-Issue13V5OracleEffectControlRecord',
    '''-OracleSmokeSummary'', [string]$oracle.oracle_smoke.path',
    '''-ComparisonHarnessManifest'',',
    '[string]$Config.harness_manifest_path',
    '$Config.oracle_effect.comparisons.primary.root',
    '$Config.oracle_effect.comparisons.replay.root',
    '$Config.oracle_effect.comparison_harness.manifest_path',
    '$Config.comparison.preparation_equivalence_profile.path',
    "'wlv-issue13-v5-oracle-effect-binding/2'",
    "'wlv-issue13-v5-oracle-effect-proof/2'",
    "'source_controller_inventory_sha256'", "'r_runtime_inventory_sha256'",
    "'comparison_harness', 'rscript', 'r_library', 'runtime_immutability'",
    'Assert-Issue13V5ScenarioStateHashes',
    'Scenario samples are not anchored by the state-bound metrics',
    'Assert-Issue13V5CompletedEvidenceState',
    'Test-Issue13V5ExactBoolean',
    'ConvertTo-Issue13V5PhysicalPath', 'CoordinatorNativePath',
    'VolumeNameGuid', 'QueryDosDevice',
    'Test-Issue13V5ForbiddenDriveTarget',
    'must not use a SUBST or mapped-drive alias'
  )) {
  if (-not $libraryText.Contains($required)) {
    throw "Coordinator library lacks required safety guard: $required"
  }
}

$booleanGuardFiles = @($script:Issue13V5ControllerFiles | Where-Object {
  [IO.Path]::GetExtension([string]$_) -ceq '.ps1'
})
$booleanConversions = [Collections.Generic.List[string]]::new()
foreach ($name in $booleanGuardFiles) {
  $tokens = @()
  $errors = @()
  $ast = $bootstrapSourceAsts[$name]
  if ($errors.Count -ne 0) {
    throw "PowerShell parser rejected boolean-guard source $name`: $($errors[0].Message)"
  }
  foreach ($conversion in @($ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.ConvertExpressionAst] -and
        (Test-Issue13V5TypeConstraint $node.Type 'System.Boolean')
    }, $true))) {
    $booleanConversions.Add("$name|$($conversion.Extent.Text)")
  }
}
$expectedBooleanConversions = @(
  'issue13-v5-coordinator-lib.ps1|[bool]$Expected',
  'issue13-v5-coordinator-lib.ps1|[bool]$Value',
  'issue13-v5-oracle-effect-lib.ps1|[bool]$Expected',
  'issue13-v5-oracle-effect-lib.ps1|[bool]$Value'
)
if ([string]::Join("`n", @($booleanConversions.ToArray() | Sort-Object)) -cne
    [string]::Join("`n", $expectedBooleanConversions)) {
  throw 'External boolean validation acquired an unapproved Boolean conversion.'
}
$booleanMutantTokens = $null
$booleanMutantErrors = $null
$booleanMutantAst = [Management.Automation.Language.Parser]::ParseInput(
  '[System.Boolean]$externalValue', [ref]$booleanMutantTokens,
  [ref]$booleanMutantErrors)
$booleanMutantConversions = @($booleanMutantAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.ConvertExpressionAst] -and
    (Test-Issue13V5TypeConstraint $node.Type 'System.Boolean')
}, $true))
if ($booleanMutantErrors.Count -ne 0 -or
    $booleanMutantConversions.Count -ne 1) {
  throw 'Boolean identity guard missed a System.Boolean conversion.'
}

$exactBooleanCases = @(
  [pscustomobject]@{
    value = $true; expected = $true; accepted = $true
  },
  [pscustomobject]@{
    value = $false; expected = $false; accepted = $true
  },
  [pscustomobject]@{
    value = 'true'; expected = $true; accepted = $false
  },
  [pscustomobject]@{
    value = 'false'; expected = $false; accepted = $false
  },
  [pscustomobject]@{
    value = 1; expected = $true; accepted = $false
  },
  [pscustomobject]@{
    value = $null; expected = $false; accepted = $false
  },
  [pscustomobject]@{
    value = $true; expected = 'true'; accepted = $false
  }
)
foreach ($case in $exactBooleanCases) {
  $coordinatorAccepted = Test-Issue13V5ExactBoolean `
    $case.value $case.expected
  $oracleAccepted = Test-Issue13OracleEffectExactBoolean `
    $case.value $case.expected
  if ($coordinatorAccepted -isnot [bool] -or
      $oracleAccepted -isnot [bool] -or
      $coordinatorAccepted -cne $case.accepted -or
      $oracleAccepted -cne $case.accepted) {
    throw 'Exact-Boolean negative self-test failed.'
  }
}

$driveTargetCases = @(
  [pscustomobject]@{ target = '\??\D:\alias'; forbidden = $true },
  [pscustomobject]@{
    target = '\Device\Mup\server\share'; forbidden = $true
  },
  [pscustomobject]@{
    target = '\Device\LanmanRedirector\server\share'; forbidden = $true
  },
  [pscustomobject]@{
    target = '\Device\WebDavRedirector\server\share'; forbidden = $true
  },
  [pscustomobject]@{
    target = '\Device\HarddiskVolume3'; forbidden = $false
  }
)
foreach ($case in $driveTargetCases) {
  $coordinatorForbidden = Test-Issue13V5ForbiddenDriveTarget $case.target
  $oracleForbidden = Test-Issue13OracleEffectForbiddenDriveTarget $case.target
  if ($coordinatorForbidden -isnot [bool] -or
      $oracleForbidden -isnot [bool] -or
      $coordinatorForbidden -cne $case.forbidden -or
      $oracleForbidden -cne $case.forbidden) {
    throw "Drive-target negative self-test failed: $($case.target)"
  }
}

$physicalRepository = ConvertTo-Issue13V5PhysicalPath `
  $RepositoryRoot 'static repository root'
$oraclePhysicalRepository = ConvertTo-Issue13OracleEffectPhysicalPath `
  $RepositoryRoot 'static repository root'
$missingRepositoryDescendant = Join-Path $RepositoryRoot `
  'static-missing-descendant\child'
if (-not (Test-Issue13V5PathContained `
      $missingRepositoryDescendant $RepositoryRoot) -or
    -not (Test-Issue13OracleEffectPathContained `
      $missingRepositoryDescendant $RepositoryRoot)) {
  throw 'Physical containment rejected a missing descendant.'
}
$configPathIsolationRejected = $false
try {
  $null = Assert-Issue13V5ConfigPathIsolation `
    $missingRepositoryDescendant @($RepositoryRoot)
} catch {
  $configPathIsolationRejected = $_.Exception.Message.Contains(
    'V5 config/immutable-root isolation paths overlap:')
}
if (-not $configPathIsolationRejected) {
  throw 'Config-path isolation accepted a repository descendant.'
}
if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
  if ($physicalRepository -cnotmatch
        '^\\\\\?\\Volume\{[0-9A-Fa-f-]+\}\\' -or
      $oraclePhysicalRepository -cnotmatch
        '^\\\\\?\\Volume\{[0-9A-Fa-f-]+\}\\') {
    throw 'Physical canonicalization did not return volume-GUID identity.'
  }
  $systemDirectory = [Environment]::SystemDirectory
  Assert-Issue13V5PathsDisjoint $RepositoryRoot $systemDirectory `
    'Static repository/system-directory isolation'
  Assert-Issue13OracleEffectPathsDisjoint $RepositoryRoot $systemDirectory `
    'Static repository/system-directory isolation'
  foreach ($converter in @('coordinator', 'oracle')) {
    $uncRejected = $false
    try {
      if ($converter -ceq 'coordinator') {
        $null = ConvertTo-Issue13V5PhysicalPath `
          '\\server\share\issue13' 'static UNC path'
      } else {
        $null = ConvertTo-Issue13OracleEffectPhysicalPath `
          '\\server\share\issue13' 'static UNC path'
      }
    } catch {
      $uncRejected = $_.Exception.Message.Contains(
        'must use a local drive-letter path')
    }
    if (-not $uncRejected) {
      throw "Physical $converter canonicalization accepted a UNC path."
    }
  }
}

$tokens = @()
$errors = @()
$libraryAst = $bootstrapSourceAsts['issue13-v5-coordinator-lib.ps1']
function Test-Issue13V5FrozenCommandDataflow(
  [Management.Automation.Language.Ast]$RootAst,
  [string]$CommandName,
  [string[]]$ExpectedArguments,
  [string]$ExpectedChain
) {
  $calls = @($RootAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        $CommandName
  }, $true))
  if ($calls.Count -ne 1 -or
      [string]::Join("`n", @($calls[0].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
        [string]::Join("`n", $ExpectedArguments) -or
      (Get-Issue13V5AstAncestorChain $calls[0] $RootAst) -cne
        $ExpectedChain) {
    return $false
  }
  $true
}
$configDefinitions = @($libraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5Config'
}, $true))
$configPathIsolationDefinitions = @($libraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5ConfigPathIsolation'
}, $true))
$oracleIsolationDefinitions = @($libraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5OracleComparisonIsolation'
}, $true))
if ($errors.Count -ne 0 -or $configDefinitions.Count -ne 1 -or
    $configPathIsolationDefinitions.Count -ne 1 -or
    $oracleIsolationDefinitions.Count -ne 1) {
  throw 'Coordinator root-isolation AST is missing or ambiguous.'
}
$configDisjointCalls = @($configDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5PathsDisjoint'
}, $true))
$configPhysicalCalls = @($configDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'ConvertTo-Issue13V5PhysicalPath'
}, $true))
$configPathIsolationCalls = @($configDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5ConfigPathIsolation'
}, $true))
$configPathIsolationDisjointCalls =
  @($configPathIsolationDefinitions[0].FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5PathsDisjoint'
  }, $true))
$oracleIsolationDisjointCalls = @($oracleIsolationDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5PathsDisjoint'
}, $true))
function Test-Issue13V5ConfigValidatorIsolationAst(
  [Management.Automation.Language.FunctionDefinitionAst]$Definition
) {
  $allowedMutationSignatures = @(
    ('git|-C|([string]$config.repository_root)|cat-file|-e|' +
      "([string]`$config.candidate_commit + '^{commit}')"),
    ('git|-C|([string]$config.repository_root)|cat-file|-e|' +
      "([string]`$config.baseline_runtime_commit + '^{commit}')"),
    ('git|-C|([string]$config.repository_root)|rev-parse|' +
      "([string]`$config.baseline_runtime_commit + '^')"),
    ('git|-C|([string]$config.repository_root)|rev-parse|' +
      "([string]`$config.baseline_runtime_commit + '^{tree}')"),
    ('git|-C|([string]$config.repository_root)|merge-base|--is-ancestor|' +
      '$script:Issue13V5BaselineCommit|([string]$config.candidate_commit)'),
    ('git|-C|([string]$config.repository_root)|merge-base|--is-ancestor|' +
      '$script:Issue13V5BaselineRuntimeCommit|' +
      '([string]$config.candidate_commit)')
  )
  $pathWrites = @(Get-Issue13V5VariableWriteAsts $Definition '$path')
  $rootWrites = @(Get-Issue13V5VariableWriteAsts `
    $Definition '$immutableRoots')
  $dynamicMutators = @($Definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Test-Issue13V5ForbiddenProtectedScopeCommand `
        $node $allowedMutationSignatures)
  }, $true))
  $memberMutators = @($Definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      (Test-Issue13V5AstReferencesVariable $node '$immutableRoots')
  }, $true))
  if ($Definition.Name -cne 'Assert-Issue13V5Config' -or
      -not (Test-Issue13V5SingularDirectAssignment $Definition `
        '$path' 'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' `
        '(Resolve-Path -LiteralPath $ConfigPath).Path') -or
      -not (Test-Issue13V5SingularDirectAssignment $Definition `
        '$immutableRoots' `
        'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst') -or
      [regex]::Replace($rootWrites[0].Right.Extent.Text, '\s+', '') -cne
        '@((ConvertTo-Issue13V5Path([string]$config.repository_root))' +
        '(ConvertTo-Issue13V5Path([string]$config.source_origin))' +
        '(ConvertTo-Issue13V5Path([string]$config.candidate_source_origin))' +
        '(ConvertTo-Issue13V5Path([string]$config.harness_runtime_root))' +
        '(ConvertTo-Issue13V5Path([string]$config.r_library))' +
        '(ConvertTo-Issue13V5Path([string]$config.rscript))' +
        '(ConvertTo-Issue13V5Path([string]$config.oracle_effect.' +
          'comparisons.primary.root))' +
        '(ConvertTo-Issue13V5Path([string]$config.oracle_effect.' +
          'comparisons.replay.root)))' -or
      -not (Test-Issue13V5FrozenCommandDataflow `
        $Definition 'Assert-Issue13V5ConfigPathIsolation' `
        @('$path', '$immutableRoots') `
        ('CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>' +
          'ScriptBlockAst')) -or
      $pathWrites[0].Extent.StartOffset -ge $rootWrites[0].Extent.StartOffset -or
      $dynamicMutators.Count -ne 0 -or
      (Test-Issue13V5ForbiddenProtectedScopeRedirection `
        $Definition @('2>$null')) -or
      (Test-Issue13V5ForbiddenSessionStateMutation $Definition) -or
      $memberMutators.Count -ne 0) {
    return $false
  }
  $true
}
if ($configDefinitions[0].Extent.Text.Contains('.StartsWith(') -or
    $configDisjointCalls.Count -ne 4 -or
    $configPhysicalCalls.Count -ne 2 -or
    $configPathIsolationCalls.Count -ne 1 -or
    $configPathIsolationCalls[0].CommandElements.Count -ne 3 -or
    $configPathIsolationCalls[0].CommandElements[1].Extent.Text -cne '$path' -or
    $configPathIsolationCalls[0].CommandElements[2].Extent.Text -cne
      '$immutableRoots' -or
    -not (Test-Issue13V5FrozenCommandDataflow `
      $configDefinitions[0] 'Assert-Issue13V5ConfigPathIsolation' `
      @('$path', '$immutableRoots') `
      'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>ScriptBlockAst') -or
    -not (Test-Issue13V5ConfigValidatorIsolationAst $configDefinitions[0]) -or
    $configPathIsolationDefinitions[0].Extent.Text.Contains('.StartsWith(') -or
    $configPathIsolationDisjointCalls.Count -ne 1 -or
    -not (Test-Issue13V5FrozenCommandDataflow `
      $configPathIsolationDefinitions[0] 'Assert-Issue13V5PathsDisjoint' `
      @('$ConfigPath', '$immutableRoot',
        "'V5 config/immutable-root isolation'") `
      'CommandAst>PipelineAst>StatementBlockAst>ForEachStatementAst>NamedBlockAst>ScriptBlockAst') -or
    $oracleIsolationDefinitions[0].Extent.Text.Contains('.StartsWith(') -or
    $oracleIsolationDisjointCalls.Count -ne 2) {
  throw 'Coordinator root isolation is no longer physically canonical.'
}

$pathContainedDefinitions = @($libraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Test-Issue13V5PathContained'
}, $true))
if ($pathContainedDefinitions.Count -ne 1 -or
    @($pathContainedDefinitions[0].FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'ConvertTo-Issue13V5PhysicalPath'
    }, $true)).Count -ne 2 -or
    $pathContainedDefinitions[0].Extent.Text.Contains(
      'ConvertTo-Issue13V5Path ')) {
  throw 'Coordinator containment no longer consumes physical identities.'
}

$tokens = @()
$errors = @()
$newConfigAst = $bootstrapSourceAsts['issue13-v5-new-config.ps1']
$newConfigDisjointCalls = @($newConfigAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5PathsDisjoint'
}, $true))
$newConfigPathIsolationCalls = @($newConfigAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5ConfigPathIsolation'
}, $true))
$newConfigFreshRootCalls = @($newConfigAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5FreshRoot'
}, $true))
$newConfigImmutableAssignments = @(Get-Issue13V5VariableWriteAsts `
  $newConfigAst '$configImmutableRoots')
function Test-Issue13V5ConfigGeneratorIsolationAst(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $rootWrites = @(Get-Issue13V5VariableWriteAsts `
    $Ast '$configImmutableRoots')
  $temporaryWrites = @(Get-Issue13V5VariableWriteAsts $Ast '$temporary')
  $isolationCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5ConfigPathIsolation'
  }, $true))
  $freshCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5FreshRoot'
  }, $true))
  $moveCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Move-Item'
  }, $true))
  $physicalCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'ConvertTo-Issue13V5PhysicalPath' -and
      -not (Get-Issue13V5AstAncestorChain $node $Ast).Contains(
        'FunctionDefinitionAst')
  }, $true))
  $ancestorCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5NoReparseAncestors' -and
      -not (Get-Issue13V5AstAncestorChain $node $Ast).Contains(
        'FunctionDefinitionAst')
  }, $true))
  $dynamicMutators = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Test-Issue13V5ForbiddenProtectedScopeCommand $node @(
        "(Join-Path `$PSScriptRoot 'issue13-v5-coordinator-lib.ps1')",
        'New-Item|-ItemType|Directory|-Path|$outputParent',
        'Move-Item|-LiteralPath|$temporary|-Destination|$finalOutputFull',
        ('git|-C|$repository|cat-file|-e|' +
          "(`$BaselineRuntimeCommit + '^{commit}')"),
        ('git|-C|$repository|rev-parse|' +
          "(`$BaselineRuntimeCommit + '^')"),
        ('git|-C|$repository|rev-parse|' +
          "(`$BaselineRuntimeCommit + '^{tree}')"),
        ('git|-C|$repository|cat-file|-e|' +
          "(`$CandidateCommit + '^{commit}')"),
        ('git|-C|$repository|merge-base|--is-ancestor|' +
          '$baselineCommit|$CandidateCommit'),
        ('git|-C|$repository|merge-base|--is-ancestor|' +
          '$BaselineRuntimeCommit|$CandidateCommit')
      ))
  }, $true))
  $rootMemberMutators = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      (Test-Issue13V5AstReferencesVariable `
        $node '$configImmutableRoots')
  }, $true))
  $signatures = @($isolationCalls | ForEach-Object {
    [string]::Join('|', @($_.CommandElements | ForEach-Object {
      $_.Extent.Text
    })) + '|' + (Get-Issue13V5AstAncestorChain $_ $Ast)
  })
  $ancestorSignatures = @($ancestorCalls | ForEach-Object {
    [string]::Join('|', @($_.CommandElements | ForEach-Object {
      $_.Extent.Text
    })) + '|' + (Get-Issue13V5AstAncestorChain $_ $Ast)
  })
  if ([string]::Join("`n", $signatures) -cne [string]::Join("`n", @(
      ('Assert-Issue13V5ConfigPathIsolation|$outputFull|' +
        '$configImmutableRoots|CommandAst>PipelineAst>' +
        'AssignmentStatementAst>NamedBlockAst'),
      ('Assert-Issue13V5ConfigPathIsolation|$finalOutputFull|' +
        '$configImmutableRoots|CommandAst>PipelineAst>' +
        'AssignmentStatementAst>NamedBlockAst'),
      ('Assert-Issue13V5ConfigPathIsolation|$finalOutputFull|' +
        '$configImmutableRoots|CommandAst>PipelineAst>' +
        'AssignmentStatementAst>NamedBlockAst')
    )) -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$outputFull' 'AssignmentStatementAst>NamedBlockAst' `
        'ConvertTo-Issue13V5FullPath $Output $false') -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$finalOutputFull' 'AssignmentStatementAst>NamedBlockAst' `
        'Join-Path $outputParent ([IO.Path]::GetFileName($outputFull))') -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$configImmutableRoots' 'AssignmentStatementAst>NamedBlockAst') -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$temporary' 'AssignmentStatementAst>NamedBlockAst') -or
      [regex]::Replace($rootWrites[0].Right.Extent.Text, '\s+', '') -cne
        '@($repository,$harnessRuntime,$source,$candidateSource,$library,' +
          '$rscriptFull,$oraclePrimaryRoot,$oracleReplayRoot)' -or
      [regex]::Replace(
        $temporaryWrites[0].Right.Extent.Text, '\s+', '') -cne
        "Join-Path`$outputParent('.'+[IO.Path]::GetFileName(" +
          "`$finalOutputFull)+'-'+[Guid]::NewGuid().ToString('N')+'.tmp')" -or
      $freshCalls.Count -ne 3 -or
      $isolationCalls[0].Extent.StartOffset -ge
        [int](@($freshCalls | ForEach-Object { $_.Extent.StartOffset } |
          Measure-Object -Minimum)[0].Minimum) -or
      $physicalCalls.Count -ne 3 -or
      [string]::Join("`n", $ancestorSignatures) -cne
        [string]::Join("`n", @(
          ('Assert-Issue13V5NoReparseAncestors|$protectedRoot|' +
            "'Oracle-effect protected root'|CommandAst>PipelineAst>" +
            'StatementBlockAst>ForEachStatementAst>StatementBlockAst>' +
            'ForEachStatementAst>NamedBlockAst'),
          ('Assert-Issue13V5NoReparseAncestors|$outputFull|' +
            "'V5 config output'|CommandAst>PipelineAst>NamedBlockAst"),
          ('Assert-Issue13V5NoReparseAncestors|$finalOutputFull|' +
            "'Resolved V5 config output'|CommandAst>PipelineAst>NamedBlockAst"),
          ('Assert-Issue13V5NoReparseAncestors|$finalOutputFull|' +
            "'Final V5 config output'|CommandAst>PipelineAst>NamedBlockAst")
        )) -or
      $moveCalls.Count -ne 1 -or
      $moveCalls[0].GetCommandName() -cne 'Move-Item' -or
      [string]::Join("`n", @($moveCalls[0].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
        "-LiteralPath`n`$temporary`n-Destination`n`$finalOutputFull" -or
      $isolationCalls[2].Extent.EndOffset -ge
        $moveCalls[0].Extent.StartOffset -or
      $dynamicMutators.Count -ne 0 -or
      (Test-Issue13V5ForbiddenProtectedScopeRedirection `
        $Ast @('2>$null')) -or
      (Test-Issue13V5ForbiddenSessionStateMutation $Ast) -or
      $rootMemberMutators.Count -ne 0) {
    return $false
  }
  $true
}
$newConfigImmutableVariables = if (
    $newConfigImmutableAssignments.Count -eq 1) {
  @($newConfigImmutableAssignments[0].Right.FindAll({
    param($node)
    $node -is [Management.Automation.Language.VariableExpressionAst]
  }, $true) | ForEach-Object { '$' + $_.VariablePath.UserPath })
} else { @() }
$newConfigFirstFreshRootOffset = if ($newConfigFreshRootCalls.Count -gt 0) {
  [int](@($newConfigFreshRootCalls | ForEach-Object {
    $_.Extent.StartOffset
  } | Measure-Object -Minimum)[0].Minimum)
} else { -1 }
if ($errors.Count -ne 0 -or
    $newConfigAst.Extent.Text.Contains('.StartsWith(') -or
    $newConfigDisjointCalls.Count -ne 7 -or
    $newConfigPathIsolationCalls.Count -ne 3 -or
    $newConfigFreshRootCalls.Count -ne 3 -or
    $newConfigPathIsolationCalls[0].Extent.StartOffset -ge
      $newConfigFirstFreshRootOffset -or
    $newConfigImmutableAssignments.Count -ne 1 -or
    [string]::Join("`n", $newConfigImmutableVariables) -cne
    [string]::Join("`n", @(
        '$repository', '$harnessRuntime', '$source', '$candidateSource',
        '$library', '$rscriptFull', '$oraclePrimaryRoot', '$oracleReplayRoot'
      )) -or
    -not (Test-Issue13V5ConfigGeneratorIsolationAst $newConfigAst)) {
  throw 'Config generator root isolation is no longer physically canonical.'
}
$newConfigIsolationOwner = $newConfigPathIsolationCalls[0].Parent
while ($null -ne $newConfigIsolationOwner -and
    $newConfigIsolationOwner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
  $newConfigIsolationOwner = $newConfigIsolationOwner.Parent
}
$newConfigIsolationStatement = [string]$newConfigIsolationOwner.Extent.Text
if ($newConfigText.IndexOf(
      $newConfigIsolationStatement, [StringComparison]::Ordinal) -ne
    $newConfigText.LastIndexOf(
      $newConfigIsolationStatement, [StringComparison]::Ordinal)) {
  throw 'Config generator isolation statement is not textually unique.'
}
$newConfigDeadBranchText = $newConfigText.Replace(
  $newConfigIsolationStatement,
  "if (`$false) {`n$newConfigIsolationStatement`n}")
$newConfigDeadBranchTokens = $null
$newConfigDeadBranchErrors = $null
$newConfigDeadBranchAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $newConfigDeadBranchText, [ref]$newConfigDeadBranchTokens,
    [ref]$newConfigDeadBranchErrors)
if ($newConfigDeadBranchErrors.Count -ne 0 -or
    (Test-Issue13V5ConfigGeneratorIsolationAst $newConfigDeadBranchAst)) {
  throw 'Config generator accepted a dead path-isolation branch.'
}
$newConfigTypedRootText = $newConfigText.Replace(
  [string]$newConfigImmutableAssignments[0].Extent.Text,
  [string]$newConfigImmutableAssignments[0].Extent.Text +
    "`n[string[]]`$CoNfIgImMuTaBlErOoTs = @(`$repository)")
$newConfigTypedRootTokens = $null
$newConfigTypedRootErrors = $null
$newConfigTypedRootAst = [Management.Automation.Language.Parser]::ParseInput(
  $newConfigTypedRootText, [ref]$newConfigTypedRootTokens,
  [ref]$newConfigTypedRootErrors)
if ($newConfigTypedRootErrors.Count -ne 0 -or
    (Test-Issue13V5ConfigGeneratorIsolationAst $newConfigTypedRootAst)) {
  throw 'Config generator accepted a typed case-variant root mutation.'
}
$newConfigWrappedRootText = $newConfigText.Replace(
  '$repository, $harnessRuntime',
  '[System.String]($repository + ''\x''), $harnessRuntime')
$newConfigWrappedRootTokens = $null
$newConfigWrappedRootErrors = $null
$newConfigWrappedRootAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $newConfigWrappedRootText, [ref]$newConfigWrappedRootTokens,
    [ref]$newConfigWrappedRootErrors)
if ($newConfigWrappedRootErrors.Count -ne 0 -or
    (Test-Issue13V5ConfigGeneratorIsolationAst `
      $newConfigWrappedRootAst)) {
  throw 'Config generator accepted a wrapped immutable root.'
}
$newConfigDynamicRootText = $newConfigText.Replace(
  [string]$newConfigImmutableAssignments[0].Extent.Text,
  [string]$newConfigImmutableAssignments[0].Extent.Text +
    "`nsV -Name configImmutableRoots -Value @(`$repository)")
$newConfigDynamicRootTokens = $null
$newConfigDynamicRootErrors = $null
$newConfigDynamicRootAst = [Management.Automation.Language.Parser]::ParseInput(
  $newConfigDynamicRootText, [ref]$newConfigDynamicRootTokens,
  [ref]$newConfigDynamicRootErrors)
if ($newConfigDynamicRootErrors.Count -ne 0 -or
    (Test-Issue13V5ConfigGeneratorIsolationAst $newConfigDynamicRootAst)) {
  throw 'Config generator accepted an alias-based root mutation.'
}
$newConfigMoveCalls = @($newConfigAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Move-Item'
}, $true))
$newConfigMoveStatement = [string]$newConfigMoveCalls[0].Parent.Extent.Text
$newConfigOutputMutationText = $newConfigText.Replace(
  $newConfigMoveStatement,
  "`$FiNaLoUtPuTfUlL = Join-Path `$repository 'issue13-mutant.json'`n" +
    $newConfigMoveStatement)
$newConfigOutputMutationTokens = $null
$newConfigOutputMutationErrors = $null
$newConfigOutputMutationAst = [Management.Automation.Language.Parser]::ParseInput(
  $newConfigOutputMutationText, [ref]$newConfigOutputMutationTokens,
  [ref]$newConfigOutputMutationErrors)
if ($newConfigOutputMutationErrors.Count -ne 0 -or
    (Test-Issue13V5ConfigGeneratorIsolationAst `
      $newConfigOutputMutationAst)) {
  throw 'Config generator accepted a post-check output mutation.'
}
$configIsolationOwner = $configPathIsolationCalls[0].Parent
while ($null -ne $configIsolationOwner -and
    $configIsolationOwner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
  $configIsolationOwner = $configIsolationOwner.Parent
}
$libraryText = $libraryAst.Extent.Text
$configIsolationStatement = [string]$configIsolationOwner.Extent.Text
if ($libraryText.IndexOf(
      $configIsolationStatement, [StringComparison]::Ordinal) -ne
    $libraryText.LastIndexOf(
      $configIsolationStatement, [StringComparison]::Ordinal)) {
  throw 'Config validator isolation statement is not textually unique.'
}
$configDeadBranchText = $libraryText.Replace(
  $configIsolationStatement,
  "if (`$false) {`n$configIsolationStatement`n  }")
$configDeadBranchTokens = $null
$configDeadBranchErrors = $null
$configDeadBranchAst = [Management.Automation.Language.Parser]::ParseInput(
  $configDeadBranchText, [ref]$configDeadBranchTokens,
  [ref]$configDeadBranchErrors)
$configDeadBranchDefinitions = @($configDeadBranchAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5Config'
}, $true))
if ($configDeadBranchErrors.Count -ne 0 -or
    $configDeadBranchDefinitions.Count -ne 1 -or
    (Test-Issue13V5ConfigValidatorIsolationAst `
      $configDeadBranchDefinitions[0])) {
  throw 'Config validator accepted a dead path-isolation branch.'
}
$configRootWrites = @(Get-Issue13V5VariableWriteAsts `
  $configDefinitions[0] '$immutableRoots')
$configTypedRootText = $libraryText.Replace(
  [string]$configRootWrites[0].Extent.Text,
  [string]$configRootWrites[0].Extent.Text +
    "`n  [string[]]`$ImMuTaBlErOoTs = @(`$config.repository_root)")
$configTypedRootTokens = $null
$configTypedRootErrors = $null
$configTypedRootAst = [Management.Automation.Language.Parser]::ParseInput(
  $configTypedRootText, [ref]$configTypedRootTokens,
  [ref]$configTypedRootErrors)
$configTypedRootDefinitions = @($configTypedRootAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5Config'
}, $true))
if ($configTypedRootErrors.Count -ne 0 -or
    $configTypedRootDefinitions.Count -ne 1 -or
    (Test-Issue13V5ConfigValidatorIsolationAst `
      $configTypedRootDefinitions[0])) {
  throw 'Config validator accepted a typed case-variant root mutation.'
}
$configDynamicRootText = $libraryText.Replace(
  [string]$configRootWrites[0].Extent.Text,
  [string]$configRootWrites[0].Extent.Text +
    "`n  Microsoft.PowerShell.Utility\Set-Variable " +
      "-Name immutableRoots -Value @(`$config.repository_root)")
$configDynamicRootTokens = $null
$configDynamicRootErrors = $null
$configDynamicRootAst = [Management.Automation.Language.Parser]::ParseInput(
  $configDynamicRootText, [ref]$configDynamicRootTokens,
  [ref]$configDynamicRootErrors)
$configDynamicRootDefinitions = @($configDynamicRootAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5Config'
}, $true))
if ($configDynamicRootErrors.Count -ne 0 -or
    $configDynamicRootDefinitions.Count -ne 1 -or
    (Test-Issue13V5ConfigValidatorIsolationAst `
      $configDynamicRootDefinitions[0])) {
  throw 'Config validator accepted a qualified dynamic root mutation.'
}

$tokens = @()
$errors = @()
$oracleLibraryAst =
  $bootstrapSourceAsts['issue13-v5-oracle-effect-lib.ps1']
function Test-Issue13V5OracleProofConsumerAst(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string]$ProofArgument,
  [string]$ResolvedVariable,
  [string]$BarrierCommand,
  [string]$FirstConsumerCommand,
  [string[]]$FirstConsumerElements,
  [string]$FirstConsumerChain
) {
  $assignments = @(Get-Issue13V5VariableWriteAsts `
    $Ast '$proofProtectedRoots')
  $proofArgumentWrites = @(Get-Issue13V5VariableWriteAsts `
    $Ast $ProofArgument)
  $resolvedWrites = @(Get-Issue13V5VariableWriteAsts `
    $Ast $ResolvedVariable)
  $calls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13OracleEffectProofPathIsolation'
  }, $true))
  $barriers = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        $BarrierCommand
  }, $true))
  $dynamicMutators = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Test-Issue13V5ForbiddenProtectedScopeCommand $node @(
        "(Join-Path `$PSScriptRoot 'issue13-v5-oracle-effect-lib.ps1')"
      ))
  }, $true))
  $memberMutators = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      (Test-Issue13V5AstReferencesVariable `
        $node '$proofProtectedRoots')
  }, $true))
  $resolvedMemberUses = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      (Test-Issue13V5AstReferencesVariable $node $ResolvedVariable)
  }, $true))
  $expectedRoots = '@($RepositoryRoot,' +
    '(Split-Path-Parent([IO.Path]::GetFullPath($ComparisonHarnessManifest))),' +
    '$RLibrary,$Rscript,' +
    '(Split-Path-Parent([IO.Path]::GetFullPath($StrictSmokeSummary))),' +
    '(Split-Path-Parent([IO.Path]::GetFullPath($OracleSmokeSummary))),' +
    '$OraclePatch,$SpecPath,$SchemaPath,$ComparisonRoot,$ReplayRoot)'
  if ($assignments.Count -ne 1 -or
      $proofArgumentWrites.Count -ne 0 -or
      $assignments[0].Left.Extent.Text -cne '$proofProtectedRoots' -or
      (Get-Issue13V5AstAncestorChain $assignments[0] $Ast) -cne
        'AssignmentStatementAst>NamedBlockAst' -or
      [regex]::Replace($assignments[0].Right.Extent.Text, '\s+', '') -cne
        $expectedRoots -or
      $resolvedWrites.Count -ne 1 -or
      $resolvedWrites[0].Left.Extent.Text -cne $ResolvedVariable -or
      $calls.Count -ne 1 -or
      [string]::Join("`n", @($calls[0].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
        ($ProofArgument + "`n`$proofProtectedRoots") -or
      (Get-Issue13V5AstAncestorChain $calls[0] $Ast) -cne
        'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst' -or
      -not [object]::ReferenceEquals(
        $calls[0].Parent.Parent, $resolvedWrites[0]) -or
      $barriers.Count -lt 1 -or
      $calls[0].Extent.StartOffset -ge
        [int](@($barriers | ForEach-Object {
          $_.Extent.StartOffset
        } | Measure-Object -Minimum)[0].Minimum) -or
      $dynamicMutators.Count -ne 0 -or
      (Test-Issue13V5ForbiddenProtectedScopeRedirection $Ast) -or
      (Test-Issue13V5ForbiddenSessionStateMutation $Ast) -or
      $memberMutators.Count -ne 0 -or
      $resolvedMemberUses.Count -ne 0) {
    return $false
  }
  $reads = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.VariableExpressionAst] -and
      (Get-Issue13V5AssignmentBaseVariableName $node) -ieq
        $ResolvedVariable -and
      $node.Extent.StartOffset -ge $resolvedWrites[0].Extent.EndOffset
  }, $true) | Sort-Object { $_.Extent.StartOffset })
  if ($reads.Count -lt 1 -or
      $reads[0].Extent.Text -cne $ResolvedVariable) {
    return $false
  }
  $firstConsumer = $reads[0]
  while ($null -ne $firstConsumer -and
      $firstConsumer -isnot [Management.Automation.Language.CommandAst]) {
    $firstConsumer = $firstConsumer.Parent
  }
  if ($null -eq $firstConsumer -or
      $firstConsumer.GetCommandName() -cne $FirstConsumerCommand -or
      $firstConsumer.InvocationOperator -ne
        [Management.Automation.Language.TokenKind]::Unknown -or
      [string]::Join("`n", @($firstConsumer.CommandElements |
        ForEach-Object { $_.Extent.Text })) -cne
        [string]::Join("`n", $FirstConsumerElements) -or
      (Get-Issue13V5AstAncestorChain $firstConsumer $Ast) -cne
        $FirstConsumerChain) {
    return $false
  }
  $true
}
function Test-Issue13V5OracleWriterIsolationAst(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $definitions = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
        'Write-Issue13OracleEffectJsonOnce'
  }, $true))
  if ($definitions.Count -ne 1) { return $false }
  $definition = $definitions[0]
  $isolationCalls = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13OracleEffectProofPathIsolation'
  }, $true))
  $signatures = @($isolationCalls | ForEach-Object {
    [string]::Join('|', @($_.CommandElements | ForEach-Object {
      $_.Extent.Text
    })) + '|' + (Get-Issue13V5AstAncestorChain $_ $definition)
  })
  $pathAssignments = @(Get-Issue13V5VariableWriteAsts $definition '$Path')
  $fullAssignments = @(Get-Issue13V5VariableWriteAsts $definition '$full')
  $parentAssignments = @(Get-Issue13V5VariableWriteAsts `
    $definition '$parent')
  $temporaryAssignments = @(Get-Issue13V5VariableWriteAsts `
    $definition '$temporary')
  $protectedAssignments = @(Get-Issue13V5VariableWriteAsts `
    $definition '$ProtectedRoots')
  $dynamicMutators = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Test-Issue13V5ForbiddenProtectedScopeCommand $node @(
        'Remove-Item|-LiteralPath|$temporary|-Force'
      ))
  }, $true))
  $protectedMemberMutators = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      (Test-Issue13V5AstReferencesVariable $node '$ProtectedRoots')
  }, $true))
  $fileCalls = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      $node.Static -and
      (Test-Issue13V5TypeExpression $node.Expression 'System.IO.File')
  }, $true))
  if ([string]::Join("`n", $signatures) -cne
      [string]::Join("`n", @(
        ('Assert-Issue13OracleEffectProofPathIsolation|$Path|$ProtectedRoots|' +
          'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>ScriptBlockAst'),
        ('Assert-Issue13OracleEffectProofPathIsolation|$full|$ProtectedRoots|' +
          'CommandAst>PipelineAst>AssignmentStatementAst>StatementBlockAst>' +
          'TryStatementAst>NamedBlockAst>ScriptBlockAst')
      )) -or
      $pathAssignments.Count -ne 0 -or
      $fullAssignments.Count -ne 1 -or
      $fullAssignments[0].Left.Extent.Text -cne '$full' -or
      -not [object]::ReferenceEquals(
        $fullAssignments[0], $isolationCalls[0].Parent.Parent) -or
      -not (Test-Issue13V5SingularDirectAssignment $definition `
        '$parent' `
        'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' `
        'Split-Path -Parent $full') -or
      -not (Test-Issue13V5SingularDirectAssignment $definition `
        '$temporary' `
        'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst') -or
      [regex]::Replace(
        $temporaryAssignments[0].Right.Extent.Text, '[\s`]', '') -cne
        "Join-Path`$parent('.'+[IO.Path]::GetFileName(`$full)+'.'+" +
          "[Guid]::NewGuid().ToString('N')+'.tmp')" -or
      $protectedAssignments.Count -ne 0 -or
      $dynamicMutators.Count -ne 0 -or
      (Test-Issue13V5ForbiddenProtectedScopeRedirection $definition) -or
      (Test-Issue13V5ForbiddenSessionStateMutation $definition) -or
      $protectedMemberMutators.Count -ne 0 -or
      $fileCalls.Count -ne 2 -or
      $fileCalls[0].Member -isnot
        [Management.Automation.Language.StringConstantExpressionAst] -or
      $fileCalls[0].Member.Extent.Text -cne 'WriteAllText' -or
      $fileCalls[0].Arguments.Count -ne 3 -or
      $fileCalls[0].Arguments[0].Extent.Text -cne '$temporary' -or
      $fileCalls[0].Arguments[1].Extent.Text -cne '$json + "`n"' -or
      $fileCalls[0].Arguments[2].Extent.Text -cne '$encoding' -or
      $fileCalls[1].Member -isnot
        [Management.Automation.Language.StringConstantExpressionAst] -or
      $fileCalls[1].Member.Extent.Text -cne 'Move' -or
      $fileCalls[1].Arguments.Count -ne 2 -or
      $fileCalls[1].Arguments[0].Extent.Text -cne '$temporary' -or
      $fileCalls[1].Arguments[1].Extent.Text -cne '$full' -or
      $fullAssignments[0].Extent.EndOffset -ge
        $parentAssignments[0].Extent.StartOffset -or
      $parentAssignments[0].Extent.EndOffset -ge
        $temporaryAssignments[0].Extent.StartOffset -or
      $temporaryAssignments[0].Extent.EndOffset -ge
        $fileCalls[0].Extent.StartOffset -or
      $fileCalls[0].Extent.EndOffset -ge
        $isolationCalls[1].Extent.StartOffset -or
      $isolationCalls[1].Extent.EndOffset -ge
        $fileCalls[1].Extent.StartOffset) {
    return $false
  }
  $true
}
$oraclePathFunctions = @(
  'Test-Issue13OracleEffectPathEqual',
  'Test-Issue13OracleEffectPathContained'
)
foreach ($functionName in $oraclePathFunctions) {
  $definitions = @($oracleLibraryAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq $functionName
  }, $true))
  if ($errors.Count -ne 0 -or $definitions.Count -ne 1 -or
      @($definitions[0].FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
          (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
            'ConvertTo-Issue13OracleEffectPhysicalPath'
      }, $true)).Count -ne 2) {
    throw "Oracle $functionName no longer consumes physical identities."
  }
}
$oracleComparisonDefinitions = @($oracleLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13OracleEffectComparisonIsolation'
}, $true))
if ($oracleComparisonDefinitions.Count -ne 1 -or
    $oracleComparisonDefinitions[0].Extent.Text.Contains('.StartsWith(') -or
    @($oracleComparisonDefinitions[0].FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Assert-Issue13OracleEffectPathsDisjoint'
    }, $true)).Count -ne 2) {
  throw 'Oracle comparison isolation is no longer physically canonical.'
}
$oracleProofIsolationDefinitions = @($oracleLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13OracleEffectProofPathIsolation'
}, $true))
$oracleWriterDefinitions = @($oracleLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Write-Issue13OracleEffectJsonOnce'
}, $true))
if ($oracleProofIsolationDefinitions.Count -ne 1 -or
    $oracleWriterDefinitions.Count -ne 1) {
  throw 'Oracle proof path-isolation definitions are missing or ambiguous.'
}
$oracleProofDisjointCalls = @($oracleProofIsolationDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13OracleEffectPathsDisjoint'
}, $true))
$oracleProofPhysicalCalls = @($oracleProofIsolationDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'ConvertTo-Issue13OracleEffectPhysicalPath'
}, $true))
$oracleWriterIsolationCalls = @($oracleWriterDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13OracleEffectProofPathIsolation'
}, $true))
$oracleWriterIsolationSignatures = @($oracleWriterIsolationCalls |
  ForEach-Object {
    [string]::Join('|', @($_.CommandElements | ForEach-Object {
      $_.Extent.Text
    })) + '|' +
      (Get-Issue13V5AstAncestorChain $_ $oracleWriterDefinitions[0])
  })
if ($oracleProofIsolationDefinitions[0].Extent.Text.Contains('.StartsWith(') -or
    $oracleProofDisjointCalls.Count -ne 1 -or
    (Get-Issue13V5AstAncestorChain $oracleProofDisjointCalls[0] `
      $oracleProofIsolationDefinitions[0]) -cne
      'CommandAst>PipelineAst>StatementBlockAst>ForEachStatementAst>NamedBlockAst>ScriptBlockAst' -or
    $oracleProofPhysicalCalls.Count -ne 2 -or
    [string]::Join("`n", $oracleWriterIsolationSignatures) -cne
      [string]::Join("`n", @(
        ('Assert-Issue13OracleEffectProofPathIsolation|$Path|$ProtectedRoots|' +
          'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>ScriptBlockAst'),
        ('Assert-Issue13OracleEffectProofPathIsolation|$full|$ProtectedRoots|' +
          'CommandAst>PipelineAst>AssignmentStatementAst>StatementBlockAst>' +
          'TryStatementAst>NamedBlockAst>ScriptBlockAst')
      )) -or
    -not (Test-Issue13V5OracleWriterIsolationAst $oracleLibraryAst)) {
  throw 'Oracle proof writer path isolation is no longer physically canonical.'
}
$oracleWriterText = $oracleLibraryAst.Extent.Text
$oracleSecondIsolationOwner = $oracleWriterIsolationCalls[1].Parent
while ($null -ne $oracleSecondIsolationOwner -and
    $oracleSecondIsolationOwner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
  $oracleSecondIsolationOwner = $oracleSecondIsolationOwner.Parent
}
$oracleWriterFullMutationText = $oracleWriterText.Replace(
  [string]$oracleSecondIsolationOwner.Extent.Text,
  [string]$oracleSecondIsolationOwner.Extent.Text +
    "`n    `$full = Join-Path `$ProtectedRoots[0] 'proof.json'")
$oracleWriterFullMutationTokens = $null
$oracleWriterFullMutationErrors = $null
$oracleWriterFullMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterFullMutationText, [ref]$oracleWriterFullMutationTokens,
    [ref]$oracleWriterFullMutationErrors)
if ($oracleWriterFullMutationErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst $oracleWriterFullMutationAst)) {
  throw 'Oracle proof writer accepted a post-check destination mutation.'
}
$oracleWriterProtectedMutationText = $oracleWriterText.Replace(
  [string]$oracleSecondIsolationOwner.Extent.Text,
  [string]$oracleSecondIsolationOwner.Extent.Text +
    "`n    Set-Variable -Name ProtectedRoots -Value @(`$full)")
$oracleWriterProtectedMutationTokens = $null
$oracleWriterProtectedMutationErrors = $null
$oracleWriterProtectedMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterProtectedMutationText,
    [ref]$oracleWriterProtectedMutationTokens,
    [ref]$oracleWriterProtectedMutationErrors)
if ($oracleWriterProtectedMutationErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst `
      $oracleWriterProtectedMutationAst)) {
  throw 'Oracle proof writer accepted a protected-root mutation.'
}
$oracleWriterTemporaryMutationText = $oracleWriterText.Replace(
  [string]$oracleSecondIsolationOwner.Extent.Text,
  [string]$oracleSecondIsolationOwner.Extent.Text +
    "`n    `$TeMpOrArY = 'C:\issue13-sensitive.tmp'")
$oracleWriterTemporaryMutationTokens = $null
$oracleWriterTemporaryMutationErrors = $null
$oracleWriterTemporaryMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterTemporaryMutationText,
    [ref]$oracleWriterTemporaryMutationTokens,
    [ref]$oracleWriterTemporaryMutationErrors)
if ($oracleWriterTemporaryMutationErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst `
      $oracleWriterTemporaryMutationAst)) {
  throw 'Oracle proof writer accepted a post-check temporary mutation.'
}
$oracleWriterTemporaryAssignments = @(Get-Issue13V5VariableWriteAsts `
  $oracleWriterDefinitions[0] '$temporary')
$oracleWriterParentMutationText = $oracleWriterText.Replace(
  [string]$oracleWriterTemporaryAssignments[0].Extent.Text,
  "  `$PaReNt = `$ProtectedRoots[0]`n" +
    [string]$oracleWriterTemporaryAssignments[0].Extent.Text)
$oracleWriterParentMutationTokens = $null
$oracleWriterParentMutationErrors = $null
$oracleWriterParentMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterParentMutationText, [ref]$oracleWriterParentMutationTokens,
    [ref]$oracleWriterParentMutationErrors)
if ($oracleWriterParentMutationErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst $oracleWriterParentMutationAst)) {
  throw 'Oracle proof writer accepted a protected parent mutation.'
}
$oracleWriterPathMutationText = $oracleWriterText.Replace(
  [string]$oracleWriterIsolationCalls[0].Parent.Parent.Extent.Text,
  "  `$PaTh = `$ProtectedRoots[0]`n" +
    [string]$oracleWriterIsolationCalls[0].Parent.Parent.Extent.Text)
$oracleWriterPathMutationTokens = $null
$oracleWriterPathMutationErrors = $null
$oracleWriterPathMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterPathMutationText, [ref]$oracleWriterPathMutationTokens,
    [ref]$oracleWriterPathMutationErrors)
if ($oracleWriterPathMutationErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst $oracleWriterPathMutationAst)) {
  throw 'Oracle proof writer accepted an input-path mutation.'
}
$oracleWriterWriteArgumentText = $oracleWriterText.Replace(
  '[IO.File]::WriteAllText($temporary,',
  '[IO.File]::WriteAllText($Path,')
$oracleWriterWriteArgumentTokens = $null
$oracleWriterWriteArgumentErrors = $null
$oracleWriterWriteArgumentAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterWriteArgumentText, [ref]$oracleWriterWriteArgumentTokens,
    [ref]$oracleWriterWriteArgumentErrors)
if ($oracleWriterWriteArgumentErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst $oracleWriterWriteArgumentAst)) {
  throw 'Oracle proof writer accepted an unsealed staging destination.'
}
$oracleWriterDynamicMoveText = $oracleWriterText.Replace(
  '[IO.File]::Move($temporary, $full)',
  "[IO.File]::('M' + 'ove')(`$temporary, `$full)")
$oracleWriterDynamicMoveTokens = $null
$oracleWriterDynamicMoveErrors = $null
$oracleWriterDynamicMoveAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterDynamicMoveText, [ref]$oracleWriterDynamicMoveTokens,
    [ref]$oracleWriterDynamicMoveErrors)
if ($oracleWriterDynamicMoveErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst $oracleWriterDynamicMoveAst)) {
  throw 'Oracle proof writer accepted a dynamic File.Move member.'
}
$oracleConsumerAsts = @{}
foreach ($consumer in @(
    [pscustomobject]@{
      name = 'issue13-v5-oracle-effect-generate.ps1'
      proof = '$OutputPath'
      resolved = '$proofFull'
      barrier = 'Get-Issue13OracleEffectInputContext'
      first_command = 'Test-Path'
      first_elements = @('Test-Path', '-LiteralPath', '$proofFull')
      first_chain = 'CommandAst>PipelineAst>ParenExpressionAst>' +
        'UnaryExpressionAst>CommandExpressionAst>PipelineAst>' +
        'ParenExpressionAst>CommandAst>PipelineAst>NamedBlockAst'
    },
    [pscustomobject]@{
      name = 'issue13-v5-oracle-effect-validate.ps1'
      proof = '$ProofPath'
      resolved = '$resolvedProof'
      barrier = 'Get-Issue13OracleEffectEvidence'
      first_command = 'Get-Content'
      first_elements = @(
        'Get-Content', '-Raw', '-LiteralPath', '$resolvedProof'
      )
      first_chain =
        'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst'
    }
  )) {
  $consumerTokens = @()
  $consumerErrors = @()
  $consumerAst = $bootstrapSourceAsts[$consumer.name]
  if ($consumerErrors.Count -ne 0 -or
      -not (Test-Issue13V5OracleProofConsumerAst `
        $consumerAst $consumer.proof $consumer.resolved $consumer.barrier `
        $consumer.first_command $consumer.first_elements `
        $consumer.first_chain)) {
    throw "Oracle proof consumer isolation changed: $($consumer.name)"
  }
  $oracleConsumerAsts[$consumer.name] = [pscustomobject]@{
    ast = $consumerAst
    proof = $consumer.proof
    resolved = $consumer.resolved
    barrier = $consumer.barrier
    first_command = $consumer.first_command
    first_elements = $consumer.first_elements
    first_chain = $consumer.first_chain
  }
}
foreach ($consumerName in @($oracleConsumerAsts.Keys | Sort-Object)) {
  $record = $oracleConsumerAsts[$consumerName]
  $consumerAst = $record.ast
  $consumerText = $consumerAst.Extent.Text
  $isolationCalls = @($consumerAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13OracleEffectProofPathIsolation'
  }, $true))
  $owner = $isolationCalls[0].Parent
  while ($null -ne $owner -and $owner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
    $owner = $owner.Parent
  }
  $statement = [string]$owner.Extent.Text
  $conditionalText = $consumerText.Replace(
    $statement, [string]$owner.Left.Extent.Text + ' = if ($false) {' +
      "`n" + [string]$owner.Right.Extent.Text + "`n} else { `$null }")
  $conditionalTokens = $null
  $conditionalErrors = $null
  $conditionalAst = [Management.Automation.Language.Parser]::ParseInput(
    $conditionalText, [ref]$conditionalTokens, [ref]$conditionalErrors)
  if ($conditionalErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $conditionalAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted conditional isolation: $consumerName"
  }
  $proofArgumentName = $record.proof.TrimStart('$')
  $proofArgumentMutationText = $consumerText.Replace(
    $statement, "[string]`$" + $proofArgumentName.ToUpperInvariant() +
      " = `$RepositoryRoot`n" + $statement)
  $proofArgumentMutationTokens = $null
  $proofArgumentMutationErrors = $null
  $proofArgumentMutationAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $proofArgumentMutationText, [ref]$proofArgumentMutationTokens,
      [ref]$proofArgumentMutationErrors)
  if ($proofArgumentMutationErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $proofArgumentMutationAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted input-path mutation: $consumerName"
  }
  $resolvedName = $record.resolved.TrimStart('$')
  $resolvedMutationText = $consumerText.Replace(
    $statement, $statement + "`n[string]`$" +
      $resolvedName.ToUpperInvariant() + ' = $RepositoryRoot')
  $resolvedMutationTokens = $null
  $resolvedMutationErrors = $null
  $resolvedMutationAst = [Management.Automation.Language.Parser]::ParseInput(
    $resolvedMutationText, [ref]$resolvedMutationTokens,
    [ref]$resolvedMutationErrors)
  if ($resolvedMutationErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $resolvedMutationAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted resolved-path mutation: $consumerName"
  }
  $resolvedReads = @($consumerAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.VariableExpressionAst] -and
      (Get-Issue13V5AssignmentBaseVariableName $node) -ieq
        $record.resolved -and
      $node.Extent.StartOffset -ge $owner.Extent.EndOffset
  }, $true) | Sort-Object { $_.Extent.StartOffset })
  if ($resolvedReads.Count -lt 1 -or
      $resolvedReads[0].Extent.Text -cne $record.resolved) {
    throw "Oracle proof consumer first read is missing: $consumerName"
  }
  $firstRead = $resolvedReads[0]
  $originalArgumentText = $consumerText.Substring(
      0, $firstRead.Extent.StartOffset) + $record.proof +
    $consumerText.Substring($firstRead.Extent.EndOffset)
  $originalArgumentTokens = $null
  $originalArgumentErrors = $null
  $originalArgumentAst = [Management.Automation.Language.Parser]::ParseInput(
    $originalArgumentText, [ref]$originalArgumentTokens,
    [ref]$originalArgumentErrors)
  if ($originalArgumentErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $originalArgumentAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted an unisolated first read: $consumerName"
  }
  $dummyReadText = $consumerText.Substring(0, $firstRead.Extent.StartOffset) +
    ('$null = ' + $record.resolved + "`n") +
    $consumerText.Substring($firstRead.Extent.StartOffset)
  $dummyReadTokens = $null
  $dummyReadErrors = $null
  $dummyReadAst = [Management.Automation.Language.Parser]::ParseInput(
    $dummyReadText, [ref]$dummyReadTokens, [ref]$dummyReadErrors)
  if ($dummyReadErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $dummyReadAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted a dummy first read: $consumerName"
  }
  $assignments = @(Get-Issue13V5VariableWriteAsts `
    $consumerAst '$proofProtectedRoots')
  $subassignmentText = $consumerText.Replace(
    [string]$assignments[0].Extent.Text,
    [string]$assignments[0].Extent.Text +
      "`n`$proofProtectedRoots[0] = `$null")
  $subassignmentTokens = $null
  $subassignmentErrors = $null
  $subassignmentAst = [Management.Automation.Language.Parser]::ParseInput(
    $subassignmentText, [ref]$subassignmentTokens,
    [ref]$subassignmentErrors)
  if ($subassignmentErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $subassignmentAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted root subassignment: $consumerName"
  }
  $dynamicText = $consumerText.Replace(
    [string]$assignments[0].Extent.Text,
    [string]$assignments[0].Extent.Text +
      "`nSet-Variable -Name proofProtectedRoots -Value @(`$RLibrary)")
  $dynamicTokens = $null
  $dynamicErrors = $null
  $dynamicAst = [Management.Automation.Language.Parser]::ParseInput(
    $dynamicText, [ref]$dynamicTokens, [ref]$dynamicErrors)
  if ($dynamicErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $dynamicAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted dynamic root mutation: $consumerName"
  }
}

$legacyPathCases = @(
  [pscustomobject]@{ path = 'D:\root\v4\child'; expected = $true },
  [pscustomobject]@{ path = 'D:\root\V4R12-candidate'; expected = $true },
  [pscustomobject]@{ path = '/tmp/final-v4r2/run'; expected = $true },
  [pscustomobject]@{ path = 'D:\root\v5c4'; expected = $false },
  [pscustomobject]@{
    path = 'docs/validation/issue-13.md'
    expected = $false
  }
)
foreach ($case in $legacyPathCases) {
  if (-not (Test-Issue13V5ExactBoolean `
      (Test-Issue13V5LegacyPath ([string]$case.path)) $case.expected)) {
    throw "Legacy path matcher failed its static case: $($case.path)"
  }
}

$pathProjectionConfig = [pscustomobject]@{
  reuse_policy = [pscustomobject]@{ v4_evidence_allowed = $false }
  repository_root = 'D:\root\v4\repo'
  harness_runtime_root = 'D:\root\v5-runtime'
  harness_root = 'D:\root\v5-runtime\harness'
  harness_manifest_path = 'D:\root\v5-runtime\manifest.json'
  worktree_root = 'D:\root\v5-worktrees'
  evidence_root = 'D:\root\v5-evidence'
  control_root = 'D:\root\v5-control'
  source_origin = 'D:\root\sources'
  candidate_source_origin = 'D:\root\candidate-sources'
  rscript = 'D:\R\Rscript.exe'
  r_library = 'D:\R\library'
  baseline_runtime_index = 'D:\root\v5-index.json'
  baseline_overlay = [pscustomobject]@{ path = 'D:\root\v5.patch' }
  strict_baseline_smoke = [pscustomobject]@{
    path = 'D:\root\v5-strict.json'
  }
  compatibility_baseline_smoke = [pscustomobject]@{
    path = 'D:\root\v5-compat.json'
  }
  oracle_effect = [pscustomobject]@{
    oracle_smoke = [pscustomobject]@{ path = 'D:\root\v5-oracle-smoke.json' }
    proof = [pscustomobject]@{ path = 'D:\root\v5-oracle-proof.json' }
    comparisons = [pscustomobject]@{
      primary = [pscustomobject]@{
        root = 'D:\root\v5-oracle-primary'
      }
      replay = [pscustomobject]@{
        root = 'D:\root\v5-oracle-replay'
      }
    }
    comparison_harness = [pscustomobject]@{
      manifest_path = 'D:\root\v5-runtime\manifest.json'
    }
    tooling = @($oracleEffectFiles | ForEach-Object {
      [pscustomobject]@{ path = Join-Path $root $_ }
    })
  }
  comparison = [pscustomobject]@{
    preparation_equivalence_profile = [pscustomobject]@{
      path = 'D:\root\v5-runtime\issue13-evidence-harness\issue13-v5-preparation-equivalence.json'
    }
  }
  report = [pscustomobject]@{
    required_path = 'docs/validation/issue-13.md'
  }
  methods = @([pscustomobject]@{
    baseline = 'D:\root\v5-baseline'
    candidate = 'D:\root\V4R12-candidate'
  })
  supplemental_roots = [pscustomobject]@{
    candidate_fault = '/tmp/final-v4r2/run'
    baseline_paper0 = '/tmp/v5-paper0'
  }
}
$projectedPaths = @(Get-Issue13V5ConfiguredPaths $pathProjectionConfig)
$projectedLegacyPaths = @($projectedPaths | Where-Object {
  Test-Issue13V5LegacyPath $_
})
$expectedProjectedPathCount = 12L + 10L +
  [long]$oracleEffectFiles.Count +
  (2L * [long]@($pathProjectionConfig.methods).Count) +
  [long]@($pathProjectionConfig.supplemental_roots.PSObject.Properties).Count
if ($expectedProjectedPathCount -ne 32L -or
    $projectedPaths.Count -ne $expectedProjectedPathCount -or
    @($projectedPaths | Where-Object {
      [string]::IsNullOrWhiteSpace([string]$_)
    }).Count -ne 0 -or
    $projectedLegacyPaths.Count -ne 3) {
  throw 'Configured path projection failed its static cases.'
}

$wiodr13Contract = Get-Issue13V5SourceContractSha256 @(
  (Join-Path $RepositoryRoot 'contracts\units\wiodr13_v2-units.csv'),
  (Join-Path $RepositoryRoot 'contracts\units\wiodr13_v2-aggregations.csv')
)
$wiodr16Contract = Get-Issue13V5SourceContractSha256 @(
  (Join-Path $RepositoryRoot 'contracts\units\wiodr16_v2-units.csv'),
  (Join-Path $RepositoryRoot 'contracts\units\wiodr16_v2-aggregations.csv')
)
if ($wiodr13Contract -cne
      '1f2462835e70d5681d7a5b9b29be5f0598cdb35a9abd72d3d147a6636ae5c905' -or
    $wiodr16Contract -cne
      '3b23ab671df4905dee50b35efd8dff8d4897f65f2b74a2677d7614d9137e801a') {
  throw 'Candidate source contracts differ from the arm-specific bindings.'
}

$tamperRoot = Join-Path ([IO.Path]::GetTempPath()) (
  'wlv-issue13-v5-state-anchor-' + [Guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($tamperRoot)
try {
  $tamperUtf8 = [Text.UTF8Encoding]::new($false, $true)
  $tamperResult = Join-Path $tamperRoot 'scenario-result.json'
  $tamperMetrics = Join-Path $tamperRoot 'process-metrics.json'
  $tamperSamples = Join-Path $tamperRoot 'process-samples.csv'
  $tamperStdout = Join-Path $tamperRoot 'stdout.log'
  $tamperStderr = Join-Path $tamperRoot 'stderr.log'
  $tamperSpec = Join-Path $tamperRoot 'process-spec.json'
  [IO.File]::WriteAllText($tamperResult, "{}`n", $tamperUtf8)
  [IO.File]::WriteAllText($tamperSamples,
    "sample_at_utc,pid,parent_pid,name,created_at_utc,working_set_bytes,private_bytes,cpu_seconds`n2026-01-01T00:00:00Z,1,,R,2026-01-01T00:00:00Z,1,1,0`n",
    $tamperUtf8)
  [IO.File]::WriteAllText($tamperStdout, '', $tamperUtf8)
  [IO.File]::WriteAllText($tamperStderr, '', $tamperUtf8)
  [IO.File]::WriteAllText($tamperSpec, "{}`n", $tamperUtf8)
  $tamperMetricsDocument = [ordered]@{
    samples_path = Join-Path $tamperRoot `
      'stale-attempt\process-samples.csv'
    samples_sha256 = Get-Issue13V5Sha256 $tamperSamples
    stdout_path = $tamperStdout
    stdout_sha256 = Get-Issue13V5Sha256 $tamperStdout
    stderr_path = $tamperStderr
    stderr_sha256 = Get-Issue13V5Sha256 $tamperStderr
    process_spec_path = $tamperSpec
    process_spec_sha256 = Get-Issue13V5Sha256 $tamperSpec
  }
  [IO.File]::WriteAllText($tamperMetrics,
    (($tamperMetricsDocument | ConvertTo-Json -Depth 10) + "`n"),
    $tamperUtf8)
  $stateResultSha = Get-Issue13V5Sha256 $tamperResult
  $stateMetricsSha = Get-Issue13V5Sha256 $tamperMetrics
  $null = Assert-Issue13V5ScenarioStateHashes $tamperRoot `
    $stateResultSha $stateMetricsSha 'static-authentic'
  [IO.File]::AppendAllText($tamperSamples,
    "2026-01-01T00:00:01Z,1,,R,2026-01-01T00:00:00Z,2,2,1`n",
    $tamperUtf8)
  $tamperMetricsDocument.samples_sha256 =
    Get-Issue13V5Sha256 $tamperSamples
  [IO.File]::WriteAllText($tamperMetrics,
    (($tamperMetricsDocument | ConvertTo-Json -Depth 10) + "`n"),
    $tamperUtf8)
  $coherentTamperRejected = $false
  try {
    $null = Assert-Issue13V5ScenarioStateHashes $tamperRoot `
      $stateResultSha $stateMetricsSha 'static-coherent-tamper'
  } catch {
    $coherentTamperRejected = $_.Exception.Message.Contains(
      'Scenario state hash changed')
  }
  if (-not $coherentTamperRejected) {
    throw 'State anchor accepted coherent samples+metrics tampering.'
  }
} finally {
  if ([IO.Directory]::Exists($tamperRoot)) {
    [IO.Directory]::Delete($tamperRoot, $true)
  }
}

$coordinatorText = [string]
  $bootstrapSourceTexts['issue13-v5-coordinator.ps1']
foreach ($required in @(
    'Get-Issue13V5SourceBinding', '-Arm ([string]$record.arm)',
    "'cross_engine_source_v1'"
  )) {
  if (-not $coordinatorText.Contains($required)) {
    throw "Coordinator lacks arm-specific source routing: $required"
  }
}

$compareText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-compare-override.R'),
  [Text.UTF8Encoding]::new($false, $true))
foreach ($required in @(
    'run_root <- dirname(path)',
    'identical(run_root, context_run_root)',
    'identical(expected_commit, observed_commit)',
    'context$input_binding_sha256',
    'input_binding_valid',
    'identical(wlv13_git_commit(project_root), expected_commit)',
    'isTRUE(wlv13_git_runtime_clean(project_root))'
  )) {
  if (-not $compareText.Contains($required)) {
    throw "V5 compare override lacks structural runtime binding: $required"
  }
}

$recordNames = @($records.ToArray() | ForEach-Object { [string]$_.name })
if (@($recordNames | Sort-Object -Unique).Count -ne $recordNames.Count) {
  throw 'Static controller records contain a duplicate source.'
}
foreach ($name in $expectedControllerFiles) {
  if ($name -cin $recordNames) { continue }
  $path = Join-Path $root $name
  if (-not $bootstrapSourceFileSha256.ContainsKey($name) -and
      -not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "V5 controller source is missing: $name"
  }
  $commandCount = 0L
  if ([IO.Path]::GetExtension($name) -ceq '.ps1') {
    $tokens = @()
    $errors = @()
    $controllerAst = $bootstrapSourceAsts[$name]
    if ($errors.Count -ne 0) {
      throw "PowerShell parser rejected controller $name`: $($errors[0].Message)"
    }
    $commandCount = [long]@($controllerAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst]
    }, $true)).Count
  }
  $records.Add([ordered]@{
    name = $name
    sha256 = if ($bootstrapSourceFileSha256.ContainsKey($name)) {
      [string]$bootstrapSourceFileSha256[$name]
    } else {
      Get-Issue13V5Sha256 $path
    }
    command_ast_count = $commandCount
  })
}
$controllerRecords = @($expectedControllerFiles | ForEach-Object {
  $name = $_
  $match = @($records.ToArray() | Where-Object {
    [string]$_.name -ceq $name
  })
  if ($match.Count -ne 1) {
    throw "Static controller record is missing or ambiguous: $name"
  }
  $match[0]
})
if ($controllerRecords.Count -ne 34 -or
    [string]::Join("`n", @($controllerRecords.name)) -cne
      [string]::Join("`n", $expectedControllerFiles)) {
  throw 'Static controller records do not cover the exact 34-file inventory.'
}

$runtime = (Resolve-Path -LiteralPath $HarnessRuntimeRoot).Path
$manifestPath = Join-Path $runtime 'v5-harness-manifest.json'
$repository = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$staticConfig = [pscustomobject]@{
  repository_root = $repository
  candidate_commit = $CandidateCommit
  harness_runtime_root = $runtime
  harness_root = (Join-Path $runtime 'issue13-evidence-harness')
  harness_manifest_path = $manifestPath
  harness_manifest_sha256 = Get-Issue13V5Sha256 $manifestPath
}
$harnessBinding = Assert-Issue13V5HarnessBinding $staticConfig
$manifest = $harnessBinding.manifest
$inventory = $harnessBinding.inventory
$expectedHarnessFileCount = 39L
$expectedHarnessTotalBytes = 594386L
$expectedHarnessInventorySha256 =
  '9f50c978ffc5f1f2d69d70ca8e5a7205eca39ec8441843cd5fa43b959eaf03c1'
if ($inventory.file_count -ne $expectedHarnessFileCount -or
    $inventory.total_bytes -ne $expectedHarnessTotalBytes -or
    $inventory.inventory_sha256 -cne $expectedHarnessInventorySha256 -or
    [long]$manifest.output_tooling.file_count -ne $expectedHarnessFileCount -or
    [long]$manifest.output_tooling.total_bytes -ne
      $expectedHarnessTotalBytes -or
    [string]$manifest.output_tooling.inventory_sha256 -cne
      $expectedHarnessInventorySha256 -or
    [long]$manifest.sealed_output_tooling.file_count -ne
      $expectedHarnessFileCount -or
    [long]$manifest.sealed_output_tooling.total_bytes -ne
      $expectedHarnessTotalBytes -or
    [string]$manifest.sealed_output_tooling.inventory_sha256 -cne
      $expectedHarnessInventorySha256) {
  throw 'Materialized V5 harness failed its static authentication.'
}

$materializedCompare = [IO.File]::ReadAllText(
  (Join-Path $runtime 'issue13-evidence-harness\issue13-compare-lib.R'),
  [Text.UTF8Encoding]::new($false, $true))
$materializedPreparationCompare = [IO.File]::ReadAllText(
  (Join-Path $runtime 'issue13-preparation-compare.R'),
  [Text.UTF8Encoding]::new($false, $true))
$materializedPreparationLibrary = [IO.File]::ReadAllText(
  (Join-Path $runtime 'issue13-prep-paper-lib.R'),
  [Text.UTF8Encoding]::new($false, $true))
$materializedPreparationEquivalence = [IO.File]::ReadAllText(
  (Join-Path $runtime `
    'issue13-evidence-harness\issue13-v5-preparation-equivalence.R'),
  [Text.UTF8Encoding]::new($false, $true))
$materializedSelftest = [IO.File]::ReadAllText(
  (Join-Path $runtime 'issue13-evidence-harness\issue13-selftest.R'),
  [Text.UTF8Encoding]::new($false, $true))
$materializedDiagnosticBridgesPath = Join-Path $runtime `
  'issue13-evidence-harness\issue13-v5-diagnostic-module-bridges.csv'
$materializedStage5ProfilesPath = Join-Path $runtime `
  'issue13-evidence-harness\issue13-v5-stage5-multiplicity-profiles.csv'
if ((Get-Issue13V5Sha256 $materializedDiagnosticBridgesPath) -cne
      (Get-Issue13V5Sha256 $diagnosticBridgePath) -or
    (Get-Issue13V5Sha256 $materializedStage5ProfilesPath) -cne
      (Get-Issue13V5Sha256 $stage5ProfilePath) -or
    @(Import-Csv -LiteralPath $materializedDiagnosticBridgesPath `
      -Delimiter ';').Count -le 0 -or
    @(Import-Csv -LiteralPath $materializedStage5ProfilesPath `
      -Delimiter ';').Count -le 0) {
  throw 'Materialized diagnostic bridge/profile manifests are not sealed.'
}
foreach ($required in @(
    'cross_engine_source_v1',
    'cross_engine_source && (!identical(candidate$kind, "source")',
    'normalized = "file:_unit_contract.csv"'
  )) {
  if (-not $materializedCompare.Contains($required)) {
    throw "Materialized comparison runtime lacks source projection: $required"
  }
}
foreach ($required in @(
    'manifest_tables_equivalence_profile_exact',
    'source_equivalence <- wlv13_v5p_compare_source(',
    'source_unit_contract_bridge <- wlv13_v5d_compare_source_unit_contract(',
    'source_equivalence$unit_contract$cross_engine_bridge <-',
    'isTRUE(source_unit_contract_bridge$passed)',
    'csv[["_unit_contract.csv"]] <- source_equivalence$unit_contract',
    'csv[["_source_manifest.csv"]] <- source_equivalence$source_manifest',
    'wlv-issue13-preparation-rule-matrix/2'
  )) {
  if (-not $materializedPreparationCompare.Contains($required)) {
    throw "Materialized preparation runtime lacks exhaustive bridge: $required"
  }
}
foreach ($required in @(
    'sealed-exhaustive-source-manifest-equivalence',
    'sealed-exhaustive-unit-contract-equivalence',
    'wlv13_v5p_exact_table', 'file_sha256', 'table_sha256',
    'expected_file_sha256', 'expected_table_sha256',
    'wlv13_v5p_selftest <- function'
  )) {
  if (-not $materializedPreparationEquivalence.Contains($required)) {
    throw "Materialized preparation profile lacks exact binding: $required"
  }
}
foreach ($required in @(
    'sidecar_architecture_valid <- isTRUE(left_contract$legacy)',
    'identical(right_contract$schema_version, "1")',
    'identical(right_contract$fst_sha256, right_sha)',
    'baseline_sidecar_format = "legacy-positional"',
    'candidate_sidecar_format = "versioned-v1"'
  )) {
  if (-not $materializedPreparationLibrary.Contains($required)) {
    throw "Materialized preparation library lacks sidecar gate: $required"
  }
}
foreach ($required in @(
    'issue13-aggregate-core-selftest.R',
    'issue13-v5-compatibility-baseline-override.R',
    'output-v5-policy-reject',
    'V5 aggregate accepted a synthetic unbound baseline profile.',
    'identical(metadata_assertions, 626L)',
    'identical(diagnostic_assertions, 226L)',
    'identical(preparation_assertions, 173L)'
  )) {
  if (-not $materializedSelftest.Contains($required)) {
    throw "Materialized self-test lacks V5 aggregate separation: $required"
  }
}
$ruleMatrixPath = Join-Path $runtime 'issue13-preparation-rule-matrix.json'
$ruleMatrix = [IO.File]::ReadAllText(
  $ruleMatrixPath, [Text.UTF8Encoding]::new($false, $true)) |
  ConvertFrom-Json -DateKind String
$preparationMode = $ruleMatrix.comparison_modes.preparation_cross_engine
$faultMode = $ruleMatrix.comparison_modes.fault_within_engine
$manifestRule = @($preparationMode.rules | Where-Object {
  [string]$_.id -ceq 'source-manifests'
})
$contractRule = @($preparationMode.rules | Where-Object {
  [string]$_.id -ceq 'contracts-and-labels'
})
$arrayRule = @($preparationMode.rules | Where-Object {
  [string]$_.id -ceq 'normalized-arrays'
})
if ([string]$ruleMatrix.schema -cne
      'wlv-issue13-preparation-rule-matrix/2' -or
    [string]$preparationMode.candidate -cne
      'candidate-runtime-pinned-by-v5-config' -or
    [string]$faultMode.candidate -cne
      'candidate-runtime-pinned-by-v5-config' -or
    @($preparationMode.ignored_artifacts).Count -ne 0 -or
    [string]$preparationMode.numeric_tolerance -cne 'none-bitwise' -or
    $manifestRule.Count -ne 1 -or $contractRule.Count -ne 1 -or
    $arrayRule.Count -ne 1 -or
    -not ([string]$manifestRule[0].comparison).Contains(
      'complete controller-pinned source manifest table') -or
    -not ([string]$contractRule[0].comparison).Contains(
      'complete controller-pinned _unit_contract.csv table') -or
    -not ([string]$arrayRule[0].comparison).Contains(
      'candidate versioned-v1 sidecars')) {
  throw 'Materialized preparation rule matrix is not the sealed V5 equivalence contract.'
}

foreach ($bootstrapName in @(
    $bootstrapSourceFileSha256.Keys | Sort-Object)) {
  $bootstrapPath = Join-Path $root $bootstrapName
  $bootstrapFinalBytes = [IO.File]::ReadAllBytes($bootstrapPath)
  $bootstrapFinalHash = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($bootstrapFinalBytes))
  if ($bootstrapFinalHash -cne
      [string]$bootstrapSourceFileSha256[$bootstrapName]) {
    throw "Controller source changed during static verification: $bootstrapName"
  }
}

[pscustomobject][ordered]@{
  status = 'passed'
  r_started = $false
  generation = 'v5'
  baseline_commit = $script:Issue13V5BaselineCommit
  baseline_runtime_commit = $script:Issue13V5BaselineRuntimeCommit
  baseline_policy = [string]$manifest.baseline_policy
  controller_files = [object[]]$controllerRecords
  harness_file_count = [long]$inventory.file_count
  harness_inventory_sha256 = [string]$inventory.inventory_sha256
  expected_worktrees = 29
  expected_pairs = 76
  expected_scenarios = 162
  expected_comparisons = 202
  expected_faults = 10
}
