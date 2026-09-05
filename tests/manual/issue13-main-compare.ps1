param(
  [Parameter(Mandatory = $true)][string]$ConfigPath,
  [Parameter(Mandatory = $true)][string]$ComparisonBindingPath,
  [string]$ArrayProofBindingPath,
  [ValidateRange(1, 2)][int]$MaxJobs = 2,
  [ValidateRange(1, 10)][int]$MaxAttempts = 1
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'issue13-main-lib.ps1')
. (Join-Path $PSScriptRoot 'issue13-main-comparison-binding.ps1')
. (Join-Path $PSScriptRoot 'issue13-main-array-proof-binding.ps1')

function Save-CompareState([object]$State, [string]$Path) {
  $State.revision = [long]$State.revision + 1L
  $State.updated_at_utc = [DateTime]::UtcNow.ToString('o')
  $null = Write-Issue13MainJson $State $Path
}

function Find-MainPhase([object]$State, [string]$Name) {
  $matches = @($State.phases | Where-Object phase -CEQ $Name)
  if ($matches.Count -ne 1) { throw "Phase lookup failed: $Name" }
  $matches[0]
}

function Find-MainComparison([object]$State, [string]$Id) {
  $matches = @($State.comparisons | Where-Object id -CEQ $Id)
  if ($matches.Count -ne 1) { throw "Comparison lookup failed: $Id" }
  $matches[0]
}

function Get-ComparisonInputs([object]$State, [object]$Comparison) {
  $phase = Find-MainPhase $State ([string]$Comparison.phase)
  $selector = 'run:' + [string]$phase.method
  if ([string]$Comparison.kind -ceq 'parity') {
    return [ordered]@{
      candidate_result = Get-Issue13MainScenarioResult $phase.candidate
      candidate_selector = $selector
      baseline_result = Get-Issue13MainScenarioResult $phase.baseline
      baseline_selector = $selector
      input_contracts = @(
        (New-ComparisonInputContract $State $phase 'candidate' 'candidate'),
        (New-ComparisonInputContract $State $phase 'baseline' 'baseline')
      )
    }
  }
  $armName = [string]$Comparison.arm
  $full = Find-MainPhase $State "calculate/$($phase.method)/workers1"
  [ordered]@{
    candidate_result = Get-Issue13MainScenarioResult $phase.$armName
    candidate_selector = $selector
    baseline_result = Get-Issue13MainScenarioResult $full.$armName
    baseline_selector = $selector
    input_contracts = @(
      (New-ComparisonInputContract $State $phase 'candidate' $armName),
      (New-ComparisonInputContract $State $full 'baseline' $armName)
    )
  }
}

function New-ComparisonInputContract(
  [object]$State, [object]$Phase, [string]$Side, [string]$Arm
) {
  [ordered]@{
    side = $Side; arm = $Arm; method = [string]$Phase.method
    scenario_id = $Arm + '/' + [string]$Phase.phase
    commit = [string]$State.arm_bindings.$Arm.commit
    expected_worker_processes = $(if ([long]$Phase.workers -eq 2) { 2L } else { 0L })
  }
}

