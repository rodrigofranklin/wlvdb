param(
  [Parameter(Mandatory)][string]$ScienceConfigPath,
  [Parameter(Mandatory)][string]$OutputRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'issue13-main-lib.ps1')

function Assert-PerformanceProvisioningDisjoint([string]$Destination, [string[]]$ProtectedPaths) {
  $target = [IO.Path]::GetFullPath($Destination).TrimEnd('\', '/')
  foreach ($path in $ProtectedPaths) {
    $protected = [IO.Path]::GetFullPath($path).TrimEnd('\', '/')
    if ([string]::Equals($target, $protected, [StringComparison]::OrdinalIgnoreCase) -or
        $target.StartsWith($protected + [IO.Path]::DirectorySeparatorChar,
          [StringComparison]::OrdinalIgnoreCase) -or
        $protected.StartsWith($target + [IO.Path]::DirectorySeparatorChar,
          [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Performance destination overlaps a protected scientific or checkout path.'
    }
  }
  # Reject aliases before copying: lexical disjointness cannot prove safety
  # through a junction/symlink in an existing destination ancestor.
  $ancestor = $target
  while (-not [string]::IsNullOrWhiteSpace($ancestor)) {
    if ((Test-Path -LiteralPath $ancestor) -and
        ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      throw 'Performance destination has a linked ancestor; physical isolation is not established.'
    }
    $ancestor = Split-Path -Parent $ancestor
  }
}

$scienceConfig = ConvertTo-Issue13MainFullPath $ScienceConfigPath -RequireExistingFile
$config = Read-Issue13MainJson $scienceConfig
$null = Assert-Issue13MainConfig $config
$root = ConvertTo-Issue13MainFullPath $OutputRoot
if ((Split-Path -Leaf $root) -cnotmatch '^wlvdb-issue13-performance-[a-z0-9-]+$' -or
    (Test-Path -LiteralPath $root)) {
  throw 'Performance output must be a new, specifically named directory.'
}
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$scienceBefore = Get-Issue13MainSha256 $scienceConfig
$armBindings = @{}
$protectedPaths = @($repo, [string]$config.control_root, [string]$config.evidence_root)
foreach ($arm in @('baseline', 'candidate')) {
  $armBindings[$arm] = Get-Issue13MainArmBinding $config $arm
  foreach ($method in @('wiodr13', 'wiodr16')) {
    $protectedPaths += [string]$armBindings[$arm].roots.$method
  }
}
Assert-PerformanceProvisioningDisjoint $root $protectedPaths
$sourceRecords = [Collections.Generic.List[object]]::new()
$copyBytes = 0L
foreach ($arm in @('baseline', 'candidate')) {
  $binding = $armBindings[$arm]
  foreach ($method in @('wiodr13', 'wiodr16')) {
    $source = Join-Path $binding.roots.$method 'source_data'
    $files = @(Get-ChildItem -LiteralPath $source -Recurse -File -Force)
    if (@(Get-ChildItem -LiteralPath $source -Recurse -Force |
        Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) {
      throw 'Linked source data requires explicit handling, not a recursive copy.'
    }
    $inventory = @($files | Sort-Object FullName | ForEach-Object {
      $relative = [IO.Path]::GetRelativePath($source, $_.FullName).Replace('\', '/')
      [ordered]@{ relative_path = $relative; size_bytes = [long]$_.Length;
        sha256 = Get-Issue13MainSha256 $_.FullName }
    })
    $bytes = 0L
    foreach ($file in $inventory) { $bytes += [long]$file.size_bytes }
    $copyBytes += $bytes
    $sourceRecords.Add([ordered]@{
      arm = $arm; method = $method; source_root = $source
      commit = $binding.commit; seed_commit = $binding.seed_commit
      size_bytes = $bytes; files = $inventory
    })
  }
}
$drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($root))
if ($drive.AvailableFreeSpace - $copyBytes -lt 10737418240L) {
  throw 'Insufficient free storage for the source copies and 10 GiB floor.'
}
$null = New-Item -ItemType Directory -Path $root
$records = [Collections.Generic.List[object]]::new()
foreach ($record in $sourceRecords) {
  $destination = Join-Path $root ('worktrees/' + $record.arm + '-' + $record.method)
  & $config.git -C $repo worktree add --detach $destination $record.commit
  if ($LASTEXITCODE -ne 0) { throw 'Could not create the exact detached performance worktree.' }
  $targetData = Join-Path $destination 'source_data'
  $copyLog = Join-Path $root ($record.arm + '-' + $record.method + '-copy.log')
  & robocopy $record.source_root $targetData /E /COPY:DAT /DCOPY:DAT /R:0 /W:0 /MT:4 `
    /NFL /NDL /NJH /NJS "/LOG:$copyLog"
  if ($LASTEXITCODE -ge 8) { throw 'A performance source copy failed; retain the partial root.' }
  $copied = @(Get-ChildItem -LiteralPath $targetData -Recurse -File -Force)
  if ($copied.Count -ne @($record.files).Count) { throw 'Copied source inventory count differs.' }
  foreach ($file in @($record.files)) {
    $sourceFile = Join-Path $record.source_root $file.relative_path
    $targetFile = Join-Path $targetData $file.relative_path
    if ((Get-Issue13MainSha256 $sourceFile) -cne $file.sha256 -or
        (Get-Issue13MainSha256 $targetFile) -cne $file.sha256 -or
        [long](Get-Item -LiteralPath $targetFile).Length -ne [long]$file.size_bytes) {
      throw 'Source data changed during copying or failed exact verification.'
    }
  }
  $record['root'] = $destination
  $record['verified'] = $true
  $records.Add($record)
}
$executionConfig = Read-Issue13MainJson $scienceConfig
$executionConfig.campaign_id = 'issue13-performance-054-c1'
$executionConfig.control_root = Join-Path $root 'control'
$executionConfig.evidence_root = Join-Path $root 'evidence'
foreach ($arm in @('baseline', 'candidate')) {
  $armRecords = @($records | Where-Object { $_.arm -ceq $arm })
  $armBinding = [ordered]@{
    schema = 'wlv-issue13-main-arm-binding/1'; arm = $arm
    commit = $armRecords[0].commit; seed_commit = $armRecords[0].seed_commit
    roots = [ordered]@{
      wiodr13 = @($armRecords | Where-Object { $_.method -ceq 'wiodr13' })[0].root
      wiodr16 = @($armRecords | Where-Object { $_.method -ceq 'wiodr16' })[0].root
    }
  }
  $armPath = Join-Path $root ($arm + '-binding.json')
  $null = Write-Issue13MainJson $armBinding $armPath
  $executionConfig.arms.$arm.binding_path = $armPath
}
$configPath = Join-Path $root 'campaign-performance-c1.json'
$configSha = Write-Issue13MainJson $executionConfig $configPath
if ((Get-Issue13MainSha256 $scienceConfig) -cne $scienceBefore) {
  throw 'The original scientific configuration changed during provisioning.'
}
$manifest = [ordered]@{
  schema = 'wlv-issue13-main-performance-provisioning/1'
  created_at_utc = [DateTime]::UtcNow.ToString('o')
  science_config_path = $scienceConfig; science_config_sha256 = $scienceBefore
  execution_config_path = $configPath; execution_config_sha256 = $configSha
  source_bytes_copied = $copyBytes; roots = [object[]]$records.ToArray()
  scientific_runs_executed = $false; seeds_imported = $false
}
$null = Write-Issue13MainJson $manifest (Join-Path $root 'provisioning.json')
& $config.sealed_pwsh -NoProfile -File (Join-Path $PSScriptRoot 'issue13-main-gate.ps1') `
  -Action Initialize -ConfigPath $configPath
if ($LASTEXITCODE -ne 0) { throw 'Performance execution initialization failed.' }
Write-Output $configPath
