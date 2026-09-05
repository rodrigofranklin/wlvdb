param(
  [Parameter(Mandatory = $true)][string]$ConfigPath,
  [Parameter(Mandatory = $true)][string]$ComparisonBindingPath,
  [Parameter(Mandatory = $true)][string]$OutputRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'issue13-main-lib.ps1')
. (Join-Path $PSScriptRoot 'issue13-main-comparison-binding.ps1')
$config = Read-Issue13MainJson $ConfigPath
$output = ConvertTo-Issue13MainFullPath $OutputRoot
if (Test-Path -LiteralPath $output) { throw 'Selftest output already exists.' }
$null = New-Item -ItemType Directory -Path $output
$bindingSha = Get-Issue13MainSha256 $ComparisonBindingPath
$binding = Assert-Issue13MainComparisonBinding $ComparisonBindingPath $bindingSha $config
$checks = [Collections.Generic.List[object]]::new()
$checks.Add(@{ id = 'valid-independent-binding'; passed = $true })
$before = Get-Issue13MainSha256 $config.harness_manifest

function Expect-Failure([string]$Id, [scriptblock]$Action) {
  $failed = $false
  $message = $null
  try { $null = & $Action } catch { $failed = $true; $message = $_.Exception.Message }
  if (-not $failed) { throw "Negative selftest unexpectedly passed: $Id" }
  $checks.Add(@{ id = $Id; passed = $true; rejected_with = $message })
}

