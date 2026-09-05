param(
  [Parameter(Mandatory)][ValidateSet('Plan', 'Run', 'Status')][string]$Action,
  [Parameter(Mandatory)][string]$ConfigPath,
  [ValidateRange(1, 28)][int]$MaximumRepeats = 28
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'issue13-main-lib.ps1')

function ConvertTo-PerformanceUtc([string]$Value) {
  if ($Value -notmatch '(Z|\+00:00)$') { throw "Missing UTC timestamp: $Value" }
  [DateTimeOffset]::Parse($Value, [Globalization.CultureInfo]::InvariantCulture).UtcDateTime
}

function Test-PerformanceOverlap([object]$Left, [object]$Right) {
  $Left.start -lt $Right.end -and $Right.start -lt $Left.end
}

function Get-PerformanceOverlaps([object]$Interval, [string]$JobPath, [string]$MetricsPath) {
  @($intervals | Where-Object {
    ([string]::IsNullOrEmpty($_.owner) -or
      (-not (Test-Issue13MainSamePath $_.owner $JobPath) -and
       -not (Test-Issue13MainSamePath $_.owner $MetricsPath))) -and
    (Test-PerformanceOverlap $Interval $_)
  } | ForEach-Object id)
}

function Add-PerformanceInterval([string]$Id, [string]$Start, [string]$End,
    [string]$Owner = '') {
  $from = ConvertTo-PerformanceUtc $Start
  $to = ConvertTo-PerformanceUtc $End
  if ($to -lt $from) { throw "Inverted activity interval: $Id" }
  $intervals.Add([pscustomobject]@{ id = $Id; start = $from; end = $to; owner = $Owner })
}

