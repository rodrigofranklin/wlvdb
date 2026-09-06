#requires -Version 7.5
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateSet('New', 'Status', 'Complete', 'Fail', 'Clean')]
  [string]$Action,
  [ValidatePattern('^[a-z0-9][a-z0-9_-]{0,79}$')][string]$Id,
  [string]$Purpose = '',
  [switch]$Preserve,
  [switch]$Apply
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$tempRoot = Join-Path $repo 'temp'
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function Assert-RealAncestors([string]$Path) {
  $cursor = [IO.Path]::GetFullPath($Path)
  while ($cursor) {
    if (Test-Path -LiteralPath $cursor) {
      $item = Get-Item -LiteralPath $cursor -Force
      if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Linked path is not allowed: $cursor"
      }
    }
    $cursor = Split-Path -Parent $cursor
  }
}

function Assert-CampaignPath([string]$Path) {
  $full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
  if (-not [string]::Equals((Split-Path -Parent $full), $tempRoot,
      [StringComparison]::OrdinalIgnoreCase)) {
    throw 'A campaign must be a direct child of this repository temp directory.'
  }
  Assert-RealAncestors $full
  $full
}

function Read-Campaign([string]$Path) {
  $null = Assert-CampaignPath $Path
  $manifest = Join-Path $Path '.campaign.json'
  if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
    throw "Unknown directory, missing campaign manifest: $Path"
  }
  Assert-RealAncestors $manifest
  $record = [IO.File]::ReadAllText($manifest, $utf8) | ConvertFrom-Json -AsHashtable -DateKind String
  if ($record.schema -cne 'wlv-campaign/1' -or
      $record.id -cne (Split-Path -Leaf $Path) -or
      $record.status -cnotin @('active', 'completed', 'failed', 'archived') -or
      $record.preserve -isnot [bool]) {
    throw "Invalid campaign manifest: $manifest"
  }
  $record
}

function Write-Campaign([string]$Path, [System.Collections.IDictionary]$Record) {
  $manifest = Join-Path $Path '.campaign.json'
  Assert-RealAncestors $manifest
  $text = $Record | ConvertTo-Json -Depth 10
  [IO.File]::WriteAllText($manifest, $text, $utf8)
  if ([IO.File]::ReadAllText($manifest, $utf8) -cne $text) {
    throw 'Campaign manifest failed its UTF-8 round trip.'
  }
}

