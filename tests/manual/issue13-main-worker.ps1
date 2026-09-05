param(
  [Parameter(Mandatory = $true)][string]$JobPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'issue13-main-lib.ps1')

$resolvedJobPath = ConvertTo-Issue13MainFullPath $JobPath -RequireExistingFile
$jobSha256 = Get-Issue13MainSha256 $resolvedJobPath
$job = Read-Issue13MainJson $resolvedJobPath
if ($job.schema -cne 'wlv-issue13-main-job/1') {
  throw 'Unsupported reduced gate job schema.'
}
$attemptRoot = ConvertTo-Issue13MainFullPath ([string]$job.attempt_root) `
  -RequireExistingDirectory
$resultPath = Join-Path $attemptRoot 'attempt-result.json'
if (Test-Path -LiteralPath $resultPath) {
  throw "Attempt result already exists: $resultPath"
}
$started = [DateTime]::UtcNow
$outcome = [ordered]@{
  schema = 'wlv-issue13-main-attempt/1'
  scenario_id = [string]$job.scenario_id
  attempt = [long]$job.attempt
  status = 'running'
  passed = $false
  started_at_utc = $started.ToString('o')
  finished_at_utc = $null
  job_path = $resolvedJobPath
  job_sha256 = $jobSha256
  config_sha256 = [string]$job.config_sha256
  tooling_binding_sha256 = [string]$job.tooling_binding_sha256
  worktree_root = [string]$job.worktree_root
  runtime_commit = [string]$job.runtime_commit
  seed_commit = [string]$job.seed_commit
  channel = [string]$job.channel
  evidence_directory = [string]$job.scenario_evidence
  scenario_result_sha256 = $null
  process_metrics_sha256 = $null
  controller_records = [object[]]$job.controller_records
  error = $null
}

$priorEnvironment = $null

try {
  $configPath = ConvertTo-Issue13MainFullPath ([string]$job.config_path) `
    -RequireExistingFile
  if ((Get-Issue13MainSha256 $configPath) -cne [string]$job.config_sha256) {
    throw 'Reduced gate config changed after this job was planned.'
  }
  $config = Read-Issue13MainJson $configPath
  $null = Assert-Issue13MainConfig $config
  $priorEnvironment = Enter-Issue13MainClosedREnvironment $config
  $null = Assert-Issue13MainControllerSnapshots `
    ([object[]]$job.controller_records) -RequireExecutionFiles
  $armBindingPath = ConvertTo-Issue13MainFullPath `
    ([string]$job.arm_binding_path) -RequireExistingFile
  if ((Get-Issue13MainSha256 $armBindingPath) -cne
      [string]$job.arm_binding_sha256) {
    throw 'Arm binding changed after this job was planned.'
  }
  $armBinding = Get-Issue13MainArmBinding $config ([string]$job.arm)
  if ([string]$armBinding.binding_sha256 -cne
      [string]$job.arm_binding_sha256 -or
      [string]$armBinding.commit -cne [string]$job.runtime_commit -or
      [string]$armBinding.seed_commit -cne [string]$job.seed_commit) {
    throw 'Arm binding identity differs from the planned job.'
  }
  if (-not (Test-Issue13MainSamePath `
      ([string]$armBinding.roots.([string]$job.method)) `
      ([string]$job.worktree_root))) {
    throw 'Arm root identity differs from the planned job.'
  }
  $bindingPath = ConvertTo-Issue13MainFullPath `
    ([string]$job.tooling_binding_path) -RequireExistingFile
  if ((Get-Issue13MainSha256 $bindingPath) -cne
      [string]$job.tooling_binding_sha256) {
    throw 'Tooling binding changed after this job was planned.'
  }
  $binding = Read-Issue13MainJson $bindingPath
  $null = Assert-Issue13MainToolingBinding $binding

  $root = ConvertTo-Issue13MainFullPath ([string]$job.worktree_root) `
    -RequireExistingDirectory
  $gitOutput = @(& ([string]$config.git) -C $root rev-parse HEAD 2>&1)
  $gitExitCode = $LASTEXITCODE
  $commit = if ($gitOutput.Count -gt 0) { ([string]$gitOutput[0]).Trim() } else { '' }
  if ($gitExitCode -ne 0 -or $commit -cne [string]$job.runtime_commit) {
    throw "Worktree commit differs for $($job.scenario_id)."
  }
  if ((Get-Issue13MainSha256 ([string]$job.source_manifest_path)) -cne
      [string]$job.source_manifest_sha256) {
    throw "Source manifest changed for $($job.scenario_id)."
  }
  if ([string]$job.kind -ceq 'recalculate') {
    if ((Get-Issue13MainSha256 ([string]$job.seed_result)) -cne
        [string]$job.seed_result_sha256) {
      throw "Seed result changed for $($job.scenario_id)."
    }
  } elseif (-not [string]::IsNullOrEmpty([string]$job.seed_result) -or
      -not [string]::IsNullOrEmpty([string]$job.seed_result_sha256)) {
    throw 'Calculate job unexpectedly has a seed result.'
  }
  $resultsLock = Join-Path $root 'results\.lock-results'
  if (Test-Path -LiteralPath $resultsLock) {
    throw "Results root is already locked: $root"
  }

  $specsRoot = [string]$job.specs_root
  $attemptEvidence = [string]$job.attempt_evidence_root
  $builder = if ([string]$job.kind -ceq 'calculate') {
    'issue13-build-calculate-bundle.R'
  } elseif ([string]$job.kind -ceq 'recalculate') {
    'issue13-build-recalc-bundle.R'
  } else {
    throw "Unsupported reduced scientific kind: $($job.kind)"
  }
  $arguments = [Collections.Generic.List[string]]::new()
  foreach ($value in @(
      '--vanilla', (Join-Path ([string]$config.harness_root) $builder),
      '--arm', [string]$job.arm,
      '--method', [string]$job.method,
      '--project-root', $root,
      '--runtime-commit', [string]$job.runtime_commit,
      '--channel', [string]$job.channel,
      '--output', $specsRoot,
      '--evidence-root', $attemptEvidence,
      '--rscript', [string]$config.rscript,
      '--r-library', [string]$config.r_library,
      '--timeout-seconds', '14400')) {
    $arguments.Add([string]$value)
  }
  if ([string]$job.kind -ceq 'calculate') {
    foreach ($value in @('--workers', [string]$job.workers)) {
      $arguments.Add([string]$value)
    }
  } else {
    foreach ($value in @(
        '--stage', [string]$job.stage,
        '--variant', [string]$job.variant,
        '--seed-commit', [string]$job.seed_commit,
        '--seed-result', [string]$job.seed_result)) {
      $arguments.Add([string]$value)
    }
  }
  & ([string]$config.rscript) $arguments.ToArray()
  if ($LASTEXITCODE -ne 0) {
    throw "Scenario bundle builder failed: $($job.scenario_id)"
  }
  $bundlePath = ConvertTo-Issue13MainFullPath `
    (Join-Path $specsRoot 'bundle.json') -RequireExistingFile
  $bundle = Read-Issue13MainJson $bundlePath
  if ([string]$bundle.scenario_id -cne [string]$job.scenario_id -or
      [string]$bundle.runtime_commit -cne [string]$job.runtime_commit -or
      [string]$bundle.channel -cne [string]$job.channel -or
      -not [string]::Equals(
        [IO.Path]::GetFullPath([string]$bundle.scenario_evidence),
        [IO.Path]::GetFullPath([string]$job.scenario_evidence),
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Scenario bundle binding differs: $($job.scenario_id)"
  }

  if ([string]$job.kind -ceq 'recalculate') {
    & ([string]$config.sealed_pwsh) -NoLogo -NoProfile -File `
      (Join-Path ([string]$config.harness_root) `
        'issue13-run-recalc-bundle.ps1') -BundlePath $bundlePath
  } else {
    & ([string]$config.sealed_pwsh) -NoLogo -NoProfile -File `
      (Join-Path ([string]$config.harness_root) 'issue13-monitor.ps1') `
      -SpecPath ([string]$bundle.process_spec) `
      -EvidenceDir ([string]$bundle.scenario_evidence)
  }
  if ($LASTEXITCODE -ne 0) {
    throw "Scenario runner failed: $($job.scenario_id)"
  }
  if ((Get-Issue13MainSha256 ([string]$job.source_manifest_path)) -cne
      [string]$job.source_manifest_sha256 -or
      ([string]$job.kind -ceq 'recalculate' -and
       (Get-Issue13MainSha256 ([string]$job.seed_result)) -cne
         [string]$job.seed_result_sha256)) {
    throw "A scientific input changed during execution: $($job.scenario_id)"
  }
  $expectedWorkers = if ([string]$job.kind -ceq 'calculate' -and
      [long]$job.workers -eq 2) { 2L } else { 0L }
  $validated = Test-Issue13MainScenarioEvidence `
    ([string]$job.scenario_evidence) ([string]$job.scenario_id) `
    ([string]$job.runtime_commit) $expectedWorkers
  $outcome.status = 'passed'
  $outcome.passed = $true
  $outcome.scenario_result_sha256 = [string]$validated.result_sha256
  $outcome.process_metrics_sha256 = [string]$validated.metrics_sha256
} catch {
  $outcome.status = 'failed'
  $outcome.error = $_.Exception.Message
} finally {
  if ($null -ne $priorEnvironment) {
    Exit-Issue13MainClosedREnvironment ([object[]]$priorEnvironment)
  }
  $outcome.finished_at_utc = [DateTime]::UtcNow.ToString('o')
  $null = Write-Issue13MainJson $outcome $resultPath
}

if (-not (Test-Issue13MainExactBoolean $outcome.passed $true)) {
  Write-Error ([string]$outcome.error)
  exit 1
}
exit 0
