#requires -Version 7.5
[CmdletBinding()]
param(
  [string]$CampaignId = 'issue28-recalculation',
  [ValidateSet('wiodr13', 'wiodr16')][string[]]$Methods = @('wiodr13', 'wiodr16')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$campaign = [IO.Path]::GetFullPath((Join-Path $repo "temp/$CampaignId"))
if ([IO.Path]::GetDirectoryName($campaign) -cne (Join-Path $repo 'temp')) {
  throw 'The campaign must be a direct child of repository temp.'
}
$record = Get-Content -LiteralPath (Join-Path $campaign '.campaign.json') -Raw | ConvertFrom-Json
if ($record.status -cne 'active') { throw 'The campaign must already be active.' }
$taskRoot = Join-Path $campaign 'worktrees/candidate'
if (-not (Test-Path -LiteralPath (Join-Path $taskRoot 'R/bootstrap.R'))) {
  throw 'Provision the immutable candidate snapshot and normalized sources first.'
}
$saved = @{}
foreach ($name in @('TEMP', 'TMP', 'TMPDIR', 'LC_ALL', 'LANG', 'WLV_ISSUE28_CHANNEL')) {
  $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
try {
  foreach ($name in @('TEMP', 'TMP', 'TMPDIR')) {
    [Environment]::SetEnvironmentVariable($name, (Join-Path $campaign 'scratch'), 'Process')
  }
  $env:LC_ALL = 'C'
  $env:LANG = 'C'
  Push-Location -LiteralPath $repo
  try {
    $scenarios = @(
      @('full1', 'calculate', '1', '1', 'all'),
      @('stage1-full1', 'recalculate', '1', '1', 'all'),
      @('stage4-full1', 'recalculate', '4', '1', 'all'),
      @('stage4-full2', 'recalculate', '4', '2', 'all'),
      @('stage5-full1', 'recalculate', '5', '1', 'all'),
      @('stage4-baskets1', 'recalculate', '4', '1', 'basket_price.r.pc,basket_value.r.pc'),
      @('stage4-baskets2', 'recalculate', '4', '2', 'basket_price.r.pc,basket_value.r.pc'),
      @('stage5-select1', 'recalculate', '5', '1', 'gross_output.s.du'),
      @('stage5-select2', 'recalculate', '5', '2', 'gross_output.s.du')
    )
    foreach ($method in $Methods) {
      $baseline = Join-Path $campaign "results/$method-full1.json"
      $env:WLV_ISSUE28_CHANNEL = if (Test-Path -LiteralPath $baseline) {
        (Get-Content -LiteralPath $baseline -Raw | ConvertFrom-Json).channel
      } else { "validation/issue28/$method" }
      foreach ($scenario in $scenarios) {
        $name = "$method-$($scenario[0])"
        $reportPath = Join-Path $campaign "results/$name.json"
        if (Test-Path -LiteralPath $reportPath) {
          $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
          if (-not $report.passed) { throw "Existing scenario failed: $name" }
          Write-Output "Reusing passed scenario $name"
          continue
        }
        $logPath = Join-Path $campaign "logs/$name-suite.log"
        if (Test-Path -LiteralPath $logPath) {
          throw "An unfinished attempt exists for $name; inspect its log before resuming."
        }
        $harnessPath = Join-Path $campaign "logs/$name-harness.R"
        if (Test-Path -LiteralPath $harnessPath) { throw "Existing frozen harness for $name" }
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'issue28-recalculation.R') -Destination $harnessPath
        $arguments = @($harnessPath,
          $taskRoot, $method, $scenario[1], $scenario[2], $scenario[3], $scenario[4], $reportPath)
        if ($scenario[1] -ceq 'recalculate') { $arguments += $baseline }
        & Rscript @arguments > $logPath 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Scenario failed: $name. See $logPath" }
        Get-Content -LiteralPath $logPath -Tail 1
      }
    }
  } finally { Pop-Location }
} finally {
  foreach ($name in $saved.Keys) {
    [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process')
  }
}
