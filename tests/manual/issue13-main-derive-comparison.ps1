param(
  [Parameter(Mandatory = $true)][string]$ConfigPath,
  [Parameter(Mandatory = $true)][string]$OutputRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'issue13-main-lib.ps1')
. (Join-Path $PSScriptRoot 'issue13-main-comparison-binding.ps1')

$config = Read-Issue13MainJson (
  ConvertTo-Issue13MainFullPath $ConfigPath -RequireExistingFile)
$null = Assert-Issue13MainConfig $config
$output = ConvertTo-Issue13MainFullPath $OutputRoot -RequireExistingDirectory
$metadataPath = Join-Path $output 'metadata-derived.json'
$null = Assert-Issue13MainComparisonMetadata $metadataPath
$provenancePath = Join-Path $output 'metadata-derivation-provenance.json'
$differencePath = Join-Path $output 'metadata-diff-vs-v5.json'
$null = Assert-Issue13MainMetadataDerivation $metadataPath $provenancePath `
  $differencePath $config
$runtimeRoot = Join-Path $output 'runtime'
$bindingPath = Join-Path $output 'comparison-binding.json'
if ((Test-Path -LiteralPath $runtimeRoot) -or
    (Test-Path -LiteralPath $bindingPath)) {
  throw 'A comparison derivative already exists; it must not be overwritten.'
}
$manifest = Read-Issue13MainJson $config.harness_manifest
$sourceRoot = Split-Path -Parent $config.harness_root
$metadataRelative = 'issue13-evidence-harness/issue13-v5-metadata-equivalence.json'
$overrideRelative = 'issue13-evidence-harness/issue13-v5-compare-override.R'
$controllerRecords = New-Issue13MainControllerSnapshots $output @(
  [pscustomobject]@{ role = 'comparison-deriver'; path = $PSCommandPath },
  [pscustomobject]@{ role = 'comparison-binding-lib'; path =
    (Join-Path $PSScriptRoot 'issue13-main-comparison-binding.ps1') },
  [pscustomobject]@{ role = 'shared-lib'; path =
    (Join-Path $PSScriptRoot 'issue13-main-lib.ps1') },
  [pscustomobject]@{ role = 'metadata-generator'; path =
    (Join-Path $PSScriptRoot 'issue13-main-build-metadata.R') }
)
$null = New-Item -ItemType Directory -Path $runtimeRoot
$records = [Collections.Generic.List[object]]::new()
foreach ($record in @($manifest.derived_output_tooling.records)) {
  $relative = ([string]$record.relative_path).Replace('\', '/')
  $source = [IO.Path]::GetFullPath((Join-Path $sourceRoot $relative))
  $target = [IO.Path]::GetFullPath((Join-Path $runtimeRoot $relative))
  if (-not $target.StartsWith($runtimeRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase) -or
      -not $source.StartsWith($sourceRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase) -or
      (Get-Issue13MainSha256 $source) -cne [string]$record.sha256) {
    throw 'A source tooling file has changed or escaped its root.'
  }
  $null = New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force
  if ($relative -ceq $metadataRelative) {
    [IO.File]::Copy($metadataPath, $target, $false)
  } elseif ($relative -ceq $overrideRelative) {
    $expected = Get-Issue13MainReducedCompareOverride (
      [IO.File]::ReadAllText($source, [Text.UTF8Encoding]::new($false, $true)))
    [IO.File]::WriteAllText($target, $expected, [Text.UTF8Encoding]::new($false))
    if ([IO.File]::ReadAllText($target, [Text.UTF8Encoding]::new($false, $true)) -cne
        $expected -or $expected.Contains([char]0xfffd)) {
      throw 'The deterministic comparison transform failed its UTF-8 round trip.'
    }
  } else {
    [IO.File]::Copy($source, $target, $false)
  }
  $records.Add([ordered]@{
    relative_path = $relative
    size_bytes = [long](Get-Item -LiteralPath $target).Length
    sha256 = Get-Issue13MainSha256 $target
  })
}
$binding = [ordered]@{
  schema = 'wlv-issue13-main-comparison-binding/1'
  campaign_id = [string]$config.campaign_id
  classification = 'metadata-derivation-only-no-science-reexecution'
  created_at_utc = [DateTime]::UtcNow.ToString('o')
  source_manifest = [string]$config.harness_manifest
  source_manifest_sha256 = Get-Issue13MainSha256 $config.harness_manifest
  runtime_root = $runtimeRoot
  metadata_sha256 = Get-Issue13MainSha256 $metadataPath
  arm_bindings = [ordered]@{
    baseline = [ordered]@{
      path = $config.arms.baseline.binding_path
      sha256 = Get-Issue13MainSha256 $config.arms.baseline.binding_path
      commit = (Get-Issue13MainArmBinding $config 'baseline').commit
    }
    candidate = [ordered]@{
      path = $config.arms.candidate.binding_path
      sha256 = Get-Issue13MainSha256 $config.arms.candidate.binding_path
      commit = (Get-Issue13MainArmBinding $config 'candidate').commit
    }
  }
  changed_files = @($overrideRelative, $metadataRelative)
  records = [object[]]$records.ToArray()
  derivation_records = @(
    (New-Issue13MainFileRecord 'metadata' $metadataPath),
    (New-Issue13MainFileRecord 'provenance' $provenancePath),
    (New-Issue13MainFileRecord 'historical-profile-differences' $differencePath)
  )
  controller_records = [object[]]$controllerRecords
}
$bindingSha = Write-Issue13MainJson $binding $bindingPath
$null = Assert-Issue13MainComparisonBinding $bindingPath $bindingSha $config
Write-Output $bindingPath
Write-Output $bindingSha
