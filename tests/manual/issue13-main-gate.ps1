param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Plan', 'Initialize', 'RunScience', 'Status')]
  [string]$Action,
  [string]$ConfigPath,
  [string]$OutputPath,
  [ValidateSet('all', 'baseline', 'candidate')][string]$Arm = 'all',
  [ValidateRange(1, 4)][int]$MaxJobs = 4,
  [ValidateRange(1, 10)][int]$MaxAttempts = 1
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'issue13-main-lib.ps1')

function Save-MainState([object]$State, [string]$Path) {
  $State.revision = [long]$State.revision + 1L
  $State.updated_at_utc = [DateTime]::UtcNow.ToString('o')
  $null = Write-Issue13MainJson $State $Path
}

function Get-GitValue([object]$Config, [string]$Root, [string[]]$Arguments) {
  $values = @(& ([string]$Config.git) -C $Root @Arguments 2>&1)
  if ($LASTEXITCODE -ne 0 -or $values.Count -eq 0) {
    throw "Git inspection failed for $Root."
  }
  ([string]$values[0]).Trim()
}

function Get-ArmStateSlot([object]$State, [string]$ArmName) {
  $State.arm_bindings.$ArmName
}

function Ensure-ArmBinding(
  [object]$Config,
  [object]$State,
  [string]$ArmName,
  [string]$StatePath
) {
  $binding = Get-Issue13MainArmBinding $Config $ArmName
  $slot = Get-ArmStateSlot $State $ArmName
  if ([string]$slot.status -ceq 'bound') {
    if ([string]$slot.binding_sha256 -cne [string]$binding.binding_sha256) {
      throw "The $ArmName arm binding changed after first use."
    }
    return $binding
  }
  $sourceV5 = Read-Issue13MainJson ([string]$Config.source_v5_config)
  if ($ArmName -ceq 'baseline' -and
      [string]$sourceV5.baseline_runtime_commit -cne
        [string]$binding.commit) {
    throw 'Baseline binding differs from the V5 compatibility oracle commit.'
  }
  $rootRecords = [Collections.Generic.List[object]]::new()
  foreach ($method in $script:Issue13MainMethods) {
    $root = [string]$binding.roots.$method
    $commit = Get-GitValue $Config $root @('rev-parse', 'HEAD')
    $tree = Get-GitValue $Config $root @('rev-parse', 'HEAD^{tree}')
    if ($commit -cne [string]$binding.commit) {
      throw "The $ArmName/$method root is not pinned to its binding."
    }
    $dirty = @(& ([string]$Config.git) -C $root status --porcelain=v1 `
      --untracked-files=all -- R catalog config contracts methods parameters `
      scripts/run_wlv.R renv.lock DESCRIPTION 2>&1)
    if ($LASTEXITCODE -ne 0 -or $dirty.Count -ne 0) {
      throw "The $ArmName/$method runtime is not clean."
    }
    $sourceContracts = @($sourceV5.source_contract_bindings | Where-Object {
      [string]$_.arm -ceq $ArmName -and [string]$_.source -ceq $method
    })
    if ($sourceContracts.Count -ne 1) {
      throw "V5 source contract lookup failed: $ArmName/$method"
    }
    $sourceContract = $sourceContracts[0]
    $sourceManifest = ConvertTo-Issue13MainFullPath `
      (Join-Path (Join-Path $root 'source_data') `
        ([string]$sourceContract.manifest_relative_path)) `
      -RequireExistingFile
    if ((Get-Issue13MainSha256 $sourceManifest) -cne
        [string]$sourceContract.manifest_sha256) {
      throw "Source manifest differs from the V5 binding: $ArmName/$method"
    }
    $rootRecords.Add([ordered]@{
      method = $method
      root = $root
      commit = $commit
      tree = $tree
      source_manifest_path = $sourceManifest
      source_manifest_sha256 = [string]$sourceContract.manifest_sha256
      source_generation_id = [string]$sourceContract.source_generation_id
      source_contract_id = [string]$sourceContract.contract_id
      source_contract_version = [string]$sourceContract.contract_version
      source_contract_sha256 = [string]$sourceContract.contract_sha256
    })
  }
  $expectedInventory = if ($ArmName -ceq 'baseline') {
    $sourceV5.source_inventory
  } else {
    $sourceV5.candidate_source_inventory
  }
  $slot.status = 'bound'
  $slot.binding_path = [string]$binding.binding_path
  $slot.binding_sha256 = [string]$binding.binding_sha256
  $slot.commit = [string]$binding.commit
  $slot.seed_commit = [string]$binding.seed_commit
  $slot.roots = [object[]]$rootRecords.ToArray()
  $slot.expected_source_inventory = $expectedInventory
  $slot.bound_at_utc = [DateTime]::UtcNow.ToString('o')
  Save-MainState $State $StatePath
  $binding
}

function Enter-MainLock([object]$Config, [string]$CurrentAction) {
  $lockPath = Join-Path ([string]$Config.control_root) '.issue13-main-lock'
  if (Test-Path -LiteralPath $lockPath) {
    $ownerPath = Join-Path $lockPath 'owner.json'
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
    if ($active) { throw "Reduced gate is already running: $lockPath" }
    $orphanRoot = Join-Path ([string]$Config.control_root) 'orphan-locks'
    $null = New-Item -ItemType Directory -Path $orphanRoot -Force
    $orphan = Join-Path $orphanRoot (
      'orphan-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))
    [IO.Directory]::Move($lockPath, $orphan)
  }
  $null = New-Item -ItemType Directory -Path $lockPath
  $process = Get-Process -Id $PID
  $owner = [ordered]@{
    schema = 'wlv-issue13-main-lock/1'
    pid = [long]$PID
    process_started_at_utc = $process.StartTime.ToUniversalTime().ToString('o')
    action = $CurrentAction
    acquired_at_utc = [DateTime]::UtcNow.ToString('o')
  }
  $null = Write-Issue13MainJson $owner (Join-Path $lockPath 'owner.json')
  $lockPath
}

function Exit-MainLock([string]$LockPath) {
  if (Test-Path -LiteralPath $LockPath -PathType Container) {
    [IO.Directory]::Delete($LockPath, $true)
  }
}

function Wait-MainAdmission(
  [object]$Config,
  [object[]]$Ready,
  [int]$MaximumJobs
) {
  $deadline = [DateTime]::UtcNow.AddSeconds(900)
  while ($true) {
    $os = Get-CimInstance Win32_OperatingSystem
    $freeMemory = [long]$os.FreePhysicalMemory * 1024L
    $memoryReserved = 0L
    $diskReserved = @{}
    $diskFree = @{}
    $admitted = [Collections.Generic.List[object]]::new()
    foreach ($item in $Ready) {
      if ($admitted.Count -ge $MaximumJobs) { break }
      $memory = if ([long]$item.phase.workers -eq 2) {
        [long]$Config.scheduling.job_reserve_bytes.workers2
      } elseif ([string]$item.method -ceq 'wiodr16') {
        [long]$Config.scheduling.job_reserve_bytes.wiodr16_workers1
      } else {
        [long]$Config.scheduling.job_reserve_bytes.wiodr13_workers1
      }
      $disk = if ([string]$item.method -ceq 'wiodr16') { 4294967296L } `
        else { 2147483648L }
      $drive = [IO.Path]::GetPathRoot([string]$item.root)
      if (-not $diskFree.ContainsKey($drive)) {
        $name = $drive.TrimEnd('\').TrimEnd(':')
        $diskFree[$drive] = [long](Get-PSDrive -Name $name).Free
        $diskReserved[$drive] = 0L
      }
      $candidateMemory = $memoryReserved + $memory
      $candidateDisk = [long]$diskReserved[$drive] + $disk
      $memoryOk = $candidateMemory -le
          [long]$Config.scheduling.memory_budget_bytes -and
        $freeMemory - $candidateMemory -ge
          [long]$Config.scheduling.minimum_free_physical_bytes
      $diskOk = [long]$diskFree[$drive] - $candidateDisk -ge
        [long]$Config.scheduling.minimum_free_worktree_volume_bytes
      if ($memoryOk -and $diskOk) {
        $admitted.Add($item)
        $memoryReserved = $candidateMemory
        $diskReserved[$drive] = $candidateDisk
      }
    }
    if ($admitted.Count -gt 0) { return [object[]]$admitted.ToArray() }
    if ([DateTime]::UtcNow -ge $deadline) {
      throw 'CPU/RAM/disk admission did not become safe within 15 minutes.'
    }
    Start-Sleep -Seconds 5
  }
}