function Get-Worktrees {
  $lines = @(& git -C $repo worktree list --porcelain)
  if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect registered Git worktrees.' }
  @($lines | Where-Object { $_.StartsWith('worktree ') } |
    ForEach-Object { [IO.Path]::GetFullPath($_.Substring(9)).TrimEnd('\', '/') })
}

function Test-Within([string]$Path, [string]$Parent) {
  [string]::Equals($Path, $Parent, [StringComparison]::OrdinalIgnoreCase) -or
    $Path.StartsWith($Parent + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase)
}

function Assert-RemovableCampaign([string]$Path, [string[]]$Worktrees) {
  $record = Read-Campaign $Path
  if ($record.id -ceq '054' -or $record.preserve -or
      $record.status -cnotin @('completed', 'failed')) {
    throw "Campaign is active or preserved: $Path"
  }
  $items = @(Get-ChildItem -LiteralPath $Path -Recurse -Force)
  if (@($items | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) {
    throw "Campaign contains a link or junction: $Path"
  }
  if (@($items | Where-Object { $_.Name -match '(^\.running\.lock$|^\.lock|^\.issue13.*lock$)' }).Count) {
    throw "Campaign contains a process/result lock: $Path"
  }
  # A running process explicitly pointing at this campaign prevents removal.
  # Failure to query processes is an error, not permission to delete.
  $forward = $Path.Replace('\', '/')
  $processes = @(Get-CimInstance Win32_Process | Where-Object {
    $_.ProcessId -ne $PID -and $_.CommandLine -and
      ($_.CommandLine.Contains($Path, [StringComparison]::OrdinalIgnoreCase) -or
       $_.CommandLine.Contains($forward, [StringComparison]::OrdinalIgnoreCase))
  })
  if ($processes.Count) { throw "A running process references this campaign: $Path" }
  $children = @($Worktrees | Where-Object { Test-Within $_ $Path })
  # Unknown nested repositories are preserved, never erased as loose files.
  foreach ($gitItem in @($items | Where-Object Name -EQ '.git')) {
    if ($children -notcontains (Split-Path -Parent $gitItem.FullName)) {
      throw "Unregistered repository in campaign: $($gitItem.FullName)"
    }
  }
  foreach ($worktree in $children) {
    $status = @(& git -c core.longpaths=true -C $worktree status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0 -or $status.Count) {
      throw "Preserve local code changes before cleaning worktree: $worktree"
    }
  }
  [pscustomobject]@{
    id = $record.id
    path = $Path
    bytes = [long](($items | Where-Object { -not $_.PSIsContainer } |
      Measure-Object -Property Length -Sum).Sum)
    worktrees = $children
  }
}

Assert-RealAncestors $tempRoot
if ($Action -cne 'Status' -and $Action -cne 'Clean' -and -not $Id) {
  throw '-Id is required for this action.'
}
if ($Apply -and $Action -cne 'Clean') { throw '-Apply is only valid with Clean.' }
if ($Preserve -and $Action -cnotin @('New', 'Complete', 'Fail')) {
  throw '-Preserve is only valid with New, Complete or Fail.'
}

if ($Action -ceq 'New') {
  if ($Id -ceq '054') { throw 'Campaign 054 is reserved for the preserved archive.' }
  $path = Assert-CampaignPath (Join-Path $tempRoot $Id)
  if (Test-Path -LiteralPath $path) { throw "Campaign already exists: $path" }
  $null = New-Item -ItemType Directory -Path $path
  foreach ($child in @('worktrees', 'scratch', 'logs', 'results')) {
    $null = New-Item -ItemType Directory -Path (Join-Path $path $child)
  }
  $commit = & git -C $repo rev-parse HEAD
  if ($LASTEXITCODE -ne 0) { throw 'Cannot record repository commit.' }
  Write-Campaign $path ([ordered]@{
    schema = 'wlv-campaign/1'; id = $Id; purpose = $Purpose
    commit = [string]$commit; status = 'active'; preserve = [bool]$Preserve
    created_at_utc = [DateTime]::UtcNow.ToString('o')
  })
  [pscustomobject]@{ id = $Id; root = $path; temporary_directory = Join-Path $path 'scratch' }
  return
}

if ($Action -cin @('Complete', 'Fail')) {
  $path = Assert-CampaignPath (Join-Path $tempRoot $Id)
  $record = Read-Campaign $path
  if ($record.id -ceq '054' -or $record.status -ceq 'archived') {
    throw 'Archived campaigns cannot be changed.'
  }
  $record.status = if ($Action -ceq 'Complete') { 'completed' } else { 'failed' }
  $record.preserve = $record.preserve -or [bool]$Preserve
  $record.closed_at_utc = [DateTime]::UtcNow.ToString('o')
  Write-Campaign $path $record
  [pscustomobject]$record
  return
}

$paths = if ($Id) {
  @(Assert-CampaignPath (Join-Path $tempRoot $Id))
} elseif (Test-Path -LiteralPath $tempRoot) {
  @(Get-ChildItem -LiteralPath $tempRoot -Directory -Force | ForEach-Object FullName)
} else { @() }

if ($Action -ceq 'Status') {
  foreach ($path in $paths) {
    $record = Read-Campaign $path
    [pscustomobject]@{ id = $record.id; status = $record.status; preserve = $record.preserve; path = $path }
  }
  return
}

$worktrees = @(Get-Worktrees)
$plans = @(
  foreach ($path in $paths) {
    $record = Read-Campaign $path
    if ($record.id -ceq '054' -or $record.preserve -or $record.status -ceq 'archived') {
      if ($Id) { throw "Campaign is preserved: $path" }
      continue
    }
    if ($record.status -ceq 'active') {
      if ($Id) { throw "Campaign is active: $path" }
      continue
    }
    Assert-RemovableCampaign $path $worktrees
  }
)
# Resolve every target and perform every preflight before the first deletion.
foreach ($plan in $plans) {
  [pscustomobject]@{ id = $plan.id; path = $plan.path; gib = [math]::Round($plan.bytes / 1GB, 3); apply = [bool]$Apply }
}
if (-not $Apply) { return }
foreach ($plan in $plans) {
  $null = Assert-RemovableCampaign $plan.path @(Get-Worktrees)
  foreach ($worktree in $plan.worktrees) {
    # --force permits generated, ignored data; visible code changes were refused.
    & git -c core.longpaths=true -C $repo worktree remove --force $worktree
    if ($LASTEXITCODE -ne 0) { throw "Git worktree removal failed: $worktree" }
  }
  $null = Assert-CampaignPath $plan.path
  if (Test-Path -LiteralPath $plan.path) {
    Remove-Item -LiteralPath $plan.path -Recurse -Force
  }
  if (Test-Path -LiteralPath $plan.path) { throw "Campaign removal was incomplete: $($plan.path)" }
}
