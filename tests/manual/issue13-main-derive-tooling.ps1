param(
  [Parameter(Mandatory = $true)][string]$SourceHarnessRoot,
  [Parameter(Mandatory = $true)][string]$SourceHarnessManifest,
  [Parameter(Mandatory = $true)][string]$SourcePowerShellRoot,
  [Parameter(Mandatory = $true)][string]$OutputRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function FullPath([string]$Path, [switch]$Directory, [switch]$File) {
  if (-not [IO.Path]::IsPathFullyQualified($Path)) {
    throw "Path must be absolute: $Path"
  }
  $full = [IO.Path]::GetFullPath($Path)
  if ($Directory -and -not (Test-Path -LiteralPath $full -PathType Container)) {
    throw "Directory is missing: $full"
  }
  if ($File -and -not (Test-Path -LiteralPath $full -PathType Leaf)) {
    throw "File is missing: $full"
  }
  $full
}

function Sha256([string]$Path) {
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function TextSha256([string]$Text) {
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
  $digest = [Security.Cryptography.SHA256]::HashData($bytes)
  [Convert]::ToHexString($digest).ToLowerInvariant()
}

function Assert-NoReparseTree([string]$Root) {
  $cursor = [IO.DirectoryInfo]::new($Root)
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "A tree ancestor is a reparse point: $($cursor.FullName)"
    }
    $cursor = $cursor.Parent
  }
  foreach ($item in Get-ChildItem -LiteralPath $Root -Recurse -Force) {
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "Tree contains a reparse point: $($item.FullName)"
    }
  }
}

function Get-TreeInventory([string]$Root) {
  $records = [Collections.Generic.List[object]]::new()
  $totalBytes = 0L
  $relativePaths = [string[]]@(Get-ChildItem -LiteralPath $Root -Recurse `
    -File -Force | ForEach-Object {
      [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/')
    })
  [Array]::Sort($relativePaths, [StringComparer]::Ordinal)
  foreach ($relative in $relativePaths) {
    $path = Join-Path $Root $relative
    $file = Get-Item -LiteralPath $path -Force
    $totalBytes += [long]$file.Length
    $records.Add([ordered]@{
      relative_path = $relative
      size_bytes = [long]$file.Length
      sha256 = Sha256 $path
    })
  }
  $canonical = [string]::Join("`n", @($records | ForEach-Object {
    "$($_.relative_path)|$($_.size_bytes)|$($_.sha256)"
  }))
  [ordered]@{
    file_count = [long]$records.Count
    total_bytes = $totalBytes
    inventory_sha256 = TextSha256 $canonical
    records = [object[]]$records.ToArray()
  }
}

