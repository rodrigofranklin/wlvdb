param(
  [Parameter(Mandatory)][ValidateSet('Plan', 'Run', 'Status')][string]$Action,
  [Parameter(Mandatory)][string]$ConfigPath,
  [string]$ExecutionConfigPath,
  [string]$ComparisonBindingPath,
  [ValidateRange(1, 32)][int]$MaximumRepeats = 32
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'issue13-main-lib.ps1')
. (Join-Path $PSScriptRoot 'issue13-main-comparison-binding.ps1')

function Assert-PerformanceOperationalDelta([object]$ScienceConfig, [object]$ExecutionConfig) {
  $copy = $ExecutionConfig | ConvertTo-Json -Depth 30 | ConvertFrom-Json -DateKind String
  foreach ($field in @('campaign_id', 'control_root', 'evidence_root')) { $copy.$field = $ScienceConfig.$field }
  foreach ($arm in @('baseline', 'candidate')) { $copy.arms.$arm.binding_path = $ScienceConfig.arms.$arm.binding_path }
  if (($copy | ConvertTo-Json -Depth 30 -Compress) -cne
      ($ScienceConfig | ConvertTo-Json -Depth 30 -Compress)) {
    throw 'Execution config may change only campaign/layout/arm-binding paths.'
  }
}

function Get-PerformanceRootRecord([string]$Arm, [string]$Method, [switch]$Original) {
  $owner = if ($Original) { $science } else { $execution }
  $matches = @($owner.arm_bindings.$Arm.roots | Where-Object method -CEQ $Method)
  if ($matches.Count -ne 1) { throw 'Performance root coverage differs.' }
  $matches[0]
}

function Get-PerformanceFullPhase([string]$Method) {
  @($science.phases | Where-Object phase -CEQ "calculate/$Method/workers1")[0]
}

function Get-PerformanceLocalSeed([string]$Arm, [string]$Method) {
  $phase = Get-PerformanceFullPhase $Method
  if (-not $separateExecution) {
    $record = @($phase.$Arm.attempts | Where-Object status -CEQ 'passed')[-1]
    return Get-PerformanceProof $phase $Arm $record -Original
  }
  $records = @($performance.attempts | Where-Object {
    $_.scenario_id -ceq "$Arm/calculate/$Method/workers1" -and $_.status -ceq 'passed'
  })
  if ($records.Count -eq 0) { return $null }
  Get-PerformanceProof $phase $Arm $records[0]
}

function Get-PerformanceSeedCertificate([string]$Arm, [string]$Method, [object]$Seed) {
  $id = "seed-parity/$Arm/$Method"
  $records = @($performance.attempts | Where-Object { $_.scenario_id -ceq $id -and $_.status -ceq 'passed' })
  if ($records.Count -eq 0) { return $null }
  $record = $records[-1]
  $job = Read-Issue13MainJson $record.job_path
  $result = Read-Issue13MainJson $record.result_path
  $original = Get-Issue13MainScenarioResult (Get-PerformanceFullPhase $Method).$Arm
  if ((Get-Issue13MainSha256 $record.job_path) -cne $record.job_sha256 -or
      (Get-Issue13MainSha256 $record.result_path) -cne $record.result_sha256 -or
      $job.schema -cne 'wlv-issue13-performance-seed-job/1' -or $job.scenario_id -cne $id -or
      $job.mode -cne 'strict' -or $job.original_result_sha256 -cne (Get-Issue13MainSha256 $original) -or
      $job.local_result_sha256 -cne $Seed.proof.result_sha256 -or
      -not (Test-Issue13MainSamePath $job.original_result $original) -or
      -not (Test-Issue13MainSamePath $job.local_result $Seed.proof.result_path) -or
      $job.scientific_config_sha256 -cne $science.config_sha256 -or
      $job.execution_config_sha256 -cne $execution.config_sha256 -or
      $job.comparison_binding_sha256 -cne $comparisonBindingSha -or
      $result.schema -cne 'wlv-issue13-performance-seed-result/1' -or
      $result.scenario_id -cne $id -or $result.job_sha256 -cne $record.job_sha256 -or
      -not (Test-Issue13MainExactBoolean $result.passed $true) -or $result.status -cne 'passed' -or
      $result.original_result_sha256 -cne $job.original_result_sha256 -or
      $result.local_result_sha256 -cne $job.local_result_sha256 -or
      $result.comparison_binding_sha256 -cne $comparisonBindingSha -or
      (Get-Issue13MainSha256 $result.comparison_path) -cne $result.comparison_sha256) {
    throw 'Local seed certificate identity or comparison evidence changed.'
  }
  $document = Read-Issue13MainJson $result.comparison_path
  if ($document.scenario_id -cne $id -or $document.comparison_mode -cne 'strict' -or
      -not (Test-Issue13MainExactBoolean $document.passed $true)) { throw 'Local seed strict parity did not pass.' }
  $null = Assert-Issue13MainControllerSnapshots ([object[]]$job.controller_records)
  $record
}

