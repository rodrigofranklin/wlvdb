param(
  [Parameter(Mandatory = $true)][string]$JobPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'issue13-main-lib.ps1')
. (Join-Path $PSScriptRoot 'issue13-main-comparison-binding.ps1')

$resolvedJobPath = ConvertTo-Issue13MainFullPath $JobPath -RequireExistingFile
$jobSha256 = Get-Issue13MainSha256 $resolvedJobPath
$job = Read-Issue13MainJson $resolvedJobPath
if ($job.schema -cne 'wlv-issue13-main-comparison-job/2') {
  throw 'Unsupported reduced comparison job schema.'
}
$attemptRoot = ConvertTo-Issue13MainFullPath ([string]$job.attempt_root) `
  -RequireExistingDirectory
$resultPath = Join-Path $attemptRoot 'attempt-result.json'
$outcome = [ordered]@{
  schema = 'wlv-issue13-main-comparison-attempt/2'
  comparison_id = [string]$job.comparison_id
  attempt = [long]$job.attempt
  status = 'running'; passed = $false
  comparison_passed = $null
  started_at_utc = [DateTime]::UtcNow.ToString('o')
  finished_at_utc = $null
  job_path = $resolvedJobPath
  job_sha256 = $jobSha256
  config_sha256 = [string]$job.config_sha256
  tooling_binding_sha256 = [string]$job.tooling_binding_sha256
  comparison_binding_sha256 = [string]$job.comparison_binding_sha256
  comparison_binding_path = [string]$job.comparison_binding_path
  output_directory = [string]$job.output_directory
  comparison_sha256 = $null
  controller_records = [object[]]$job.controller_records
  error = $null
}
$priorEnvironment = $null
try {
  if ((Get-Issue13MainSha256 ([string]$job.config_path)) -cne
      [string]$job.config_sha256) {
    throw 'Reduced gate config changed after comparison planning.'
  }
  $config = Read-Issue13MainJson ([string]$job.config_path)
  $null = Assert-Issue13MainConfig $config
  $priorEnvironment = Enter-Issue13MainClosedREnvironment $config
  $null = Assert-Issue13MainControllerSnapshots `
    ([object[]]$job.controller_records) -RequireExecutionFiles
  if ($job.allow_difference -isnot [bool]) {
    throw 'allow_difference is not an exact JSON boolean.'
  }
  $binding = Read-Issue13MainJson ([string]$job.tooling_binding_path)
  if ((Get-Issue13MainSha256 ([string]$job.tooling_binding_path)) -cne
      [string]$job.tooling_binding_sha256) {
    throw 'Tooling binding changed after comparison planning.'
  }
  $null = Assert-Issue13MainToolingBinding $binding
  $comparisonBinding = Assert-Issue13MainComparisonBinding `
    ([string]$job.comparison_binding_path) `
    ([string]$job.comparison_binding_sha256) $config
  $comparisonHarness = Join-Path ([string]$comparisonBinding.runtime_root) `
    'issue13-evidence-harness'
  $null = Assert-Issue13MainComparisonInputs $job $config
  foreach ($side in @('candidate', 'baseline')) {
    $pathName = $side + '_result'
    $hashName = $side + '_result_sha256'
    if ((Get-Issue13MainSha256 ([string]$job.$pathName)) -cne
        [string]$job.$hashName) {
      throw "Comparison input changed: $side"
    }
  }
  if (Test-Path -LiteralPath ([string]$job.output_directory)) {
    throw 'Comparison output directory already exists.'
  }
  & ([string]$config.rscript) --vanilla `
    (Join-Path $comparisonHarness 'issue13-compare-results.R') `
    --candidate-result ([string]$job.candidate_result) `
    --candidate-selector ([string]$job.candidate_selector) `
    --baseline-result ([string]$job.baseline_result) `
    --baseline-selector ([string]$job.baseline_selector) `
    --output ([string]$job.output_directory) `
    --scenario-id ([string]$job.comparison_id) `
    --comparison-mode ([string]$job.mode) --chunk-rows 1000000
  $exitCode = $LASTEXITCODE
  $null = Assert-Issue13MainComparisonBinding `
    ([string]$job.comparison_binding_path) `
    ([string]$job.comparison_binding_sha256) $config
  $allowedExitCodes = if (Test-Issue13MainExactBoolean `
      $job.allow_difference $true) { @(0, 1) } else { @(0) }
  if ($exitCode -notin $allowedExitCodes) {
    throw "Comparator exited unexpectedly: $exitCode"
  }
  $comparisonPath = Join-Path ([string]$job.output_directory) 'comparison.json'
  $document = Read-Issue13MainJson $comparisonPath
  if ($document.schema -cne 'wlv-issue13-artifact-comparison/1' -or
      [string]$document.scenario_id -cne [string]$job.comparison_id -or
      [string]$document.comparison_mode -cne [string]$job.mode -or
      $document.passed -isnot [bool] -or
      ((Test-Issue13MainExactBoolean $job.allow_difference $false) -and
       -not (Test-Issue13MainExactBoolean $document.passed $true))) {
    throw 'Comparator output failed its reduced binding.'
  }
  foreach ($side in @('candidate', 'baseline')) {
    if ((Get-Issue13MainSha256 ([string]$job.($side + '_result'))) -cne
        [string]$job.($side + '_result_sha256')) {
      throw "Comparison input changed during comparison: $side"
    }
  }
  $outcome.status = 'passed'
  $outcome.passed = $true
  $outcome.comparison_passed = $document.passed
  $outcome.comparison_sha256 = Get-Issue13MainSha256 $comparisonPath
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
