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
. (Join-Path $root 'issue13-v5-coordinator-lib.ps1')

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
  if (-not (Test-Path -LiteralPath (Join-Path $root $name) -PathType Leaf)) {
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
  $tokens = $null
  $errors = $null
  $ast = [Management.Automation.Language.Parser]::ParseFile(
    $path, [ref]$tokens, [ref]$errors)
  if ($errors.Count -ne 0) {
    throw "PowerShell parser rejected $name`: $($errors[0].Message)"
  }
  $commands = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst]
  }, $true))
  $dangerous = @($commands | Where-Object {
    [string]$_.GetCommandName() -cin @(
      'Invoke-Expression', 'iex', 'Remove-Item', 'Stop-Process',
      'Start-Job', 'Start-ThreadJob'
    )
  })
  if ($dangerous.Count -ne 0) {
    throw "Forbidden coordinator command appears in $name."
  }
  $text = [IO.File]::ReadAllText($path,
    [Text.UTF8Encoding]::new($false, $true))
  $legacyMatches = @($legacyPathNeedles | Where-Object {
    $text.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0
  })
  if ($legacyMatches.Count -ne 0) {
    throw "Coordinator depends on a legacy V4 path: $name"
  }
  $records.Add([ordered]@{
    name = $name
    sha256 = Get-Issue13V5Sha256 $path
    command_ast_count = [long]$commands.Count
  })
}

foreach ($name in $oracleEffectFiles) {
  $path = Join-Path $root $name
  if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
      $name -cnotin $script:Issue13V5ControllerFiles -or
      (Get-Issue13V5Sha256 $path) -cnotmatch '^[0-9a-f]{64}$') {
    throw "Oracle-effect controller source is missing or unpinned: $name"
  }
  $oracleCommandCount = 0L
  if ([IO.Path]::GetExtension($name) -ceq '.ps1') {
    $tokens = $null
    $errors = $null
    $oracleAst = [Management.Automation.Language.Parser]::ParseFile(
      $path, [ref]$tokens, [ref]$errors)
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
    sha256 = Get-Issue13V5Sha256 $path
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
  if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
      (Get-Issue13V5Sha256 $path) -cnotmatch '^[0-9a-f]{64}$') {
    throw "Diagnostic evidence controller is missing or unpinned: $name"
  }
  $textValue = [IO.File]::ReadAllText(
    $path, [Text.UTF8Encoding]::new($false, $true))
  if ($textValue.Contains([char]0xfffd)) {
    throw "Diagnostic evidence controller is not strict UTF-8: $name"
  }
  $diagnosticControllerText[$name] = $textValue
  $commandCount = 0L
  if ([IO.Path]::GetExtension($name) -ceq '.ps1') {
    $tokens = $null
    $errors = $null
    $diagnosticAst = [Management.Automation.Language.Parser]::ParseFile(
      $path, [ref]$tokens, [ref]$errors)
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
    sha256 = Get-Issue13V5Sha256 $path
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
    'schema=issue13-v5-clean-bridge-capture/1',
    'tool_records=$($toolRecordsBefore.Count)',
    'harness_inventory_sha256=$harnessInventoryBefore',
    'harness_runtime_inventory_before_sha256=$harnessRuntimeInventoryBefore',
    'harness_runtime_inventory_after_sha256=$harnessRuntimeInventoryAfter',
    'rscript_sha256=$rscriptSha256',
    'r_library_path=$($script:rLibrary.Replace',
    'r_library_inventory_before_sha256=$rLibraryInventoryBefore',
    'r_library_inventory_after_sha256=$rLibraryInventoryAfter',
    'Invoke-SealedRscript',
    '"R_LIBS_USER"',
    '"TZ", "UTC"',
    'metadata_equivalence = Resolve-ExistingFile',
    'source_wiodr13_inventory_before_sha256=',
    'source_wiodr16_inventory_after_sha256=',
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
    'identical(capture_assertions, 25L)',
    'harness_runtime_inventory_before_sha256',
    'harness_runtime_inventory_after_sha256',
    'r_library_inventory_before_sha256',
    'r_library_inventory_after_sha256',
    'length(stage_header) + 9L + 6L + 12L + 36L + 36L'
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
    'schema=issue13-v5-clean-stage5-capture/1',
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
    'r_library_path=$($script:rLibrary.Replace',
    'r_library_inventory_before_sha256=$rLibraryInventoryBefore',
    'r_library_inventory_after_sha256=$rLibraryInventoryAfter',
    'Invoke-SealedRscript',
    '"R_LIBS_USER"',
    '"TZ", "UTC"',
    'metadata_equivalence = Resolve-ExistingFile',
    'Write-Output "baseline_recalculations=36"'
  )) {
  if (-not $diagnosticControllerText[
      'issue13-v5-capture-clean-stage5-evidence.ps1'].Contains($required)) {
    throw "Clean stage-five capturer lacks exhaustive tooling seal: $required"
  }
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
    sha256 = Get-Issue13V5Sha256 $path
    command_ast_count = 0L
  })
}
$materializerText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-materialize-harness.ps1'),
  [Text.UTF8Encoding]::new($false, $true))