function Get-Phase([object]$State, [string]$PhaseName) {
  $matches = @($State.phases | Where-Object phase -CEQ $PhaseName)
  if ($matches.Count -ne 1) { throw "Phase lookup failed: $PhaseName" }
  $matches[0]
}

function Test-PhaseDependency([object]$State, [object]$Phase, [string]$ArmName) {
  if ([string]$Phase.kind -ceq 'calculate' -and [long]$Phase.workers -eq 1) {
    return $true
  }
  $full = Get-Phase $State "calculate/$($Phase.method)/workers1"
  [string]$full.$ArmName.status -ceq 'passed'
}

function Test-RecordedProcessActive([object]$Attempt) {
  if ($null -eq $Attempt -or $null -eq $Attempt.pid -or
      [string]::IsNullOrWhiteSpace(
        [string]$Attempt.process_started_at_utc)) { return $false }
  $process = Get-Process -Id ([long]$Attempt.pid) -ErrorAction SilentlyContinue
  if ($null -eq $process) { return $false }
  $process.StartTime.ToUniversalTime().ToString('o') -ceq
    [string]$Attempt.process_started_at_utc
}

function Assert-NoRecordedDescendants([object]$Attempt) {
  $ancestorIds = [Collections.Generic.HashSet[uint32]]::new()
  $null = $ancestorIds.Add([uint32][long]$Attempt.pid)
  $processes = @(Get-CimInstance Win32_Process)
  $changed = $true
  while ($changed) {
    $changed = $false
    foreach ($process in $processes) {
      if (-not $ancestorIds.Contains([uint32]$process.ProcessId) -and
          $ancestorIds.Contains([uint32]$process.ParentProcessId)) {
        $null = $ancestorIds.Add([uint32]$process.ProcessId)
        $changed = $true
      }
    }
  }
  $descendants = @($ancestorIds | Where-Object {
    [long]$_ -ne [long]$Attempt.pid
  })
  if ($descendants.Count -ne 0) {
    throw ('A prior worker still has live descendants: ' +
      [string]::Join(', ', $descendants))
  }
}