function Get-PerformanceIntervals {
  $script:intervals = [Collections.Generic.List[object]]::new()
  foreach ($phase in @($science.phases)) {
    foreach ($arm in @('baseline', 'candidate')) {
      foreach ($attempt in @($phase.$arm.attempts)) {
        if ([string]::IsNullOrWhiteSpace([string]$attempt.process_started_at_utc)) { continue }
        $end = if (Test-Path -LiteralPath ([string]$attempt.result_path) -PathType Leaf) {
          (Read-Issue13MainJson ([string]$attempt.result_path)).finished_at_utc
        } elseif ([string]$attempt.status -cin @('starting', 'running')) {
          '9999-12-31T23:59:59Z'
        } else { $science.updated_at_utc }
        Add-PerformanceInterval ([string]$attempt.result_path) `
          ([string]$attempt.process_started_at_utc) ([string]$end) ([string]$attempt.job_path)
      }
    }
  }
  foreach ($comparison in @($science.comparisons)) {
    foreach ($attempt in @($comparison.attempts)) {
      if ([string]::IsNullOrWhiteSpace([string]$attempt.process_started_at_utc)) { continue }
      $end = if (Test-Path -LiteralPath ([string]$attempt.result_path) -PathType Leaf) {
        (Read-Issue13MainJson ([string]$attempt.result_path)).finished_at_utc
      } elseif ([string]$comparison.status -ceq 'running') { '9999-12-31T23:59:59Z' } `
        else { $science.updated_at_utc }
      Add-PerformanceInterval ([string]$attempt.result_path) `
        ([string]$attempt.process_started_at_utc) ([string]$end)
    }
  }
  # Include orphan/failed monitor records and auxiliary fault seeds, not just passed jobs.
  foreach ($file in @(Get-ChildItem -LiteralPath ([string]$config.evidence_root) `
      -Filter process-metrics.json -File -Recurse)) {
    $metrics = Read-Issue13MainJson $file.FullName
    Add-PerformanceInterval $file.FullName ([string]$metrics.started_at_utc) `
      ([string]$metrics.finished_at_utc) $file.FullName
  }
  $supplementPath = Join-Path ([string]$config.control_root) 'supplemental/state.json'
  if (Test-Path -LiteralPath $supplementPath -PathType Leaf) {
    $supplement = Read-Issue13MainJson $supplementPath
    # Supplemental comparator/importer calls have no per-call UTC history. Never infer
    # isolation from missing telemetry: conservatively exclude their entire envelope.
    if ([string]$supplement.status -cne 'initialized' -or
        @($supplement.scenarios.PSObject.Properties).Count -gt 0 -or
        @($supplement.comparisons.PSObject.Properties).Count -gt 0 -or
        $null -ne $supplement.current) {
      $end = if ($null -ne $supplement.current -or $supplement.status -ceq 'running') {
        '9999-12-31T23:59:59Z'
      } else { [string]$supplement.updated_at }
      Add-PerformanceInterval 'supplemental-conservative-envelope' `
        ([string]$science.created_at_utc) $end
    }
  }
  foreach ($attempt in @($performance.attempts)) {
    if ([string]::IsNullOrWhiteSpace([string]$attempt.process_started_at_utc)) { continue }
    $end = if (Test-Path -LiteralPath ([string]$attempt.result_path) -PathType Leaf) {
      (Read-Issue13MainJson ([string]$attempt.result_path)).finished_at_utc
    } else { '9999-12-31T23:59:59Z' }
    Add-PerformanceInterval ([string]$attempt.result_path) `
      ([string]$attempt.process_started_at_utc) ([string]$end) ([string]$attempt.job_path)
  }
}

function Get-PerformanceProof([object]$Phase, [string]$Arm, [object]$Attempt,
    [switch]$Original) {
  if ((Get-Issue13MainSha256 ([string]$Attempt.job_path)) -cne [string]$Attempt.job_sha256) {
    throw 'A performance/science job changed after scheduling.'
  }
  $job = Read-Issue13MainJson ([string]$Attempt.job_path)
  $slot = $science.arm_bindings.$Arm
  $root = @($slot.roots | Where-Object method -CEQ $Phase.method)
  if ($root.Count -ne 1 -or $job.schema -cne 'wlv-issue13-main-job/1' -or
      $job.scenario_id -cne "$Arm/$($Phase.phase)" -or $job.arm -cne $Arm -or
      $job.method -cne $Phase.method -or $job.kind -cne $Phase.kind -or
      [long]$job.workers -ne [long]$Phase.workers -or
      [string]$job.stage -cne [string]$Phase.stage -or
      [string]$job.variant -cne [string]$Phase.variant -or
      $job.runtime_commit -cne $slot.commit -or $job.seed_commit -cne $slot.seed_commit -or
      $job.config_sha256 -cne $science.config_sha256 -or
      $job.tooling_binding_sha256 -cne $science.tooling_binding_sha256 -or
      $job.arm_binding_sha256 -cne $slot.binding_sha256 -or
      -not (Test-Issue13MainSamePath $job.worktree_root $root[0].root) -or
      -not (Test-Issue13MainSamePath $job.source_manifest_path $root[0].source_manifest_path) -or
      $job.source_manifest_sha256 -cne $root[0].source_manifest_sha256 -or
      (Get-Issue13MainSha256 $job.source_manifest_path) -cne $job.source_manifest_sha256) {
    throw "Performance identity differs from science: $Arm/$($Phase.phase)"
  }
  foreach ($name in @('source_generation_id', 'source_contract_id',
      'source_contract_version', 'source_contract_sha256')) {
    if ([string]$job.$name -cne [string]$root[0].$name) { throw "Source identity differs: $name" }
  }
  if ($Phase.kind -ceq 'recalculate') {
    $seedPhase = @($science.phases | Where-Object phase -CEQ "calculate/$($Phase.method)/workers1")[0]
    $seed = Get-Issue13MainScenarioResult $seedPhase.$Arm
    if (-not (Test-Issue13MainSamePath $job.seed_result $seed) -or
        $job.seed_result_sha256 -cne (Get-Issue13MainSha256 $seed)) {
      throw 'Performance repeat must use the original authenticated science seed.'
    }
  }
  $null = Assert-Issue13MainControllerSnapshots ([object[]]$job.controller_records)
  $outcome = Read-Issue13MainJson ([string]$Attempt.result_path)
  if ($outcome.schema -cne 'wlv-issue13-main-attempt/1' -or
      -not (Test-Issue13MainExactBoolean $outcome.passed $true) -or
      $outcome.status -cne 'passed' -or $outcome.job_sha256 -cne $Attempt.job_sha256 -or
      $outcome.scenario_id -cne $job.scenario_id -or $outcome.channel -cne $job.channel -or
      $outcome.runtime_commit -cne $job.runtime_commit -or
      -not (Test-Issue13MainSamePath $outcome.evidence_directory $job.scenario_evidence) -or
      (Get-Issue13MainSha256 ([string]$Attempt.result_path)) -cne $Attempt.result_sha256) {
    throw 'Performance attempt result binding differs.'
  }
  $workers = if ($Phase.kind -ceq 'calculate' -and [long]$Phase.workers -eq 2) { 2L } else { 0L }
  $proof = Test-Issue13MainScenarioEvidence $job.scenario_evidence $job.scenario_id $job.runtime_commit $workers
  if ($proof.result_sha256 -cne $outcome.scenario_result_sha256 -or
      $proof.metrics_sha256 -cne $outcome.process_metrics_sha256 -or
      ($Original -and ($proof.result_sha256 -cne $Phase.$Arm.scenario_result_sha256 -or
        $proof.metrics_sha256 -cne $Phase.$Arm.process_metrics_sha256))) {
    throw 'Performance metrics differ from recorded evidence.'
  }
  $metrics = Read-Issue13MainJson $proof.metrics_path
  $interval = [pscustomobject]@{
    start = ConvertTo-PerformanceUtc $metrics.started_at_utc
    end = ConvertTo-PerformanceUtc $metrics.finished_at_utc
  }
  if ($interval.end -le $interval.start -or $proof.elapsed_seconds -le 0 -or $proof.peak_rss_bytes -le 0) {
    throw 'Invalid performance duration or RSS.'
  }
  $overlaps = @(Get-PerformanceOverlaps $interval ([string]$Attempt.job_path) $proof.metrics_path)
  [pscustomobject]@{ job = $job; attempt = $Attempt; proof = $proof
    start = $interval.start.ToString('o'); end = $interval.end.ToString('o')
    overlaps = $overlaps; controlled = $overlaps.Count -eq 0 }
}

function Get-PerformancePlan {
  Get-PerformanceIntervals
  $pairs = [Collections.Generic.List[object]]::new()
  $repeatBytes = @{}
  foreach ($phase in @($science.phases | Sort-Object ordinal)) {
    $pair = [ordered]@{ phase = $phase.phase; baseline = $null; candidate = $null; gate = $null }
    foreach ($arm in @('baseline', 'candidate')) {
      $selection = $null
      $original = $null
      if ($phase.$arm.status -ceq 'passed') {
        $passed = @($phase.$arm.attempts | Where-Object status -CEQ 'passed')[-1]
        $original = Get-PerformanceProof $phase $arm $passed -Original
        if ($original.controlled) {
          $selection = [ordered]@{ class = 'controlled-reused-singleton'; measurement = $original }
        }
        foreach ($attempt in @($performance.attempts | Where-Object {
            $_.scenario_id -ceq "$arm/$($phase.phase)" -and $_.status -ceq 'passed'
          })) {
          $repeat = Get-PerformanceProof $phase $arm $attempt
          if ($repeat.controlled) {
            $selection = [ordered]@{ class = 'controlled-serial-repeat'; measurement = $repeat }
            break
          }
        }
      }
      if ($null -eq $selection) {
        $root = @($science.arm_bindings.$arm.roots | Where-Object method -CEQ $phase.method)[0].root
        $drive = [IO.Path]::GetPathRoot([string]$root)
        $bytes = if ($phase.method -ceq 'wiodr16') { 4294967296L } else { 2147483648L }
        if ($null -ne $original) {
          $result = Read-Issue13MainJson $original.proof.result_path
          $runBytes = 0L
          foreach ($output in @($result.outputs)) {
            if ($output.kind -ceq 'run') {
              $runBytes += [long](Get-ChildItem -LiteralPath ([string]$output.root) -File -Recurse |
                Measure-Object Length -Sum).Sum
            }
          }
          # Output plus staging/seed headroom; estimation is not a guarantee.
          $bytes = [long][Math]::Max($bytes, [Math]::Ceiling(2.5 * $runBytes + 104857600L))
        }
        if (-not $repeatBytes.ContainsKey($drive)) { $repeatBytes[$drive] = 0L }
        $repeatBytes[$drive] += $bytes
        $selection = [ordered]@{ class = 'performance-pending'; repeat_required = $true
          science_passed = $phase.$arm.status -ceq 'passed'; estimated_additional_bytes = $bytes
          worktree_root = $root; original = $original }
      }
      $pair[$arm] = $selection
    }
    if ($pair.baseline.class -cne 'performance-pending' -and $pair.candidate.class -cne 'performance-pending') {
      $pair.gate = Get-Issue13MainPerformance $config $pair.baseline.measurement.proof $pair.candidate.measurement.proof
    }
    $pairs.Add([pscustomobject]$pair)
  }
  $disk = @($repeatBytes.Keys | Sort-Object | ForEach-Object {
    $free = [long](Get-PSDrive -Name $_.TrimEnd('\', '/', ':')).Free
    [ordered]@{ volume = $_; free_bytes = $free; estimated_additional_bytes = $repeatBytes[$_]
      required_free_floor_bytes = [long]$config.scheduling.minimum_free_worktree_volume_bytes
      fits = $free - [long]$repeatBytes[$_] -ge [long]$config.scheduling.minimum_free_worktree_volume_bytes }
  })
  $complete = @($pairs | Where-Object { $null -ne $_.gate }).Count
  $failed = @($pairs | Where-Object { $null -ne $_.gate -and
      (-not $_.gate.time_passed -or -not $_.gate.rss_passed) }).Count
  [ordered]@{ schema = 'wlv-issue13-main-performance-plan/1'; campaign_id = $science.campaign_id
    status = if ($complete -lt 14) { 'performance-pending' } elseif ($failed -gt 0) { 'failed' } else { 'passed' }
    controlled_pairs = $complete; required_pairs = 14; failed_pairs = $failed
    repeats_required = @($pairs | ForEach-Object { $_.baseline; $_.candidate } |
      Where-Object class -CEQ 'performance-pending').Count
    disk_estimate = $disk; pairs = [object[]]$pairs.ToArray()
    updated_at_utc = [DateTime]::UtcNow.ToString('o') }
}

$resolvedConfig = ConvertTo-Issue13MainFullPath $ConfigPath -RequireExistingFile
$config = Read-Issue13MainJson $resolvedConfig
$null = Assert-Issue13MainConfig $config
$sciencePath = Join-Path ([string]$config.control_root) 'state.json'
$science = Read-Issue13MainJson $sciencePath
if ($science.schema -cne 'wlv-issue13-main-state/1' -or
    $science.config_sha256 -cne (Get-Issue13MainSha256 $resolvedConfig) -or
    @($science.phases).Count -ne 14 -or
    [string]::Join('|', @($science.phases.phase | Sort-Object)) -cne
      [string]::Join('|', @((New-Issue13MainPhases).phase | Sort-Object))) {
  throw 'Scientific state/config or exact 14-pair matrix differs.'
}
$binding = Read-Issue13MainJson $science.tooling_binding_path
if ((Get-Issue13MainSha256 $science.tooling_binding_path) -cne $science.tooling_binding_sha256) {
  throw 'Scientific tooling binding changed.'
}
$null = Assert-Issue13MainToolingBinding $binding
foreach ($arm in @('baseline', 'candidate')) {
  $armBinding = Get-Issue13MainArmBinding $config $arm
  if ($armBinding.binding_sha256 -cne $science.arm_bindings.$arm.binding_sha256) {
    throw "Arm binding changed: $arm"
  }
}
$performanceRoot = Join-Path ([string]$config.control_root) 'performance'
$performancePath = Join-Path $performanceRoot 'state.json'
$performance = if (Test-Path -LiteralPath $performancePath -PathType Leaf) {
  Read-Issue13MainJson $performancePath
} else {
  [pscustomobject]@{ schema = 'wlv-issue13-main-performance-state/1'; campaign_id = $science.campaign_id
    config_sha256 = $science.config_sha256; status = 'performance-pending'; current = $null; attempts = @() }
}
if ($performance.schema -cne 'wlv-issue13-main-performance-state/1' -or
    $performance.config_sha256 -cne $science.config_sha256) { throw 'Performance state binding changed.' }
$plan = Get-PerformancePlan
if ($Action -cin @('Plan', 'Status')) { $plan | ConvertTo-Json -Depth 30; exit 0 }
if (@($science.phases | ForEach-Object { $_.baseline; $_.candidate } |
    Where-Object status -CNE 'passed').Count -ne 0) { throw 'Finish all 28 scientific scenarios before serial repeats.' }
if (@($plan.disk_estimate | Where-Object { -not $_.fits }).Count -gt 0) {
  throw 'Estimated repeat outputs do not fit. Coordinate separate bound roots; never delete real evidence.'
}
# Share the existing science/comparison lock and supplemental lock. No machine-wide R exclusivity.
$mainLock = Join-Path ([string]$config.control_root) '.issue13-main-lock'
if (Test-Path -LiteralPath $mainLock) { throw 'Science/comparison controller is active or needs recovery.' }
$null = New-Item -ItemType Directory -Path $mainLock
$supplementLock = $null
$process = $null
try {
  $null = Write-Issue13MainJson ([ordered]@{ schema = 'wlv-issue13-main-lock/1'; pid = $PID
    process_started_at_utc = (Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')
    action = 'ControlledPerformance'; acquired_at_utc = [DateTime]::UtcNow.ToString('o') }) (Join-Path $mainLock 'owner.json')
  $supplementLockPath = Join-Path ([string]$config.control_root) 'supplemental/controller.lock'
  $null = New-Item -ItemType Directory -Path (Split-Path -Parent $supplementLockPath) -Force
  $supplementLock = [IO.File]::Open($supplementLockPath, [IO.FileMode]::OpenOrCreate,
    [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
  if ($null -ne $performance.current) { throw 'A prior performance attempt needs explicit recovery; preserve its evidence.' }
  $supplementStatePath = Join-Path (Split-Path -Parent $supplementLockPath) 'state.json'
  if ((Test-Path -LiteralPath $supplementStatePath) -and
      $null -ne (Read-Issue13MainJson $supplementStatePath).current) {
    throw 'A supplemental child needs explicit recovery before controlled performance.'
  }
  $count = 0
  foreach ($pair in @($plan.pairs)) {
    foreach ($arm in @('baseline', 'candidate')) {
      if ($pair.$arm.class -cne 'performance-pending' -or $count -ge $MaximumRepeats) { continue }
      $original = $pair.$arm.original
      $job = $original.job | ConvertTo-Json -Depth 30 | ConvertFrom-Json
      $number = 1 + @($performance.attempts | Where-Object scenario_id -CEQ $job.scenario_id).Count
      $safe = Get-Issue13MainSafeId $job.scenario_id
      $attemptRoot = Join-Path $performanceRoot "$safe/attempt-$($number.ToString('0000'))"
      $evidenceRoot = Join-Path ([string]$config.evidence_root) "performance/$safe/attempt-$($number.ToString('0000'))"
      if ((Test-Path -LiteralPath $attemptRoot) -or (Test-Path -LiteralPath $evidenceRoot)) {
        throw 'Performance attempt already exists; it will not be overwritten.'
      }
      $os = Get-CimInstance Win32_OperatingSystem
      $reserve = if ([long]$job.workers -eq 2) { $config.scheduling.job_reserve_bytes.workers2 } `
        elseif ($job.method -ceq 'wiodr16') { $config.scheduling.job_reserve_bytes.wiodr16_workers1 } `
        else { $config.scheduling.job_reserve_bytes.wiodr13_workers1 }
      if ([long]$os.FreePhysicalMemory * 1024L - [long]$reserve -lt
          [long]$config.scheduling.minimum_free_physical_bytes) { throw 'Insufficient free RAM for controlled repeat.' }
      $volume = [IO.Path]::GetPathRoot([string]$job.worktree_root).TrimEnd('\', '/', ':')
      if ([long](Get-PSDrive -Name $volume).Free - [long]$pair.$arm.estimated_additional_bytes -lt
          [long]$config.scheduling.minimum_free_worktree_volume_bytes) {
        throw 'Insufficient disk headroom for this repeat; existing evidence is preserved.'
      }
      $null = New-Item -ItemType Directory -Path $attemptRoot
      $job.attempt = $number; $job.attempt_root = $attemptRoot
      $job.specs_root = Join-Path $evidenceRoot 'specs'
      $job.attempt_evidence_root = Join-Path $evidenceRoot 'evidence'
      $job.scenario_evidence = Join-Path $job.attempt_evidence_root "scenarios/$safe"
      $ordinal = @($science.phases | Where-Object phase -CEQ $pair.phase)[0].ordinal
      $job.channel = "i13perf-$($config.campaign_id)-$arm-p$ordinal-a$number".ToLowerInvariant()
      $job.controller_records = New-Issue13MainControllerSnapshots $attemptRoot @(
        [pscustomobject]@{ role = 'performance-controller'; path = $PSCommandPath },
        [pscustomobject]@{ role = 'shared-lib'; path = (Join-Path $PSScriptRoot 'issue13-main-lib.ps1') },
        [pscustomobject]@{ role = 'science-worker'; path = (Join-Path $PSScriptRoot 'issue13-main-worker.ps1') })
      $jobPath = Join-Path $attemptRoot 'job.json'
      $attempt = [pscustomobject]@{ scenario_id = $job.scenario_id; status = 'starting'
        job_path = $jobPath; job_sha256 = Write-Issue13MainJson $job $jobPath
        result_path = (Join-Path $attemptRoot 'attempt-result.json'); result_sha256 = $null
        pid = $null; process_started_at_utc = $null }
      $performance.attempts = @($performance.attempts) + @($attempt)
      $performance.current = $attempt
      $null = Write-Issue13MainJson $performance $performancePath
      $info = [Diagnostics.ProcessStartInfo]::new()
      $info.FileName = [string]$config.sealed_pwsh; $info.UseShellExecute = $false
      $info.CreateNoWindow = $true; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
      foreach ($arg in @('-NoLogo', '-NoProfile', '-File',
          (Join-Path $PSScriptRoot 'issue13-main-worker.ps1'), '-JobPath', $jobPath)) {
        $info.ArgumentList.Add([string]$arg)
      }
      Set-Issue13MainChildEnvironment $info $config
      $process = [Diagnostics.Process]::Start($info)
      $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
      $attempt.pid = $process.Id; $attempt.process_started_at_utc = $process.StartTime.ToUniversalTime().ToString('o')
      $attempt.status = 'running'; $null = Write-Issue13MainJson $performance $performancePath
      if (-not $process.WaitForExit(18000000)) { throw 'Controlled performance worker exceeded five hours.' }
      [IO.File]::WriteAllText((Join-Path $attemptRoot 'worker.stdout.log'), $stdout.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
      [IO.File]::WriteAllText((Join-Path $attemptRoot 'worker.stderr.log'), $stderr.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
      if ($process.ExitCode -ne 0) { throw "Performance worker failed: $($job.scenario_id)" }
      $attempt.result_sha256 = Get-Issue13MainSha256 $attempt.result_path
      $attempt.status = 'passed'; $performance.current = $null
      $null = Write-Issue13MainJson $performance $performancePath
      $process.Dispose(); $process = $null
      $plan = Get-PerformancePlan
      $performance.status = $plan.status
      $null = Write-Issue13MainJson $plan (Join-Path $performanceRoot 'report.json')
      $null = Write-Issue13MainJson $performance $performancePath
      $count++
    }
  }
  $performance.status = $plan.status
  $null = Write-Issue13MainJson $plan (Join-Path $performanceRoot 'report.json')
  $null = Write-Issue13MainJson $performance $performancePath
  $plan | ConvertTo-Json -Depth 30
} finally {
  if ($null -ne $process) {
    if (-not $process.HasExited) { $process.Kill($true); $null = $process.WaitForExit(30000) }
    $process.Dispose()
  }
  if ($null -ne $supplementLock) { $supplementLock.Dispose() }
  [IO.Directory]::Delete($mainLock, $true)
}
