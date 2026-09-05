param([Parameter(Mandatory)][string]$JobPath)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'issue13-main-lib.ps1')
. (Join-Path $PSScriptRoot 'issue13-main-comparison-binding.ps1')

$jobPathResolved = ConvertTo-Issue13MainFullPath $JobPath -RequireExistingFile
$job = Read-Issue13MainJson $jobPathResolved
if ($job.schema -cne 'wlv-issue13-performance-seed-job/1' -or $job.mode -cne 'strict' -or
    $job.arm -cnotin @('baseline', 'candidate') -or $job.method -cnotin @('wiodr13', 'wiodr16')) {
  throw 'Invalid performance seed comparison job.'
}
$outcome = [ordered]@{
  schema = 'wlv-issue13-performance-seed-result/1'; status = 'running'; passed = $false
  scenario_id = $job.scenario_id; started_at_utc = [DateTime]::UtcNow.ToString('o')
  finished_at_utc = $null; job_path = $jobPathResolved
  job_sha256 = Get-Issue13MainSha256 $jobPathResolved
  scientific_config_sha256 = $job.scientific_config_sha256
  execution_config_sha256 = $job.execution_config_sha256
  original_result_sha256 = $job.original_result_sha256
  local_result_sha256 = $job.local_result_sha256
  comparison_binding_sha256 = $job.comparison_binding_sha256
  comparison_path = Join-Path $job.output_directory 'comparison.json'
  comparison_sha256 = $null; error = $null
}
$prior = $null
try {
  foreach ($prefix in @('scientific', 'execution')) {
    if ((Get-Issue13MainSha256 $job.($prefix + '_config_path')) -cne $job.($prefix + '_config_sha256')) {
      throw "Seed comparison config changed: $prefix"
    }
  }
  $scientific = Read-Issue13MainJson $job.scientific_config_path
  $execution = Read-Issue13MainJson $job.execution_config_path
  $null = Assert-Issue13MainConfig $scientific
  $null = Assert-Issue13MainConfig $execution
  $null = Assert-Issue13MainControllerSnapshots ([object[]]$job.controller_records) -RequireExecutionFiles
  $comparison = Assert-Issue13MainComparisonBinding $job.comparison_binding_path `
    $job.comparison_binding_sha256 $scientific
  # The comparator is the authenticated D binding. Its same-root worker cannot
  # validate C inputs; bind each native proof to its own config instead.
  foreach ($side in @('original', 'local')) {
    $sideConfig = if ($side -ceq 'original') { $scientific } else { $execution }
    $armBinding = Get-Issue13MainArmBinding $sideConfig $job.arm
    if ($armBinding.binding_sha256 -cne $job.($side + '_arm_binding_sha256') -or
        $armBinding.commit -cne $job.commit -or $armBinding.seed_commit -cne $job.commit) {
      throw "Seed arm identity differs: $side"
    }
    $path = $job.($side + '_result')
    if ((Get-Issue13MainSha256 $path) -cne $job.($side + '_result_sha256')) {
      throw "Seed input changed: $side"
    }
    $proof = Read-Issue13MainJson $path
    if (-not (Test-Issue13MainSamePath $proof.project_root $armBinding.roots.($job.method)) -or
        $proof.kind -cne 'calculate' -or $proof.request.method -cne $job.method -or
        [long]$proof.request.workers -ne 1L -or
        $proof.PSObject.Properties.Name -ccontains 'authentication' -or
        $proof.PSObject.Properties.Name -ccontains 'execution_mode') {
      throw "The $side seed is not a native local workers=1 calculation."
    }
    $null = Test-Issue13MainScenarioEvidence (Split-Path -Parent $path) `
      ($job.arm + '/calculate/' + $job.method + '/workers1') $job.commit 0L
  }
  if (Test-Path -LiteralPath $job.output_directory) { throw 'Seed comparison output already exists.' }
  $prior = Enter-Issue13MainClosedREnvironment $scientific
  & $scientific.rscript --vanilla `
    (Join-Path $comparison.runtime_root 'issue13-evidence-harness/issue13-compare-results.R') `
    --candidate-result $job.local_result --candidate-selector ('run:' + $job.method) `
    --baseline-result $job.original_result --baseline-selector ('run:' + $job.method) `
    --output $job.output_directory --scenario-id $job.scenario_id --comparison-mode strict --chunk-rows 1000000
  if ($LASTEXITCODE -ne 0) { throw 'Native local seed differs from its original scientific seed.' }
  $null = Assert-Issue13MainComparisonBinding $job.comparison_binding_path `
    $job.comparison_binding_sha256 $scientific
  $document = Read-Issue13MainJson $outcome.comparison_path
  if ($document.schema -cne 'wlv-issue13-artifact-comparison/1' -or
      $document.scenario_id -cne $job.scenario_id -or $document.comparison_mode -cne 'strict' -or
      -not (Test-Issue13MainExactBoolean $document.passed $true)) {
    throw 'Strict seed comparison did not produce a passed bound result.'
  }
  foreach ($side in @('original', 'local')) {
    if ((Get-Issue13MainSha256 $job.($side + '_result')) -cne $job.($side + '_result_sha256')) {
      throw 'A seed proof changed during comparison.'
    }
  }
  $outcome.comparison_sha256 = Get-Issue13MainSha256 $outcome.comparison_path
  $outcome.status = 'passed'; $outcome.passed = $true
} catch {
  $outcome.status = 'failed'; $outcome.error = $_.Exception.Message
} finally {
  if ($null -ne $prior) { Exit-Issue13MainClosedREnvironment $prior }
  $outcome.finished_at_utc = [DateTime]::UtcNow.ToString('o')
  $null = Write-Issue13MainJson $outcome (Join-Path $job.attempt_root 'attempt-result.json')
}
if (-not $outcome.passed) { Write-Error $outcome.error; exit 1 }
