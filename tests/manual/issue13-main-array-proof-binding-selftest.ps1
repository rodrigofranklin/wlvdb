param(
  [Parameter(Mandatory)][string]$ConfigPath,
  [Parameter(Mandatory)][string]$ComparisonBindingPath,
  [Parameter(Mandatory)][string]$CachePath,
  [Parameter(Mandatory)][string]$OutputRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'issue13-main-lib.ps1')
. (Join-Path $PSScriptRoot 'issue13-main-comparison-binding.ps1')
. (Join-Path $PSScriptRoot 'issue13-main-array-proof-binding.ps1')

$output = ConvertTo-Issue13MainFullPath $OutputRoot
if (Test-Path -LiteralPath $output) { throw 'Use a new array-proof selftest directory.' }
$null = New-Item -ItemType Directory -Path $output
$config = Read-Issue13MainJson $ConfigPath
$science = Read-Issue13MainJson (Join-Path $config.control_root 'state.json')
$protected = @($ConfigPath, $ComparisonBindingPath, $CachePath,
  $science.tooling_binding_path, $config.harness_manifest) | ForEach-Object {
  [pscustomobject]@{ path = $_; sha256 = Get-Issue13MainSha256 $_ }
}
$checks = [Collections.Generic.List[object]]::new()

function Expect-ProofFailure([string]$Id, [scriptblock]$Action,
    [string]$ExpectedMessage = 'Array-proof') {
  $failure = $null
  try { $null = & $Action } catch { $failure = $_.Exception.Message }
  if ($null -eq $failure) { throw "Negative selftest unexpectedly passed: $Id" }
  if ($failure -notmatch $ExpectedMessage) {
    throw "Negative selftest failed for an unrelated reason: $Id / $failure"
  }
  $checks.Add([ordered]@{ id = $Id; passed = $true; rejected_with = $failure })
}

$bound = New-Issue13MainArrayProofBinding (Join-Path $output 'valid-binding') `
  $CachePath $ConfigPath $ComparisonBindingPath
$proof = Assert-Issue13MainArrayProofBinding $bound.path $bound.sha256 `
  $ConfigPath $ComparisonBindingPath
$checks.Add([ordered]@{ id = 'real-cache-valid-binding'; passed = $true })
$arguments = @(Get-Issue13MainArrayProofArguments $proof)
if ($arguments.Count % 2 -ne 0 -or
    @($arguments | Where-Object { $_ -ceq '--array-proof' }).Count -ne 1 -or
    $arguments[[Array]::IndexOf($arguments, '--array-proof') + 1] -cne $proof.records.cache.path -or
    $arguments[[Array]::IndexOf($arguments, '--array-proof-sha256') + 1] -cne $proof.records.cache.sha256) {
  throw 'Bound cache arguments differ from the validated file record.'
}
$checks.Add([ordered]@{ id = 'worker-arguments-bind-cache-path-and-hash'; passed = $true })

$disabled = [pscustomobject]@{ status = 'passed' }
$enabled = [pscustomobject]@{
  array_proof_binding_path = $bound.path; array_proof_binding_sha256 = $bound.sha256
}
Assert-Issue13MainArrayProofSelection $disabled $null $null
Assert-Issue13MainArrayProofSelection $enabled $bound.path $bound.sha256
Assert-Issue13MainArrayProofSelection $enabled $bound.path.ToUpperInvariant() $bound.sha256
$checks.Add([ordered]@{ id = 'resume-unchanged-enabled-disabled-and-path-case'; passed = $true })
Expect-ProofFailure 'resume-cannot-enable' {
  Assert-Issue13MainArrayProofSelection $disabled $bound.path $bound.sha256
}
Expect-ProofFailure 'resume-cannot-disable' {
  Assert-Issue13MainArrayProofSelection $enabled $null $null
}
Expect-ProofFailure 'resume-cannot-change-path' {
  Assert-Issue13MainArrayProofSelection $enabled (Join-Path $output 'other-binding.json') $bound.sha256
}
Expect-ProofFailure 'resume-cannot-change-hash' {
  Assert-Issue13MainArrayProofSelection $enabled $bound.path ('0' * 64)
}
Expect-ProofFailure 'resume-rejects-path-without-hash' {
  Assert-Issue13MainArrayProofSelection ([pscustomobject]@{
    array_proof_binding_path = $bound.path }) $bound.path $bound.sha256
}
Expect-ProofFailure 'resume-rejects-hash-without-path' {
  Assert-Issue13MainArrayProofSelection ([pscustomobject]@{
    array_proof_binding_sha256 = $bound.sha256 }) $null $null
}
Expect-ProofFailure 'binding-sha-mismatch' {
  Assert-Issue13MainArrayProofBinding $bound.path ('0' * 64) $ConfigPath $ComparisonBindingPath
}

