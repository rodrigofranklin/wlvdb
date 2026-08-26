[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RepositoryRoot,
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ExpectedCandidateCommit,
  [string]$SpecPath,
  [string]$SchemaPath,
  [Parameter(Mandatory = $true)][string]$StrictSmokeSummary,
  [Parameter(Mandatory = $true)][string]$OracleSmokeSummary,
  [Parameter(Mandatory = $true)][string]$OraclePatch,
  [Parameter(Mandatory = $true)][string]$ComparisonHarnessManifest,
  [Parameter(Mandatory = $true)][string]$Rscript,
  [Parameter(Mandatory = $true)][string]$RLibrary,
  [Parameter(Mandatory = $true)][string]$ComparisonRoot,
  [Parameter(Mandatory = $true)][string]$ReplayRoot,
  [Parameter(Mandatory = $true)][string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SpecPath)) {
  $SpecPath = Join-Path $PSScriptRoot 'issue13-v5-oracle-effect-spec.json'
}
if ([string]::IsNullOrWhiteSpace($SchemaPath)) {
  $SchemaPath = Join-Path $PSScriptRoot `
    'issue13-v5-oracle-effect-proof.schema.json'
}

. (Join-Path $PSScriptRoot 'issue13-v5-oracle-effect-lib.ps1')
$null = Test-Issue13OracleEffectNegativeSelfTests

$proofProtectedRoots = @(
  $RepositoryRoot,
  (Split-Path -Parent ([IO.Path]::GetFullPath($ComparisonHarnessManifest))),
  $RLibrary,
  $Rscript,
  (Split-Path -Parent ([IO.Path]::GetFullPath($StrictSmokeSummary))),
  (Split-Path -Parent ([IO.Path]::GetFullPath($OracleSmokeSummary))),
  $OraclePatch,
  $SpecPath,
  $SchemaPath,
  $ComparisonRoot,
  $ReplayRoot
)
$proofFull = Assert-Issue13OracleEffectProofPathIsolation `
  $OutputPath $proofProtectedRoots
Assert-Issue13OracleEffect (-not (Test-Path -LiteralPath $proofFull)) `
  "refusing to overwrite proof output: $proofFull"
Assert-Issue13OracleEffect (Test-Path -LiteralPath `
    (Split-Path -Parent $proofFull) -PathType Container) `
  "proof output parent does not exist: $(Split-Path -Parent $proofFull)"
Assert-Issue13OracleEffectNoReparseAncestors `
  (Split-Path -Parent $proofFull) 'proof output parent'
$primaryFull = Resolve-Issue13OracleEffectNewDirectoryPath $ComparisonRoot `
  'primary comparison root'
$replayFull = Resolve-Issue13OracleEffectNewDirectoryPath $ReplayRoot `
  'replay comparison root'
