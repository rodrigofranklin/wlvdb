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
  [Parameter(Mandatory = $true)][string]$ProofPath
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

$resolvedProof = Resolve-Issue13OracleEffectFile $ProofPath 'oracle-effect proof'
$proofJson = Get-Content -Raw -LiteralPath $resolvedProof
try {
  $schemaPassed = $proofJson | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop
} catch {
  throw "Oracle-effect proof fails JSON Schema validation: $($_.Exception.Message)"
}
Assert-Issue13OracleEffect ([bool]$schemaPassed) `
  'oracle-effect proof fails JSON Schema validation.'

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
  -RLibrary $RLibrary
$proof = Read-Issue13OracleEffectJson $resolvedProof 'oracle-effect proof'
$null = Test-Issue13OracleEffectProofObject $proof $evidence

[pscustomobject][ordered]@{
  schema = 'wlv-issue13-v5-oracle-effect-validation/2'
  status = 'passed'
  passed = $true
  proof_path = $resolvedProof
  proof_sha256 = Get-Issue13OracleEffectSha256 $resolvedProof
  strict_common_comparison_count = `
    @($evidence.comparison_workflow.comparisons).Count
  comparison_execution_count = @($evidence.comparison_workflow.commands).Count
  approved_run_inventory_count = @($evidence.approved_run_immutability).Count
  recovered_method_count = @($evidence.recovered_methods).Count
  source_controller_inventory_sha256 = [string]$evidence.terminal_runtime.
    comparison_harness.source_controller.inventory_sha256
  r_runtime_inventory_sha256 = [string]$evidence.terminal_runtime.r_library.
    inventory_sha256
  oracle_effect_closed = $true
  final_v5_gate_substituted = $false
} | ConvertTo-Json -Depth 5