function Enter-CompareLock([object]$Config) {
  $path = Join-Path ([string]$Config.control_root) '.issue13-main-lock'
  if (Test-Path -LiteralPath $path) {
    $ownerPath = Join-Path $path 'owner.json'
    $active = $false
    if (Test-Path -LiteralPath $ownerPath -PathType Leaf) {
      try {
        $owner = Read-Issue13MainJson $ownerPath
        $process = Get-Process -Id ([long]$owner.pid) -ErrorAction SilentlyContinue
        $active = $null -ne $process -and
          $process.StartTime.ToUniversalTime().ToString('o') -ceq
            [string]$owner.process_started_at_utc
      } catch { $active = $false }
    }
    if ($active) { throw "Reduced gate lock is active: $path" }
    $orphanRoot = Join-Path ([string]$Config.control_root) 'orphan-locks'
    $null = New-Item -ItemType Directory -Path $orphanRoot -Force
    $orphan = Join-Path $orphanRoot (
      'comparison-orphan-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))
    [IO.Directory]::Move($path, $orphan)
  }
  $null = New-Item -ItemType Directory -Path $path
  $null = Write-Issue13MainJson ([ordered]@{
    schema = 'wlv-issue13-main-lock/1'; pid = [long]$PID
    process_started_at_utc =
      (Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')
    action = 'CompareScience'; acquired_at_utc = [DateTime]::UtcNow.ToString('o')
  }) (Join-Path $path 'owner.json')
  $path
}

function Test-ComparisonProcessActive([object]$Attempt) {
  if ($null -eq $Attempt.pid -or [string]::IsNullOrWhiteSpace(
      [string]$Attempt.process_started_at_utc)) { return $false }
  $process = Get-Process -Id ([long]$Attempt.pid) -ErrorAction SilentlyContinue
  $null -ne $process -and
    $process.StartTime.ToUniversalTime().ToString('o') -ceq
      [string]$Attempt.process_started_at_utc
}

function Assert-NoComparisonDescendants([object]$Attempt) {
  $ids = [Collections.Generic.HashSet[uint32]]::new()
  $null = $ids.Add([uint32][long]$Attempt.pid)
  $processes = @(Get-CimInstance Win32_Process)
  $changed = $true
  while ($changed) {
    $changed = $false
    foreach ($process in $processes) {
      if (-not $ids.Contains([uint32]$process.ProcessId) -and
          $ids.Contains([uint32]$process.ParentProcessId)) {
        $null = $ids.Add([uint32]$process.ProcessId); $changed = $true
      }
    }
  }
  $descendants = @($ids | Where-Object { [long]$_ -ne [long]$Attempt.pid })
  if ($descendants.Count -ne 0) {
    throw ('A prior comparison worker still has live descendants: ' +
      [string]::Join(', ', $descendants))
  }
}

function Get-BoundComparisonJob(
  [object]$Config,
  [object]$State,
  [object]$Comparison,
  [object]$Attempt
) {
  $jobPath = ConvertTo-Issue13MainFullPath ([string]$Attempt.job_path) `
    -RequireExistingFile
  if ((Get-Issue13MainSha256 $jobPath) -cne [string]$Attempt.job_sha256) {
    throw 'A comparison job changed after scheduling.'
  }
  $job = Read-Issue13MainJson $jobPath
  Assert-Issue13MainArrayProofSelection $job $script:resolvedArrayProofBinding $script:arrayProofBindingSha256
  Assert-Issue13MainArrayProofSelection $Attempt $script:resolvedArrayProofBinding $script:arrayProofBindingSha256
  if ($script:resolvedArrayProofBinding) {
    $null = Assert-Issue13MainArrayProofBinding $script:resolvedArrayProofBinding `
      $script:arrayProofBindingSha256 $job.config_path $script:resolvedComparisonBinding
  }
  $null = Assert-Issue13MainComparisonBindingIdentity $job $Attempt `
    $script:resolvedComparisonBinding $script:comparisonBindingSha256
  $safe = Get-Issue13MainSafeId ([string]$Comparison.id)
  $attemptName = 'attempt-' + ([long]$Attempt.attempt).ToString('0000')
  $expectedAttemptRoot = Join-Path (Join-Path (Join-Path `
    ([string]$Config.control_root) 'comparison-attempts') $safe) $attemptName
  $expectedOutput = Join-Path (Join-Path (Join-Path `
    ([string]$Config.evidence_root) 'comparison-attempts') $safe) $attemptName
  $inputs = Get-ComparisonInputs $State $Comparison
  if ($Comparison.allow_difference -isnot [bool] -or
      $job.schema -cne 'wlv-issue13-main-comparison-job/2' -or
      [string]$job.comparison_id -cne [string]$Comparison.id -or
      [long]$job.attempt -ne [long]$Attempt.attempt -or
      [string]$job.mode -cne [string]$Comparison.mode -or
      $job.allow_difference -isnot [bool] -or
      $job.allow_difference -ne $Comparison.allow_difference -or
      -not (Test-Issue13MainSamePath ([string]$job.attempt_root) `
        $expectedAttemptRoot) -or
      -not (Test-Issue13MainSamePath ([string]$job.output_directory) `
        $expectedOutput) -or
      -not (Test-Issue13MainSamePath ([string]$job.candidate_result) `
        ([string]$inputs.candidate_result)) -or
      -not (Test-Issue13MainSamePath ([string]$job.baseline_result) `
        ([string]$inputs.baseline_result)) -or
      [string]$job.candidate_selector -cne
        [string]$inputs.candidate_selector -or
      [string]$job.baseline_selector -cne
        [string]$inputs.baseline_selector -or
      [string]$job.config_sha256 -cne [string]$State.config_sha256 -or
      [string]$job.tooling_binding_sha256 -cne
        [string]$State.tooling_binding_sha256 -or
      -not (Test-Issue13MainSamePath ([string]$Attempt.result_path) `
        (Join-Path $expectedAttemptRoot 'attempt-result.json'))) {
    throw "Comparison job identity differs: $($Comparison.id)"
  }
  foreach ($side in @('candidate', 'baseline')) {
    if ((Get-Issue13MainSha256 ([string]$job.($side + '_result'))) -cne
        [string]$job.($side + '_result_sha256')) {
      throw "Comparison input changed: $side/$($Comparison.id)"
    }
  }
  if ((ConvertTo-Json -InputObject $job.input_contracts -Depth 8 -Compress) -cne
      (ConvertTo-Json -InputObject $inputs.input_contracts -Depth 8 -Compress)) {
    throw 'Comparison input contracts differ from the scientific plan.'
  }
  $null = Assert-Issue13MainComparisonInputs $job $Config
  $null = Assert-Issue13MainControllerSnapshots `
    ([object[]]$job.controller_records)
  $null = Assert-Issue13MainComparisonBinding `
    ([string]$job.comparison_binding_path) `
    ([string]$job.comparison_binding_sha256) $Config
  $job
}

function Get-ValidatedComparisonResult(
  [object]$Config,
  [object]$State,
  [object]$Comparison,
  [object]$Attempt
) {
  $job = Get-BoundComparisonJob $Config $State $Comparison $Attempt
  $resultPath = ConvertTo-Issue13MainFullPath ([string]$Attempt.result_path) `
    -RequireExistingFile
  $result = Read-Issue13MainJson $resultPath
  Assert-Issue13MainArrayProofSelection $result $script:resolvedArrayProofBinding $script:arrayProofBindingSha256
  $comparisonPath = ConvertTo-Issue13MainFullPath `
    (Join-Path ([string]$job.output_directory) 'comparison.json') `
    -RequireExistingFile
  $document = Read-Issue13MainJson $comparisonPath
  if ($result.schema -cne 'wlv-issue13-main-comparison-attempt/2' -or
      [string]$result.comparison_id -cne [string]$job.comparison_id -or
      [long]$result.attempt -ne [long]$job.attempt -or
      [string]$result.status -cne 'passed' -or
      -not (Test-Issue13MainExactBoolean $result.passed $true) -or
      $result.comparison_passed -isnot [bool] -or
      -not (Test-Issue13MainSamePath ([string]$result.job_path) `
        ([string]$Attempt.job_path)) -or
      [string]$result.job_sha256 -cne [string]$Attempt.job_sha256 -or
      [string]$result.config_sha256 -cne [string]$job.config_sha256 -or
      [string]$result.tooling_binding_sha256 -cne
        [string]$job.tooling_binding_sha256 -or
      [string]$result.comparison_binding_sha256 -cne
        [string]$job.comparison_binding_sha256 -or
      -not (Test-Issue13MainSamePath $result.comparison_binding_path `
        $job.comparison_binding_path) -or
      -not (Test-Issue13MainSamePath ([string]$result.output_directory) `
        ([string]$job.output_directory)) -or
      -not (Test-Issue13MainControllerRecordEquality `
        ([object[]]$result.controller_records) `
        ([object[]]$job.controller_records)) -or
      $document.schema -cne 'wlv-issue13-artifact-comparison/1' -or
      [string]$document.scenario_id -cne [string]$job.comparison_id -or
      [string]$document.comparison_mode -cne [string]$job.mode -or
      $document.passed -isnot [bool] -or
      $document.passed -ne $result.comparison_passed -or
      ((Test-Issue13MainExactBoolean $job.allow_difference $false) -and
       -not (Test-Issue13MainExactBoolean $document.passed $true)) -or
      (Get-Issue13MainSha256 $comparisonPath) -cne
        [string]$result.comparison_sha256) {
    throw "Comparison result identity differs: $($Comparison.id)"
  }
  [pscustomobject]@{ job = $job; result = $result; path = $comparisonPath }
}

function Start-Comparison(
  [object]$Config,
  [string]$ResolvedConfig,
  [object]$State,
  [string]$StatePath,
  [object]$Comparison
) {
  $attempt = [long]$Comparison.attempt_count + 1L
  $safe = Get-Issue13MainSafeId ([string]$Comparison.id)
  $attemptName = 'attempt-' + $attempt.ToString('0000')
  $attemptRoot = Join-Path (Join-Path (Join-Path `
    ([string]$Config.control_root) 'comparison-attempts') $safe) $attemptName
  $output = Join-Path (Join-Path (Join-Path `
    ([string]$Config.evidence_root) 'comparison-attempts') $safe) $attemptName
  if ((Test-Path -LiteralPath $attemptRoot) -or (Test-Path -LiteralPath $output)) {
    throw "Comparison attempt already exists: $($Comparison.id)/$attempt"
  }
  $null = New-Item -ItemType Directory -Path $attemptRoot
  $inputs = Get-ComparisonInputs $State $Comparison
  if ($Comparison.allow_difference -isnot [bool]) {
    throw "Comparison policy boolean is invalid: $($Comparison.id)"
  }
  $controllerRecords = New-Issue13MainControllerSnapshots $attemptRoot @(
    [pscustomobject]@{ role = 'comparison-scheduler'; path = $PSCommandPath },
    [pscustomobject]@{ role = 'shared-lib'; path =
      (Join-Path $PSScriptRoot 'issue13-main-lib.ps1') },
    [pscustomobject]@{ role = 'comparison-binding-lib'; path =
      (Join-Path $PSScriptRoot 'issue13-main-comparison-binding.ps1') },
    [pscustomobject]@{ role = 'array-proof-binding-lib'; path =
      (Join-Path $PSScriptRoot 'issue13-main-array-proof-binding.ps1') },
    [pscustomobject]@{ role = 'comparison-worker'; path =
      (Join-Path $PSScriptRoot 'issue13-main-compare-worker.ps1') }
  )
  $job = [ordered]@{
    schema = 'wlv-issue13-main-comparison-job/2'
    comparison_id = [string]$Comparison.id
    attempt = $attempt
    attempt_root = $attemptRoot
    output_directory = $output
    mode = [string]$Comparison.mode
    allow_difference = $Comparison.allow_difference
    candidate_result = [string]$inputs.candidate_result
    candidate_result_sha256 = Get-Issue13MainSha256 `
      ([string]$inputs.candidate_result)
    candidate_selector = [string]$inputs.candidate_selector
    baseline_result = [string]$inputs.baseline_result
    baseline_result_sha256 = Get-Issue13MainSha256 `
      ([string]$inputs.baseline_result)
    baseline_selector = [string]$inputs.baseline_selector
    config_path = $ResolvedConfig
    config_sha256 = [string]$State.config_sha256
    tooling_binding_path = [string]$State.tooling_binding_path
    tooling_binding_sha256 = [string]$State.tooling_binding_sha256
    comparison_binding_path = $script:resolvedComparisonBinding
    comparison_binding_sha256 = $script:comparisonBindingSha256
    array_proof_binding_path = $script:resolvedArrayProofBinding
    array_proof_binding_sha256 = $script:arrayProofBindingSha256
    input_contracts = $inputs.input_contracts
    controller_records = [object[]]$controllerRecords
  }
  $jobPath = Join-Path $attemptRoot 'job.json'
  $jobSha = Write-Issue13MainJson $job $jobPath
  $attemptRecord = [pscustomobject][ordered]@{
    attempt = $attempt; status = 'starting'; job_path = $jobPath
    job_sha256 = $jobSha; result_path = Join-Path $attemptRoot `
      'attempt-result.json'; result_sha256 = $null; pid = $null
    process_started_at_utc = $null; exit_code = $null
    comparison_binding_path = $script:resolvedComparisonBinding
    comparison_binding_sha256 = $script:comparisonBindingSha256
    array_proof_binding_path = $script:resolvedArrayProofBinding
    array_proof_binding_sha256 = $script:arrayProofBindingSha256
  }
  $Comparison.attempt_count = $attempt
  $Comparison.status = 'running'
  $Comparison.attempts = [object[]](@($Comparison.attempts) + @($attemptRecord))
  Save-CompareState $State $StatePath
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = [string]$Config.sealed_pwsh
  $info.UseShellExecute = $false; $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
  foreach ($argument in @(
      '-NoLogo', '-NoProfile', '-File',
      (Join-Path $PSScriptRoot 'issue13-main-compare-worker.ps1'),
      '-JobPath', $jobPath)) {
    $null = $info.ArgumentList.Add([string]$argument)
  }
  Set-Issue13MainChildEnvironment $info $Config
  $process = $null
  try {
    $process = [Diagnostics.Process]::Start($info)
    $attemptRecord.status = 'running'; $attemptRecord.pid = [long]$process.Id
    $attemptRecord.process_started_at_utc =
      $process.StartTime.ToUniversalTime().ToString('o')
    Save-CompareState $State $StatePath
    [pscustomobject]@{
      process = $process; stdout = $process.StandardOutput.ReadToEndAsync()
      stderr = $process.StandardError.ReadToEndAsync(); record = $Comparison
      attempt = $attemptRecord; attempt_root = $attemptRoot; completed = $false
    }
  } catch {
    if ($null -ne $process) {
      try {
        if (-not $process.HasExited) { $process.Kill($true) }
        $null = $process.WaitForExit(30000)
      } catch { }
    }
    $attemptRecord.status = 'launch-failed'
    $Comparison.status = 'failed'; $Comparison.failure = $_.Exception.Message
    Save-CompareState $State $StatePath
    throw
  }
}

