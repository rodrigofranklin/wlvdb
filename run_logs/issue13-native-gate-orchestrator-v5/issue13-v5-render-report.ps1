param(
  [Parameter(Mandatory = $true)][string]$ConfigPath,
  [Parameter(Mandatory = $true)][string]$StatePath,
  [Parameter(Mandatory = $true)][string]$Output,
  [switch]$ConfirmWriteReport
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $ConfirmWriteReport) {
  throw 'Report generation requires -ConfirmWriteReport.'
}
$scriptRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
. (Join-Path $scriptRoot 'issue13-v5-coordinator-lib.ps1')

$binding = Assert-Issue13V5Config $ConfigPath
$config = $binding.config
$expectedStatePath = ConvertTo-Issue13V5Path (Get-Issue13V5StatePath $config)
$providedStatePath = ConvertTo-Issue13V5Path (
  (Resolve-Path -LiteralPath $StatePath).Path)
if (-not [string]::Equals($providedStatePath, $expectedStatePath,
    [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Report state path is not the canonical control-root gate-state.json.'
}
$state = Read-Issue13V5State $config $binding.sha256
if ([string]$state.schema -cne 'wlv-issue13-v5-coordinator-state/1' -or
    [string]$state.config_sha256 -cne [string]$binding.sha256 -or
    [string]$state.final_aggregate.status -cne 'passed' -or
    [string]$state.prep_fault.aggregate_status -cne 'passed' -or
    @($state.phases | Where-Object comparison_status -cne 'completed').Count `
      -ne 0 -or
    @($state.prep_fault.faults | Where-Object status -cne 'executed').Count `
      -ne 0) {
  throw 'Only a complete passed V5 state can produce the report.'
}
if ((Get-Issue13V5Sha256 $state.final_aggregate.path) -cne
    [string]$state.final_aggregate.sha256) {
  throw 'Final aggregate changed before report generation.'
}
$null = Assert-Issue13V5FinalBindings $config $state

$repository = (Resolve-Path -LiteralPath $config.repository_root).Path
$head = (& git -C $repository rev-parse HEAD 2>$null).Trim()
$trackedStatus = @(& git -C $repository status '--porcelain=v1' `
  '--untracked-files=no' 2>$null)
if ($LASTEXITCODE -ne 0 -or $head -cne [string]$config.candidate_commit -or
    $trackedStatus.Count -ne 0) {
  throw 'Report generation requires the pinned candidate HEAD and tracked-clean tree.'
}

$outputPath = ConvertTo-Issue13V5Path $Output
if (Test-Path -LiteralPath $outputPath) {
  throw "Report output already exists: $outputPath"
}
$expectedOutput = ConvertTo-Issue13V5Path (
  Join-Path $repository ([string]$config.report.required_path))
if (-not [string]::Equals($outputPath, $expectedOutput,
    [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Report output differs from the configured required path.'
}

$aggregatePath = [string]$state.final_aggregate.path
$aggregateRoot = Split-Path -Parent $aggregatePath
$aggregate = Read-Issue13V5Json $aggregatePath
$prepFault = Read-Issue13V5Json $state.prep_fault.aggregate_path
$strictSmoke = Read-Issue13V5Json $config.strict_baseline_smoke.path
$compatibilitySmoke = Read-Issue13V5Json `
  $config.compatibility_baseline_smoke.path
$preparation = Read-Issue13V5Json `
  $state.prep_fault.preparation_comparison_path
$preparationPassed = [string]$preparation.status -ceq 'passed'
$paperComparisonPath = Join-Path (
  Get-Issue13V5ComparisonDirectory $config 'parity/paper/0') 'comparison.json'
$paperComparison = Read-Issue13V5Json $paperComparisonPath
$performance = @(Import-Csv -LiteralPath (
  Join-Path $aggregateRoot 'performance.csv'))
$oracle = @(Import-Csv -LiteralPath (
  Join-Path $aggregateRoot 'oracle-classification.csv'))
$checks = @(Import-Csv -LiteralPath (Join-Path $aggregateRoot 'checks.csv'))
$expectedSciencePhases = @(Get-Issue13V5ExpectedSciencePhases)
$expectedPerformanceScenarios = @(
  @($expectedSciencePhases.phase) + @('prepare/all', 'paper/0') | Sort-Object)
$observedPerformanceScenarios = @($performance.scenario | Sort-Object)
$expectedOraclePhases = @($expectedSciencePhases |
  Where-Object kind -ceq 'recalculate' | ForEach-Object phase | Sort-Object)
$observedOraclePhases = @($oracle.phase | Sort-Object)
if ($performance.Count -ne 76 -or
    @($performance.scenario | Sort-Object -Unique).Count -ne 76 -or
    [string]::Join("`n", $observedPerformanceScenarios) -cne
      [string]::Join("`n", $expectedPerformanceScenarios) -or
    @($performance | Where-Object {
      [string]$_.time_passed -cne 'TRUE' -or
      [string]$_.rss_passed -cne 'TRUE' -or
      [string]$_.rss_recomputed_from_authenticated_samples -cne 'TRUE' -or
      [long]$_.baseline_rss_sample_count -le 0L -or
      [long]$_.candidate_rss_sample_count -le 0L -or
      [string]$_.baseline_samples_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$_.candidate_samples_sha256 -cnotmatch '^[0-9a-f]{64}$'
    }).Count -ne 0 -or
    $oracle.Count -ne 60 -or
    @($oracle.phase | Sort-Object -Unique).Count -ne 60 -or
    [string]::Join("`n", $observedOraclePhases) -cne
      [string]::Join("`n", $expectedOraclePhases) -or
    @($oracle | Where-Object {
      [string]$_.delta_schema -cne
        'wlv-issue13-complete-recalculation-delta/1' -or
      [string]$_.complete_delta_equal -cne 'TRUE' -or
      [string]$_.baseline_delta_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$_.candidate_delta_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$_.baseline_delta_sha256 -cne
        [string]$_.candidate_delta_sha256
    }).Count -ne 0 -or
    $checks.Count -le 0 -or
    $checks.Count -ne [long]$aggregate.check_count -or
    @($checks | Where-Object { [string]$_.passed -cne 'TRUE' }).Count -ne 0 -or
    -not $preparationPassed -or -not [bool]$paperComparison.passed -or
    [bool]$strictSmoke.passed -or [long]$strictSmoke.passed_count -ne 5 -or
    [long]$strictSmoke.failed_count -ne 7 -or
    -not [bool]$compatibilitySmoke.passed -or
    [long]$compatibilitySmoke.passed_count -ne 12 -or
    [long]$compatibilitySmoke.failed_count -ne 0) {
  throw 'Passed aggregate tables or paper comparison are inconsistent.'
}

$oraclePath = Join-Path $aggregateRoot 'oracle-classification.csv'
$performancePath = Join-Path $aggregateRoot 'performance.csv'
$oracleDeltaPayload = [string]::Join("`n", @($oracle | Sort-Object phase |
  ForEach-Object {
    [string]$_.phase + '|' + [string]$_.method + '|' +
      [string]$_.delta_schema + '|' +
      [string]$_.baseline_delta_sha256 + '|' +
      [string]$_.candidate_delta_sha256 + '|' +
      [string]$_.complete_delta_equal
  }))
$rssEvidencePayload = [string]::Join("`n", @($performance |
  Sort-Object scenario | ForEach-Object {
    [string]$_.scenario + '|' + [string]$_.baseline_rss_sample_count + '|' +
      [string]$_.candidate_rss_sample_count + '|' +
      [string]$_.baseline_samples_sha256 + '|' +
      [string]$_.candidate_samples_sha256
  }))
$oracleDeltaInventorySha256 = Get-Issue13V5TextSha256 $oracleDeltaPayload
$rssEvidenceInventorySha256 = Get-Issue13V5TextSha256 $rssEvidencePayload

$commandRoot = Join-Path ([string]$config.control_root) 'commands'
$commandEntries = @(Get-ChildItem -LiteralPath $commandRoot -Filter '*.json' `
  -File | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{
      path = $_.FullName
      sha256 = Get-Issue13V5Sha256 $_.FullName
      document = Read-Issue13V5Json $_.FullName
    }
  })
$commandRecords = @($commandEntries | ForEach-Object document)
if ($commandRecords.Count -le 0 -or
    @($commandRecords | Where-Object {
      [string]$_.schema -cne 'wlv-issue13-v5-command/1' -or
      [long]$_.exit_code -notin @([long[]]$_.expected_exit_codes) -or
      [bool]$_.timed_out -or
      [string]$_.stdout_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$_.stderr_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      (Get-Issue13V5Sha256 ([string]$_.stdout_path)) -cne
        [string]$_.stdout_sha256 -or
      (Get-Issue13V5Sha256 ([string]$_.stderr_path)) -cne
        [string]$_.stderr_sha256
    }).Count -ne 0) {
  throw 'Command records are incomplete, failed, or changed.'
}
$commandInventory = Get-Issue13V5TreeInventory $commandRoot
$evidenceInventory = Get-Issue13V5TreeInventory $config.evidence_root
$aggregateInventory = Get-Issue13V5TreeInventory $aggregateRoot
$oracleEffectProof = Read-Issue13V5Json $config.oracle_effect.proof.path
$oracleEffectControl = Assert-Issue13V5OracleEffectControlRecord $config $state `
  $binding.oracle_effect_validation
$oracleWorkflow = $oracleEffectProof.evidence.comparison_workflow
$oracleCommon = @($oracleWorkflow.comparisons)
$oracleCommands = @($oracleWorkflow.commands)
$oracleApprovedRuns = @($oracleEffectProof.evidence.approved_run_immutability)
$oracleRecovered = @($oracleEffectProof.evidence.recovered_methods)
$oracleTerminalRuntime = $oracleEffectProof.evidence.terminal_runtime
$oracleTerminalHarness =
  $oracleTerminalRuntime.comparison_harness
$oracleSourceController = $oracleTerminalHarness.source_controller
$oracleRLibrary = $oracleTerminalRuntime.r_library
$oracleRuntimeImmutability = $oracleTerminalRuntime.runtime_immutability
if ([string]$oracleEffectProof.schema -cne
      'wlv-issue13-v5-oracle-effect-proof/2' -or
    $oracleCommon.Count -ne 5 -or $oracleCommands.Count -ne 10 -or
    $oracleApprovedRuns.Count -ne 17 -or $oracleRecovered.Count -ne 7 -or
    @($oracleCommon.method | Sort-Object -Unique).Count -ne 5 -or
    @($oracleApprovedRuns | Where-Object { -not [bool]$_.immutable }).Count `
      -ne 0 -or
    @($oracleRecovered.method | Sort-Object -Unique).Count -ne 7 -or
    -not [bool]$oracleWorkflow.generator_created_both_roots -or
    -not [bool]$oracleEffectProof.conclusion.
      strict_common_primary_and_replay_passed -or
    [long]$oracleEffectProof.conclusion.approved_run_count -ne 17L -or
    -not [bool]$oracleEffectProof.conclusion.approved_runs_immutable -or
    [string]$oracleTerminalHarness.generation -cne 'v5-terminal' -or
    [string]$oracleTerminalHarness.expected_candidate_commit -cne
      [string]$config.candidate_commit -or
    [bool]$oracleEffectProof.final_evidence_eligible -or
    -not [bool]$oracleEffectProof.conclusion.oracle_effect_closed -or
    [bool]$oracleEffectProof.conclusion.final_v5_gate_substituted) {
  throw 'Oracle-effect proof does not contain the exact closed 5+7 partition.'
}
$oracleControllerRecords = @($oracleSourceController.records)
$configuredOracleController =
  $config.oracle_effect.comparison_harness.source_controller
if ([long]$oracleSourceController.file_count -ne 34L -or
    $oracleControllerRecords.Count -ne 34 -or
    @($oracleControllerRecords.name | Sort-Object -Unique).Count -ne 34 -or
    [string]$oracleSourceController.commit_sha256 -cne
      [string]$config.candidate_commit -or
    [string]$oracleTerminalHarness.source_controller_commit_sha256 -cne
      [string]$config.candidate_commit -or
    [string]$oracleSourceController.inventory_sha256 -cne
      [string]$configuredOracleController.inventory_sha256 -or
    ($oracleSourceController | ConvertTo-Json -Depth 30 -Compress) -cne
      ($configuredOracleController | ConvertTo-Json -Depth 30 -Compress)) {
  throw 'Oracle-effect terminal source-controller inventory changed.'
}
$expectedOracleCleared = [string[]]@(
  'LANG', 'LC_ALL', 'LC_CTYPE', 'R_ARCH', 'R_DEFAULT_PACKAGES',
  'R_ENVIRON', 'R_ENVIRON_USER', 'R_HOME', 'R_LIBS', 'R_LIBS_SITE',
  'R_PROFILE', 'R_PROFILE_USER', 'R_STARTUP_DEBUG',
  'RENV_CONFIG_AUTOLOADER_ENABLED', 'RENV_PATHS_LIBRARY',
  'RENV_PATHS_ROOT'
) | Sort-Object
$observedOracleCleared = [string[]]@(
  $oracleRLibrary.environment.cleared) | Sort-Object
$oracleEnvironmentSet = @($oracleRLibrary.environment.set)
$oracleLibsUserSet = @($oracleEnvironmentSet | Where-Object {
  [string]$_.name -ceq 'R_LIBS_USER' -and
  [string]$_.value -ceq [string]$config.r_library
})
$oracleTzSet = @($oracleEnvironmentSet | Where-Object {
  [string]$_.name -ceq 'TZ' -and [string]$_.value -ceq 'UTC'
})
$oracleRequiredPackages = [string[]]@(
  $oracleRLibrary.required_packages | Sort-Object)
$expectedOraclePackages = [string[]]@('fst', 'jsonlite', 'openssl') |
  Sort-Object
$oracleLoadedPackages = @($oracleRLibrary.loaded_packages)
$oracleLoadedRequiredPackages = [string[]]@(
  $oracleLoadedPackages | Where-Object { [bool]$_.required } |
    ForEach-Object { [string]$_.name } | Sort-Object)
if ([string]$oracleRLibrary.path -cne [string]$config.r_library -or
    [string]$oracleRLibrary.environment_variable -cne 'R_LIBS_USER' -or
    $oracleEnvironmentSet.Count -ne 2 -or $oracleLibsUserSet.Count -ne 1 -or
    $oracleTzSet.Count -ne 1 -or
    @(Compare-Object $expectedOracleCleared $observedOracleCleared `
      -CaseSensitive).Count -ne 0 -or
    @(Compare-Object $expectedOraclePackages $oracleRequiredPackages `
      -CaseSensitive).Count -ne 0 -or
    @(Compare-Object $expectedOraclePackages $oracleLoadedRequiredPackages `
      -CaseSensitive).Count -ne 0 -or
    $oracleLoadedPackages.Count -lt 3 -or
    [string]$oracleRLibrary.r_version -notmatch '^R version ' -or
    [string]::IsNullOrWhiteSpace([string]$oracleRLibrary.platform) -or
    [string]$oracleRLibrary.inventory_sha256 -cne
      [string]$config.oracle_effect.r_library.inventory_sha256 -or
    [string]$oracleTerminalRuntime.rscript.path -cne
      [string]$config.oracle_effect.rscript.path -or
    [string]$oracleTerminalRuntime.rscript.sha256 -cne
      [string]$config.oracle_effect.rscript.sha256) {
  throw 'Oracle-effect terminal R runtime inventory changed.'
}
$oracleEnvironmentSetJson = $oracleRLibrary.environment.set |
  ConvertTo-Json -Depth 10 -Compress
$oracleCommandEnvironmentFailures = @($oracleCommands | Where-Object {
  @($_.arguments) -cnotcontains '--vanilla' -or
  [string]$_.r_library_environment.name -cne 'R_LIBS_USER' -or
  [string]$_.r_library_environment.value -cne [string]$config.r_library -or
  ($_.environment_set | ConvertTo-Json -Depth 10 -Compress) -cne
    $oracleEnvironmentSetJson -or
  @(Compare-Object $expectedOracleCleared `
      ([string[]]@($_.environment_cleared) | Sort-Object) `
      -CaseSensitive).Count -ne 0
})
if ($oracleCommandEnvironmentFailures.Count -ne 0) {
  throw 'Oracle-effect commands do not share the sealed --vanilla R environment.'
}
$oracleRuntimeBeforeJson = $oracleRuntimeImmutability.before |
  ConvertTo-Json -Depth 50 -Compress
$oracleRuntimeAfterJson = $oracleRuntimeImmutability.after |
  ConvertTo-Json -Depth 50 -Compress
if (-not [bool]$oracleRuntimeImmutability.immutable -or
    $oracleRuntimeBeforeJson -cne $oracleRuntimeAfterJson -or
    ($oracleRuntimeImmutability.before.r_library |
      ConvertTo-Json -Depth 30 -Compress) -cne
      ($oracleRLibrary | ConvertTo-Json -Depth 30 -Compress) -or
    ($oracleRuntimeImmutability.before.rscript |
      ConvertTo-Json -Depth 10 -Compress) -cne
      ($oracleTerminalRuntime.rscript |
        ConvertTo-Json -Depth 10 -Compress)) {
  throw 'Oracle-effect terminal R runtime is not immutable.'
}
$oracleRuntimeInventorySha256 =
  Get-Issue13V5TextSha256 $oracleRuntimeBeforeJson

$baselineSeconds = [double](($performance | Measure-Object `
  baseline_seconds -Sum).Sum)
$candidateSeconds = [double](($performance | Measure-Object `
  candidate_seconds -Sum).Sum)
$maximumTimeRatio = ($performance | ForEach-Object {
  [double]$_.candidate_seconds / [double]$_.baseline_seconds
} | Measure-Object -Maximum).Maximum
$maximumCandidateRss = ($performance | ForEach-Object {
  [int64]$_.candidate_peak_rss_bytes
} | Measure-Object -Maximum).Maximum
$maximumRssUtilization = ($performance | ForEach-Object {
  [double]$_.candidate_peak_rss_bytes / [double]$_.rss_limit_bytes
} | Measure-Object -Maximum).Maximum
$oracleGroups = @($oracle | Group-Object classification | Sort-Object Name)
$faultRows = @($state.prep_fault.faults | Sort-Object fault_id)

$sourceIdentityLines = [Collections.Generic.List[string]]::new()
$preparationEquivalenceBinding =
  $config.comparison.preparation_equivalence_profile
$preparationEquivalencePath = ConvertTo-Issue13V5Path (
  [string]$preparationEquivalenceBinding.path)
$preparationEquivalenceSha = Get-Issue13V5Sha256 $preparationEquivalencePath
if ($preparationEquivalenceSha -cne
      [string]$preparationEquivalenceBinding.sha256 -or
    -not [bool]$preparationEquivalenceBinding.
      all_rows_fields_and_order_exact -or
    @($preparationEquivalenceBinding.architecture_projection).Count -ne 0 -or
    [string]$preparationEquivalenceBinding.source_unit_contract_bridge -cne
      'exhaustive-source-unit-contract-bridge') {
  throw 'Preparation equivalence report binding changed.'
}
foreach ($sourceName in @('wiodr13', 'wiodr16')) {
  $sourceComparison =
    $preparation.sources.PSObject.Properties[$sourceName].Value
  $baselineManifest = $sourceComparison.baseline_manifest
  $candidateManifest = $sourceComparison.candidate_manifest
  $manifestComparison =
    $sourceComparison.csv.PSObject.Properties['_source_manifest.csv'].Value
  $unitComparison =
    $sourceComparison.csv.PSObject.Properties['_unit_contract.csv'].Value
  $unitBridge = $unitComparison.cross_engine_bridge
  $baselineBinding = @($config.source_contract_bindings | Where-Object {
    [string]$_.arm -ceq 'baseline' -and
      [string]$_.source -ceq $sourceName
  })
  $candidateBinding = @($config.source_contract_bindings | Where-Object {
    [string]$_.arm -ceq 'candidate' -and
      [string]$_.source -ceq $sourceName
  })
  $arrayComparisons = @(
    $sourceComparison.arrays.PSObject.Properties | ForEach-Object {
      $_.Value
    })
  $sealedTableComparisons = @($manifestComparison, $unitComparison)
  $sealedArmComparisons = @($sealedTableComparisons | ForEach-Object {
    @($_.baseline, $_.candidate)
  })
  if (-not [bool]$sourceComparison.passed -or
      -not [bool]$sourceComparison.
        manifest_tables_equivalence_profile_exact -or
      -not [bool]$baselineManifest.passed -or
      -not [bool]$candidateManifest.passed -or
      -not [bool]$manifestComparison.passed -or
      [string]$manifestComparison.comparison_mode -cne
        'sealed-exhaustive-source-manifest-equivalence' -or
      -not [bool]$unitComparison.passed -or
      [string]$unitComparison.comparison_mode -cne
        'sealed-exhaustive-unit-contract-equivalence' -or
      -not [bool]$unitBridge.passed -or
      [string]$unitBridge.comparison_mode -cne
        'exhaustive-source-unit-contract-bridge' -or
      [string]$unitBridge.source -cne $sourceName -or
      -not [bool]$unitBridge.all_columns_compared -or
      -not [bool]$unitBridge.exact_order_after_bridge -or
      [long]$unitBridge.aggregation_note_bridge_rows -ne 0L -or
      [bool]$manifestComparison.raw_semantic_equal -or
      [bool]$unitComparison.raw_semantic_equal -or
      @($sealedTableComparisons | Where-Object {
        [string]$_.profile_sha256 -cne $preparationEquivalenceSha
      }).Count -ne 0 -or
      @($sealedArmComparisons | Where-Object {
        -not [bool]$_.passed -or -not [bool]$_.exact_table -or
        [long]$_.rows -le 0L -or @($_.columns).Count -le 0 -or
        [string]$_.file_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        [string]$_.table_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        [string]$_.file_sha256 -cne [string]$_.expected_file_sha256 -or
        [string]$_.table_sha256 -cne [string]$_.expected_table_sha256
      }).Count -ne 0 -or
      $baselineBinding.Count -ne 1 -or $candidateBinding.Count -ne 1) {
    throw "Preparation source equivalence profile is invalid: $sourceName"
  }
  if ($arrayComparisons.Count -ne 2 -or
      @($arrayComparisons | Where-Object {
        -not [bool]$_.passed -or
        -not [bool]$_.dimension_names_identical -or
        -not [bool]$_.fst_column_schema_identical -or
        -not [bool]$_.bitwise_values_identical -or
        [long]$_.compared_values -ne [long]$_.flattened_values -or
        -not [bool]$_.baseline_internal_hash_ok -or
        -not [bool]$_.candidate_internal_hash_ok -or
        -not [bool]$_.sidecar_architecture_valid -or
        [bool]$_.sidecars_semantically_identical -or
        [string]$_.baseline_sidecar_format -cne 'legacy-positional' -or
        [string]$_.candidate_sidecar_format -cne 'versioned-v1' -or
        [string]$_.baseline_sha256 -cne [string]$_.candidate_sha256 -or
        [string]$_.baseline_sidecar_sha256 -ceq
          [string]$_.candidate_sidecar_sha256
      }).Count -ne 0) {
    throw "Prepared FST sidecar architecture is invalid: $sourceName"
  }
  foreach ($record in @(
      @($baselineManifest, $baselineBinding[0]),
      @($candidateManifest, $candidateBinding[0])
    )) {
    foreach ($field in @(
        'source_generation_id', 'contract_id', 'contract_version',
        'contract_sha256'
      )) {
      if ([string]$record[0].$field -cne [string]$record[1].$field) {
        throw "Preparation source identity differs from its binding: $sourceName/$field"
      }
    }
  }
  if ([string]$baselineManifest.contract_id -cne
        [string]$candidateManifest.contract_id -or
      [string]$baselineManifest.contract_version -cne
        [string]$candidateManifest.contract_version) {
    throw "Preparation contract ID/version differs: $sourceName"
  }
  $sourceIdentityLines.Add(
    '- `' + $sourceName + '`: contract_id `' +
      [string]$baselineManifest.contract_id + '`, contract_version `' +
      [string]$baselineManifest.contract_version + '`. Baseline: geração `' +
      [string]$baselineManifest.source_generation_id + '`, contrato `' +
      [string]$baselineManifest.contract_sha256 + '`, manifest `' +
      [string]$baselineBinding[0].manifest_sha256 + '`. Candidato: geração `' +
      [string]$candidateManifest.source_generation_id + '`, contrato `' +
      [string]$candidateManifest.contract_sha256 + '`, manifest `' +
      [string]$candidateBinding[0].manifest_sha256 +
      '`. `_unit_contract.csv` e `_source_manifest.csv` correspondem célula ' +
      'por célula aos perfis completos de cada braço (`' +
      $preparationEquivalenceSha + '`); o bridge tipado entre braços também ' +
      'compara todas as colunas e nenhuma projeção arquitetural é autorizada. ' +
      'Sidecars FST `legacy-positional` → `versioned-v1` validados.'
  )
}
$euklemsArtifacts = @(
  $preparation.euklems.artifacts.PSObject.Properties | ForEach-Object {
    $_.Value
  })
if (-not [bool]$preparation.euklems.passed -or
    [long]$preparation.euklems.artifact_count -ne 42L -or
    $euklemsArtifacts.Count -ne 42 -or
    [string]::Join(',', @($preparation.euklems.expected_years)) -cne
      [string]::Join(',', (1995..2015)) -or
    [string]::Join(',', @($preparation.euklems.expected_series)) -cne
      'ekk,ekdeprate' -or
    @($euklemsArtifacts | Where-Object {
      -not [bool]$_.passed -or
      [string]$_.baseline_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$_.candidate_sha256 -cnotmatch '^[0-9a-f]{64}$'
    }).Count -ne 0) {
  throw 'EU KLEMS prepared artifact identity is incomplete or differs.'
}
$euklemsIdentityPayload = [string]::Join("`n", @(
  $euklemsArtifacts | Sort-Object artifact | ForEach-Object {
    [string]$_.artifact + '|' + [string]$_.baseline_sha256 + '|' +
      [string]$_.candidate_sha256
  }))
$euklemsIdentitySha256 = Get-Issue13V5TextSha256 $euklemsIdentityPayload
$sourceIdentityLines.Add(
  '- `euklems`: 42 FSTs (1995–2015, `ekk`/`ekdeprate`) com esquemas e ' +
    'células idênticos; identidade agregada dos hashes de ambos os braços `' +
    $euklemsIdentitySha256 +
    '`. O contrato atual não publica `_source_manifest.csv` para EU KLEMS; ' +
    'as duas caches oficiais e cada artefato preparado são autenticados.'
)

$sourceCacheLines = @($script:Issue13V5PreparationCaches | ForEach-Object {
  '- `' + $_.relative_path.Replace('\', '/') + '`: `' + $_.sha256 +
    '` (' + [string]$_.size_bytes + ' bytes)'
})
$commandLines = @($commandEntries | ForEach-Object {
  $record = $_.document
  $argumentsJson = ConvertTo-Json -InputObject @($record.arguments) -Compress
  $environmentJson = $record.environment | ConvertTo-Json -Compress
  $removedJson = ConvertTo-Json -InputObject `
    @($record.environment_removed) -Compress
  '- registro `' + [string]$_.sha256 + '`; label `' +
    [string]$record.label + '`; executável `' +
    [string]$record.executable + '`; cwd `' +
    [string]$record.working_directory + '`; exit `' +
    [string]$record.exit_code + '`; argumentos `' + $argumentsJson +
    '`; ambiente injetado `' + $environmentJson +
    '`; ambiente removido `' + $removedJson + '`; stdout `' +
    [string]$record.stdout_sha256 + '`; stderr `' +
    [string]$record.stderr_sha256 + '`.'
})
$oracleValidationArguments = ConvertTo-Json -InputObject @(
  $oracleEffectControl.validation.command.arguments) -Compress
$oracleValidationCommandLine = '- validação oracle-effect; executável `' +
  [string]$oracleEffectControl.validation.command.executable + '`; cwd `' +
  [string]$oracleEffectControl.validation.command.working_directory +
  '`; exit `0`; argumentos `' + $oracleValidationArguments +
  '`; stdout `' +
  [string]$oracleEffectControl.validation.command.stdout_sha256 + '`.'
$oracleCommonLines = @($oracleCommon | Sort-Object method | ForEach-Object {
  $comparisonFile = @($_.files | Where-Object name -ceq 'comparison.json')
  if ($comparisonFile.Count -ne 1 -or
      [string]$comparisonFile[0].primary_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$comparisonFile[0].replay_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$comparisonFile[0].normalized_sha256 -cnotmatch
        '^[0-9a-f]{64}$' -or
      -not [bool]$comparisonFile[0].normalized_identical) {
    throw "Oracle-effect common comparison file is missing: $($_.method)"
  }
  '- `' + [string]$_.method + '`: strict primary/replay `passed`; ' +
    'comparison normalizada `' +
    [string]$comparisonFile[0].normalized_sha256 + '` (primary `' +
    [string]$comparisonFile[0].primary_sha256 + '`, replay `' +
    [string]$comparisonFile[0].replay_sha256 + '`); cc2 manifest `' +
    [string]$_.baseline_manifest_sha256 + '`; e2f manifest `' +
    [string]$_.candidate_manifest_sha256 + '`.'
})
$oracleRecoveredLines = @($oracleRecovered | Sort-Object method |
  ForEach-Object {
    '- `' + [string]$_.method + '`: falha cc2 `' +
      [string]$_.strict_failure_id + '` (`' +
      [string]$_.strict_scenario_sha256 + '`); run e2f manifest `' +
      [string]$_.oracle_manifest_sha256 + '`, inventário `' +
      [string]$_.oracle_inventory_sha256 + '`; mudanças `' +
      ([string]::Join(',', @($_.change_ids))) + '`.'
  })
$oracleLines = if ($oracleGroups.Count) {
  @($oracleGroups | ForEach-Object {
    '- `' + $_.Name + '`: ' + [string]$_.Count
  })
} else { @('- Nenhuma classificação de oracle foi emitida.') }
$faultLines = @($faultRows | ForEach-Object {
  '- `' + $_.fault_id + '`: `passed`, resultado `' + $_.result_sha256 + '`'
})

$text = @"
# Issue #13 — relatório integral de paridade V5

Este documento registra o gate real, write-once e sem reutilização de evidência
do rework atômico do motor. O merge do issue #12 permanece a origem histórica
imutável. Como ele falha antes de produzir sete oráculos, a execução final do
baseline usa um único filho direto de compatibilidade, autenticado pela íntegra
de seu diff. O smoke estrito 5/7 é preservado como evidência negativa e nunca é
importado como resultado científico final.

## Identidade

- `baseline_commit`: `$($config.baseline_commit)`
- `baseline_base_commit`: `$($config.baseline_base_commit)`
- `baseline_runtime_commit`: `$($config.baseline_runtime_commit)`
- `candidate_commit`: `$($config.candidate_commit)`
- Gate: 12 métodos, 76 pares, 162 cenários monitorados, 202 comparações e 10
  falhas injetadas.
- Agregado: `$aggregatePath`
- Estado final: `$StatePath`

## source_ids

- Inventário baseline oficial: `$($config.source_inventory.inventory_sha256)`
  ($($config.source_inventory.file_count) arquivos,
  $($config.source_inventory.total_bytes) bytes).
- Inventário de diretórios baseline:
  `$($config.source_inventory.directory_list_sha256)`.
- Inventário candidato nativo:
  `$($config.candidate_source_inventory.inventory_sha256)`
  ($($config.candidate_source_inventory.file_count) arquivos,
  $($config.candidate_source_inventory.total_bytes) bytes).
- Inventário de diretórios candidato:
  `$($config.candidate_source_inventory.directory_list_sha256)`.
$([string]::Join("`n", $sourceCacheLines))

Identidades das gerações preparadas. Cada braço foi validado contra seu
contrato; a comparação científica usa a ponte tipada e exaustiva selada, sem
qualquer projeção de linha, campo, ordem ou tolerância:

$([string]::Join("`n", $sourceIdentityLines))

## commands

Os comandos foram registrados individualmente com argumentos, código de saída,
tempo e hashes de stdout/stderr. Inventário autenticado:
`$($commandInventory.inventory_sha256)` ($($commandInventory.file_count) arquivos).

$([string]::Join("`n", $commandLines))
$oracleValidationCommandLine

## hashes

- Configuração V5: `$($binding.sha256)`
- Harness materializado: `$($binding.harness_inventory.inventory_sha256)`
- Índice baseline compatibility-oracle-cc2: `$($config.baseline_runtime_index_sha256)`
- `baseline_overlay_patch`: `$($config.baseline_overlay.sha256)`
  (stable patch-id `$($config.baseline_overlay.patch_id)`).
- `strict_baseline_smoke`: `$($config.strict_baseline_smoke.sha256)`.
- `compatibility_baseline_smoke`:
  `$($config.compatibility_baseline_smoke.sha256)`.
- Smoke dedicado da prova do efeito do oráculo:
  `$($config.oracle_effect.oracle_smoke.sha256)`.
- Prova auxiliar do efeito do oráculo: `$($config.oracle_effect.proof.sha256)`.
- Inventário agregado do par primary/replay:
  `$($config.oracle_effect.comparisons.inventory.inventory_sha256)`.
- Inventário da raiz primary (cinco comparações strict):
  `$($config.oracle_effect.comparisons.primary.inventory.inventory_sha256)`.
- Inventário da raiz replay (cinco comparações strict):
  `$($config.oracle_effect.comparisons.replay.inventory.inventory_sha256)`.
- Manifesto do harness terminal do comparador:
  `$($config.oracle_effect.comparison_harness.manifest_sha256)`.
- Inventário dos 34 controladores-fonte do harness terminal:
  `$($oracleSourceController.inventory_sha256)`.
- Inventário do runtime R isolado: `$($oracleRLibrary.inventory_sha256)`;
  snapshot imutável `$oracleRuntimeInventorySha256`.
- Perfil exaustivo de equivalência da preparação:
  `$($preparationEquivalenceBinding.sha256)`; projeções autorizadas: `0`.
- Registro de controle da prova:
  `$($state.oracle_effect.control_record_sha256)`.
- Tabela de 60 deltas de recálculo: `$(Get-Issue13V5Sha256 $oraclePath)`;
  projeção agregada `$oracleDeltaInventorySha256`.
- Tabela RSS autenticada: `$(Get-Issue13V5Sha256 $performancePath)`;
  projeção agregada `$rssEvidenceInventorySha256`.
- Evidência final: `$($evidenceInventory.inventory_sha256)`
- Agregado final: `$($state.final_aggregate.sha256)`
- Envelope do agregado: `$($aggregateInventory.inventory_sha256)`
- Subagregado preparação/falhas: `$(Get-Issue13V5Sha256 $state.prep_fault.aggregate_path)`
- Comparação paper 0: `$(Get-Issue13V5Sha256 $paperComparisonPath)`

## times

- Tempo baseline somado: `$([Math]::Round($baselineSeconds, 3))` segundos.
- Tempo candidato somado: `$([Math]::Round($candidateSeconds, 3))` segundos.
- Maior razão candidato/baseline: `$([Math]::Round($maximumTimeRatio, 6))`
  (limite `1.2`).
- Todos os 76 limites de tempo passaram: `TRUE`.

## peak_rss

- Maior RSS candidato: `$maximumCandidateRss` bytes.
- Maior utilização do limite RSS: `$([Math]::Round($maximumRssUtilization, 6))`.
- Regra: baseline + `max(10%, 512 MiB)`; todos os 76 pares passaram.
- Os 76 picos foram recomputados de `process-samples.csv` autenticado; todas as
  contagens por braço são positivas e todos os hashes de amostras têm 64
  dígitos hexadecimais. Projeção RSS: `$rssEvidenceInventorySha256`.
- WIOD13/WIOD16 com `workers=2`: equivalentes a `workers=1`, contagem exata de
  workers e `cluster_closed=true`.

## differences

- Checks executados: `$($aggregate.check_count)`; falhas: `0`.
- O smoke estrito em `cc2c861` passou 5 métodos e falhou 7; sua evidência é
  negativa e `final_evidence_eligible=false`.
- O smoke do oráculo filho passou os 12 métodos; ele também é apenas preflight
  e `final_evidence_eligible=false`.
- A alteração do baseline executável é o patch integral autenticado do filho
  direto; nenhuma alteração dele pertence ao candidato ou ao PR.
- As diferenças arquiteturais são exclusivamente as transformações
  explicitamente declaradas: `_runtime_resources.rds`,
  `_nonfinite_resolution_diagnostics.csv`, os campos de identidade/proveniência
  não científicos do envelope e a transição de sidecar descrita abaixo.
  A preparação não autoriza projeções: sua ponte tipada compara todas as linhas,
  colunas e a ordem integral. Cada transformação possui validação própria; não
  existe fallback genérico.
- As fontes normalizadas têm manifests/contratos próprios por braço.
  `_unit_contract.csv` e `_source_manifest.csv` são comparados integralmente
  contra tabelas arm-specific controller-pinned; `module`,
  `aggregation_notes`, identidades, tamanhos, hashes, ordem e todas as demais
  células permanecem vinculados. Os sidecars são aceitos somente após validar
  a transição autenticada
  `legacy-positional` → `versioned-v1`, dimensões, dimnames, hash interno e o
  array bit a bit; todos os demais artefatos e campos permanecem estritos.
- `_nonfinite_resolution_diagnostics.csv` é candidato-only conforme contrato.
- Não foi introduzida tolerância numérica nova.
- Os 60 oráculos de recálculo têm schema
  `wlv-issue13-complete-recalculation-delta/1`,
  `complete_delta_equal=TRUE` e digests baseline/candidato idênticos. Projeção
  agregada: `$oracleDeltaInventorySha256`.
$([string]::Join("`n", $oracleLines))

## oracle_effect_proof

A prova auxiliar fecha o efeito do patch autorizado `cc2 → e2f`, mas conserva
`final_evidence_eligible=false`; ela é uma pré-condição obrigatória e não
substitui o gate V5 final.

- Prova: `$($config.oracle_effect.proof.path)`; SHA-256
  `$($config.oracle_effect.proof.sha256)`.
- Patch autorizado: `$($config.baseline_overlay.sha256)`; stable patch-id
  `$($config.baseline_overlay.patch_id)`.
- Spec: `$($oracleEffectProof.evidence.spec.sha256)`; schema da prova:
  `$($oracleEffectProof.evidence.proof_schema.sha256)`.
- Pares strict comuns: `5/5`; execuções primary/replay: `10/10`; inventários de
  runs aprovados e imutáveis: `17/17`; métodos recuperados: `7/7`; efeito
  fechado: `TRUE`; substituição do gate final: `FALSE`.
- Raiz primary: `$($config.oracle_effect.comparisons.primary.root)`; inventário
  `$($config.oracle_effect.comparisons.primary.inventory.inventory_sha256)`
  ($($config.oracle_effect.comparisons.primary.inventory.file_count) arquivos).
- Raiz replay: `$($config.oracle_effect.comparisons.replay.root)`; inventário
  `$($config.oracle_effect.comparisons.replay.inventory.inventory_sha256)`
  ($($config.oracle_effect.comparisons.replay.inventory.file_count) arquivos).
- Inventário agregado primary/replay:
  `$($config.oracle_effect.comparisons.inventory.inventory_sha256)`.
- Harness terminal: geração `$($oracleTerminalHarness.generation)`, commit
  `$($oracleTerminalHarness.expected_candidate_commit)`, manifesto
  `$($oracleTerminalHarness.manifest_sha256)`, inventários output/sealed/instalado
  `$($oracleTerminalHarness.output_tooling.inventory_sha256)` /
  `$($oracleTerminalHarness.sealed_output_tooling.inventory_sha256)` /
  `$($oracleTerminalHarness.installed_inventory.inventory_sha256)`.
- Controladores-fonte: `34/34`, commit
  `$($oracleSourceController.commit_sha256)`, inventário
  `$($oracleSourceController.inventory_sha256)`.
- Rscript autenticado:
  `$($oracleTerminalRuntime.rscript.sha256)`; biblioteca R
  `$($oracleRLibrary.path)` via `R_LIBS_USER`; inventário
  `$($oracleRLibrary.inventory_sha256)`; os dez comandos usam `--vanilla`,
  `TZ=UTC` e removem as 16 variáveis de ambiente seladas.
- Runtime R antes/depois: `$oracleRuntimeInventorySha256`; imutável: `TRUE`;
  versão `$($oracleRLibrary.r_version)`; plataforma
  `$($oracleRLibrary.platform)`; pacotes obrigatórios `fst,jsonlite,openssl`.
- Smoke da prova: `$($config.oracle_effect.oracle_smoke.sha256)`; smoke terminal
  do gate: `$($config.compatibility_baseline_smoke.sha256)`.

Cinco métodos comuns, comparados integralmente em modo strict:

$([string]::Join("`n", $oracleCommonLines))

Sete métodos recuperados, com falha cc2 e efeitos/diagnósticos e2f autenticados:

$([string]::Join("`n", $oracleRecoveredLines))

## preparation_results

- Status: `$($preparation.status)`; passed: `$preparationPassed`.
- WIOD13, WIOD16 e EU KLEMS foram preparados a partir das mesmas seis caches
  oficiais autenticadas.
- As gerações normalizadas baseline e candidata foram autenticadas
  separadamente antes da execução científica.
- Arrays normativos foram comparados bit a bit, preservando `NA`, `NaN`,
  infinitos e zero assinado; a extensão versionada dos sidecars candidatos foi
  validada contra os payloads FST.
- Promoção atômica e ausência de staging/locks foram verificadas.

## paper0_results

- Status da comparação semântica do workbook: `$($paperComparison.status)`.
- Métodos: `ochoa_1` e `ochoa_2`.
- O release e as células/sheets do workbook foram comparados semanticamente.
- Papers 3 e 4 permanecem não suportados no preflight.

## fault_results

- Falhas injetadas aprovadas: `$($prepFault.summary.fault_gates_passed)`.
- Rollbacks aprovados: `$($prepFault.summary.rollback_gates_passed)`.
- Releases parciais visíveis: `$($prepFault.summary.visible_partial_releases)`.
- Entradas de staging/lock remanescentes: `$($prepFault.summary.staging_entries)`.
$([string]::Join("`n", $faultLines))

## Conclusão

O agregado V5 passou integralmente. A evidência está vinculada à origem
`cc2c861`, ao runtime-oráculo filho autenticado, ao commit candidato acima, às
fontes oficiais e ao tooling V5 materializado. Qualquer alteração posterior em
configuração, harness, cenários, comparações, logs ou artefatos invalida os
hashes registrados neste relatório.
"@

$parent = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $parent
}
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$temporary = Join-Path $parent ('.issue-13.md-' +
  [Guid]::NewGuid().ToString('N') + '.tmp')
[IO.File]::WriteAllText($temporary, $text, $utf8)
$roundtrip = [IO.File]::ReadAllText($temporary, $utf8)
if (-not [string]::Equals($roundtrip, $text,
    [StringComparison]::Ordinal) -or $roundtrip.Contains([char]0xFFFD)) {
  throw 'Issue #13 report UTF-8 round trip failed.'
}
foreach ($field in @($config.report.required_fields)) {
  if ($roundtrip -cnotmatch [regex]::Escape([string]$field)) {
    throw "Report lacks configured field: $field"
  }
}
[IO.File]::Move($temporary, $outputPath)
if (-not [string]::Equals(
    [IO.File]::ReadAllText($outputPath, $utf8), $text,
    [StringComparison]::Ordinal)) {
  throw 'Installed Issue #13 report differs from verified UTF-8 payload.'
}
[pscustomobject]@{
  status = 'written'
  path = (Resolve-Path -LiteralPath $outputPath).Path
  sha256 = Get-Issue13V5Sha256 $outputPath
  baseline_commit = [string]$config.baseline_commit
  baseline_runtime_commit = [string]$config.baseline_runtime_commit
  candidate_commit = [string]$config.candidate_commit
}