function New-ProofHistoryFixture([string]$Id, [bool]$Enabled) {
  $directory = Join-Path $output $Id
  $null = New-Item -ItemType Directory -Path $directory
  $comparisons = foreach ($status in @('passed', 'failed', 'running')) {
    $selection = [ordered]@{
      schema = 'synthetic-array-proof-resume-selection/1'; status = $status
      array_proof_binding_path = $(if ($Enabled) { $bound.path } else { $null })
      array_proof_binding_sha256 = $(if ($Enabled) { $bound.sha256 } else { $null })
    }
    $job = Join-Path $directory ($status + '-job.json')
    $result = Join-Path $directory ($status + '-result.json')
    $attempt = [pscustomobject]@{
      status = $status; job_path = $job; job_sha256 = Write-Issue13MainJson $selection $job
      result_path = $result; result_sha256 = Write-Issue13MainJson $selection $result
      array_proof_binding_path = $selection.array_proof_binding_path
      array_proof_binding_sha256 = $selection.array_proof_binding_sha256
    }
    [pscustomobject]@{ id = $status; status = $status; attempts = @($attempt) }
  }
  [pscustomobject]@{ comparisons = @($comparisons) }
}

$history = New-ProofHistoryFixture 'history-enabled' $true
Assert-Issue13MainArrayProofHistory $history $bound.path $bound.sha256
$historyDisabled = New-ProofHistoryFixture 'history-disabled' $false
Assert-Issue13MainArrayProofHistory $historyDisabled $null $null
$checks.Add([ordered]@{ id = 'all-history-statuses-accept-unchanged-selection'; passed = $true })
Expect-ProofFailure 'history-cannot-disable-after-passed-attempt' {
  Assert-Issue13MainArrayProofHistory $history $null $null
}
Expect-ProofFailure 'history-cannot-enable-after-passed-attempt' {
  Assert-Issue13MainArrayProofHistory $historyDisabled $bound.path $bound.sha256
}
Expect-ProofFailure 'history-cannot-change-path' {
  Assert-Issue13MainArrayProofHistory $history (Join-Path $output 'other-binding.json') $bound.sha256
}
Expect-ProofFailure 'history-cannot-change-hash' {
  Assert-Issue13MainArrayProofHistory $history $bound.path ('0' * 64)
}
foreach ($status in @('passed', 'failed', 'running')) {
  foreach ($location in @('attempt', 'job', 'outcome')) {
    $id = "history-$status-$location-selection-changed"
    $testState = New-ProofHistoryFixture $id $true
    $attempt = @($testState.comparisons | Where-Object status -CEQ $status)[0].attempts[0]
    if ($location -ceq 'attempt') {
      $attempt.array_proof_binding_path = $null
      $attempt.array_proof_binding_sha256 = $null
    } else {
      $property = if ($location -ceq 'job') { 'job_path' } else { 'result_path' }
      $shaProperty = if ($location -ceq 'job') { 'job_sha256' } else { 'result_sha256' }
      $document = Read-Issue13MainJson $attempt.$property
      $document.array_proof_binding_path = $null
      $document.array_proof_binding_sha256 = $null
      $attempt.$shaProperty = Write-Issue13MainJson $document $attempt.$property
    }
    Expect-ProofFailure $id {
      Assert-Issue13MainArrayProofHistory $testState $bound.path $bound.sha256
    }
  }
}
foreach ($property in @('job_sha256', 'result_sha256')) {
  $testState = New-ProofHistoryFixture ('history-' + $property) $true
  $testState.comparisons[0].attempts[0].$property = '0' * 64
  Expect-ProofFailure ('history-' + $property) {
    Assert-Issue13MainArrayProofHistory $testState $bound.path $bound.sha256
  } 'Historical comparison'
}