function Complete-Comparison(
  [object]$Config,
  [object]$State,
  [string]$StatePath,
  [object]$Job
) {
  $Job.process.WaitForExit()
  [IO.File]::WriteAllText((Join-Path $Job.attempt_root 'worker.stdout.log'),
    $Job.stdout.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $Job.attempt_root 'worker.stderr.log'),
    $Job.stderr.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
  $Job.attempt.exit_code = [long]$Job.process.ExitCode
  try {
    if ($Job.process.ExitCode -ne 0) {
      throw "Comparison worker exited with code $($Job.process.ExitCode)."
    }
    $validated = Get-ValidatedComparisonResult $Config $State `
      $Job.record $Job.attempt
    $result = $validated.result
    $Job.attempt.status = 'passed'
    $Job.attempt.result_sha256 = Get-Issue13MainSha256 `
      ([string]$Job.attempt.result_path)
    $Job.record.status = 'passed'
    $Job.record.output_directory = [string]$result.output_directory
    $Job.record.comparison_sha256 = [string]$result.comparison_sha256
    $Job.record.passed = $result.comparison_passed
    $Job.record.failure = $null
    $Job.completed = $true
  } catch {
    $Job.attempt.status = 'failed'
    $Job.record.status = 'failed'; $Job.record.failure = $_.Exception.Message
  }
  Save-CompareState $State $StatePath
}

