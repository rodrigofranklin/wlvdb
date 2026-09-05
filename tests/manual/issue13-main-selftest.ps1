param(
  [string]$SourceV5Config =
    'D:\Trabalho\Code\wlvdb-issue13-native-final-config-v5-terminal-rerun-053\gate-config.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'issue13-main-lib.ps1')

$plan = New-Issue13MainPlan
if ($plan.scientific_pair_count -ne 14 -or
    $plan.scientific_scenario_count -ne 28 -or
    $plan.preparation_pair_count -ne 1 -or
    $plan.fault_count -ne 10 -or
    $plan.monitored_scenario_count -ne 40 -or
    $plan.authenticated_comparison_count -ne 41 -or
    $plan.paper_scenarios -ne 0 -or
    @($plan.phases).Count -ne 14 -or
    @($plan.faults).Count -ne 10) {
  throw 'Reduced main plan counts changed.'
}
$ids = @($plan.phases | ForEach-Object phase)
if (@($ids | Select-Object -Unique).Count -ne 14 -or
    @($plan.phases | Where-Object workers -eq 2).Count -ne 2 -or
    @($plan.phases | Where-Object kind -eq 'recalculate').Count -ne 10) {
  throw 'Reduced main plan phase coverage changed.'
}

$source = Read-Issue13MainJson $SourceV5Config
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
  'issue13-main-selftest-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $temporaryRoot
try {
  $configPath = Join-Path $temporaryRoot 'campaign.json'
  $utcRoundTripPath = Join-Path $temporaryRoot 'utc-round-trip.json'
  $utcReference = '2026-09-04T22:15:16.1234567Z'
  $null = Write-Issue13MainJson ([ordered]@{ value = $utcReference }) `
    $utcRoundTripPath
  $utcRoundTrip = Read-Issue13MainJson $utcRoundTripPath
  if ($utcRoundTrip.value -isnot [string] -or
      [string]$utcRoundTrip.value -cne $utcReference) {
    throw 'UTC JSON text did not survive an exact string round trip.'
  }
  $config = [ordered]@{
    schema = 'wlv-issue13-main-gate-config/1'
    campaign_id = 'issue13-main-selftest'
    source_v5_config = (Resolve-Path -LiteralPath $SourceV5Config).Path
    control_root = Join-Path $temporaryRoot 'control'
    evidence_root = Join-Path $temporaryRoot 'evidence'
    harness_root = [string]$source.harness_root
    harness_manifest = [string]$source.harness_manifest_path
    rscript = [string]$source.rscript
    r_library = [string]$source.r_library
    sealed_pwsh =
      'C:\Users\rodri\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
    git = 'C:\Program Files\Git\cmd\git.exe'
    arms = [ordered]@{
      baseline = [ordered]@{
        binding_path = Join-Path $temporaryRoot 'baseline-binding.json'
      }
      candidate = [ordered]@{
        binding_path = Join-Path $temporaryRoot 'candidate-binding.json'
      }
    }
    supplemental_roots = [ordered]@{
      baseline_preparation = 'D:\pending\baseline-preparation'
      candidate_preparation = 'D:\pending\candidate-preparation'
      candidate_fault = 'D:\pending\candidate-fault'
    }
    scheduling = [ordered]@{
      maximum_isolated_jobs = 4
      comparison_jobs = 2
      memory_budget_bytes = 85899345920L
      minimum_free_physical_bytes = 17179869184L
      minimum_free_worktree_volume_bytes = 21474836480L
      job_reserve_bytes = [ordered]@{
        wiodr13_workers1 = 8589934592L
        wiodr16_workers1 = 23622320128L
        workers2 = 42949672960L
      }
    }
    performance = [ordered]@{
      science_measurements = 'observational'
      controlled_maximum_jobs = 1
      candidate_time_ratio_maximum = 1.2
      candidate_time_absolute_allowance_seconds = 600.0
      candidate_rss_baseline_ratio_allowance = 0.1
      candidate_rss_minimum_allowance_bytes = 536870912L
    }
  }
  $null = Write-Issue13MainJson $config $configPath
  & ([string]$config.sealed_pwsh) -NoLogo -NoProfile -File `
    (Join-Path $PSScriptRoot 'issue13-main-gate.ps1') `
    -Action Initialize -ConfigPath $configPath | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Initialize self-test failed.' }
  $state = Read-Issue13MainJson (Join-Path $config.control_root 'state.json')
  $binding = Read-Issue13MainJson `
    (Join-Path $config.control_root 'tooling-binding.json')
  if ($state.schema -cne 'wlv-issue13-main-state/1' -or
      @($state.phases).Count -ne 14 -or
      @($state.comparisons).Count -ne 38 -or
      [string]$state.arm_bindings.baseline.status -cne 'pending' -or
      [string]$state.arm_bindings.candidate.status -cne 'pending' -or
      $binding.eligibility -cne
        'tooling-only-no-historical-evidence-adoption') {
    throw 'Initialize did not preserve the reduced campaign contract.'
  }
  Write-Output 'Issue #13 reduced main gate self-test passed.'
} finally {
  $resolvedTemporary = [IO.Path]::GetFullPath($temporaryRoot)
  $resolvedSystemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  if (-not $resolvedTemporary.StartsWith($resolvedSystemTemp,
      [StringComparison]::OrdinalIgnoreCase) -or
      [IO.Path]::GetFileName($resolvedTemporary) -cnotmatch
        '^issue13-main-selftest-[0-9a-f]{32}$') {
    throw 'Refusing to remove an unexpected self-test directory.'
  }
  if (Test-Path -LiteralPath $resolvedTemporary) {
    [IO.Directory]::Delete($resolvedTemporary, $true)
  }
}
