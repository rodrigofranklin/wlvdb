#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9_-]{0,79}$')][string]$Id,
  [Parameter(Mandatory)][string]$Executable,
  [string[]]$ArgumentList = @(),
  [string]$Purpose = '',
  [switch]$Preserve
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$manager = Join-Path $PSScriptRoot 'manage-campaigns.ps1'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$command = Get-Command $Executable -CommandType Application -ErrorAction Stop | Select-Object -First 1
$campaign = & $manager -Action New -Id $Id -Purpose $Purpose -Preserve:$Preserve
$savedEnvironment = @{}
$names = @('TEMP', 'TMP', 'TMPDIR', 'WLV_CAMPAIGN_ROOT', 'PYTHONUTF8', 'PYTHONIOENCODING')
foreach ($name in $names) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$savedConsoleEncoding = [Console]::OutputEncoding
$exitCode = 1
try {
  foreach ($name in @('TEMP', 'TMP', 'TMPDIR')) {
    [Environment]::SetEnvironmentVariable($name, $campaign.temporary_directory, 'Process')
  }
  $env:WLV_CAMPAIGN_ROOT = $campaign.root
  $env:PYTHONUTF8 = '1'
  $env:PYTHONIOENCODING = 'utf-8'
  [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
  Push-Location -LiteralPath $repo
  try {
    $log = Join-Path $campaign.root 'logs/console.log'
    & $command.Source @ArgumentList 2>&1 | Tee-Object -FilePath $log
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) { throw "Experiment exited with code $exitCode. See $log" }
  } finally { Pop-Location }
  $null = & $manager -Action Complete -Id $Id
} catch {
  $null = & $manager -Action Fail -Id $Id
  throw
} finally {
  foreach ($name in $names) {
    [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
  }
  [Console]::OutputEncoding = $savedConsoleEncoding
}
Write-Output "Experiment completed: $($campaign.root). Review retained outputs, then run manage-campaigns.ps1 -Action Clean."