Assert-Issue13OracleEffect (-not (Test-Issue13OracleEffectPathEqual `
    $primaryFull $replayFull)) 'primary and replay roots must differ.'

$before = Get-Issue13OracleEffectInputContext `
  -RepositoryRoot $RepositoryRoot `
  -ExpectedCandidateCommit $ExpectedCandidateCommit `
  -SpecPath $SpecPath `
  -SchemaPath $SchemaPath `
  -StrictSmokeSummary $StrictSmokeSummary `
  -OracleSmokeSummary $OracleSmokeSummary `
  -OraclePatch $OraclePatch `
  -ComparisonHarnessManifest $ComparisonHarnessManifest `
  -Rscript $Rscript `
  -RLibrary $RLibrary
$null = Assert-Issue13OracleEffectComparisonIsolation $primaryFull $replayFull `
  $before

$executedCommands = Invoke-Issue13OracleEffectFreshComparisons `
  -Context $before `
  -ComparisonRoot $ComparisonRoot `
  -ReplayRoot $ReplayRoot

$after = Get-Issue13OracleEffectInputContext `
  -RepositoryRoot $RepositoryRoot `
  -ExpectedCandidateCommit $ExpectedCandidateCommit `
  -SpecPath $SpecPath `
  -SchemaPath $SchemaPath `
  -StrictSmokeSummary $StrictSmokeSummary `
  -OracleSmokeSummary $OracleSmokeSummary `
  -OraclePatch $OraclePatch `
  -ComparisonHarnessManifest $ComparisonHarnessManifest `
  -Rscript $Rscript `
  -RLibrary $RLibrary
$null = Assert-Issue13OracleEffectComparisonIsolation $primaryFull $replayFull `
  $after -RequireExisting

$beforeRuntime = [pscustomobject][ordered]@{
  harness = $before.harness
  rscript = $before.rscript
  r_library = $before.r_library
}
$afterRuntime = [pscustomobject][ordered]@{
  harness = $after.harness
  rscript = $after.rscript
  r_library = $after.r_library
}
Assert-Issue13OracleEffect (
  ($beforeRuntime | ConvertTo-Json -Depth 100 -Compress) -ceq `
    ($afterRuntime | ConvertTo-Json -Depth 100 -Compress)
) 'terminal harness/Rscript/RLibrary changed during primary/replay execution.'

$evidence = Get-Issue13OracleEffectEvidence `
  -RepositoryRoot $RepositoryRoot `
  -ExpectedCandidateCommit $ExpectedCandidateCommit `
  -SpecPath $SpecPath `
  -SchemaPath $SchemaPath `
  -StrictSmokeSummary $StrictSmokeSummary `
  -OracleSmokeSummary $OracleSmokeSummary `
  -OraclePatch $OraclePatch `
  -ComparisonRoot $ComparisonRoot `
  -ReplayRoot $ReplayRoot `
  -ComparisonHarnessManifest $ComparisonHarnessManifest `
  -Rscript $Rscript `
  -RLibrary $RLibrary `
  -PreparedContext $after `
  -RunInventoriesBefore $before.approved_runs `
  -RuntimeBefore $beforeRuntime
Assert-Issue13OracleEffect (
  ($executedCommands | ConvertTo-Json -Depth 20 -Compress) -ceq `
    ($evidence.comparison_workflow.commands | ConvertTo-Json -Depth 20 -Compress)
) 'recorded comparison commands differ from the commands actually executed.'

$proof = New-Issue13OracleEffectProofObject -Evidence $evidence
$proofJson = $proof | ConvertTo-Json -Depth 100
try {
  $schemaPassed = $proofJson | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop
} catch {
  throw "Generated oracle-effect proof fails JSON Schema validation: $($_.Exception.Message)"
}
Assert-Issue13OracleEffect (Test-Issue13OracleEffectExactBoolean $schemaPassed $true) `
  'generated oracle-effect proof fails JSON Schema validation.'
$written = Write-Issue13OracleEffectJsonOnce -Value $proof -Path $proofFull `
  -SchemaPath $SchemaPath -ProtectedRoots $proofProtectedRoots
$roundtrip = Read-Issue13OracleEffectJson $written 'written oracle-effect proof'
$writtenJson = Get-Content -Raw -LiteralPath $written
try {
  $writtenSchemaPassed = $writtenJson | Test-Json -SchemaFile $SchemaPath `
    -ErrorAction Stop
} catch {
  throw "Written oracle-effect proof fails JSON Schema validation: $($_.Exception.Message)"
}
Assert-Issue13OracleEffect (Test-Issue13OracleEffectExactBoolean $writtenSchemaPassed $true) `
  'written oracle-effect proof fails JSON Schema validation.'
$null = Test-Issue13OracleEffectProofObject $roundtrip $evidence

[pscustomobject][ordered]@{
  schema = 'wlv-issue13-v5-oracle-effect-generation/2'
  status = 'passed'
  passed = $true
  proof_path = $written
  proof_sha256 = Get-Issue13OracleEffectSha256 $written
  strict_common_comparison_count = `
    @($evidence.comparison_workflow.comparisons).Count
  comparison_execution_count = @($evidence.comparison_workflow.commands).Count
  approved_run_inventory_count = @($evidence.approved_run_immutability).Count
  recovered_method_count = @($evidence.recovered_methods).Count
  final_evidence_eligible = $false
} | ConvertTo-Json -Depth 5