function Assert-PerformanceProvisioning([switch]$HashPayloads) {
  if (-not $separateExecution) { return }
  $provision = Read-Issue13MainJson $provisioningPath
  if ($provision.schema -cne 'wlv-issue13-main-performance-provisioning/1' -or
      $provision.science_config_sha256 -cne $science.config_sha256 -or
      $provision.execution_config_sha256 -cne $execution.config_sha256 -or @($provision.roots).Count -ne 4) {
    throw 'Performance provisioning does not bind both exact configs and four roots.'
  }
  foreach ($arm in @('baseline', 'candidate')) {
    foreach ($method in @('wiodr13', 'wiodr16')) {
      $original = Get-PerformanceRootRecord $arm $method -Original
      $local = Get-PerformanceRootRecord $arm $method
      $records = @($provision.roots | Where-Object { $_.arm -ceq $arm -and $_.method -ceq $method })
      if ($records.Count -ne 1) { throw 'Provisioning root coverage differs.' }
      $record = $records[0]
      if (-not (Test-Issue13MainExactBoolean $record.verified $true) -or
          -not (Test-Issue13MainSamePath $record.root $local.root) -or
          -not (Test-Issue13MainSamePath $record.source_root (Join-Path $original.root 'source_data')) -or
          $record.commit -cne $execution.arm_bindings.$arm.commit -or
          $record.seed_commit -cne $execution.arm_bindings.$arm.seed_commit) {
        throw 'Provisioned root identity differs from the execution binding.'
      }
      foreach ($dataRoot in @($record.source_root, (Join-Path $record.root 'source_data'))) {
        if (@(Get-ChildItem -LiteralPath $dataRoot -File -Recurse).Count -ne @($record.files).Count) {
          throw 'Provisioned source file coverage changed.'
        }
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($file in @($record.files)) {
          $path = [IO.Path]::GetFullPath((Join-Path $dataRoot $file.relative_path))
          if (-not $path.StartsWith([IO.Path]::GetFullPath($dataRoot).TrimEnd('\') + '\',
              [StringComparison]::OrdinalIgnoreCase) -or -not $seen.Add($path) -or
              (Get-Item -LiteralPath $path).Length -ne [long]$file.size_bytes -or
              ($HashPayloads -and (Get-Issue13MainSha256 $path) -cne $file.sha256)) {
            throw 'Source copy changed or escaped its provisioned inventory.'
          }
        }
      }
    }
  }
}

function Initialize-PerformanceBinding {
  $path = Join-Path $performanceRoot 'performance-binding.json'
  if (-not (Test-Path -LiteralPath $path)) {
    $files = @($resolvedConfig, $resolvedExecution, $science.tooling_binding_path,
      $execution.tooling_binding_path, $resolvedComparisonBinding, $PSCommandPath,
      (Join-Path $PSScriptRoot 'issue13-main-performance-seed.ps1'),
      (Join-Path $PSScriptRoot 'issue13-main-worker.ps1'),
      (Join-Path $PSScriptRoot 'issue13-main-lib.ps1'),
      (Join-Path $PSScriptRoot 'issue13-main-comparison-binding.ps1'))
    foreach ($arm in @('baseline', 'candidate')) {
      $files += $science.arm_bindings.$arm.binding_path, $execution.arm_bindings.$arm.binding_path
    }
    if ($separateExecution) { $files += $provisioningPath }
    $records = @($files | Select-Object -Unique | ForEach-Object {
      [ordered]@{ path = [IO.Path]::GetFullPath($_); sha256 = Get-Issue13MainSha256 $_ }
    })
    $null = Write-Issue13MainJson ([ordered]@{
      schema = 'wlv-issue13-performance-binding/1'; scientific_config_sha256 = $science.config_sha256
      execution_config_sha256 = $execution.config_sha256; records = $records
    }) $path
  }
  $hash = Get-Issue13MainSha256 $path
  if ($null -ne $performance.binding_sha256 -and $performance.binding_sha256 -cne $hash) {
    throw 'Performance binding changed after execution began.'
  }
  $document = Read-Issue13MainJson $path
  if ($document.schema -cne 'wlv-issue13-performance-binding/1' -or
      $document.scientific_config_sha256 -cne $science.config_sha256 -or
      $document.execution_config_sha256 -cne $execution.config_sha256) { throw 'Performance binding identity differs.' }
  foreach ($record in @($document.records)) {
    if ((Get-Issue13MainSha256 $record.path) -cne $record.sha256) { throw "Bound performance input changed: $($record.path)" }
  }
  $performance.binding_path = $path; $performance.binding_sha256 = $hash
}

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

function Add-SupplementalPerformanceIntervals([object]$Supplement, [string]$LegacyStart) {
  if ($Supplement.PSObject.Properties.Name -ccontains 'process_journal') {
    $journal = $Supplement.process_journal
    if ($journal.schema -cne 'wlv-issue13-supplemental-process-journal/1' -or
        $journal.complete_from_inception -isnot [bool]) {
      throw 'Supplemental process journal schema or coverage is invalid.'
    }
    if (-not $journal.complete_from_inception) {
      Add-PerformanceInterval 'supplemental-pre-journal-history' $LegacyStart `
        ([string]$journal.legacy_finished_at_utc)
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($record in @($journal.records)) {
      if ([string]::IsNullOrWhiteSpace([string]$record.id) -or -not $seen.Add([string]$record.id) -or
          [long]$record.pid -le 0 -or
          [string]$record.status -cnotin @('running', 'passed', 'failed', 'abandoned')) {
        throw 'Supplemental process journal record is invalid.'
      }
      $end = if ([string]::IsNullOrWhiteSpace([string]$record.finished_at_utc)) {
        if ($record.status -cin @('passed', 'failed')) { throw 'Finished process lacks its UTC end.' }
        '9999-12-31T23:59:59Z'
      } else { [string]$record.finished_at_utc }
      Add-PerformanceInterval ('supplemental-process/' + $record.id) `
        ([string]$record.process_started_at_utc) $end
    }
    if ($null -ne $Supplement.current -and
        ($Supplement.current.PSObject.Properties.Name -cnotcontains 'journal_id' -or
         -not $seen.Contains([string]$Supplement.current.journal_id))) {
      throw 'Current supplemental process is missing from its journal.'
    }
    return
  }
  # Only old states without a process journal use the whole activity envelope.
  if ([string]$Supplement.status -cne 'initialized' -or
      @($Supplement.scenarios.PSObject.Properties).Count -gt 0 -or
      @($Supplement.comparisons.PSObject.Properties).Count -gt 0 -or
      $null -ne $Supplement.current) {
    $end = if ($null -ne $Supplement.current -or $Supplement.status -ceq 'running') {
      '9999-12-31T23:59:59Z'
    } else { [string]$Supplement.updated_at }
    Add-PerformanceInterval 'supplemental-conservative-envelope' $LegacyStart $end
  }
}

function Add-EarlyParityPerformanceIntervals([string]$CampaignRoot) {
  foreach ($directory in @(Get-ChildItem -LiteralPath $CampaignRoot -Directory -Filter 'early-parity-*')) {
    $processPath = Join-Path $directory.FullName 'process.json'
    $errorPath = Join-Path $directory.FullName 'execution-error.json'
    $outcomePath = Join-Path $directory.FullName 'attempt-result.json'
    if (Test-Path -LiteralPath $processPath -PathType Leaf) {
      $process = Read-Issue13MainJson $processPath
      $end = if (Test-Path -LiteralPath $outcomePath -PathType Leaf) {
        [string](Read-Issue13MainJson $outcomePath).finished_at_utc
      } else { '9999-12-31T23:59:59Z' }
      if ([string]::IsNullOrWhiteSpace($end)) { $end = '9999-12-31T23:59:59Z' }
      Add-PerformanceInterval $processPath ([string]$process.process_started_at_utc) $end
    } elseif (Test-Path -LiteralPath $errorPath -PathType Leaf) {
      $errorRecord = Read-Issue13MainJson $errorPath
      $end = if ([string]::IsNullOrWhiteSpace([string]$errorRecord.finished_at_utc)) {
        '9999-12-31T23:59:59Z'
      } else { [string]$errorRecord.finished_at_utc }
      Add-PerformanceInterval $errorPath ([string]$errorRecord.started_at_utc) $end
    } else { throw "Early comparison has no authenticated time interval: $($directory.FullName)" }
  }
  foreach ($directory in @(Get-ChildItem -LiteralPath $CampaignRoot -Directory -Filter 'array-proof-canary-*')) {
    $intervalPath = Join-Path $directory.FullName 'comparison-interval.json'
    $record = Read-Issue13MainJson $intervalPath
    if ($record.schema -cne 'wlv-issue13-main-array-proof-canary-interval/1') {
      throw 'Array-proof canary has an invalid comparison interval.'
    }
    $end = if (Test-Issue13MainExactBoolean $record.process_absent_at_finished_at $true) {
      [string]$record.finished_at_utc
    } else { '9999-12-31T23:59:59Z' }
    foreach ($output in @($record.comparison_outputs)) {
      if ((Get-Issue13MainSha256 $output.path) -cne $output.sha256) {
        throw 'Array-proof canary comparison evidence changed.'
      }
    }
    # Bounds are explicitly conservative; never treat this diagnostic interval
    # as a performance measurement or extend it using a later state timestamp.
    Add-PerformanceInterval $intervalPath ([string]$record.started_at_utc) $end
  }
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
  foreach ($evidencePath in @($config.evidence_root, $executionConfig.evidence_root | Select-Object -Unique)) {
    foreach ($file in @(Get-ChildItem -LiteralPath $evidencePath -Filter process-metrics.json -File -Recurse)) {
      $metrics = Read-Issue13MainJson $file.FullName
      Add-PerformanceInterval $file.FullName ([string]$metrics.started_at_utc) `
        ([string]$metrics.finished_at_utc) $file.FullName
    }
  }
  Add-EarlyParityPerformanceIntervals (Split-Path -Parent $resolvedConfig)
  $supplementPath = Join-Path ([string]$config.control_root) 'supplemental/state.json'
  if (Test-Path -LiteralPath $supplementPath -PathType Leaf) {
    $supplement = Read-Issue13MainJson $supplementPath
    Add-SupplementalPerformanceIntervals $supplement ([string]$science.created_at_utc)
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
  $owner = if ($Original) { $science } else { $execution }
  $slot = $owner.arm_bindings.$Arm
  $root = Get-PerformanceRootRecord $Arm $Phase.method -Original:$Original
  if ($job.schema -cne 'wlv-issue13-main-job/1' -or
      $job.scenario_id -cne "$Arm/$($Phase.phase)" -or $job.arm -cne $Arm -or
      $job.method -cne $Phase.method -or $job.kind -cne $Phase.kind -or
      [long]$job.workers -ne [long]$Phase.workers -or
      [string]$job.stage -cne [string]$Phase.stage -or
      [string]$job.variant -cne [string]$Phase.variant -or
      $job.runtime_commit -cne $slot.commit -or $job.seed_commit -cne $slot.seed_commit -or
      $job.config_sha256 -cne $owner.config_sha256 -or
      $job.tooling_binding_sha256 -cne $owner.tooling_binding_sha256 -or
      $job.arm_binding_sha256 -cne $slot.binding_sha256 -or
      -not (Test-Issue13MainSamePath $job.worktree_root $root.root) -or
      -not (Test-Issue13MainSamePath $job.source_manifest_path $root.source_manifest_path) -or
      $job.source_manifest_sha256 -cne $root.source_manifest_sha256 -or
      (Get-Issue13MainSha256 $job.source_manifest_path) -cne $job.source_manifest_sha256) {
    throw "Performance identity differs from science: $Arm/$($Phase.phase)"
  }
  foreach ($name in @('source_generation_id', 'source_contract_id',
      'source_contract_version', 'source_contract_sha256')) {
    if ([string]$job.$name -cne [string]$root.$name) { throw "Source identity differs: $name" }
  }
  if ($Phase.kind -ceq 'recalculate') {
    $seedProof = if ($Original) { $null } else { Get-PerformanceLocalSeed $Arm $Phase.method }
    $seed = if ($Original) { Get-Issue13MainScenarioResult (Get-PerformanceFullPhase $Phase.method).$Arm } `
      elseif ($null -ne $seedProof) { $seedProof.proof.result_path } else { throw 'Local native seed is missing.' }
    if (-not (Test-Issue13MainSamePath $job.seed_result $seed) -or
        $job.seed_result_sha256 -cne (Get-Issue13MainSha256 $seed)) {
      throw 'Performance repeat must use its authenticated same-root native seed.'
    }
    if (-not $Original -and $separateExecution -and
        $null -eq (Get-PerformanceSeedCertificate $Arm $Phase.method $seedProof)) {
      throw 'Local seed lacks strict parity with the original scientific seed.'
    }
  }
  if (-not $Original -and ($job.scientific_config_sha256 -cne $science.config_sha256 -or
      -not (Test-Issue13MainSamePath $job.scientific_config_path $resolvedConfig))) {
    throw 'Performance attempt lost its original scientific binding.'
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

function Get-PerformanceStorageEstimate([object]$Phase, [string]$Arm, [object]$Original) {
  $resultPath = if ($null -ne $Original) { $Original.proof.result_path } else {
    $full = Get-PerformanceFullPhase $Phase.method
    if ($full.$Arm.status -ceq 'passed') { Get-Issue13MainScenarioResult $full.$Arm } else { $null }
  }
  $runBytes = if ($Phase.method -ceq 'wiodr16') { 4294967296L } else { 2147483648L }
  $basis = 'forecast-without-original-output'
  if ($null -ne $resultPath) {
    $runBytes = 0L
    foreach ($output in @((Read-Issue13MainJson $resultPath).outputs | Where-Object kind -CEQ 'run')) {
      $runBytes += [long](Get-ChildItem -LiteralPath $output.root -File -Recurse | Measure-Object Length -Sum).Sum
    }
    if ($runBytes -le 0) { throw 'Original run has no measurable persistent output.' }
    $basis = if ($null -ne $Original) { 'same-scenario-original-output' } else { 'same-method-full-original-output' }
  }
  [pscustomobject]@{ basis = $basis; original_run_bytes = $runBytes
    persistent_bytes = $runBytes + 1048576L
    transient_bytes = [long][Math]::Ceiling(1.5 * $runBytes + 104857600L)
    individual_reserve_bytes = [long][Math]::Ceiling(2.5 * $runBytes + 104857600L) }
}

function Get-PerformancePlan {
  Get-PerformanceIntervals
  $pairs = [Collections.Generic.List[object]]::new()
  $jobs = [Collections.Generic.List[object]]::new()
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
          if ($repeat.controlled -and $null -eq $selection) {
            $selection = [ordered]@{ class = 'controlled-serial-repeat'; measurement = $repeat }
            break
          }
        }
      }
      if ($null -eq $selection) {
        $root = (Get-PerformanceRootRecord $arm $phase.method).root
        $storage = Get-PerformanceStorageEstimate $phase $arm $original
        $selection = [ordered]@{ class = 'performance-pending'; repeat_required = $true
          science_passed = $phase.$arm.status -ceq 'passed'; storage = $storage
          worktree_root = $root; original = $original }
        $jobs.Add([pscustomobject]@{ scenario_id = "$arm/$($phase.phase)"; phase = $phase.phase
          arm = $arm; method = $phase.method; ordinal = [double]$phase.ordinal; kind = $phase.kind
          role = 'measurement-repeat'; root = $root; storage = $storage; original = $original })
      }
      $pair[$arm] = $selection
    }
    if ($pair.baseline.class -cne 'performance-pending' -and $pair.candidate.class -cne 'performance-pending') {
      $pair.gate = Get-Issue13MainPerformance $config $pair.baseline.measurement.proof $pair.candidate.measurement.proof
    }
    $pairs.Add([pscustomobject]$pair)
  }
  if ($separateExecution) {
    foreach ($method in @('wiodr13', 'wiodr16')) {
      foreach ($arm in @('baseline', 'candidate')) {
        $recalcs = @($jobs | Where-Object { $_.arm -ceq $arm -and $_.method -ceq $method -and $_.kind -ceq 'recalculate' })
        if ($recalcs.Count -eq 0) { continue }
        $full = Get-PerformanceFullPhase $method
        $seed = Get-PerformanceLocalSeed $arm $method
        if ($null -eq $seed -and @($jobs | Where-Object scenario_id -CEQ "$arm/$($full.phase)").Count -eq 0) {
          $record = @($full.$arm.attempts | Where-Object status -CEQ 'passed')[-1]
          $original = Get-PerformanceProof $full $arm $record -Original
          $jobs.Add([pscustomobject]@{ scenario_id = "$arm/$($full.phase)"; phase = $full.phase
            arm = $arm; method = $method; ordinal = [double]$full.ordinal; kind = 'calculate'
            role = 'auxiliary-local-seed'; root = (Get-PerformanceRootRecord $arm $method).root
            storage = (Get-PerformanceStorageEstimate $full $arm $original); original = $original })
        }
        if ($null -eq $seed -or $null -eq (Get-PerformanceSeedCertificate $arm $method $seed)) {
          $jobs.Add([pscustomobject]@{ scenario_id = "seed-parity/$arm/$method"; phase = $full.phase
            arm = $arm; method = $method; ordinal = [double]$full.ordinal + 0.25; kind = 'seed-comparison'
            role = 'strict-local-seed-parity'; root = $executionConfig.evidence_root; original = $null
            storage = [pscustomobject]@{ persistent_bytes = 1048576L; transient_bytes = 2147483648L
              individual_reserve_bytes = 2147483648L; basis = 'streaming-comparison-reserve' } })
        }
      }
    }
  }
  $disk = @($jobs | Group-Object { [IO.Path]::GetPathRoot([string]$_.root) } | ForEach-Object {
    $free = [long](Get-PSDrive -Name $_.Name.TrimEnd('\', '/', ':')).Free
    $persistent = [long]($_.Group.storage.persistent_bytes | Measure-Object -Sum).Sum
    $transient = [long]($_.Group.storage.transient_bytes | Measure-Object -Maximum).Maximum
    [ordered]@{ volume = $_.Name; free_bytes = $free; remaining_persistent_bytes = $persistent
      maximum_single_job_transient_bytes = $transient; estimated_additional_bytes = $persistent + $transient
      required_free_floor_bytes = [long]$config.scheduling.minimum_free_worktree_volume_bytes
      fits = $free - $persistent - $transient -ge [long]$config.scheduling.minimum_free_worktree_volume_bytes }
  })
  $complete = @($pairs | Where-Object { $null -ne $_.gate }).Count
  $failed = @($pairs | Where-Object { $null -ne $_.gate -and
      (-not $_.gate.time_passed -or -not $_.gate.rss_passed) }).Count
  [ordered]@{ schema = 'wlv-issue13-main-performance-plan/1'; campaign_id = $science.campaign_id
    scientific_config = [ordered]@{ path = $resolvedConfig; sha256 = $science.config_sha256 }
    execution_config = [ordered]@{ path = $resolvedExecution; sha256 = $execution.config_sha256 }
    comparison_binding = [ordered]@{ path = $resolvedComparisonBinding; sha256 = $comparisonBindingSha }
    status = if ($complete -lt 14) { 'performance-pending' } elseif ($failed -gt 0) { 'failed' } else { 'passed' }
    controlled_pairs = $complete; required_pairs = 14; failed_pairs = $failed
    repeats_required = @($pairs | ForEach-Object { $_.baseline; $_.candidate } |
      Where-Object class -CEQ 'performance-pending').Count
    auxiliary_seed_calculations_required = @($jobs | Where-Object role -CEQ 'auxiliary-local-seed').Count
    seed_comparisons_required = @($jobs | Where-Object kind -CEQ 'seed-comparison').Count
    native_calculations_and_recalculations_required = @($jobs | Where-Object kind -CNE 'seed-comparison').Count
    completed_auxiliary_seed_calculations = @($performance.attempts | Where-Object {
      $_.role -ceq 'auxiliary-local-seed' -and $_.status -ceq 'passed' }).Count
    jobs = @($jobs | Sort-Object ordinal, @{ Expression = {
      $baselineFirst = [long][Math]::Floor($_.ordinal) % 2 -ne 0
      if (($_.arm -ceq 'baseline') -eq $baselineFirst) { 0 } else { 1 }
    } })
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
$resolvedExecution = if ([string]::IsNullOrWhiteSpace($ExecutionConfigPath)) { $resolvedConfig } else {
  ConvertTo-Issue13MainFullPath $ExecutionConfigPath -RequireExistingFile
}
$separateExecution = -not (Test-Issue13MainSamePath $resolvedConfig $resolvedExecution)
$executionConfig = Read-Issue13MainJson $resolvedExecution
Assert-PerformanceOperationalDelta $config $executionConfig
$null = Assert-Issue13MainConfig $executionConfig
$execution = Read-Issue13MainJson (Join-Path $executionConfig.control_root 'state.json')
if ($execution.schema -cne 'wlv-issue13-main-state/1' -or
    $execution.config_sha256 -cne (Get-Issue13MainSha256 $resolvedExecution) -or
    $execution.tooling_binding_sha256 -cne $science.tooling_binding_sha256 -or
    (Get-Issue13MainSha256 $execution.tooling_binding_path) -cne $execution.tooling_binding_sha256) {
  throw 'Execution campaign/config/tooling identity differs.'
}
foreach ($arm in @('baseline', 'candidate')) {
  $localBinding = Get-Issue13MainArmBinding $executionConfig $arm
  if ($localBinding.binding_sha256 -cne $execution.arm_bindings.$arm.binding_sha256 -or
      $localBinding.commit -cne $science.arm_bindings.$arm.commit -or
      $localBinding.seed_commit -cne $science.arm_bindings.$arm.seed_commit) { throw 'Execution arm commit or binding differs.' }
  foreach ($method in @('wiodr13', 'wiodr16')) {
    $original = Get-PerformanceRootRecord $arm $method -Original
    $local = Get-PerformanceRootRecord $arm $method
    foreach ($field in @('source_manifest_sha256', 'source_generation_id', 'source_contract_id',
        'source_contract_version', 'source_contract_sha256')) {
      if ([string]$local.$field -cne [string]$original.$field) { throw "Execution source identity differs: $field" }
    }
    if ((Get-Issue13MainSha256 $local.source_manifest_path) -cne $original.source_manifest_sha256) {
      throw 'Execution source manifest differs from the original.'
    }
    if ($separateExecution -and (Test-Issue13MainSamePath $local.root $original.root)) {
      throw 'Separate execution must use separate roots.'
    }
  }
}
$resolvedComparisonBinding = if ([string]::IsNullOrWhiteSpace($ComparisonBindingPath)) {
  Join-Path (Split-Path -Parent $resolvedConfig) 'comparison-tooling-v1/comparison-binding.json'
} else { ConvertTo-Issue13MainFullPath $ComparisonBindingPath -RequireExistingFile }
$comparisonBindingSha = Get-Issue13MainSha256 $resolvedComparisonBinding
$null = Assert-Issue13MainComparisonBinding $resolvedComparisonBinding $comparisonBindingSha $config
$provisioningPath = Join-Path (Split-Path -Parent $resolvedExecution) 'provisioning.json'
Assert-PerformanceProvisioning
$performanceRoot = Join-Path ([string]$executionConfig.control_root) 'performance'
$performancePath = Join-Path $performanceRoot 'state.json'
$performance = if (Test-Path -LiteralPath $performancePath -PathType Leaf) {
  Read-Issue13MainJson $performancePath
} else {
  [pscustomobject]@{ schema = 'wlv-issue13-main-performance-state/2'; campaign_id = $executionConfig.campaign_id
    config_sha256 = $science.config_sha256; execution_config_sha256 = $execution.config_sha256
    comparison_binding_sha256 = $comparisonBindingSha; binding_path = $null; binding_sha256 = $null
    status = 'performance-pending'; current = $null; attempts = @() }
}
if ($performance.schema -cne 'wlv-issue13-main-performance-state/2' -or
    $performance.config_sha256 -cne $science.config_sha256 -or
    $performance.execution_config_sha256 -cne $execution.config_sha256 -or
    $performance.comparison_binding_sha256 -cne $comparisonBindingSha) { throw 'Performance state binding changed.' }
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
$executionLock = $null
$process = $null
try {
  $null = Write-Issue13MainJson ([ordered]@{ schema = 'wlv-issue13-main-lock/1'; pid = $PID
    process_started_at_utc = (Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')
    action = 'ControlledPerformance'; acquired_at_utc = [DateTime]::UtcNow.ToString('o') }) (Join-Path $mainLock 'owner.json')
  if ($separateExecution) {
    $candidateLock = Join-Path $executionConfig.control_root '.issue13-main-lock'
    if (Test-Path -LiteralPath $candidateLock) { throw 'Execution campaign is already locked.' }
    $null = New-Item -ItemType Directory -Path $candidateLock
    $executionLock = $candidateLock
    Copy-Item -LiteralPath (Join-Path $mainLock 'owner.json') -Destination (Join-Path $executionLock 'owner.json')
  }
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
  if (@($intervals | Where-Object { $_.end.Year -eq 9999 }).Count -gt 0) {
    throw 'A campaign or early comparison interval remains open; controlled repeats cannot start.'
  }
  Initialize-PerformanceBinding
  Assert-PerformanceProvisioning -HashPayloads
  $count = 0
  foreach ($item in @($plan.jobs)) {
      $arm = [string]$item.arm
      $phase = @($science.phases | Where-Object phase -CEQ $item.phase)[0]
      $isComparison = $item.kind -ceq 'seed-comparison'
      if (-not $isComparison -and $count -ge $MaximumRepeats) { continue }
      $seed = if ($isComparison -or $item.kind -ceq 'recalculate') {
        Get-PerformanceLocalSeed $arm $item.method
      } else { $null }
      if ($isComparison -and $null -eq $seed) { continue }
      if ($item.kind -ceq 'recalculate' -and $separateExecution -and
          ($null -eq $seed -or $null -eq (Get-PerformanceSeedCertificate $arm $item.method $seed))) {
        throw 'Recalculation requires a local seed with strict D/C parity.'
      }
      $number = 1 + @($performance.attempts | Where-Object scenario_id -CEQ $item.scenario_id).Count
      $safe = Get-Issue13MainSafeId $item.scenario_id
      $attemptRoot = Join-Path $performanceRoot "$safe/attempt-$($number.ToString('0000'))"
      $evidenceRoot = Join-Path ([string]$executionConfig.evidence_root) "performance/$safe/attempt-$($number.ToString('0000'))"
      if ((Test-Path -LiteralPath $attemptRoot) -or (Test-Path -LiteralPath $evidenceRoot)) {
        throw 'Performance attempt already exists; it will not be overwritten.'
      }
      $os = Get-CimInstance Win32_OperatingSystem
      $reserve = if ($isComparison) { 2147483648L } `
        elseif ([long]$phase.workers -eq 2) { $config.scheduling.job_reserve_bytes.workers2 } `
        elseif ($item.method -ceq 'wiodr16') { $config.scheduling.job_reserve_bytes.wiodr16_workers1 } `
        else { $config.scheduling.job_reserve_bytes.wiodr13_workers1 }
      if ([long]$os.FreePhysicalMemory * 1024L - [long]$reserve -lt
          [long]$config.scheduling.minimum_free_physical_bytes) { throw 'Insufficient free RAM for controlled repeat.' }
      $volume = [IO.Path]::GetPathRoot([string]$item.root).TrimEnd('\', '/', ':')
      if ([long](Get-PSDrive -Name $volume).Free - [long]$item.storage.individual_reserve_bytes -lt
          [long]$config.scheduling.minimum_free_worktree_volume_bytes) {
        throw 'Insufficient disk headroom for this repeat; existing evidence is preserved.'
      }
      $null = New-Item -ItemType Directory -Path $attemptRoot
      $workerPath = Join-Path $PSScriptRoot $(if ($isComparison) {
        'issue13-main-performance-seed.ps1'
      } else { 'issue13-main-worker.ps1' })
      $controllers = New-Issue13MainControllerSnapshots $attemptRoot @(
        [pscustomobject]@{ role = 'performance-controller'; path = $PSCommandPath },
        [pscustomobject]@{ role = 'shared-lib'; path = (Join-Path $PSScriptRoot 'issue13-main-lib.ps1') },
        [pscustomobject]@{ role = 'comparison-binding'; path = (Join-Path $PSScriptRoot 'issue13-main-comparison-binding.ps1') },
        [pscustomobject]@{ role = 'worker'; path = $workerPath })
      if ($isComparison) {
        $originalPath = Get-Issue13MainScenarioResult (Get-PerformanceFullPhase $item.method).$arm
        $job = [pscustomobject]@{
          schema = 'wlv-issue13-performance-seed-job/1'; scenario_id = $item.scenario_id
          arm = $arm; method = $item.method; commit = $execution.arm_bindings.$arm.commit
          attempt_root = $attemptRoot; mode = 'strict'; output_directory = Join-Path $evidenceRoot 'comparison'
          original_result = $originalPath; original_result_sha256 = Get-Issue13MainSha256 $originalPath
          local_result = $seed.proof.result_path; local_result_sha256 = $seed.proof.result_sha256
          original_arm_binding_sha256 = $science.arm_bindings.$arm.binding_sha256
          local_arm_binding_sha256 = $execution.arm_bindings.$arm.binding_sha256
          scientific_config_path = $resolvedConfig; scientific_config_sha256 = $science.config_sha256
          execution_config_path = $resolvedExecution; execution_config_sha256 = $execution.config_sha256
          comparison_binding_path = $resolvedComparisonBinding; comparison_binding_sha256 = $comparisonBindingSha
          controller_records = $controllers
        }
      } else {
      $job = $item.original.job | ConvertTo-Json -Depth 30 | ConvertFrom-Json -DateKind String
      $rootRecord = Get-PerformanceRootRecord $arm $item.method
      $job.worktree_root = $rootRecord.root
      $job.source_manifest_path = $rootRecord.source_manifest_path
      $job.config_path = $resolvedExecution; $job.config_sha256 = $execution.config_sha256
      $job.arm_binding_path = $execution.arm_bindings.$arm.binding_path
      $job.arm_binding_sha256 = $execution.arm_bindings.$arm.binding_sha256
      $job.tooling_binding_path = $execution.tooling_binding_path
      $job.tooling_binding_sha256 = $execution.tooling_binding_sha256
      $job | Add-Member -NotePropertyName scientific_config_path -NotePropertyValue $resolvedConfig -Force
      $job | Add-Member -NotePropertyName scientific_config_sha256 -NotePropertyValue $science.config_sha256 -Force
      if ($item.kind -ceq 'recalculate') {
        $job.seed_result = $seed.proof.result_path; $job.seed_result_sha256 = $seed.proof.result_sha256
      }
      $job.attempt = $number; $job.attempt_root = $attemptRoot
      $job.specs_root = Join-Path $evidenceRoot 'specs'
      $job.attempt_evidence_root = Join-Path $evidenceRoot 'evidence'
      $job.scenario_evidence = Join-Path $job.attempt_evidence_root "scenarios/$safe"
      $ordinal = $phase.ordinal
      $job.channel = "i13perf-$($executionConfig.campaign_id)-$arm-p$ordinal-a$number".ToLowerInvariant()
      $job.controller_records = $controllers
      }
      $jobPath = Join-Path $attemptRoot 'job.json'
      $attempt = [pscustomobject]@{ scenario_id = $job.scenario_id; status = 'starting'; role = $item.role; kind = $item.kind
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
          $workerPath, '-JobPath', $jobPath)) {
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
      if (-not $isComparison) { $count++ }
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
  if ($null -ne $executionLock) { [IO.Directory]::Delete($executionLock, $true) }
  [IO.Directory]::Delete($mainLock, $true)
}