foreach ($case in @('wrong-config', 'wrong-config-path', 'wrong-science-binding',
    'wrong-comparison-binding', 'missing-tool-role', 'duplicate-tool-role',
    'wrong-toolfile', 'wrong-tool-size', 'wrong-cache-context', 'wrong-cache-source',
    'wrong-cache-approved-origin', 'duplicate-cache-origin')) {
  $directory = Join-Path $output $case
  $null = New-Item -ItemType Directory -Path $directory
  $document = Read-Issue13MainJson $bound.path
  switch ($case) {
    'wrong-config' { $document.config_sha256 = '0' * 64 }
    'wrong-config-path' { $document.config_path = Join-Path $directory 'other-config.json' }
    'wrong-science-binding' { $document.science_binding_sha256 = '0' * 64 }
    'wrong-comparison-binding' { $document.comparison_binding_sha256 = '0' * 64 }
    'missing-tool-role' { $document.records = @($document.records | Where-Object role -CNE 'library') }
    'duplicate-tool-role' { $document.records[1].role = $document.records[0].role }
    'wrong-toolfile' {
      $record = @($document.records | Where-Object role -CEQ 'library')[0]
      $replacement = Join-Path $directory 'different-tool.json'
      $null = Write-Issue13MainJson ([ordered]@{ deliberately_not_the_library = $true }) $replacement
      $record.path = $replacement
    }
    'wrong-tool-size' { $document.records[0].size_bytes = 1L }
    default {
      $record = @($document.records | Where-Object role -CEQ 'cache')[0]
      $cache = Read-Issue13MainJson $record.path
      switch ($case) {
        'wrong-cache-context' { $cache.context.config_sha256 = '0' * 64 }
        'wrong-cache-source' { $cache.origins[0].candidate_result.sha256 = '0' * 64 }
        'wrong-cache-approved-origin' { $cache.origins[0].comparison.sha256 = '0' * 64 }
        'duplicate-cache-origin' { $cache.origins[1] = $cache.origins[0] }
      }
      $replacement = Join-Path $directory 'different-cache.json'
      $record.sha256 = Write-Issue13MainJson $cache $replacement
      $record.path = $replacement
      $record.size_bytes = [long](Get-Item -LiteralPath $replacement).Length
    }
  }
  $path = Join-Path $directory 'binding.json'
  $sha = Write-Issue13MainJson $document $path
  Expect-ProofFailure $case {
    Assert-Issue13MainArrayProofBinding $path $sha $ConfigPath $ComparisonBindingPath
  }
}

$uncreated = Join-Path $output 'rejected-before-binding-creation'
Expect-ProofFailure 'wrong-cache-rejected-before-any-binding-creation' {
  New-Issue13MainArrayProofBinding $uncreated `
    (Join-Path $output 'wrong-cache-context/different-cache.json') $ConfigPath $ComparisonBindingPath
}
if (Test-Path -LiteralPath $uncreated) { throw 'Rejected cache still created a binding directory.' }
$checks.Add([ordered]@{ id = 'wrong-cache-left-no-binding-directory'; passed = $true })

foreach ($name in @('issue13-main-array-proof-binding.ps1',
    'issue13-main-array-proof-binding-selftest.ps1',
    'issue13-main-compare.ps1', 'issue13-main-compare-worker.ps1')) {
  $tokens = $null; $parseErrors = $null
  $null = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $PSScriptRoot $name), [ref]$tokens, [ref]$parseErrors)
  if ($parseErrors.Count) { throw "PowerShell parser rejected $name" }
  $checks.Add([ordered]@{ id = ('parser-' + $name); passed = $true })
}

$null = Assert-Issue13MainArrayProofBinding $bound.path $bound.sha256 `
  $ConfigPath $ComparisonBindingPath
foreach ($record in $protected) {
  if ((Get-Issue13MainSha256 $record.path) -cne $record.sha256) {
    throw 'An original scientific/cache/tooling input changed during the selftest.'
  }
}
$checks.Add([ordered]@{ id = 'valid-binding-and-all-original-inputs-remain-unchanged'; passed = $true })
$report = [ordered]@{
  schema = 'wlv-issue13-main-array-proof-binding-selftest/1'
  status = 'passed'; completed_at_utc = [DateTime]::UtcNow.ToString('o')
  r_processes_started = 0; scientific_runs_executed = 0
  config_path = [IO.Path]::GetFullPath($ConfigPath)
  comparison_binding_path = [IO.Path]::GetFullPath($ComparisonBindingPath)
  cache_path = [IO.Path]::GetFullPath($CachePath)
  cache_sha256 = Get-Issue13MainSha256 $CachePath
  binding = $bound; checks = [object[]]$checks.ToArray()
}
$reportPath = Join-Path $output 'selftest.json'
$null = Write-Issue13MainJson $report $reportPath
Write-Output $reportPath
