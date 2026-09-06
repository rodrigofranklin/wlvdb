# Shared output boundary for manual campaign tools. Read-only inputs may live elsewhere.
function Assert-WlvCampaignOutputPath([Parameter(Mandatory)][string]$Path) {
  $repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
  $common = @(& git -C $repository rev-parse --path-format=absolute --git-common-dir)
  if ($LASTEXITCODE -ne 0 -or $common.Count -ne 1) {
    throw 'Cannot locate the main repository for campaign storage.'
  }
  $main = Split-Path -Parent ([IO.Path]::GetFullPath([string]$common[0]))
  $temporary = Join-Path $main 'temp'
  $full = [IO.Path]::GetFullPath($Path)
  $prefix = $temporary + [IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Campaign outputs must be inside the main repository temp/<id>/ directory.'
  }
  $relative = [IO.Path]::GetRelativePath($temporary, $full)
  $id = ($relative -split '[/\\]')[0]
  if ($id -cnotmatch '^[a-z0-9][a-z0-9_-]{0,79}$' -or $id -ceq '054') {
    throw 'Invalid or preserved campaign output target.'
  }
  $cursor = $full
  while ($cursor) {
    if ((Test-Path -LiteralPath $cursor) -and
        ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      throw "Campaign output has a linked ancestor: $cursor"
    }
    $cursor = Split-Path -Parent $cursor
  }
  $manifest = Join-Path (Join-Path $temporary $id) '.campaign.json'
  if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
    throw 'Create a registered campaign first with scripts/manage-campaigns.ps1 -Action New.'
  }
  if ((Get-Item -LiteralPath $manifest -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Linked campaign manifest is not allowed.'
  }
  $record = Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($record.schema -cne 'wlv-campaign/1' -or $record.id -cne $id -or $record.status -cne 'active') {
    throw 'Campaign output requires an active campaign manifest.'
  }
  $full
}