function Stop-IncompleteComparison(
  [object]$State,
  [string]$StatePath,
  [object]$Job
) {
  if (Test-Issue13MainExactBoolean $Job.completed $true) { return }
  if ([long]$Job.process.Id -ne [long]$Job.attempt.pid -or
      $Job.process.StartTime.ToUniversalTime().ToString('o') -cne
        [string]$Job.attempt.process_started_at_utc) {
    throw 'Refusing to stop a comparison worker whose identity changed.'
  }
  $terminated = $false
  if (-not $Job.process.HasExited) {
    $Job.process.Kill($true); $terminated = $true
    if (-not $Job.process.WaitForExit(30000)) {
      throw "Comparison worker did not stop: $($Job.process.Id)"
    }
  }
  [IO.File]::WriteAllText((Join-Path $Job.attempt_root 'worker.stdout.log'),
    $Job.stdout.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $Job.attempt_root 'worker.stderr.log'),
    $Job.stderr.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
  $Job.attempt.status = if ($terminated) { 'coordinator-aborted' } else {
    'failed-cleaned'
  }
  $Job.attempt.exit_code = [long]$Job.process.ExitCode
  $Job.record.status = 'failed'
  if ($terminated -or [string]::IsNullOrWhiteSpace(
      [string]$Job.record.failure)) {
    $Job.record.failure = 'Coordinator aborted this comparison process tree.'
  }
  Save-CompareState $State $StatePath
  $Job.completed = $true
}