function Get-BoundScienceJob(
  [object]$Config,
  [object]$State,
  [object]$Phase,
  [string]$ArmName,
  [object]$Attempt
) {
  $jobPath = ConvertTo-Issue13MainFullPath ([string]$Attempt.job_path) `
    -RequireExistingFile
  if ((Get-Issue13MainSha256 $jobPath) -cne [string]$Attempt.job_sha256) {
    throw 'A scientific job changed after it was scheduled.'
  }
  $job = Read-Issue13MainJson $jobPath
  $scenarioId = "$ArmName/$($Phase.phase)"
  $safeId = Get-Issue13MainSafeId $scenarioId
  $attemptName = 'attempt-' + ([long]$Attempt.attempt).ToString('0000')
  $expectedAttemptRoot = Join-Path (Join-Path (Join-Path `
    ([string]$Config.control_root) 'attempts') $safeId) $attemptName
  $expectedEvidenceRoot = Join-Path (Join-Path (Join-Path `
    ([string]$Config.evidence_root) 'attempts') $safeId) $attemptName
  $expectedRuntimeEvidence = Join-Path $expectedEvidenceRoot 'evidence'
  $expectedScenarioEvidence = Join-Path `
    (Join-Path $expectedRuntimeEvidence 'scenarios') $safeId
  $binding = Get-ArmStateSlot $State $ArmName
  $rootRecords = @($binding.roots | Where-Object method -CEQ $Phase.method)
  if ($rootRecords.Count -ne 1 -or
      $job.schema -cne 'wlv-issue13-main-job/1' -or
      [string]$job.scenario_id -cne $scenarioId -or
      [string]$job.arm -cne $ArmName -or
      [string]$job.method -cne [string]$Phase.method -or
      [string]$job.kind -cne [string]$Phase.kind -or
      [long]$job.workers -ne [long]$Phase.workers -or
      [string]$job.stage -cne [string]$Phase.stage -or
      [string]$job.variant -cne [string]$Phase.variant -or
      [long]$job.attempt -ne [long]$Attempt.attempt -or
      -not (Test-Issue13MainSamePath ([string]$job.attempt_root) `
        $expectedAttemptRoot) -or
      -not (Test-Issue13MainSamePath ([string]$job.attempt_evidence_root) `
        $expectedRuntimeEvidence) -or
      -not (Test-Issue13MainSamePath ([string]$job.specs_root) `
        (Join-Path $expectedEvidenceRoot 'specs')) -or
      -not (Test-Issue13MainSamePath ([string]$job.scenario_evidence) `
        $expectedScenarioEvidence) -or
      -not (Test-Issue13MainSamePath ([string]$job.worktree_root) `
        ([string]$rootRecords[0].root)) -or
      -not (Test-Issue13MainSamePath ([string]$job.source_manifest_path) `
        ([string]$rootRecords[0].source_manifest_path)) -or
      [string]$job.source_manifest_sha256 -cne
        [string]$rootRecords[0].source_manifest_sha256 -or
      [string]$job.source_generation_id -cne
        [string]$rootRecords[0].source_generation_id -or
      [string]$job.source_contract_id -cne
        [string]$rootRecords[0].source_contract_id -or
      [string]$job.source_contract_version -cne
        [string]$rootRecords[0].source_contract_version -or
      [string]$job.source_contract_sha256 -cne
        [string]$rootRecords[0].source_contract_sha256 -or
      [string]$job.runtime_commit -cne [string]$binding.commit -or
      [string]$job.seed_commit -cne [string]$binding.seed_commit -or
      [string]$job.config_sha256 -cne [string]$State.config_sha256 -or
      [string]$job.tooling_binding_sha256 -cne
        [string]$State.tooling_binding_sha256 -or
      [string]$job.arm_binding_sha256 -cne
        [string]$binding.binding_sha256 -or
      -not (Test-Issue13MainSamePath ([string]$Attempt.result_path) `
        (Join-Path $expectedAttemptRoot 'attempt-result.json'))) {
    throw "Scientific job identity differs: $scenarioId"
  }
  if ((Get-Issue13MainSha256 ([string]$job.source_manifest_path)) -cne
      [string]$job.source_manifest_sha256) {
    throw "Scientific source manifest changed: $scenarioId"
  }
  if ([string]$Phase.kind -ceq 'recalculate') {
    $full = Get-Phase $State "calculate/$($Phase.method)/workers1"
    $expectedSeed = Get-Issue13MainScenarioResult $full.$ArmName
    if (-not (Test-Issue13MainSamePath ([string]$job.seed_result) `
        $expectedSeed) -or
        [string]$job.seed_result_sha256 -cne
          (Get-Issue13MainSha256 $expectedSeed)) {
      throw "Scientific seed binding differs: $scenarioId"
    }
  } elseif (-not [string]::IsNullOrEmpty([string]$job.seed_result) -or
      -not [string]::IsNullOrEmpty([string]$job.seed_result_sha256)) {
    throw "Calculate job unexpectedly has a seed: $scenarioId"
  }
  $null = Assert-Issue13MainControllerSnapshots `
    ([object[]]$job.controller_records)
  $job
}

function Get-ValidatedScienceResult(
  [object]$Config,
  [object]$State,
  [object]$Phase,
  [string]$ArmName,
  [object]$Attempt
) {
  $job = Get-BoundScienceJob $Config $State $Phase $ArmName $Attempt
  $resultPath = ConvertTo-Issue13MainFullPath ([string]$Attempt.result_path) `
    -RequireExistingFile
  $result = Read-Issue13MainJson $resultPath
  if ($result.schema -cne 'wlv-issue13-main-attempt/1' -or
      [string]$result.scenario_id -cne [string]$job.scenario_id -or
      [long]$result.attempt -ne [long]$job.attempt -or
      [string]$result.status -cne 'passed' -or
      -not (Test-Issue13MainExactBoolean $result.passed $true) -or
      -not (Test-Issue13MainSamePath ([string]$result.job_path) `
        ([string]$Attempt.job_path)) -or
      [string]$result.job_sha256 -cne [string]$Attempt.job_sha256 -or
      [string]$result.config_sha256 -cne [string]$job.config_sha256 -or
      [string]$result.tooling_binding_sha256 -cne
        [string]$job.tooling_binding_sha256 -or
      -not (Test-Issue13MainSamePath ([string]$result.worktree_root) `
        ([string]$job.worktree_root)) -or
      [string]$result.runtime_commit -cne [string]$job.runtime_commit -or
      [string]$result.seed_commit -cne [string]$job.seed_commit -or
      [string]$result.channel -cne [string]$job.channel -or
      -not (Test-Issue13MainSamePath ([string]$result.evidence_directory) `
        ([string]$job.scenario_evidence)) -or
      -not (Test-Issue13MainControllerRecordEquality `
        ([object[]]$result.controller_records) `
        ([object[]]$job.controller_records))) {
    throw "Scientific attempt identity differs: $($job.scenario_id)"
  }
  $expectedWorkers = if ([string]$job.kind -ceq 'calculate' -and
      [long]$job.workers -eq 2L) { 2L } else { 0L }
  $evidence = Test-Issue13MainScenarioEvidence `
    ([string]$job.scenario_evidence) ([string]$job.scenario_id) `
    ([string]$job.runtime_commit) $expectedWorkers
  if ([string]$result.scenario_result_sha256 -cne
        [string]$evidence.result_sha256 -or
      [string]$result.process_metrics_sha256 -cne
        [string]$evidence.metrics_sha256) {
    throw "Scientific evidence hash differs: $($job.scenario_id)"
  }
  [pscustomobject]@{ job = $job; result = $result; evidence = $evidence }
}

function Remove-AbandonedResultsLock(
  [object]$Config,
  [object]$State,
  [object]$Phase,
  [string]$ArmName,
  [object]$Attempt
) {
  $job = Get-BoundScienceJob $Config $State $Phase $ArmName $Attempt
  if (Test-RecordedProcessActive $Attempt) {
    throw "A prior worker is still active: $($Attempt.pid)"
  }
  Assert-NoRecordedDescendants $Attempt
  $lockPath = Join-Path ([string]$job.worktree_root) 'results\.lock-results'
  if (-not (Test-Path -LiteralPath $lockPath)) { return }
  $item = Get-Item -LiteralPath $lockPath -Force
  if (-not $item.PSIsContainer -or
      ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
      @(Get-ChildItem -LiteralPath $lockPath -Force).Count -ne 0) {
    throw "Abandoned results lock is not a removable empty directory: $lockPath"
  }
  [IO.Directory]::Delete($lockPath, $false)
}

function Get-ReadyScience(
  [object]$Config,
  [object]$State,
  [string[]]$SelectedArms,
  [int]$AttemptMaximum
) {
  $ready = [Collections.Generic.List[object]]::new()
  foreach ($armName in $SelectedArms) {
    $bindingSlot = Get-ArmStateSlot $State $armName
    if ([string]$bindingSlot.status -cne 'bound') { continue }
    foreach ($method in $script:Issue13MainMethods) {
      $next = @($State.phases | Sort-Object ordinal | Where-Object {
        [string]$_.method -ceq $method -and
        [string]$_.$armName.status -cne 'passed'
      } | Select-Object -First 1)
      if ($next.Count -eq 0) { continue }
      $phase = $next[0]
      $armState = $phase.$armName
      if ([string]$armState.status -ceq 'running') { continue }
      if ([long]$armState.attempt_count -ge $AttemptMaximum) { continue }
      if (-not (Test-PhaseDependency $State $phase $armName)) { continue }
      $root = @($bindingSlot.roots | Where-Object method -CEQ $method)[0].root
      $ready.Add([pscustomobject]@{
        arm = $armName; method = $method; root = [string]$root; phase = $phase
      })
    }
  }
  [object[]]$ready.ToArray()
}

function Start-ScienceJob(
  [object]$Config,
  [string]$ResolvedConfigPath,
  [object]$State,
  [string]$StatePath,
  [object]$Ready
) {
  $phase = $Ready.phase
  $armName = [string]$Ready.arm
  $armState = $phase.$armName
  $bindingSlot = Get-ArmStateSlot $State $armName
  $rootRecord = @($bindingSlot.roots | Where-Object method -CEQ `
    $phase.method)[0]
  $attempt = [long]$armState.attempt_count + 1L
  $scenarioId = "$armName/$($phase.phase)"
  $safeId = Get-Issue13MainSafeId $scenarioId
  $attemptName = 'attempt-' + $attempt.ToString('0000')
  $attemptRoot = Join-Path (Join-Path (Join-Path `
    ([string]$Config.control_root) 'attempts') $safeId) $attemptName
  $attemptEvidence = Join-Path (Join-Path (Join-Path `
    ([string]$Config.evidence_root) 'attempts') $safeId) $attemptName
  if ((Test-Path -LiteralPath $attemptRoot) -or
      (Test-Path -LiteralPath $attemptEvidence)) {
    throw "Attempt path already exists: $scenarioId/$attempt"
  }
  $null = New-Item -ItemType Directory -Path $attemptRoot
  $specsRoot = Join-Path $attemptEvidence 'specs'
  $runtimeEvidence = Join-Path $attemptEvidence 'evidence'
  $scenarioEvidence = Join-Path (Join-Path $runtimeEvidence 'scenarios') $safeId
  $channel = ('i13m-' + [string]$Config.campaign_id + '-' + $armName + '-' +
    [string]$phase.method + '-p' + ([long]$phase.ordinal).ToString('00') +
    '-a' + $attempt.ToString('00')).ToLowerInvariant()
  $seedResult = $null
  if ([string]$phase.kind -ceq 'recalculate') {
    $full = Get-Phase $State "calculate/$($phase.method)/workers1"
    $seedResult = Get-Issue13MainScenarioResult $full.$armName
  }
  $controllerRecords = New-Issue13MainControllerSnapshots $attemptRoot @(
    [pscustomobject]@{ role = 'science-scheduler'; path = $PSCommandPath },
    [pscustomobject]@{ role = 'shared-lib'; path =
      (Join-Path $PSScriptRoot 'issue13-main-lib.ps1') },
    [pscustomobject]@{ role = 'science-worker'; path =
      (Join-Path $PSScriptRoot 'issue13-main-worker.ps1') }
  )
  $job = [ordered]@{
    schema = 'wlv-issue13-main-job/1'
    scenario_id = $scenarioId
    arm = $armName
    method = [string]$phase.method
    kind = [string]$phase.kind
    workers = [long]$phase.workers
    stage = $phase.stage
    variant = $phase.variant
    attempt = $attempt
    attempt_root = $attemptRoot
    specs_root = $specsRoot
    attempt_evidence_root = $runtimeEvidence
    scenario_evidence = $scenarioEvidence
    worktree_root = [string]$Ready.root
    source_manifest_path = [string]$rootRecord.source_manifest_path
    source_manifest_sha256 = [string]$rootRecord.source_manifest_sha256
    source_generation_id = [string]$rootRecord.source_generation_id
    source_contract_id = [string]$rootRecord.source_contract_id
    source_contract_version = [string]$rootRecord.source_contract_version
    source_contract_sha256 = [string]$rootRecord.source_contract_sha256
    runtime_commit = [string]$bindingSlot.commit
    seed_commit = [string]$bindingSlot.seed_commit
    seed_result = $seedResult
    seed_result_sha256 = if ($null -eq $seedResult) { $null } else {
      Get-Issue13MainSha256 ([string]$seedResult)
    }
    channel = $channel
    config_path = $ResolvedConfigPath
    config_sha256 = [string]$State.config_sha256
    arm_binding_path = [string]$bindingSlot.binding_path
    arm_binding_sha256 = [string]$bindingSlot.binding_sha256
    tooling_binding_path = [string]$State.tooling_binding_path
    tooling_binding_sha256 = [string]$State.tooling_binding_sha256
    controller_records = [object[]]$controllerRecords
  }
  $jobPath = Join-Path $attemptRoot 'job.json'
  $jobSha = Write-Issue13MainJson $job $jobPath
  $attemptRecord = [ordered]@{
    attempt = $attempt; status = 'starting'; job_path = $jobPath;
    job_sha256 = $jobSha; result_path = (Join-Path $attemptRoot `
      'attempt-result.json'); result_sha256 = $null; pid = $null
    process_started_at_utc = $null; exit_code = $null
  }
  $armState.attempt_count = $attempt
  $armState.status = 'running'
  $armState.active_attempt = $attemptRecord
  $armState.attempts = [object[]](@($armState.attempts) + @($attemptRecord))
  Save-MainState $State $StatePath

  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = [string]$Config.sealed_pwsh
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  foreach ($argument in @(
      '-NoLogo', '-NoProfile', '-File',
      (Join-Path $PSScriptRoot 'issue13-main-worker.ps1'),
      '-JobPath', $jobPath)) {
    $null = $info.ArgumentList.Add([string]$argument)
  }
  Set-Issue13MainChildEnvironment $info $Config
  $process = $null
  try {
    $process = [Diagnostics.Process]::Start($info)
    $attemptRecord.status = 'running'
    $attemptRecord.pid = [long]$process.Id
    $attemptRecord.process_started_at_utc =
      $process.StartTime.ToUniversalTime().ToString('o')
    Save-MainState $State $StatePath
    [pscustomobject]@{
      process = $process
      stdout = $process.StandardOutput.ReadToEndAsync()
      stderr = $process.StandardError.ReadToEndAsync()
      arm = $armName
      phase = $phase
      attempt = $attemptRecord
      attempt_root = $attemptRoot
      completed = $false
    }
  } catch {
    if ($null -ne $process) {
      try {
        if (-not $process.HasExited) { $process.Kill($true) }
        $null = $process.WaitForExit(30000)
      } catch { }
    }
    $attemptRecord.status = 'launch-failed'
    $armState.status = 'failed'
    $armState.active_attempt = $null
    $armState.failure = $_.Exception.Message
    Save-MainState $State $StatePath
    throw
  }
}

function Complete-ScienceJob(
  [object]$Config,
  [object]$State,
  [string]$StatePath,
  [object]$Job
) {
  $Job.process.WaitForExit()
  $stdout = $Job.stdout.GetAwaiter().GetResult()
  $stderr = $Job.stderr.GetAwaiter().GetResult()
  [IO.File]::WriteAllText((Join-Path $Job.attempt_root 'worker.stdout.log'),
    $stdout, [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $Job.attempt_root 'worker.stderr.log'),
    $stderr, [Text.UTF8Encoding]::new($false))
  $armState = $Job.phase.([string]$Job.arm)
  $Job.attempt.exit_code = [long]$Job.process.ExitCode
  $armState.active_attempt = $null
  try {
    if ($Job.process.ExitCode -ne 0) {
      throw "Scientific worker exited with code $($Job.process.ExitCode)."
    }
    $validated = Get-ValidatedScienceResult $Config $State $Job.phase `
      ([string]$Job.arm) $Job.attempt
    $result = $validated.result
    $Job.attempt.status = 'passed'
    $Job.attempt.result_sha256 = Get-Issue13MainSha256 `
      ([string]$Job.attempt.result_path)
    $armState.status = 'passed'
    $armState.evidence_directory = [string]$result.evidence_directory
    $armState.scenario_result_sha256 = [string]$result.scenario_result_sha256
    $armState.process_metrics_sha256 = [string]$result.process_metrics_sha256
    $armState.failure = $null
    $Job.completed = $true
  } catch {
    $Job.attempt.status = 'failed'
    $armState.status = 'failed'
    $armState.failure = $_.Exception.Message
  }
  Save-MainState $State $StatePath
}

function Stop-IncompleteScienceJob(
  [object]$Config,
  [object]$State,
  [string]$StatePath,
  [object]$Job
) {
  if (Test-Issue13MainExactBoolean $Job.completed $true) { return }
  $identityMatches = [long]$Job.process.Id -eq [long]$Job.attempt.pid -and
    $Job.process.StartTime.ToUniversalTime().ToString('o') -ceq
      [string]$Job.attempt.process_started_at_utc
  if (-not $identityMatches) {
    throw 'Refusing to stop a worker whose process identity changed.'
  }
  $terminated = $false
  if (-not $Job.process.HasExited) {
    $Job.process.Kill($true)
    $terminated = $true
    if (-not $Job.process.WaitForExit(30000)) {
      throw "Scientific worker did not stop: $($Job.process.Id)"
    }
  }
  $stdout = $Job.stdout.GetAwaiter().GetResult()
  $stderr = $Job.stderr.GetAwaiter().GetResult()
  [IO.File]::WriteAllText((Join-Path $Job.attempt_root 'worker.stdout.log'),
    $stdout, [Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $Job.attempt_root 'worker.stderr.log'),
    $stderr, [Text.UTF8Encoding]::new($false))
  Remove-AbandonedResultsLock $Config $State $Job.phase `
    ([string]$Job.arm) $Job.attempt
  $armState = $Job.phase.([string]$Job.arm)
  $Job.attempt.status = if ($terminated) { 'coordinator-aborted' } else {
    'failed-cleaned'
  }
  $Job.attempt.exit_code = [long]$Job.process.ExitCode
  $armState.status = 'failed'
  $armState.active_attempt = $null
  if ($terminated -or
      [string]::IsNullOrWhiteSpace([string]$armState.failure)) {
    $armState.failure = 'Coordinator aborted this worker and its process tree.'
  }
  Save-MainState $State $StatePath
  $Job.completed = $true
}

function Repair-InterruptedScience(
  [object]$Config,
  [object]$State,
  [string]$StatePath
) {
  foreach ($phase in @($State.phases)) {
    foreach ($armName in $script:Issue13MainArms) {
      $armState = $phase.$armName
      if ([string]$armState.status -cne 'running') { continue }
      $active = $armState.active_attempt
      $resultPath = [string]$active.result_path
      if (Test-RecordedProcessActive $active) {
        throw "A prior worker is still active: $($active.pid)"
      }
      Assert-NoRecordedDescendants $active
      if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
        try {
          $validated = Get-ValidatedScienceResult $Config $State $phase `
            $armName $active
          $result = $validated.result
          Remove-AbandonedResultsLock $Config $State $phase $armName $active
          $active.status = 'passed'
          $active.result_sha256 = Get-Issue13MainSha256 $resultPath
          $armState.status = 'passed'
          $armState.evidence_directory = [string]$result.evidence_directory
          $armState.scenario_result_sha256 = [string]$result.scenario_result_sha256
          $armState.process_metrics_sha256 = [string]$result.process_metrics_sha256
          $armState.failure = $null
        } catch {
          Remove-AbandonedResultsLock $Config $State $phase $armName $active
          $active.status = 'failed'
          $armState.status = 'failed'
          $armState.failure = $_.Exception.Message
        }
        $armState.active_attempt = $null
        Save-MainState $State $StatePath
        continue
      }
      Remove-AbandonedResultsLock $Config $State $phase $armName $active
      $active.status = 'abandoned'
      $armState.status = 'failed'
      $armState.active_attempt = $null
      $armState.failure = 'Coordinator stopped before the worker produced a result.'
      Save-MainState $State $StatePath
    }
  }
}

if ($Action -ceq 'Plan') {
  $plan = New-Issue13MainPlan
  if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $plan | ConvertTo-Json -Depth 20
  } else {
    $null = Write-Issue13MainJson $plan $OutputPath
    Write-Output ([IO.Path]::GetFullPath($OutputPath))
  }
  exit 0
}

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
  throw 'ConfigPath is required for this action.'
}
$resolvedConfig = ConvertTo-Issue13MainFullPath $ConfigPath -RequireExistingFile
$config = Read-Issue13MainJson $resolvedConfig
$null = Assert-Issue13MainConfig $config
$statePath = Join-Path ([string]$config.control_root) 'state.json'

if ($Action -ceq 'Initialize') {
  if (Test-Path -LiteralPath $statePath) {
    throw "Reduced gate state already exists: $statePath"
  }
  $null = New-Item -ItemType Directory -Path ([string]$config.control_root) -Force
  $null = New-Item -ItemType Directory -Path ([string]$config.evidence_root) -Force
  $binding = Get-Issue13MainToolingBinding $config
  $bindingPath = Join-Path ([string]$config.control_root) 'tooling-binding.json'
  $bindingSha = Write-Issue13MainJson $binding $bindingPath
  $state = [pscustomobject][ordered]@{
    schema = 'wlv-issue13-main-state/1'
    campaign_id = [string]$config.campaign_id
    status = 'initialized'
    revision = 0
    created_at_utc = [DateTime]::UtcNow.ToString('o')
    updated_at_utc = [DateTime]::UtcNow.ToString('o')
    config_path = $resolvedConfig
    config_sha256 = Get-Issue13MainSha256 $resolvedConfig
    tooling_binding_path = $bindingPath
    tooling_binding_sha256 = $bindingSha
    performance_class = 'science-timings-observational-under-parallel-load'
    arm_bindings = [pscustomobject][ordered]@{
      baseline = [pscustomobject][ordered]@{
        status = 'pending'; binding_path = $null; binding_sha256 = $null
        commit = $null; seed_commit = $null; roots = [object[]]@()
        expected_source_inventory = $null; bound_at_utc = $null
      }
      candidate = [pscustomobject][ordered]@{
        status = 'pending'; binding_path = $null; binding_sha256 = $null
        commit = $null; seed_commit = $null; roots = [object[]]@()
        expected_source_inventory = $null; bound_at_utc = $null
      }
    }
    phases = [object[]](New-Issue13MainPhases)
    comparisons = [object[]](New-Issue13MainComparisons)
    oracle_deltas = [object[]]@()
    preparation = [pscustomobject][ordered]@{ phase = 'prepare/all'; status = 'planned' }
    faults = [object[]]@($script:Issue13MainFaults | ForEach-Object {
      [pscustomobject][ordered]@{ fault_id = $_; status = 'planned' }
    })
  }
  $null = Write-Issue13MainJson $state $statePath
  foreach ($armName in $script:Issue13MainArms) {
    $declaredBinding = [string]$config.arms.$armName.binding_path
    if (Test-Path -LiteralPath $declaredBinding -PathType Leaf) {
      $null = Ensure-ArmBinding $config $state $armName $statePath
    }
  }
  Write-Output $statePath
  exit 0
}

$state = Read-Issue13MainJson $statePath
if ($state.schema -cne 'wlv-issue13-main-state/1' -or
    [string]$state.config_sha256 -cne (Get-Issue13MainSha256 $resolvedConfig)) {
  throw 'Reduced gate state/config binding is invalid.'
}
$tooling = Read-Issue13MainJson ([string]$state.tooling_binding_path)
if ((Get-Issue13MainSha256 ([string]$state.tooling_binding_path)) -cne
    [string]$state.tooling_binding_sha256) {
  throw 'Reduced gate tooling binding file changed.'
}
$null = Assert-Issue13MainToolingBinding $tooling

if ($Action -ceq 'Status') {
  [pscustomobject][ordered]@{
    campaign_id = [string]$state.campaign_id
    status = [string]$state.status
    revision = [long]$state.revision
    passed_scenarios = @($state.phases | ForEach-Object {
      $_.baseline, $_.candidate
    } | Where-Object status -CEQ 'passed').Count
    total_scientific_scenarios = 28
    baseline_binding = [string]$state.arm_bindings.baseline.status
    candidate_binding = [string]$state.arm_bindings.candidate.status
    performance_class = [string]$state.performance_class
  } | ConvertTo-Json -Depth 5
  exit 0
}

$lock = Enter-MainLock $config $Action
try {
  Repair-InterruptedScience $config $state $statePath
  $selectedArms = if ($Arm -ceq 'all') {
    [string[]]$script:Issue13MainArms
  } else { [string[]]@($Arm) }
  foreach ($armName in $selectedArms) {
    $null = Ensure-ArmBinding $config $state $armName $statePath
  }
  $effectiveMax = [Math]::Min($MaxJobs,
    [long]$config.scheduling.maximum_isolated_jobs)
  while ($true) {
    $incomplete = @($state.phases | ForEach-Object {
      foreach ($armName in $selectedArms) { $_.$armName }
    } | Where-Object status -CNE 'passed')
    if ($incomplete.Count -eq 0) { break }
    $ready = @(Get-ReadyScience $config $state $selectedArms $MaxAttempts)
    if ($ready.Count -eq 0) {
      $failures = @($state.phases | ForEach-Object {
        $phase = $_
        foreach ($armName in $selectedArms) {
          if ([string]$phase.$armName.status -cne 'passed') {
            "$armName/$($phase.phase):$($phase.$armName.status)"
          }
        }
      })
      throw ('No runnable scientific scenario remains: ' +
        [string]::Join(', ', $failures))
    }
    $ready = @(Wait-MainAdmission $config $ready $effectiveMax)
    $jobs = [Collections.Generic.List[object]]::new()
    try {
      foreach ($item in $ready) {
        $jobs.Add((Start-ScienceJob $config $resolvedConfig $state $statePath `
          $item))
      }
      foreach ($job in $jobs) {
        Complete-ScienceJob $config $state $statePath $job
      }
    } finally {
      $cleanupErrors = [Collections.Generic.List[string]]::new()
      foreach ($job in $jobs) {
        try {
          Stop-IncompleteScienceJob $config $state $statePath $job
        } catch {
          $cleanupErrors.Add($_.Exception.Message)
        }
      }
      if ($cleanupErrors.Count -ne 0) {
        throw ('One or more scientific workers could not be cleaned up: ' +
          [string]::Join(' | ', $cleanupErrors))
      }
    }
  }
  $allPassed = @($state.phases | ForEach-Object {
    $_.baseline, $_.candidate
  } | Where-Object status -CNE 'passed').Count -eq 0
  $state.status = if ($allPassed) { 'science-completed' } else { 'science-partial' }
  Save-MainState $state $statePath
  Write-Output $statePath
} finally {
  Exit-MainLock $lock
}