$materializerTokens = $null
$materializerErrors = $null
$materializerAst = [Management.Automation.Language.Parser]::ParseFile(
  (Join-Path $root 'issue13-v5-materialize-harness.ps1'),
  [ref]$materializerTokens, [ref]$materializerErrors)
$materializerControllerAssignments = @($materializerAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
    $node.Left.VariablePath.UserPath -ceq 'controllerFiles'
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
$oracleValidateText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-oracle-effect-validate.ps1'),
  [Text.UTF8Encoding]::new($false, $true))
$oracleLibraryText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-oracle-effect-lib.ps1'),
  [Text.UTF8Encoding]::new($false, $true))
$oracleGenerateText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-oracle-effect-generate.ps1'),
  [Text.UTF8Encoding]::new($false, $true))
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
    [bool]$oracleSpec.final_evidence_eligible -or
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
    -not [bool]$oracleSchema.properties.passed.const -or
    [string]$oracleSchema.properties.final_evidence_eligible.const -cne
      'False' -or
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
    -not $oracleLibraryText.Contains("'--vanilla'") -or
    -not $oracleLibraryText.Contains('$commands.Count -eq 10') -or
    -not $oracleLibraryText.Contains('$approved.Count -eq 17') -or
    -not $oracleLibraryText.Contains(
      '$externalInventory.status -ceq ''sealed''') -or
    -not $oracleLibraryText.Contains('source_controller = $expectedController') -or
    -not $oracleLibraryText.Contains('runtime_immutability =') -or
    -not $oracleGenerateText.Contains(
      'Assert-Issue13OracleEffectComparisonIsolation') -or
    -not $oracleGenerateText.Contains(
      'terminal harness/Rscript/RLibrary changed during primary/replay execution.')) {
  throw 'Oracle-effect static /2 terminal 5+7 proof contract changed.'
}

$coordinatorText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-coordinator.ps1'),
  [Text.UTF8Encoding]::new($false, $true))
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
    'pair_result_sha256', 'aggregate_sha256'
  )) {
  if (-not $coordinatorText.Contains($required)) {
    throw "Coordinator lacks required closed-gate binding: $required"
  }
}

$newConfigText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-new-config.ps1'),
  [Text.UTF8Encoding]::new($false, $true))
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
    'preparation_equivalence_profile = $preparationEquivalenceBinding',
    'all_rows_fields_and_order_exact = $true',
    'architecture_projection = @()',
    "source_unit_contract_bridge = 'exhaustive-source-unit-contract-bridge'"
  )) {
  if (-not $newConfigText.Contains($required)) {
    throw "V5 config generator lacks oracle-effect binding: $required"
  }
}

$reportText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-render-report.ps1'),
  [Text.UTF8Encoding]::new($false, $true))
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
    '$unitComparison.cross_engine_bridge'
  )) {
  if (-not $reportText.Contains($required)) {
    throw "V5 report lacks fail-closed oracle/RSS evidence: $required"
  }
}

$smokeText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-baseline-smoke.ps1'),
  [Text.UTF8Encoding]::new($false, $true))
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
    'physically overlaps the',
    'The created V5 smoke root changed physical identity.',
    '$localeEnvironmentNames = @(''LANG'', ''LC_ALL'', ''LC_CTYPE'')',
    'Set-Item -LiteralPath (''Env:'' + $name) -Value $null',
    'environment_removed = [object[]]$localeEnvironmentNames'
  )) {
  if (-not $smokeText.Contains($required)) {
    throw "Baseline smoke lacks required R-process guard: $required"
  }
}

$libraryText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-coordinator-lib.ps1'),
  [Text.UTF8Encoding]::new($false, $true))
foreach ($required in @(
    "'R.exe'", "'Rscript.exe'", "'Rterm.exe'", "'Rgui.exe'",
    "'Rcmd.exe'", "'Rfe.exe'", 'Assert-Issue13V5ReportBinding',
    'roots must not be nested', '$process.Kill($true)',
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
    'Assert-Issue13V5CompletedEvidenceState'
  )) {
  if (-not $libraryText.Contains($required)) {
    throw "Coordinator library lacks required safety guard: $required"
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
  if ((Test-Issue13V5LegacyPath ([string]$case.path)) -ne
      [bool]$case.expected) {
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

$coordinatorText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-coordinator.ps1'),
  [Text.UTF8Encoding]::new($false, $true))
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
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "V5 controller source is missing: $name"
  }
  $commandCount = 0L
  if ([IO.Path]::GetExtension($name) -ceq '.ps1') {
    $tokens = $null
    $errors = $null
    $controllerAst = [Management.Automation.Language.Parser]::ParseFile(
      $path, [ref]$tokens, [ref]$errors)
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
    sha256 = Get-Issue13V5Sha256 $path
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
