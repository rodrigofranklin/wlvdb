#requires -Version 7.0
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$manager = Join-Path $repo 'scripts/manage-campaigns.ps1'
. (Join-Path $repo 'scripts/campaign-paths.ps1')
$id = 'storage-selftest-' + [Guid]::NewGuid().ToString('N')
$campaign = & $manager -Action New -Id $id -Purpose 'Campaign cleanup boundary selftest'
$root = $campaign.root
$outside = Join-Path $repo 'README.md'
$outsideHash = (Get-FileHash -LiteralPath $outside).Hash
$worktree = Join-Path $root 'worktrees/fixture'
$checks = [Collections.Generic.List[string]]::new()
function Expect-Rejection([scriptblock]$Operation, [string]$Name) {
  $rejected = $false
  try { & $Operation > $null } catch { $rejected = $true }
  if (-not $rejected) { throw "Expected rejection: $Name" }
  $checks.Add($Name)
}
try {
  Expect-Rejection { & $manager -Action Clean -Id $id -Apply } 'active campaign protected'
  Expect-Rejection { & $manager -Action Clean -Id '054' -Apply } '054 protected'
  Expect-Rejection { & $manager -Action New -Id '../escape' } 'traversal protected'
  Expect-Rejection { Assert-WlvCampaignOutputPath (Join-Path $repo 'run_logs/forbidden.json') } 'external output rejected'
  Expect-Rejection { Assert-WlvCampaignOutputPath (Join-Path $repo 'temp/054/new.json') } 'archive write rejected'
  $null = Assert-WlvCampaignOutputPath (Join-Path $root 'logs/allowed.json')
  $checks.Add('active output accepted')
  $sentinel = Join-Path $root 'results/sentinel.txt'
  [IO.File]::WriteAllText($sentinel, 'preserve until apply', [Text.UTF8Encoding]::new($false))
  $null = & $manager -Action Complete -Id $id
  Expect-Rejection { Assert-WlvCampaignOutputPath (Join-Path $root 'logs/forbidden.json') } 'closed output rejected'
  $null = & $manager -Action Clean -Id $id
  if (-not (Test-Path -LiteralPath $sentinel)) { throw 'Dry run deleted a result' }
  $checks.Add('dry run preserved files')
  # Native Git worktree with ignored results is removed only after dirty code is resolved.
  & git -c core.longpaths=true -C $repo worktree add --detach $worktree HEAD > $null 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'Cannot create fixture worktree' }
  $readme = Join-Path $worktree 'README.md'
  $original = [IO.File]::ReadAllBytes($readme)
  [IO.File]::AppendAllText($readme, "`nselftest change`n", [Text.UTF8Encoding]::new($false))
  Expect-Rejection { & $manager -Action Clean -Id $id -Apply } 'dirty worktree protected'
  [IO.File]::WriteAllBytes($readme, $original)
  $null = New-Item -ItemType Directory -Path (Join-Path $worktree 'results') -Force
  [IO.File]::WriteAllText((Join-Path $worktree 'results/generated.txt'), 'ignored result')
  $null = & $manager -Action Clean -Id $id -Apply
  if (Test-Path -LiteralPath $root) { throw 'Closed campaign was not removed' }
  if ((Get-FileHash -LiteralPath $outside).Hash -cne $outsideHash) { throw 'Outside file was altered' }
  $checks.Add('clean worktree and ignored results removed')
  $checks.Add('outside source file preserved')
  [pscustomobject]@{ passed = $true; count = $checks.Count; checks = @($checks.ToArray()) } | ConvertTo-Json
} finally {
  # Leave a failed fixture registered for inspection; no unchecked force cleanup.
  if (Test-Path -LiteralPath $root) {
    Write-Warning "Selftest fixture retained for inspection: $root"
  }
}