Expect-Failure 'binding-hash-changed' {
  Assert-Issue13MainComparisonBinding $ComparisonBindingPath ('0' * 64) $config
}
foreach ($case in @('wrong-campaign', 'missing-file', 'changed-file', 'wrong-change-list',
    'unsafe-file', 'metadata-hash', 'missing-provenance')) {
  $testBinding = Read-Issue13MainJson $ComparisonBindingPath
  switch ($case) {
    'wrong-campaign' { $testBinding.campaign_id = 'other-campaign' }
    'missing-file' { $testBinding.records = @($testBinding.records | Select-Object -Skip 1) }
    'changed-file' { $testBinding.records[0].sha256 = '0' * 64 }
    'wrong-change-list' { $testBinding.changed_files[0] = 'issue13-lib.R' }
    'unsafe-file' { $testBinding.records[0].relative_path = '../escape.R' }
    'metadata-hash' { $testBinding.metadata_sha256 = '0' * 64 }
    'missing-provenance' { $testBinding.derivation_records = @(
      $testBinding.derivation_records | Where-Object role -CNE 'provenance') }
  }
  $testPath = Join-Path $output ($case + '.json')
  $testSha = Write-Issue13MainJson $testBinding $testPath
  Expect-Failure $case {
    Assert-Issue13MainComparisonBinding $testPath $testSha $config
  }
}
$metadataPath = @($binding.derivation_records | Where-Object role -CEQ 'metadata')[0].path
foreach ($case in @('old-generation', 'deferred-method', 'missing-profile', 'wrong-commit')) {
  $metadata = Read-Issue13MainJson $metadataPath
  switch ($case) {
    'old-generation' { $metadata.candidate_runtime_generation_sha256 = '0' * 64 }
    'deferred-method' { $metadata.methods[1] = 'ochoa_1' }
    'missing-profile' { $metadata.profiles = @($metadata.profiles[0]) }
    'wrong-commit' { $metadata.candidate_commit_at_derivation = '0' * 40 }
  }
  $testPath = Join-Path $output ($case + '.json')
  $null = Write-Issue13MainJson $metadata $testPath
  Expect-Failure $case { Assert-Issue13MainComparisonMetadata $testPath }
}
$source = [IO.File]::ReadAllText((Join-Path $config.harness_root `
  'issue13-v5-compare-override.R'), [Text.UTF8Encoding]::new($false, $true))
$transformed = Get-Issue13MainReducedCompareOverride $source
Expect-Failure 'already-transformed-validator' {
  Get-Issue13MainReducedCompareOverride $transformed
}
Expect-Failure 'duplicate-derivation-guard' {
  Get-Issue13MainReducedCompareOverride (
    $source + '3ae99a848156a28431ff44cf4d9e619c6de84a83')
}
$state = Read-Issue13MainJson (Join-Path $config.control_root 'state.json')
$phase = @($state.phases | Where-Object phase -CEQ 'calculate/wiodr13/workers1')[0]
$inputJob = [pscustomobject]@{
  candidate_result = Get-Issue13MainScenarioResult $phase.candidate
  baseline_result = Get-Issue13MainScenarioResult $phase.baseline
  candidate_selector = 'run:wiodr13'; baseline_selector = 'run:wiodr13'
  input_contracts = @(
    [pscustomobject]@{ side = 'candidate'; arm = 'candidate'; method = 'wiodr13';
      scenario_id = 'candidate/calculate/wiodr13/workers1';
      commit = $state.arm_bindings.candidate.commit; expected_worker_processes = 0L },
    [pscustomobject]@{ side = 'baseline'; arm = 'baseline'; method = 'wiodr13';
      scenario_id = 'baseline/calculate/wiodr13/workers1';
      commit = $state.arm_bindings.baseline.commit; expected_worker_processes = 0L }
  )
}
$null = Assert-Issue13MainComparisonInputs $inputJob $config
$checks.Add(@{ id = 'different-engine-commits-accepted'; passed = $true })
$inputJob.input_contracts[0].arm = 'baseline'
Expect-Failure 'wrong-input-arm' { Assert-Issue13MainComparisonInputs $inputJob $config }
$inputJob.input_contracts[0].arm = 'candidate'
$inputJob.input_contracts[0].expected_worker_processes = 2L
Expect-Failure 'wrong-input-workers' { Assert-Issue13MainComparisonInputs $inputJob $config }
$inputJob.input_contracts[0].expected_worker_processes = 0L
$inputJob.baseline_result = $inputJob.candidate_result
$inputJob.input_contracts[1] = [pscustomobject]@{
  side = 'baseline'; arm = 'candidate'; method = 'wiodr13';
  scenario_id = 'candidate/calculate/wiodr13/workers1';
  commit = $state.arm_bindings.candidate.commit; expected_worker_processes = 0L
}
$null = Assert-Issue13MainComparisonInputs $inputJob $config
$checks.Add(@{ id = 'same-engine-oracle-inputs-accepted'; passed = $true })
$identity = [pscustomobject]@{
  comparison_binding_path = $ComparisonBindingPath
  comparison_binding_sha256 = $bindingSha
}
$null = Assert-Issue13MainComparisonBindingIdentity $identity $identity `
  $ComparisonBindingPath $bindingSha
Expect-Failure 'attempt-binding-a-under-binding-b' {
  Assert-Issue13MainComparisonBindingIdentity $identity $identity `
    $ComparisonBindingPath ('0' * 64)
}
$provenancePath = @($binding.derivation_records | Where-Object role -CEQ 'provenance')[0].path
$differencePath = @($binding.derivation_records | Where-Object role -CEQ 'historical-profile-differences')[0].path
foreach ($case in @('unproved-oracle', 'false-flag-as-string', 'calculation-in-derivation',
    'wrong-provenance-metadata-hash')) {
  $provenance = Read-Issue13MainJson $provenancePath
  switch ($case) {
    'unproved-oracle' { $provenance.oracle_applicability.summary.all_tables_identical = $false }
    'false-flag-as-string' { $provenance.derivation.calculations_executed = 'false' }
    'calculation-in-derivation' { $provenance.derivation.calculations_executed = $true }
    'wrong-provenance-metadata-hash' { $provenance.outputs.metadata.sha256 = '0' * 64 }
  }
  $testPath = Join-Path $output ($case + '.json')
  $null = Write-Issue13MainJson $provenance $testPath
  Expect-Failure $case {
    Assert-Issue13MainMetadataDerivation $metadataPath $testPath $differencePath $config
  }
}
if ((Get-Issue13MainSha256 $config.harness_manifest) -cne $before) {
  throw 'The science tooling manifest changed during the comparison selftest.'
}
$null = Assert-Issue13MainConfig $config
$checks.Add(@{ id = 'scientific-tooling-unchanged'; passed = $true })
$result = [ordered]@{
  schema = 'wlv-issue13-main-comparison-selftest/1'
  passed = $true
  comparison_binding_sha256 = $bindingSha
  checks = [object[]]$checks.ToArray()
}
$null = Write-Issue13MainJson $result (Join-Path $output 'selftest.json')
Write-Output ("comparison binding selftest: $($checks.Count) checks passed")
