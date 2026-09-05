param(
  [Parameter(Mandatory)][ValidateSet('Initialize', 'Prepare', 'Compare', 'Faults', 'RunAll', 'Status')]
  [string]$Action,
  [Parameter(Mandatory)][string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'issue13-main-lib.ps1')

function Test-SupplementalPathOverlap([string]$Left, [string]$Right) {
  $leftPath = [IO.Path]::GetFullPath($Left).TrimEnd('\', '/')
  $rightPath = [IO.Path]::GetFullPath($Right).TrimEnd('\', '/')
  (Test-Issue13MainSamePath $leftPath $rightPath) -or
    $leftPath.StartsWith($rightPath + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase) -or
    $rightPath.StartsWith($leftPath + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase)
}

$config = Read-Issue13MainJson $ConfigPath
$supplementalRoot = Join-Path ([string]$config.control_root) 'supplemental'
$statePath = Join-Path $supplementalRoot 'state.json'
if ($Action -ceq 'Status') {
  if (Test-Path -LiteralPath $statePath) {
    Get-Content -LiteralPath $statePath -Raw -Encoding UTF8
  } else {
    '{"schema":"wlv-issue13-main-supplemental/1","status":"planned"}'
  }
  exit 0
}

$null = Assert-Issue13MainConfig $config
$baseline = Get-Issue13MainArmBinding $config 'baseline'
$candidate = Get-Issue13MainArmBinding $config 'candidate'
$roots = $config.supplemental_roots
$rootPaths = @('baseline_preparation', 'candidate_preparation', 'candidate_fault') |
  ForEach-Object {
    ConvertTo-Issue13MainFullPath ([string]$roots.$_) -RequireExistingDirectory
  }
for ($index = 0; $index -lt $rootPaths.Count; $index++) {
  $path = $rootPaths[$index]
  for ($other = $index + 1; $other -lt $rootPaths.Count; $other++) {
    if (Test-SupplementalPathOverlap $path $rootPaths[$other]) {
      throw 'Supplemental worktrees must not overlap.'
    }
  }
  foreach ($output in @([string]$config.control_root, [string]$config.evidence_root)) {
    if (Test-SupplementalPathOverlap $path $output) {
      throw 'Supplemental worktrees must not overlap campaign output directories.'
    }
  }
  foreach ($method in $script:Issue13MainMethods) {
    foreach ($arm in @($baseline, $candidate)) {
      if (Test-SupplementalPathOverlap $path ([string]$arm.roots.$method)) {
        throw 'Supplemental worktrees must not overlap scientific worktrees.'
      }
    }
  }
}

$harness = [string]$config.harness_root
$support = Split-Path -Parent $harness
$null = New-Item -ItemType Directory -Path $supplementalRoot -Force
$lock = [IO.File]::Open((Join-Path $supplementalRoot 'controller.lock'),
  [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)

function Save-SupplementalState {
  $state.updated_at = [DateTime]::UtcNow.ToString('o')
  $null = Write-Issue13MainJson $state $statePath
}

function Initialize-SupplementalProcessJournal {
  if ($state.Contains('process_journal')) { return }
  # Retain a fixed, conservative interval for pre-journal history. Future calls
  # must never extend that legacy interval over unrelated completed science.
  $state.process_journal = [ordered]@{
    schema = 'wlv-issue13-supplemental-process-journal/1'
    complete_from_inception = [string]::IsNullOrWhiteSpace([string]$state.updated_at)
    legacy_finished_at_utc = $state.updated_at
    records = @()
  }
}

function Restore-SupplementalProcessState {
  if ($null -eq $state.current) { return }
  if (-not $state.current.Contains('process_started_at_utc')) {
    throw 'Prior supplemental process lacks a start-time identity.'
  }
  $process = Get-Process -Id ([long]$state.current.pid) -ErrorAction SilentlyContinue
  if ($null -ne $process -and
      $process.StartTime.ToUniversalTime().ToString('o') -ceq
        [string]$state.current.process_started_at_utc) {
    throw "A prior supplemental process is still active: $($state.current.pid)"
  }
  $state.abandoned_processes = @($state.abandoned_processes) + @(
    [ordered]@{
      step = $state.current.step; pid = $state.current.pid
      process_started_at_utc = $state.current.process_started_at_utc
      log = $state.current.log; status = 'abandoned'
      recorded_at_utc = [DateTime]::UtcNow.ToString('o')
    })
  if ($state.current.Contains('journal_id')) {
    $record = @($state.process_journal.records | Where-Object id -CEQ $state.current.journal_id)
    if ($record.Count -ne 1) { throw 'Abandoned process journal identity is missing.' }
    # The exact end of an interrupted process tree is unknown. Leave the end
    # open, so timing reuse cannot silently treat an abandoned run as isolated.
    $record[0].status = 'abandoned'
  }
  $state.current = $null
  Save-SupplementalState
}

function Assert-SupplementalPassedFile([string]$Path, [string]$Schema = '') {
  $document = Read-Issue13MainJson $Path
  if (($Schema -and [string]$document.schema -cne $Schema) -or
      -not (Test-Issue13MainExactBoolean $document.passed $true) -or
      ($document.PSObject.Properties.Name -contains 'status' -and
       [string]$document.status -cne 'passed')) {
    throw "Supplemental evidence failed: $Path"
  }
  $document
}

function Invoke-SupplementalProcess(
  [string]$Name, [string]$Executable, [string[]]$Arguments,
  [int]$TimeoutSeconds = 30000
) {
  $logRoot = Join-Path $supplementalRoot 'logs'
  $null = New-Item -ItemType Directory -Path $logRoot -Force
  $log = Join-Path $logRoot ($Name + '-' + [Guid]::NewGuid().ToString('N'))
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = $Executable
  $start.WorkingDirectory = $supplementalRoot
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  foreach ($argument in $Arguments) { $start.ArgumentList.Add($argument) }
  Set-Issue13MainChildEnvironment $start $config
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $start
  $stdout = [IO.File]::Create($log + '.stdout.log')
  $stderr = [IO.File]::Create($log + '.stderr.log')
  $started = $false
  $journal = $null
  $passed = $false
  try {
    $null = $process.Start()
    $started = $true
    $journal = [ordered]@{
      id = [IO.Path]::GetFileName($log); action = $Action; step = $Name
      pid = $process.Id; log = $log; status = 'running'; exit_code = $null
      process_started_at_utc = $process.StartTime.ToUniversalTime().ToString('o')
      finished_at_utc = $null
    }
    $state.process_journal.records = @($state.process_journal.records) + @($journal)
    $state.current = [ordered]@{
      step = $Name; pid = $process.Id; log = $log
      process_started_at_utc = $journal.process_started_at_utc; journal_id = $journal.id
    }
    Save-SupplementalState
    $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
    $errCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while (-not $process.WaitForExit(1000)) {
      if ($watch.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
        $process.Kill($true)
        $process.WaitForExit()
        throw "Supplemental process timed out: $Name; logs: $log"
      }
    }
    $null = $outCopy.GetAwaiter().GetResult()
    $null = $errCopy.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0) {
      throw "Supplemental process failed ($($process.ExitCode)): $Name; logs: $log"
    }
    $passed = $true
  } finally {
    try {
      if ($started -and -not $process.HasExited) {
        $process.Kill($true)
        if (-not $process.WaitForExit(60000)) {
          throw 'Supplemental child did not stop; its journal interval remains open.'
        }
      }
      if ($null -ne $journal -and $process.HasExited) {
        $journal.finished_at_utc = $process.ExitTime.ToUniversalTime().ToString('o')
        $journal.exit_code = $process.ExitCode
        $journal.status = if ($passed) { 'passed' } else { 'failed' }
        $state.current = $null
        Save-SupplementalState
      }
    } finally {
      $stdout.Dispose()
      $stderr.Dispose()
      $process.Dispose()
    }
  }
}

function Invoke-SupplementalR([string]$Name, [string]$Script, [string[]]$Arguments) {
  Invoke-SupplementalProcess $Name ([string]$config.rscript) `
    ([string[]]@('--vanilla', $Script) + $Arguments)
}

function Invoke-SupplementalPwsh([string]$Name, [string]$Script, [string[]]$Arguments) {
  Invoke-SupplementalProcess $Name ([string]$config.sealed_pwsh) `
    ([string[]]@('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $Script) + $Arguments)
}

function Assert-SupplementalBinding {
  $bindingPath = Join-Path $supplementalRoot 'tooling-binding.json'
  if (-not (Test-Path -LiteralPath $bindingPath)) {
    $files = @(
      'issue13-build-prep-fault-specs.R', 'issue13-audit-prep-fault-plan.R',
      'issue13-run-prep-fault-record.ps1', 'issue13-import-fault-inputs.R',
      'issue13-build-fault-seed-specs.R', 'issue13-run-fault-seed-record.ps1',
      'issue13-aggregate-prep-fault.R', 'issue13-scenario.R', 'issue13-lib.R',
      'issue13-matrix.R', 'issue13-monitor.ps1', 'issue13-seed-channel.R',
      'issue13-compare-results.R', 'issue13-compare-lib.R',
      'issue13-v5-difference-fingerprint.R', 'issue13-v5-compare-override.R',
      'issue13-v5-diagnostics-override.R',
      'issue13-v5-preparation-equivalence.R', 'issue13-v5-preparation-equivalence.json'
    ) | ForEach-Object { Join-Path $harness $_ }
    $files += @(
      'issue13-preparation-compare.R', 'issue13-prep-paper-lib.R',
      'issue13-preparation-auth-lib.R', 'issue13-preparation-rule-matrix.json'
    ) | ForEach-Object { Join-Path $support $_ }
    $files += @($ConfigPath, [string]$config.source_v5_config,
      [string]$config.harness_manifest, $baseline.binding_path, $candidate.binding_path,
      $PSCommandPath, (Join-Path $PSScriptRoot 'issue13-main-lib.ps1'),
      [string]$config.rscript, [string]$config.sealed_pwsh, [string]$config.git)
    $records = @($files | ForEach-Object {
      [ordered]@{ path = [IO.Path]::GetFullPath($_); sha256 = Get-Issue13MainSha256 $_ }
    })
    $binding = [ordered]@{
      schema = 'wlv-issue13-main-supplemental-binding/1'
      campaign_id = [string]$config.campaign_id
      records = $records
    }
    $null = Write-Issue13MainJson $binding $bindingPath
  }
  $binding = Read-Issue13MainJson $bindingPath
  if ([string]$binding.campaign_id -cne [string]$config.campaign_id) {
    throw 'Supplemental campaign binding changed.'
  }
  foreach ($record in $binding.records) {
    if ((Get-Issue13MainSha256 ([string]$record.path)) -cne [string]$record.sha256) {
      throw "Supplemental binding changed: $($record.path)"
    }
  }
}

function Get-SupplementalPlan {
  $planRoot = Join-Path $supplementalRoot 'plan'
  $planPath = Join-Path $planRoot 'plan.json'
  if (-not (Test-Path -LiteralPath $planPath)) {
    Invoke-SupplementalR 'build-plan' (Join-Path $harness 'issue13-build-prep-fault-specs.R') @(
      '--output-root', $planRoot,
      '--baseline-root', [string]$roots.baseline_preparation,
      '--baseline-commit', [string]$baseline.commit,
      '--candidate-root', [string]$roots.candidate_preparation,
      '--candidate-commit', [string]$candidate.commit,
      '--fault-root', [string]$roots.candidate_fault,
      '--r-library', [string]$config.r_library,
      '--channel-prefix', ('i13-main-' + ([string]$candidate.commit).Substring(0, 8) + '-')
    )
  }
  $auditPath = Join-Path $planRoot 'plan-audit.json'
  if (-not (Test-Path -LiteralPath $auditPath)) {
    Invoke-SupplementalR 'audit-plan' (Join-Path $harness 'issue13-audit-prep-fault-plan.R') @($planPath)
  }
  $audit = Assert-SupplementalPassedFile $auditPath 'wlv-issue13-prep-fault-plan-audit/2'
  $plan = Read-Issue13MainJson $planPath
  if ($plan.schema -cne 'wlv-issue13-prep-fault-plan/2' -or
      @($plan.records).Count -ne 12 -or
      [string]$audit.plan_sha256 -cne (Get-Issue13MainSha256 $planPath)) {
    throw 'Supplemental plan failed its audit binding.'
  }
  if ($state.plan_sha256 -and
      [string]$state.plan_sha256 -cne (Get-Issue13MainSha256 $planPath)) {
    throw 'Supplemental plan changed after it was recorded.'
  }
  $state.plan_path = $planPath
  $state.plan_sha256 = Get-Issue13MainSha256 $planPath
  Save-SupplementalState
  $plan
}

function Invoke-SupplementalScenario([object]$Record) {
  $id = [string]$Record.scenario_id
  foreach ($binding in @(
      @($Record.scenario_spec_path, $Record.scenario_spec_sha256),
      @($Record.process_spec_path, $Record.process_spec_sha256))) {
    if ((Get-Issue13MainSha256 ([string]$binding[0])) -cne [string]$binding[1]) {
      throw "Audited scenario specification changed: $id"
    }
  }
  $resultPath = Join-Path ([string]$Record.evidence_directory) 'scenario-result.json'
  if (-not (Test-Path -LiteralPath $resultPath)) {
    Invoke-SupplementalPwsh (Get-Issue13MainSafeId $id) `
      (Join-Path $harness 'issue13-run-prep-fault-record.ps1') @(
        '-PlanPath', [string]$state.plan_path, '-ScenarioId', $id)
  }
  $proof = Test-Issue13MainScenarioEvidence ([string]$Record.evidence_directory) `
    $id ([string]$Record.expected_commit) 0
  if ($state.scenarios.Contains($id) -and
      ([string]$state.scenarios[$id].scenario_result_sha256 -cne $proof.result_sha256 -or
       [string]$state.scenarios[$id].process_metrics_sha256 -cne $proof.metrics_sha256)) {
    throw "Recorded scenario evidence changed: $id"
  }
  if ($id.StartsWith('candidate/fault/')) {
    $faultResult = Assert-SupplementalPassedFile `
      (Join-Path ([string]$Record.evidence_directory) 'fault-result.json')
    if ([string]$faultResult.scenario_id -cne $id -or
        [string]$faultResult.fault_id -cne $id.Substring('candidate/fault/'.Length)) {
      throw "Fault evidence identity changed: $id"
    }
    foreach ($name in @('injected', 'expected_failure_observed',
        'expected_error_matched', 'channel_marker_unchanged',
        'no_partial_release_visible', 'staging_clean',
        'preparation_staging_clean', 'normalized_generation_unchanged',
        'previous_release_verified')) {
      if (-not (Test-Issue13MainExactBoolean $faultResult.$name $true)) {
        throw "Fault evidence failed $name`: $id"
      }
    }
  }
  $state.scenarios[$id] = [ordered]@{
    status = 'passed'; evidence_directory = [string]$Record.evidence_directory
    scenario_result_sha256 = $proof.result_sha256
    process_metrics_sha256 = $proof.metrics_sha256
  }
  Save-SupplementalState
}

function Invoke-SupplementalPreparation {
  $cachePath = Join-Path $supplementalRoot 'raw-cache-equality.json'
  if (-not (Test-Path -LiteralPath $cachePath)) {
    # R string literals are serialized, so paths never become executable code.
    $literal = { param($Value) ConvertTo-Json -InputObject ([string]$Value) -Compress }
    $code = 'sys.source(' + (& $literal (Join-Path $support 'issue13-prep-paper-lib.R')) +
      ',envir=environment()); a<-wlv_gate_verify_raw_caches(' +
      (& $literal $roots.baseline_preparation) + '); b<-wlv_gate_verify_raw_caches(' +
      (& $literal $roots.candidate_preparation) + '); stopifnot(a$passed,b$passed,' +
      'length(a$records)==6L,identical(a$records,b$records)); wlv_gate_write_json(' +
      'list(schema="wlv-issue13-main-raw-caches/1",passed=TRUE,baseline=a,candidate=b),' +
      (& $literal $cachePath) + ')'
    Invoke-SupplementalProcess 'raw-cache-equality' ([string]$config.rscript) @('--vanilla', '-e', $code)
  }
  $null = Assert-SupplementalPassedFile $cachePath 'wlv-issue13-main-raw-caches/1'
  foreach ($id in @('baseline/prepare/all', 'candidate/prepare/all')) {
    $record = @($plan.records | Where-Object scenario_id -CEQ $id)
    if ($record.Count -ne 1) { throw "Preparation record is missing: $id" }
    Invoke-SupplementalScenario $record[0]
  }
}

function Invoke-SupplementalComparison {
  foreach ($arm in @('baseline', 'candidate')) {
    if (-not $state.scenarios.Contains("$arm/prepare/all")) {
      throw 'Both preparation scenarios must pass before comparison.'
    }
  }
  $baseEvidence = [string]$state.scenarios['baseline/prepare/all'].evidence_directory
  $candEvidence = [string]$state.scenarios['candidate/prepare/all'].evidence_directory
  $output = Join-Path $supplementalRoot 'preparation-comparison'
  $reportPath = Join-Path $output 'issue13-preparation-comparison.json'
  if (-not (Test-Path -LiteralPath $reportPath)) {
    Invoke-SupplementalR 'preparation-comparison' (Join-Path $support 'issue13-preparation-compare.R') @(
      [string]$roots.baseline_preparation, [string]$roots.candidate_preparation,
      $output, [string]$baseline.commit, [string]$candidate.commit, '1000000',
      (Join-Path $baseEvidence 'process-metrics.json'), (Join-Path $candEvidence 'process-metrics.json'),
      (Join-Path $baseEvidence 'scenario-result.json'), (Join-Path $candEvidence 'scenario-result.json'),
      [string]$config.r_library, [string]$state.plan_path)
  }
  $report = Read-Issue13MainJson $reportPath
  if ([string]$report.status -cne 'passed' -or
      -not (Test-Issue13MainExactBoolean $report.raw_caches.identical $true) -or
      -not (Test-Issue13MainExactBoolean $report.performance.elapsed_passed $true)) {
    throw 'Preparation comparison failed.'
  }
  if ($null -ne $state.preparation_comparison -and
      [string]$state.preparation_comparison.sha256 -cne (Get-Issue13MainSha256 $reportPath)) {
    throw 'Recorded preparation comparison changed.'
  }
  $state.preparation_comparison = [ordered]@{
    path = $reportPath; sha256 = Get-Issue13MainSha256 $reportPath; status = 'passed'
  }
  foreach ($source in @('wiodr13', 'wiodr16', 'euklems')) {
    $selector = if ($source -ceq 'euklems') { 'snapshot:euklems' } else { 'source:' + $source }
    $mode = if ($source -ceq 'euklems') { 'strict' } else { 'cross_engine_source_v1' }
    $id = 'parity/prepare/' + $source
    $directory = Join-Path (Join-Path $supplementalRoot 'comparisons') $source
    $path = Join-Path $directory 'comparison.json'
    if (-not (Test-Path -LiteralPath $path)) {
      Invoke-SupplementalR ('compare-' + $source) (Join-Path $harness 'issue13-compare-results.R') @(
        '--candidate-result', (Join-Path $candEvidence 'scenario-result.json'),
        '--candidate-selector', $selector,
        '--baseline-result', (Join-Path $baseEvidence 'scenario-result.json'),
        '--baseline-selector', $selector, '--output', $directory,
        '--scenario-id', $id, '--comparison-mode', $mode, '--chunk-rows', '1000000')
    }
    $comparison = Assert-SupplementalPassedFile $path
    if ([string]$comparison.scenario_id -cne $id -or [string]$comparison.comparison_mode -cne $mode) {
      throw "Preparation comparison identity changed: $id"
    }
    foreach ($armEvidence in @(
        @('baseline', $baseEvidence), @('candidate', $candEvidence))) {
      $scenario = Read-Issue13MainJson (Join-Path ([string]$armEvidence[1]) 'scenario-result.json')
      $kind = if ($source -ceq 'euklems') { 'snapshot' } else { 'source' }
      $selected = @($scenario.outputs | Where-Object {
        [string]$_.kind -ceq $kind -and [string]$_.source -ceq $source
      })
      $armName = [string]$armEvidence[0]
      if ($selected.Count -ne 1 -or
          [string]$comparison.$armName.manifest_sha256 -cne [string]$selected[0].manifest_sha256) {
        throw "Preparation comparison manifest differs: $id/$armName"
      }
    }
    if ($state.comparisons.Contains($id) -and
        [string]$state.comparisons[$id].sha256 -cne (Get-Issue13MainSha256 $path)) {
      throw "Recorded comparison changed: $id"
    }
    $state.comparisons[$id] = [ordered]@{ path = $path; sha256 = Get-Issue13MainSha256 $path }
  }
  Save-SupplementalState
}

function Invoke-SupplementalFaults {
  if ($null -eq $state.preparation_comparison) { throw 'Faults require preparation comparison.' }
  $mainState = Read-Issue13MainJson (Join-Path ([string]$config.control_root) 'state.json')
  $phase = @($mainState.phases | Where-Object phase -CEQ 'calculate/wiodr13/workers1')
  if ($phase.Count -ne 1) { throw 'The candidate WIOD13 calculation seed is missing.' }
  $seedResult = Get-Issue13MainScenarioResult $phase[0].candidate
  $inputRoot = Join-Path $supplementalRoot 'fault-inputs'
  $importPath = Join-Path $inputRoot 'fault-input-import.json'
  if (-not (Test-Path -LiteralPath $importPath)) {
    Invoke-SupplementalR 'import-fault-inputs' (Join-Path $harness 'issue13-import-fault-inputs.R') @(
      '--prepared-root', [string]$roots.candidate_preparation,
      '--preparation-comparison', [string]$state.preparation_comparison.path,
      '--seed-project-root', [string]$candidate.roots.wiodr13,
      '--seed-result', $seedResult, '--seed-commit', [string]$candidate.commit,
      '--fault-root', [string]$roots.candidate_fault,
      '--candidate-commit', [string]$candidate.commit,
      '--method', 'wiodr13', '--output', $inputRoot)
  }
  $null = Assert-SupplementalPassedFile $importPath 'wlv-issue13-fault-input-import/1'
  $seedRoot = Join-Path $supplementalRoot 'fault-seeds'
  $seedPlanPath = Join-Path $seedRoot 'seed-plan.json'
  if (-not (Test-Path -LiteralPath $seedPlanPath)) {
    Invoke-SupplementalR 'build-fault-seeds' (Join-Path $harness 'issue13-build-fault-seed-specs.R') @(
      '--plan', [string]$state.plan_path, '--import-report', $importPath, '--output', $seedRoot)
  }
  $seedPlan = Read-Issue13MainJson $seedPlanPath
  if ($seedPlan.schema -cne 'wlv-issue13-fault-seed-plan/1' -or @($seedPlan.records).Count -ne 10) {
    throw 'Fault seed plan must contain exactly ten records.'
  }
  foreach ($seed in $seedPlan.records) {
    foreach ($binding in @(
        @($seed.seed_spec_path, $seed.seed_spec_sha256),
        @($seed.process_spec_path, $seed.process_spec_sha256))) {
      if ((Get-Issue13MainSha256 ([string]$binding[0])) -cne [string]$binding[1]) {
        throw "Fault seed specification changed: $($seed.scenario_id)"
      }
    }
    $path = Join-Path ([string]$seed.evidence_directory) 'seed-result.json'
    if (-not (Test-Path -LiteralPath $path)) {
      Invoke-SupplementalPwsh (Get-Issue13MainSafeId ([string]$seed.scenario_id)) `
        (Join-Path $harness 'issue13-run-fault-seed-record.ps1') @(
          '-SeedPlanPath', $seedPlanPath, '-ScenarioId', [string]$seed.scenario_id)
    }
    $seedResult = Assert-SupplementalPassedFile $path 'wlv-issue13-channel-seed-result/1'
    if ([string]$seedResult.scenario_id -cne [string]$seed.scenario_id -or
        [string]$seedResult.expected_commit -cne [string]$candidate.commit -or
        [string]$seedResult.expected_seed_commit -cne [string]$seedPlan.seed_commit -or
        [string]$seedResult.channel -cne [string]$seed.channel) {
      throw "Fault seed evidence identity changed: $($seed.scenario_id)"
    }
    foreach ($binding in @(
        @($seedResult.seed_proof_path, $seedResult.seed_proof_sha256),
        @($seedResult.release_manifest_path, $seedResult.release_manifest_sha256),
        @($seedResult.marker_path, $seedResult.marker_sha256))) {
      if ((Get-Issue13MainSha256 ([string]$binding[0])) -cne [string]$binding[1]) {
        throw "Fault seed evidence hash changed: $($seed.scenario_id)"
      }
    }
    $metrics = Assert-SupplementalPassedFile (Join-Path ([string]$seed.evidence_directory) 'process-metrics.json')
    if ([string]$metrics.schema -cne 'wlv-issue13-process-metrics/2' -or
        [string]$metrics.scenario_id -cne [string]$seed.scenario_id -or
        [long]$metrics.expected_worker_processes -ne 0 -or
        [long]$metrics.max_concurrent_worker_processes -ne 0 -or
        -not (Test-Issue13MainExactBoolean $metrics.worker_count_matched $true) -or
        -not (Test-Issue13MainExactBoolean $metrics.cluster_closed $true) -or
        @($metrics.lingering_pids).Count) {
      throw "Fault seed left child processes: $($seed.scenario_id)"
    }
  }
  foreach ($fault in $script:Issue13MainFaults) {
    $id = 'candidate/fault/' + $fault
    $record = @($plan.records | Where-Object scenario_id -CEQ $id)
    if ($record.Count -ne 1) { throw "Fault record is missing: $id" }
    Invoke-SupplementalScenario $record[0]
  }
  $aggregateRoot = Join-Path $supplementalRoot 'aggregate'
  $aggregatePath = Join-Path $aggregateRoot 'prep-fault-aggregate.json'
  if (-not (Test-Path -LiteralPath $aggregatePath)) {
    Invoke-SupplementalR 'aggregate' (Join-Path $harness 'issue13-aggregate-prep-fault.R') @(
      '--plan', [string]$state.plan_path,
      '--preparation-comparison', [string]$state.preparation_comparison.path,
      '--import-report', $importPath, '--seed-plan', $seedPlanPath, '--output', $aggregateRoot)
  }
  $aggregate = Assert-SupplementalPassedFile $aggregatePath 'wlv-issue13-prep-fault-aggregate/1'
  if ([long]$aggregate.summary.fault_gates_passed -ne 10 -or
      [long]$aggregate.summary.rollback_gates_passed -ne 10 -or
      [long]$aggregate.summary.visible_partial_releases -ne 0 -or
      [long]$aggregate.summary.staging_entries -ne 0) {
    throw 'The supplemental aggregate did not close all transaction gates.'
  }
  $state.aggregate = [ordered]@{ path = $aggregatePath; sha256 = Get-Issue13MainSha256 $aggregatePath }
  $state.status = 'passed'
  Save-SupplementalState
}

try {
  $state = if (Test-Path -LiteralPath $statePath) {
    Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 |
      ConvertFrom-Json -AsHashtable -DateKind String
  } else {
    [ordered]@{
      schema = 'wlv-issue13-main-supplemental/1'; campaign_id = [string]$config.campaign_id
      status = 'initialized'; current = $null; updated_at = $null
      abandoned_processes = @()
      plan_path = $null; plan_sha256 = $null; preparation_comparison = $null
      scenarios = [ordered]@{}; comparisons = [ordered]@{}; aggregate = $null; failure = $null
    }
  }
  Assert-SupplementalBinding
  Initialize-SupplementalProcessJournal
  Restore-SupplementalProcessState
  $state.status = 'running'
  $state.failure = $null
  $plan = Get-SupplementalPlan
  if ($Action -cin @('Prepare', 'RunAll')) { Invoke-SupplementalPreparation }
  if ($Action -cin @('Compare', 'RunAll')) { Invoke-SupplementalComparison }
  if ($Action -cin @('Faults', 'RunAll')) { Invoke-SupplementalFaults }
  if ($state.status -cne 'passed') {
    $state.status = switch ($Action) {
      'Prepare' { 'prepared' }
      'Compare' { 'compared' }
      default { 'initialized' }
    }
  }
  Save-SupplementalState
  Write-Output "Supplemental action completed: $Action; state: $statePath"
} catch {
  if (Get-Variable -Name state -ErrorAction SilentlyContinue) {
    $state.status = 'failed'
    $state.failure = $_.Exception.Message
    Save-SupplementalState
  }
  throw
} finally {
  $lock.Dispose()
}