function Repair-Comparisons(
  [object]$Config,
  [object]$State,
  [string]$StatePath
) {
  foreach ($record in @($State.comparisons | Where-Object status -CEQ 'running')) {
    $attempt = @($record.attempts)[-1]
    if (Test-ComparisonProcessActive $attempt) {
      throw "A prior comparison worker is still active: $($attempt.pid)"
    }
    Assert-NoComparisonDescendants $attempt
    if (Test-Path -LiteralPath ([string]$attempt.result_path) -PathType Leaf) {
      try {
        $validated = Get-ValidatedComparisonResult $Config $State $record $attempt
        $result = $validated.result
        $attempt.status = 'passed'
        $attempt.result_sha256 = Get-Issue13MainSha256 `
          ([string]$attempt.result_path)
        $record.status = 'passed'; $record.output_directory =
          [string]$result.output_directory
        $record.comparison_sha256 = [string]$result.comparison_sha256
        $record.passed = $result.comparison_passed
        $record.failure = $null
      } catch {
        $attempt.status = 'failed'
        $record.status = 'failed'; $record.failure = $_.Exception.Message
      }
      Save-CompareState $State $StatePath
      continue
    }
    $attempt.status = 'abandoned'
    $record.status = 'failed'; $record.failure = 'Interrupted comparison worker.'
    Save-CompareState $State $StatePath
  }
}

function Complete-OracleDeltas(
  [object]$Config,
  [object]$State,
  [string]$StatePath,
  [int]$AttemptMaximum
) {
  foreach ($phase in @($State.phases | Where-Object kind -CEQ 'recalculate')) {
    $id = 'oracle-delta/' + [string]$phase.phase
    $existing = @($State.oracle_deltas | Where-Object id -CEQ $id)
    $passed = @($existing | Where-Object {
      Test-Issue13MainExactBoolean $_.passed $true
    })
    if ($passed.Count -gt 1) { throw "Duplicate oracle delta success: $id" }
    if ($passed.Count -eq 1) {
      $record = $passed[0]
      $jobPath = ConvertTo-Issue13MainFullPath ([string]$record.job_path) `
        -RequireExistingFile
      if ((Get-Issue13MainSha256 $jobPath) -cne [string]$record.job_sha256) {
        throw "Oracle delta job changed: $id"
      }
      $job = Read-Issue13MainJson $jobPath
      $output = ConvertTo-Issue13MainFullPath ([string]$record.path) `
        -RequireExistingFile
      $document = Read-Issue13MainJson $output
      if ([string]$record.status -cne 'passed' -or
          -not (Test-Issue13MainExactBoolean $record.passed $true) -or
          $job.schema -cne 'wlv-issue13-main-oracle-delta-job/1' -or
          [string]$job.id -cne $id -or
          (Get-Issue13MainSha256 $output) -cne [string]$record.sha256 -or
          $document.schema -cne 'wlv-issue13-main-oracle-delta/1' -or
          [string]$document.id -cne $id -or
          -not (Test-Issue13MainExactBoolean $document.passed $true)) {
        throw "Existing oracle delta is invalid: $id"
      }
      $null = Assert-Issue13MainControllerSnapshots `
        ([object[]]$job.controller_records)
      continue
    }
    if ($existing.Count -ge $AttemptMaximum) {
      throw "No retryable oracle delta remains: $id"
    }
    $baseline = Find-MainComparison $State "oracle/baseline/$($phase.phase)"
    $candidate = Find-MainComparison $State "oracle/candidate/$($phase.phase)"
    $child = Find-MainComparison $State "parity/$($phase.phase)"
    $full = Find-MainComparison $State "parity/calculate/$($phase.method)/workers1"
    $attempt = [long]$existing.Count + 1L
    $attemptName = 'attempt-' + $attempt.ToString('0000')
    $safe = Get-Issue13MainSafeId $id
    $attemptRoot = Join-Path (Join-Path (Join-Path `
      ([string]$Config.control_root) 'oracle-delta-attempts') $safe) `
      $attemptName
    $outputRoot = Join-Path (Join-Path (Join-Path `
      ([string]$Config.evidence_root) 'oracle-delta-attempts') $safe) `
      $attemptName
    if ((Test-Path -LiteralPath $attemptRoot) -or
        (Test-Path -LiteralPath $outputRoot)) {
      throw "Oracle delta attempt path already exists: $id/$attempt"
    }
    $null = New-Item -ItemType Directory -Path $attemptRoot
    $null = New-Item -ItemType Directory -Path $outputRoot
    $output = Join-Path $outputRoot 'oracle-delta.json'
    $inputs = [object[]]@(
      [ordered]@{ role = 'baseline-oracle'; path =
        (Join-Path ([string]$baseline.output_directory) 'comparison.json') },
      [ordered]@{ role = 'candidate-oracle'; path =
        (Join-Path ([string]$candidate.output_directory) 'comparison.json') },
      [ordered]@{ role = 'child-parity'; path =
        (Join-Path ([string]$child.output_directory) 'comparison.json') },
      [ordered]@{ role = 'full-parity'; path =
        (Join-Path ([string]$full.output_directory) 'comparison.json') }
    )
    foreach ($input in $inputs) {
      $input['sha256'] = Get-Issue13MainSha256 ([string]$input.path)
    }
    $controllerRecords = New-Issue13MainControllerSnapshots $attemptRoot @(
      [pscustomobject]@{ role = 'oracle-scheduler'; path = $PSCommandPath },
      [pscustomobject]@{ role = 'shared-lib'; path =
        (Join-Path $PSScriptRoot 'issue13-main-lib.ps1') },
      [pscustomobject]@{ role = 'oracle-wrapper'; path =
        (Join-Path $PSScriptRoot 'issue13-main-oracle-delta.R') }
    )
    $job = [ordered]@{
      schema = 'wlv-issue13-main-oracle-delta-job/1'
      id = $id; attempt = $attempt; output = $output
      config_sha256 = [string]$State.config_sha256
      tooling_binding_sha256 = [string]$State.tooling_binding_sha256
      inputs = $inputs; controller_records = $controllerRecords
    }
    $jobPath = Join-Path $attemptRoot 'job.json'
    $jobSha = Write-Issue13MainJson $job $jobPath
    $record = [pscustomobject][ordered]@{
      id = $id; attempt = $attempt; status = 'running'; passed = $false
      classification = $null; job_path = $jobPath; job_sha256 = $jobSha
      path = $output; sha256 = $null; failure = $null
    }
    $failure = $null
    try {
      $info = [Diagnostics.ProcessStartInfo]::new()
      $info.FileName = [string]$Config.rscript
      $info.UseShellExecute = $false; $info.CreateNoWindow = $true
      $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
      foreach ($argument in @(
          '--vanilla', (Join-Path $PSScriptRoot 'issue13-main-oracle-delta.R'),
          [string]$Config.harness_root,
          [string]$inputs[0].path, [string]$inputs[1].path,
          [string]$inputs[2].path, [string]$inputs[3].path, $id, $output)) {
        $null = $info.ArgumentList.Add([string]$argument)
      }
      Set-Issue13MainChildEnvironment $info $Config
      $process = [Diagnostics.Process]::Start($info)
      $stdoutTask = $process.StandardOutput.ReadToEndAsync()
      $stderrTask = $process.StandardError.ReadToEndAsync()
      if (-not $process.WaitForExit(900000)) {
        $process.Kill($true); $null = $process.WaitForExit(30000)
        throw "Oracle delta timed out: $id"
      }
      [IO.File]::WriteAllText((Join-Path $attemptRoot 'worker.stdout.log'),
        $stdoutTask.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
      [IO.File]::WriteAllText((Join-Path $attemptRoot 'worker.stderr.log'),
        $stderrTask.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
      if ($process.ExitCode -ne 0) { throw "Oracle mismatch: $id" }
      $document = Read-Issue13MainJson $output
      if ($document.schema -cne 'wlv-issue13-main-oracle-delta/1' -or
          [string]$document.id -cne $id -or
          -not (Test-Issue13MainExactBoolean $document.passed $true) -or
          @($document.inputs).Count -ne 4) {
        throw "Invalid oracle delta: $id"
      }
      for ($index = 0; $index -lt 4; $index++) {
        if ([string]$document.inputs[$index].role -cne
              [string]$inputs[$index].role -or
            -not (Test-Issue13MainSamePath `
              ([string]$document.inputs[$index].path) `
              ([string]$inputs[$index].path)) -or
            [string]$document.inputs[$index].sha256 -cne
              [string]$inputs[$index].sha256) {
          throw "Oracle delta input binding differs: $id"
        }
      }
      $record.status = 'passed'; $record.passed = $true
      $record.classification = [string]$document.classification
      $record.sha256 = Get-Issue13MainSha256 $output
    } catch {
      $record.status = 'failed'; $record.failure = $_.Exception.Message
      $failure = $_
    }
    $attemptResult = Join-Path $attemptRoot 'attempt-result.json'
    $null = Write-Issue13MainJson $record $attemptResult
    $record | Add-Member -NotePropertyName attempt_result_path `
      -NotePropertyValue $attemptResult
    $record | Add-Member -NotePropertyName attempt_result_sha256 `
      -NotePropertyValue (Get-Issue13MainSha256 $attemptResult)
    $State.oracle_deltas = [object[]](@($State.oracle_deltas) + @($record))
    Save-CompareState $State $StatePath
    if ($null -ne $failure) { throw $failure }
  }
}

$resolvedConfig = ConvertTo-Issue13MainFullPath $ConfigPath -RequireExistingFile
$config = Read-Issue13MainJson $resolvedConfig
$null = Assert-Issue13MainConfig $config
$script:resolvedComparisonBinding = ConvertTo-Issue13MainFullPath `
  $ComparisonBindingPath -RequireExistingFile
$script:comparisonBindingSha256 = Get-Issue13MainSha256 `
  $script:resolvedComparisonBinding
$null = Assert-Issue13MainComparisonBinding `
  $script:resolvedComparisonBinding $script:comparisonBindingSha256 $config
$script:resolvedArrayProofBinding = $null
$script:arrayProofBindingSha256 = $null
if (-not [string]::IsNullOrWhiteSpace($ArrayProofBindingPath)) {
  $script:resolvedArrayProofBinding = ConvertTo-Issue13MainFullPath $ArrayProofBindingPath -RequireExistingFile
  $script:arrayProofBindingSha256 = Get-Issue13MainSha256 $script:resolvedArrayProofBinding
  $null = Assert-Issue13MainArrayProofBinding $script:resolvedArrayProofBinding `
    $script:arrayProofBindingSha256 $resolvedConfig $script:resolvedComparisonBinding
}
$statePath = ConvertTo-Issue13MainFullPath `
  (Join-Path ([string]$config.control_root) 'state.json') -RequireExistingFile
$state = Read-Issue13MainJson $statePath
if ($state.schema -cne 'wlv-issue13-main-state/1' -or
    (Get-Issue13MainSha256 $resolvedConfig) -cne [string]$state.config_sha256) {
  throw 'Reduced gate state/config binding is invalid.'
}
if (@($state.phases | ForEach-Object { $_.baseline, $_.candidate } |
    Where-Object status -CNE 'passed').Count -ne 0) {
  throw 'All 28 scientific scenarios must pass before comparison.'
}
$binding = Read-Issue13MainJson ([string]$state.tooling_binding_path)
if ((Get-Issue13MainSha256 ([string]$state.tooling_binding_path)) -cne
    [string]$state.tooling_binding_sha256) {
  throw 'Reduced gate tooling binding file changed.'
}
$null = Assert-Issue13MainToolingBinding $binding
$lock = Enter-CompareLock $config
try {
  Assert-Issue13MainArrayProofHistory $state $script:resolvedArrayProofBinding $script:arrayProofBindingSha256
  foreach ($comparison in @($state.comparisons | Where-Object status -CEQ 'passed')) {
    $passed = @($comparison.attempts | Where-Object status -CEQ 'passed')[-1]
    $null = Get-ValidatedComparisonResult $config $state $comparison $passed
  }
  Repair-Comparisons $config $state $statePath
  $effectiveMax = [Math]::Min($MaxJobs, [long]$config.scheduling.comparison_jobs)
  while (@($state.comparisons | Where-Object status -CNE 'passed').Count) {
    $ready = @($state.comparisons | Sort-Object ordinal | Where-Object {
      [string]$_.status -cne 'passed' -and
      [long]$_.attempt_count -lt $MaxAttempts
    } | Select-Object -First $effectiveMax)
    if ($ready.Count -eq 0) { throw 'No retryable scientific comparison remains.' }
    $jobs = [Collections.Generic.List[object]]::new()
    try {
      foreach ($record in $ready) {
        $jobs.Add((Start-Comparison $config $resolvedConfig $state $statePath `
          $record))
      }
      foreach ($job in $jobs) {
        Complete-Comparison $config $state $statePath $job
      }
    } finally {
      $cleanupErrors = [Collections.Generic.List[string]]::new()
      foreach ($job in $jobs) {
        try {
          Stop-IncompleteComparison $state $statePath $job
        } catch {
          $cleanupErrors.Add($_.Exception.Message)
        }
      }
      if ($cleanupErrors.Count -ne 0) {
        throw ('One or more comparison workers could not be cleaned up: ' +
          [string]::Join(' | ', $cleanupErrors))
      }
    }
  }
  Complete-OracleDeltas $config $state $statePath $MaxAttempts
  foreach ($phase in @($state.phases)) {
    $baseline = Test-Issue13MainScenarioEvidence `
      ([string]$phase.baseline.evidence_directory) `
      ("baseline/" + [string]$phase.phase) `
      ([string]$state.arm_bindings.baseline.commit) `
      $(if ([long]$phase.workers -eq 2) { 2L } else { 0L })
    $candidate = Test-Issue13MainScenarioEvidence `
      ([string]$phase.candidate.evidence_directory) `
      ("candidate/" + [string]$phase.phase) `
      ([string]$state.arm_bindings.candidate.commit) `
      $(if ([long]$phase.workers -eq 2) { 2L } else { 0L })
    $performance = Get-Issue13MainPerformance $config $baseline $candidate
    $performance['classification'] = 'observational-under-parallel-load'
    $phase.performance = $performance
    $phase.comparison_status = 'passed'
    $phase.comparisons = [object[]]@($state.comparisons | Where-Object {
      [string]$_.phase -ceq [string]$phase.phase
    } | ForEach-Object {
      [pscustomobject][ordered]@{
        id = [string]$_.id; passed = [bool]$_.passed
        output_directory = [string]$_.output_directory
        comparison_sha256 = [string]$_.comparison_sha256
      }
    })
  }
  $state.status = 'science-validated'
  Save-CompareState $state $statePath
  Write-Output $statePath
} finally {
  if (Test-Path -LiteralPath $lock -PathType Container) {
    [IO.Directory]::Delete($lock, $true)
  }
}