function Get-OutputToolingInventory([string]$Root) {
  $harness = Join-Path $Root 'issue13-evidence-harness'
  $records = @(Get-ChildItem -LiteralPath $Root -File -Force |
      Where-Object Name -NotIn @(
        'v5-harness-manifest.json', 'derived-harness-manifest.json'))
  $records += @(Get-ChildItem -LiteralPath $harness -File -Force)
  $records = @($records | ForEach-Object {
    $relative = $_.FullName.Substring($Root.Length + 1).Replace('\', '/')
    [pscustomobject][ordered]@{
      relative_path = $relative
      size_bytes = [long]$_.Length
      sha256 = Sha256 $_.FullName
    }
  } | Sort-Object relative_path)
  $lines = @($records | ForEach-Object {
    [string]$_.relative_path + '|' + [string]$_.size_bytes + '|' +
      [string]$_.sha256
  })
  [ordered]@{
    file_count = [long]$records.Count
    total_bytes = [long](($records | Measure-Object size_bytes -Sum).Sum)
    inventory_sha256 = TextSha256 ([string]::Join("`n", $lines))
    records = [object[]]$records
  }
}

function Copy-Tree([string]$Source, [string]$Destination) {
  $null = New-Item -ItemType Directory -Path $Destination
  foreach ($directory in Get-ChildItem -LiteralPath $Source -Recurse `
      -Directory -Force) {
    $relative = [IO.Path]::GetRelativePath($Source, $directory.FullName)
    $null = New-Item -ItemType Directory -Path (Join-Path $Destination $relative)
  }
  foreach ($file in Get-ChildItem -LiteralPath $Source -Recurse -File -Force) {
    $relative = [IO.Path]::GetRelativePath($Source, $file.FullName)
    [IO.File]::Copy($file.FullName, (Join-Path $Destination $relative), $false)
  }
}

function Write-Json([object]$Value, [string]$Path) {
  $json = $Value | ConvertTo-Json -Depth 20
  [IO.File]::WriteAllText($Path, $json + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false))
}

$sourceHarness = FullPath $SourceHarnessRoot -Directory
$sourceManifest = FullPath $SourceHarnessManifest -File
$sourcePowerShell = FullPath $SourcePowerShellRoot -Directory
$output = FullPath $OutputRoot
if (Test-Path -LiteralPath $output) { throw "Output already exists: $output" }
if (-not [string]::Equals(
    (Split-Path -Parent $sourceManifest), (Split-Path -Parent $sourceHarness),
    [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Source harness and manifest do not share their expected parent.'
}
Assert-NoReparseTree $sourceHarness
Assert-NoReparseTree $sourcePowerShell

$sourceHarnessInventory = Get-TreeInventory $sourceHarness
if ([long]$sourceHarnessInventory.file_count -ne 42L) {
  throw 'The source V5 harness is not the audited 42-file harness directory.'
}
$sourceManifestDocument = Get-Content -LiteralPath $sourceManifest -Raw `
  -Encoding UTF8 | ConvertFrom-Json
$sourceToolingRoot = Split-Path -Parent $sourceHarness
$sourceOutputInventory = Get-OutputToolingInventory $sourceToolingRoot
if ([long]$sourceOutputInventory.file_count -ne 47L -or
    [long]$sourceOutputInventory.file_count -ne
      [long]$sourceManifestDocument.output_tooling.file_count -or
    [long]$sourceOutputInventory.total_bytes -ne
      [long]$sourceManifestDocument.output_tooling.total_bytes -or
    [string]$sourceOutputInventory.inventory_sha256 -cne
      [string]$sourceManifestDocument.output_tooling.inventory_sha256) {
  throw 'The source V5 47-file tooling inventory differs from its manifest.'
}
$sourceRuntimeInventoryBefore = Get-TreeInventory $sourcePowerShell
$staging = $output + '.staging-' + [Guid]::NewGuid().ToString('N')
$null = New-Item -ItemType Directory -Path $staging
try {
  $derivedHarness = Join-Path $staging 'issue13-evidence-harness'
  $privatePowerShell = Join-Path $staging 'powershell'
  Copy-Tree $sourceHarness $derivedHarness
  Copy-Tree $sourcePowerShell $privatePowerShell
  $supportNames = [string[]]@(
    'issue13-prep-paper-lib.R',
    'issue13-preparation-auth-lib.R',
    'issue13-preparation-compare.R',
    'issue13-preparation-rule-matrix.json',
    'issue13-runtime-loader-selftest.R'
  )
  foreach ($supportName in $supportNames) {
    $supportSource = FullPath (Join-Path $sourceToolingRoot $supportName) -File
    [IO.File]::Copy($supportSource, (Join-Path $staging $supportName), $false)
  }
  $preparationSource = Join-Path $sourceToolingRoot 'issue13-prep-paper-lib.R'

  $sourceRuntimeInventoryAfter = Get-TreeInventory $sourcePowerShell
  $privateRuntimeInventory = Get-TreeInventory $privatePowerShell
  foreach ($name in @('file_count', 'total_bytes', 'inventory_sha256')) {
    if ([string]$sourceRuntimeInventoryBefore.$name -cne
        [string]$sourceRuntimeInventoryAfter.$name -or
        [string]$sourceRuntimeInventoryBefore.$name -cne
        [string]$privateRuntimeInventory.$name) {
      throw 'The PowerShell runtime changed during its private copy.'
    }
  }

  $trustedRelativePaths = [string[]]@(
    'pwsh.exe',
    'System.Management.Automation.dll',
    'Microsoft.PowerShell.Commands.Management.dll',
    'Microsoft.PowerShell.Commands.Utility.dll',
    'Microsoft.Management.Infrastructure.CimCmdlets.dll',
    'microsoft.management.infrastructure.dll',
    'microsoft.management.infrastructure.native.dll',
    'microsoft.management.infrastructure.native.unmanaged.dll',
    'Modules\Microsoft.PowerShell.Management\Microsoft.PowerShell.Management.psd1',
    'Modules\Microsoft.PowerShell.Utility\Microsoft.PowerShell.Utility.psd1',
    'Modules\CimCmdlets\CimCmdlets.psd1'
  )
  $trustedRecords = [Collections.Generic.List[object]]::new()
  foreach ($relative in $trustedRelativePaths) {
    $path = FullPath (Join-Path $privatePowerShell $relative) -File
    $trustedRecords.Add([ordered]@{
      relative_path = $relative
      size_bytes = [long](Get-Item -LiteralPath $path).Length
      sha256 = (Sha256 $path).ToUpperInvariant()
    })
  }

  $assemblyMvid = [ordered]@{}
  foreach ($name in @(
      'System.Management.Automation.dll',
      'Microsoft.PowerShell.Commands.Management.dll',
      'Microsoft.PowerShell.Commands.Utility.dll',
      'Microsoft.Management.Infrastructure.CimCmdlets.dll')) {
    $assembly = [Reflection.Assembly]::LoadFrom((Join-Path $sourcePowerShell $name))
    $assemblyMvid[$name] = $assembly.ManifestModule.ModuleVersionId.ToString('D')
  }
  $oldMvid = [ordered]@{
    'System.Management.Automation.dll' = '7071448b-dbd2-48c8-9dff-f288a19a62d2'
    'Microsoft.PowerShell.Commands.Management.dll' =
      '4c155aeb-1e5e-4023-8c7f-214e199b9530'
    'Microsoft.PowerShell.Commands.Utility.dll' =
      '99be7828-14d8-415d-ae6e-3f0185e7ef9f'
    'Microsoft.Management.Infrastructure.CimCmdlets.dll' =
      '3af4a3ba-947a-4e39-9400-da8fae0c56de'
  }
  $oldRuntimeRoot =
    'C:\Users\rodri\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell'
  $finalPrivateRuntime = Join-Path $output 'powershell'
  $guardFiles = [string[]]@(Get-ChildItem -LiteralPath $sourceHarness `
    -Filter '*.ps1' -File | Where-Object {
      [IO.File]::ReadAllText($_.FullName).Contains($oldRuntimeRoot)
    } | ForEach-Object Name)
  [Array]::Sort($guardFiles, [StringComparer]::Ordinal)
  if ($guardFiles.Count -ne 7) {
    throw 'The expected seven PowerShell runtime guards were not found.'
  }
  $changes = [Collections.Generic.List[object]]::new()
  foreach ($name in $guardFiles) {
    $sourcePath = Join-Path $sourceHarness $name
    $derivedPath = Join-Path $derivedHarness $name
    $original = [IO.File]::ReadAllText($sourcePath)
    if ([regex]::Matches($original, [regex]::Escape($oldRuntimeRoot)).Count -ne 1) {
      throw "Runtime root occurrence is not singular: $name"
    }
    $transformed = $original.Replace($oldRuntimeRoot, $finalPrivateRuntime)
    foreach ($record in $trustedRecords) {
      $escaped = [regex]::Escape([string]$record.relative_path)
      $pattern = "(?s)(relative_path\s*=\s*'$escaped'\s*size_bytes\s*=\s*)\d+L(\s*sha256\s*=\s*')([A-F0-9]{64})(')"
      $matches = [regex]::Matches($transformed, $pattern)
      if ($matches.Count -ne 1) {
        throw "Trusted runtime record is not singular in ${name}: $($record.relative_path)"
      }
      $replacementSize = [string]$record.size_bytes
      $replacementHash = [string]$record.sha256
      $transformed = [regex]::Replace($transformed, $pattern,
        [Text.RegularExpressions.MatchEvaluator]{
          param($match)
          $match.Groups[1].Value + $replacementSize + 'L' +
            $match.Groups[2].Value + $replacementHash +
            $match.Groups[4].Value
        })
    }
    foreach ($assemblyName in $oldMvid.Keys) {
      $old = [string]$oldMvid[$assemblyName]
      $new = [string]$assemblyMvid[$assemblyName]
      if ([regex]::Matches($transformed, [regex]::Escape($old)).Count -ne 1) {
        throw "Assembly MVID occurrence is not singular: $name/$assemblyName"
      }
      $transformed = $transformed.Replace($old, $new)
    }
    [IO.File]::WriteAllText($derivedPath, $transformed,
      [Text.UTF8Encoding]::new($false))
    $tokens = $null
    $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile(
      $derivedPath, [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) { throw "Derived PowerShell does not parse: $name" }
    if ([IO.File]::ReadAllText($derivedPath) -cne $transformed) {
      throw "Derived PowerShell round-trip differs: $name"
    }
    $changes.Add([ordered]@{
      relative_path = $name
      classification = 'powershell-runtime-binding-only'
      source_sha256 = Sha256 $sourcePath
      derived_sha256 = Sha256 $derivedPath
      deterministic_transform_sha256 = TextSha256 $transformed
    })
  }

  $derivedHarnessInventory = Get-TreeInventory $derivedHarness
  $sourceByPath = @{}
  foreach ($record in $sourceHarnessInventory.records) {
    $sourceByPath[[string]$record.relative_path] = $record
  }
  foreach ($record in $derivedHarnessInventory.records) {
    $sourceRecord = $sourceByPath[[string]$record.relative_path]
    if ($null -eq $sourceRecord) { throw 'Derived harness added an unknown file.' }
    $isGuard = $guardFiles -ccontains [string]$record.relative_path
    if (-not $isGuard -and [string]$record.sha256 -cne
        [string]$sourceRecord.sha256) {
      throw "A non-guard harness file changed: $($record.relative_path)"
    }
    if ([string]$record.relative_path -cmatch '\.R$' -and
        [string]$record.sha256 -cne [string]$sourceRecord.sha256) {
      throw "Scientific R tooling changed: $($record.relative_path)"
    }
  }
  if ([long]$derivedHarnessInventory.file_count -ne 42L -or
      $derivedHarnessInventory.records.Count -ne
        $sourceHarnessInventory.records.Count) {
    throw 'Derived harness file coverage changed.'
  }
  $derivedOutputInventory = Get-OutputToolingInventory $staging
  if ([long]$derivedOutputInventory.file_count -ne 47L) {
    throw 'Derived output tooling is not exactly 47 files.'
  }
  $sourceOutputByPath = @{}
  foreach ($record in $sourceOutputInventory.records) {
    $sourceOutputByPath[[string]$record.relative_path] = $record
  }
  foreach ($record in $derivedOutputInventory.records) {
    if ([string]$record.relative_path -cmatch '\.R$' -and
        [string]$record.sha256 -cne
          [string]$sourceOutputByPath[[string]$record.relative_path].sha256) {
      throw "An R tooling file changed: $($record.relative_path)"
    }
  }

  $manifest = [ordered]@{
    schema = 'wlv-issue13-main-derived-harness-manifest/1'
    campaign = 'issue13-main-054'
    status = 'materialized'
    materialized_at_utc = [DateTime]::UtcNow.ToString('o')
    source_harness_root = $sourceHarness
    source_harness_manifest = $sourceManifest
    source_harness_manifest_sha256 = Sha256 $sourceManifest
    source_harness_inventory = $sourceHarnessInventory
    source_output_tooling = $sourceOutputInventory
    derived_harness_root = Join-Path $output 'issue13-evidence-harness'
    derived_harness_inventory = $derivedHarnessInventory
    derived_output_tooling = $derivedOutputInventory
    derived_powershell_root = $finalPrivateRuntime
    derived_powershell_executable = Join-Path $finalPrivateRuntime 'pwsh.exe'
    derived_powershell_inventory = $privateRuntimeInventory
    trusted_runtime_records = [object[]]$trustedRecords.ToArray()
    changed_files = [object[]]$changes.ToArray()
    unchanged_r_file_count = @($derivedOutputInventory.records |
      Where-Object relative_path -CMatch '\.R$').Count
    scientific_r_files_unchanged = $true
    exact_changed_file_count = [long]$changes.Count
    preparation_library = [ordered]@{
      source_path = $preparationSource
      source_sha256 = Sha256 $preparationSource
      derived_path = Join-Path $output 'issue13-prep-paper-lib.R'
      derived_sha256 = Sha256 (Join-Path $staging 'issue13-prep-paper-lib.R')
    }
  }
  Write-Json $manifest (Join-Path $staging 'derived-harness-manifest.json')
  Assert-NoReparseTree $staging
  [IO.Directory]::Move($staging, $output)
  Write-Output (Join-Path $output 'derived-harness-manifest.json')
} finally {
  if (Test-Path -LiteralPath $staging -PathType Container) {
    [IO.Directory]::Delete($staging, $true)
  }
}
