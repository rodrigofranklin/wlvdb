Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Issue13V5CoordinatorRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path

$script:Issue13V5BaselineCommit =
  'cc2c86189a06676bcb9f0e05e08033d710a92509'
$script:Issue13V5BaselineProfile = 'compatibility-oracle-cc2'
$script:Issue13V5BaselineRuntimeCommit =
  'e2f4d6dae9a6d35c966b305fabac52e489faa3e7'
$script:Issue13V5BaselineRuntimeTree =
  '7da19c4f2913e857040ba228280f404b0e54eaab'
$script:Issue13V5BaselineOverlaySha256 =
  '9f9b878f8e557973127e6260a0f224c868a0c4e8dc2db52dd6aa3f7131f28cd9'
$script:Issue13V5BaselineOverlayPatchId =
  '253ca5f1397132f94e3432264084a37395c60ec3'
$script:Issue13V5HarnessFileCount = 39L
$script:Issue13V5HarnessTotalBytes = 594386L
$script:Issue13V5HarnessInventorySha256 =
  '9f50c978ffc5f1f2d69d70ca8e5a7205eca39ec8441843cd5fa43b959eaf03c1'
$script:Issue13V5SourceFileCount = 84L
$script:Issue13V5SourceDirectoryCount = 5L
$script:Issue13V5SourceTotalBytes = 2946498269L
$script:Issue13V5SourceInventorySha256 =
  'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26'
$script:Issue13V5SourceDirectorySha256 =
  '8b3a622a748f2489fe8cfd2a8273ec98ad4c372b2378d587a5ee2e3c5c916640'
$script:Issue13V5CandidateSourceFileCount = 76L
$script:Issue13V5CandidateSourceDirectoryCount = 6L
$script:Issue13V5CandidateSourceTotalBytes = 2035522216L
$script:Issue13V5CandidateSourceInventorySha256 =
  '22e90e9485d7cee19d1de786c3464106d9a857ad3d85d0c9f2b3d912a0f38026'
$script:Issue13V5CandidateSourceDirectorySha256 =
  'c75aa417f14cded3c3bb6028effc8acadd64a32e86fddc0f1278079acdb6f114'
$script:Issue13V5AllowedRCommandSha256 =
  'cb09e749c6c1d9e1d5b93ea7c1cf4333d9f57f816fcc25967b04adb4e2595fc1'
$script:Issue13V5ControllerFiles = @(
  'README.md',
  'issue13-v5-baseline-smoke.ps1',
  'issue13-v5-build-baseline-index.R',
  'issue13-v5-compare-override.R',
  'issue13-v5-compatibility-baseline-override.R',
  'issue13-v5-coordinator-lib.ps1',
  'issue13-v5-coordinator.ps1',
  'issue13-v5-materialize-harness.ps1',
  'issue13-v5-new-config.ps1',
  'issue13-v5-render-report.ps1',
  'issue13-v5-static-verify.ps1'
)
$script:Issue13V5Methods = @(
  'wiodr13', 'wiodr16', 'alternative_1', 'alternative_2', 'norow_w13',
  'ochoa_1', 'ochoa_2', 'petrovic', 'wiodr13v09', 'wiodr16v09',
  'zerodep_1', 'zerodep_2'
)
$script:Issue13V5Recalculations = @(
  [pscustomobject]@{ stage = 1L; variant = 'full'; sea_vars = @() },
  [pscustomobject]@{ stage = 4L; variant = 'full'; sea_vars = @() },
  [pscustomobject]@{ stage = 5L; variant = 'full'; sea_vars = @() },
  [pscustomobject]@{
    stage = 4L; variant = 'select-gross-output-mv'
    sea_vars = @('gross_output.s.mv')
  },
  [pscustomobject]@{
    stage = 5L; variant = 'select-gross-output-du'
    sea_vars = @('gross_output.s.du')
  }
)
$script:Issue13V5Faults = @(
  'module-execution', 'preparation-promotion',
  'publication-run-staging', 'publication-semantic-validation',
  'publication-run-manifest', 'publication-run-promotion',
  'publication-release-staging', 'publication-release-manifest',
  'publication-release-promotion', 'publication-channel-marker'
)
$script:Issue13V5PreparationCaches = @(
  [pscustomobject]@{
    relative_path = 'wiodr13\WIOTS_in_MATLAB.zip'
    size_bytes = 292278662L
    sha256 = '1a5ee1f445ab27cd9927cf2f6d21a2d65eb8b4977b681f0fd8a252353d051afe'
  },
  [pscustomobject]@{
    relative_path = 'wiodr13\Socio_Economic_Accounts_July14.xlsx'
    size_bytes = 7831205L
    sha256 = '1ca319d414e9490fe4a868f79459c2b92e1994715c0d09c6af807da31fd8c36d'
  },
  [pscustomobject]@{
    relative_path = 'wiodr16\WIOTS_in_R.zip'
    size_bytes = 641578409L
    sha256 = '30b17452273ea4ae94b6cb015aacb112be3a8f8d27e0a0f35c1b5c584b60ce90'
  },
  [pscustomobject]@{
    relative_path = 'wiodr16\Socio_Economic_Accounts.xlsx'
    size_bytes = 5536437L
    sha256 = '8cf5ed3d1b7d7ddae93037cc5e1c1d0a2721b9a7679dcc076b85ac5220c576ce'
  },
  [pscustomobject]@{
    relative_path = 'euklems\Statistical_Capital.rds'
    size_bytes = 129637707L
    sha256 = '77bf752a4c79c0e324e6be31164e8f27fdc100c89b08f68c3a227da7c7ab3b44'
  },
  [pscustomobject]@{
    relative_path = 'euklems\Statistical_National-Accounts.rds'
    size_bytes = 44200266L
    sha256 = 'c6f7b65eb263839ea824fe223a8cf5fc13fad444db5b7a857b6aa01b29d0a4f2'
  }
)

function ConvertTo-Issue13V5Path([string]$Path) {
  [IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Get-Issue13V5ConfiguredPaths([object]$Config) {
  $paths = [Collections.Generic.List[string]]::new()
  foreach ($name in @(
      'repository_root', 'harness_runtime_root', 'harness_root',
      'harness_manifest_path', 'worktree_root', 'evidence_root',
      'control_root', 'source_origin', 'candidate_source_origin',
      'rscript', 'r_library',
      'baseline_runtime_index'
    )) {
    $paths.Add([string]$Config.$name)
  }
  foreach ($value in @(
      $Config.baseline_overlay.path,
      $Config.strict_baseline_smoke.path,
      $Config.compatibility_baseline_smoke.path,
      $Config.report.required_path
    )) {
    $paths.Add([string]$value)
  }
  foreach ($method in @($Config.methods)) {
    $paths.Add([string]$method.baseline)
    $paths.Add([string]$method.candidate)
  }
  foreach ($property in @($Config.supplemental_roots.PSObject.Properties)) {
    $paths.Add([string]$property.Value)
  }
  [string[]]$paths.ToArray()
}

function Test-Issue13V5LegacyPath([string]$Path) {
  $Path -match '(?i)(^|[\\/])[^\\/]*v4(?:r[0-9]+)?[^\\/]*($|[\\/])'
}

function Get-Issue13V5Sha256([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "File does not exist: $Path"
  }
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Issue13V5TextSha256([string]$Text) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
  [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($bytes)
  ).ToLowerInvariant()
}

function Read-Issue13V5Json([string]$Path) {
  $utf8 = [Text.UTF8Encoding]::new($false, $true)
  $text = [IO.File]::ReadAllText(
    (Resolve-Path -LiteralPath $Path).Path, $utf8)
  if ($text.Contains([char]0xFFFD)) {
    throw "Invalid UTF-8 replacement character in JSON: $Path"
  }
  $text | ConvertFrom-Json -DateKind String
}

function Write-Issue13V5Json(
  [object]$Value,
  [string]$Path,
  [switch]$Replace
) {
  $full = ConvertTo-Issue13V5Path $Path
  $parent = Split-Path -Parent $full
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    $null = New-Item -ItemType Directory -Path $parent
  }
  if ((Test-Path -LiteralPath $full) -and -not $Replace) {
    throw "Refusing to overwrite write-once JSON: $full"
  }
  $utf8 = [Text.UTF8Encoding]::new($false, $true)
  $payload = ($Value | ConvertTo-Json -Depth 100) + "`n"
  $temporary = Join-Path $parent (
    '.' + [IO.Path]::GetFileName($full) + '-' +
      [Guid]::NewGuid().ToString('N') + '.tmp')
  [IO.File]::WriteAllText($temporary, $payload, $utf8)
  $roundtrip = [IO.File]::ReadAllText($temporary, $utf8)
  if (-not [string]::Equals($payload, $roundtrip,
      [StringComparison]::Ordinal)) {
    throw "UTF-8 round trip failed: $full"
  }
  $null = $roundtrip | ConvertFrom-Json -DateKind String
  if ($Replace) {
    [IO.File]::Move($temporary, $full, $true)
  } else {
    [IO.File]::Move($temporary, $full)
  }
  if (-not [string]::Equals(
      [IO.File]::ReadAllText($full, $utf8), $payload,
      [StringComparison]::Ordinal)) {
    throw "Installed JSON differs from verified payload: $full"
  }
  Get-Issue13V5Sha256 $full
}

function Assert-Issue13V5NoReparse([string]$Root) {
  $items = @((Get-Item -LiteralPath $Root -Force)) +
    @(Get-ChildItem -LiteralPath $Root -Recurse -Force)
  $bad = @($items | Where-Object {
    ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
  })
  if ($bad.Count -ne 0) {
    throw ('Reparse points are forbidden: ' +
      (($bad | ForEach-Object FullName) -join ', '))
  }
}

function Get-Issue13V5TreeInventory([string]$Root) {
  $resolved = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
  Assert-Issue13V5NoReparse $resolved
  $directories = @(Get-ChildItem -LiteralPath $resolved -Recurse `
    -Directory -Force | Sort-Object FullName)
  $files = @(Get-ChildItem -LiteralPath $resolved -Recurse -File -Force |
    Sort-Object FullName)
  $records = [Collections.Generic.List[object]]::new()
  $lines = [Collections.Generic.List[string]]::new()
  $total = [int64]0
  foreach ($file in $files) {
    $relative = $file.FullName.Substring($resolved.Length).TrimStart('\').
      Replace('\', '/')
    $sha = Get-Issue13V5Sha256 $file.FullName
    $records.Add([ordered]@{
      relative_path = $relative
      size_bytes = [int64]$file.Length
      sha256 = $sha
    })
    $lines.Add($relative + '|' + [string]$file.Length + '|' + $sha)
    $total += [int64]$file.Length
  }
  $directoryNames = [string[]]@($directories | ForEach-Object {
    $_.FullName.Substring($resolved.Length).TrimStart('\').Replace('\', '/')
  })
  [Array]::Sort($directoryNames, [StringComparer]::Ordinal)
  [pscustomobject][ordered]@{
    root = $resolved
    file_count = [long]$files.Count
    directory_count = [long]$directories.Count
    total_bytes = $total
    inventory_sha256 = Get-Issue13V5TextSha256 (
      [string]::Join("`n", $lines))
    directory_list_sha256 = Get-Issue13V5TextSha256 (
      [string]::Join("`n", $directoryNames))
    directory_records = [object[]]$directoryNames
    records = [object[]]$records.ToArray()
  }
}

function Get-Issue13V5SourceBinding(
  [object]$Config,
  [ValidateSet('baseline', 'candidate')][string]$Arm
) {
  if ($Arm -ceq 'candidate') {
    return [pscustomobject][ordered]@{
      arm = 'candidate'
      origin = [string]$Config.candidate_source_origin
      inventory = $Config.candidate_source_inventory
    }
  }
  [pscustomobject][ordered]@{
    arm = 'baseline'
    origin = [string]$Config.source_origin
    inventory = $Config.source_inventory
  }
}

function Get-Issue13V5SourceContractSha256([string[]]$Paths) {
  if ($Paths.Count -ne 2 -or
      @($Paths | Sort-Object -Unique).Count -ne 2 -or
      @($Paths | Where-Object {
        -not (Test-Path -LiteralPath $_ -PathType Leaf)
      }).Count -ne 0) {
    throw 'A V5 source contract must contain two unique files.'
  }
  $records = @($Paths | ForEach-Object {
    [pscustomobject]@{
      file = [IO.Path]::GetFileName([string]$_)
      sha256 = Get-Issue13V5Sha256 ([string]$_)
    }
  } | Sort-Object file)
  if (@($records.file | Sort-Object -Unique).Count -ne 2) {
    throw 'V5 source contract filenames must be unique.'
  }
  $fields = @(
    'wlv-source-contract-v1', '2', 'file', 'sha256', '2',
    [string]$records[0].file, [string]$records[0].sha256,
    [string]$records[1].file, [string]$records[1].sha256
  )
  $payload = [Text.StringBuilder]::new()
  foreach ($field in $fields) {
    $bytes = [Text.Encoding]::UTF8.GetBytes([string]$field)
    $null = $payload.Append([string]$bytes.Length)
    $null = $payload.Append(':')
    $null = $payload.Append([string]$field)
  }
  Get-Issue13V5TextSha256 $payload.ToString()
}

function Assert-Issue13V5SourceContractBindings([object]$Config) {
  $expected = @(
    [pscustomobject]@{
      arm = 'baseline'; source = 'wiodr13'
      runtime_commit = $script:Issue13V5BaselineRuntimeCommit
      manifest_sha256 =
        'cd3ee98c7b823b1efa9b1272dca660a3977cc4a185b033263c2bef09cc1f73a8'
      source_generation_id =
        '65691585592c9cb6dc628c46606f004113f808e5b74c511c89678fae32032e2d'
      contract_sha256 =
        'f7e04664e357d6a334685e48eced6428dfdd410f5b9811785a0ad0f696cc65eb'
      units_sha256 =
        'ff1ab869e72d18879dc2e69c61c911425d73b612870c06317047accf9520ff11'
      units_git_blob = 'c89f1ca1e463d05a0b0ec683bee16084d39f4ac3'
      aggregations_sha256 =
        'e830708911f5b6674f44e51e8625de9a072ccf5cd91395954e1040f81372004a'
      aggregations_git_blob = '4d98444799af4c715f07a3b8a0ea4c1c1570a87c'
    },
    [pscustomobject]@{
      arm = 'baseline'; source = 'wiodr16'
      runtime_commit = $script:Issue13V5BaselineRuntimeCommit
      manifest_sha256 =
        '091183d74d97f5bc22209e57be0314c5ea5e510ae3573eaf2b342237de903aa9'
      source_generation_id =
        'f135fddb4723ba3cdf29164cf1b7ec006693cc201feaf2063f91fa104e942a7a'
      contract_sha256 =
        '94b9f78e8977001fab92e8fa8528aea5b97a3f22809bec58a16a56f413a6acf7'
      units_sha256 =
        'dfd73aa1e7721a139b04345c1e9fc48dc0a0a875659b8385a73292b2fba90143'
      units_git_blob = 'fcf432fd4ddc6fd54acf88ef809e241b5e3f0cf7'
      aggregations_sha256 =
        'bbee477efe375ffee47dc69ad86d9176d3e57d4292461d86423bbe68a9cbc642'
      aggregations_git_blob = '339de049570be34158a5599de05d1eea4175cacd'
    },
    [pscustomobject]@{
      arm = 'candidate'; source = 'wiodr13'
      runtime_commit = [string]$Config.candidate_commit
      manifest_sha256 =
        'b454f0f05890374cebde8b1b3222da4b4b63b887f67283fe12c97a351adc0bb8'
      source_generation_id =
        'b16a64edd8f3cdf117002fda011e1ba19f17e3fa72936671bb98dffeb0207856'
      contract_sha256 =
        '1f2462835e70d5681d7a5b9b29be5f0598cdb35a9abd72d3d147a6636ae5c905'
      units_sha256 =
        'ff1ab869e72d18879dc2e69c61c911425d73b612870c06317047accf9520ff11'
      units_git_blob = 'c89f1ca1e463d05a0b0ec683bee16084d39f4ac3'
      aggregations_sha256 =
        'c5c9779772101380514b6dbb937de48036280e66df382f2eb84f122ec91384d3'
      aggregations_git_blob = '20fbc53bb31261b0a698ae6ac56b0344772e1e6a'
    },
    [pscustomobject]@{
      arm = 'candidate'; source = 'wiodr16'
      runtime_commit = [string]$Config.candidate_commit
      manifest_sha256 =
        '28dc13d3abb9856fb984b01eb60379e213e6e0cfae58e8fb08c3b882c19c1a35'
      source_generation_id =
        '1f747ab8d53abe8cc674b0842796a5c9b936b036a79b48715b9e04734f949976'
      contract_sha256 =
        '3b23ab671df4905dee50b35efd8dff8d4897f65f2b74a2677d7614d9137e801a'
      units_sha256 =
        'dfd73aa1e7721a139b04345c1e9fc48dc0a0a875659b8385a73292b2fba90143'
      units_git_blob = 'fcf432fd4ddc6fd54acf88ef809e241b5e3f0cf7'
      aggregations_sha256 =
        '227c32c390e019a8ccb231db1bca898667bc31d75b599beda083799fa9d27278'
      aggregations_git_blob = '516f2dc29ed594df42605811a18af49bc9328d71'
    }
  )
  $configured = @($Config.source_contract_bindings)
  if ($configured.Count -ne 4) {
    throw 'V5 config must bind four arm-specific source contracts.'
  }
  for ($index = 0; $index -lt $expected.Count; $index++) {
    $want = $expected[$index]
    $actual = $configured[$index]
    $contractId = "$($want.source)_units_v2"
    foreach ($field in @(
        'arm', 'source', 'runtime_commit', 'manifest_sha256',
        'source_generation_id', 'contract_sha256', 'units_sha256',
        'units_git_blob', 'aggregations_sha256', 'aggregations_git_blob'
      )) {
      if ([string]$actual.$field -cne [string]$want.$field) {
        throw "Source contract binding differs: $($want.arm)/$($want.source)/$field"
      }
    }
    if ([string]$actual.contract_id -cne $contractId -or
        [string]$actual.contract_version -cne '2' -or
        [string]$actual.manifest_relative_path -cne
          "$($want.source)/normalized/_source_manifest.csv" -or
        [string]$actual.units_relative_path -cne
          "contracts/units/$($want.source)_v2-units.csv" -or
        [string]$actual.aggregations_relative_path -cne
          "contracts/units/$($want.source)_v2-aggregations.csv") {
      throw "Source contract path or identity differs: $($want.arm)/$($want.source)"
    }
    $sourceBinding = Get-Issue13V5SourceBinding $Config $want.arm
    $manifestPath = Join-Path $sourceBinding.origin `
      ([string]$actual.manifest_relative_path).Replace('/', '\')
    if ((Get-Issue13V5Sha256 $manifestPath) -cne
        [string]$want.manifest_sha256) {
      throw "Source manifest changed: $($want.arm)/$($want.source)"
    }
    $manifest = @(Import-Csv -LiteralPath $manifestPath -Delimiter ',')
    if ($manifest.Count -eq 0 -or
        @($manifest.source_generation_id | Sort-Object -Unique).Count -ne 1 -or
        @($manifest.contract_id | Sort-Object -Unique).Count -ne 1 -or
        @($manifest.contract_version | Sort-Object -Unique).Count -ne 1 -or
        @($manifest.contract_sha256 | Sort-Object -Unique).Count -ne 1 -or
        [string]$manifest[0].source_generation_id -cne
          [string]$want.source_generation_id -or
        [string]$manifest[0].contract_id -cne $contractId -or
        [string]$manifest[0].contract_version -cne '2' -or
        [string]$manifest[0].contract_sha256 -cne
          [string]$want.contract_sha256) {
      throw "Source manifest contract differs: $($want.arm)/$($want.source)"
    }
    foreach ($kind in @('units', 'aggregations')) {
      $relative = [string]$actual.($kind + '_relative_path')
      $blob = (& git -C ([string]$Config.repository_root) rev-parse `
        ([string]$want.runtime_commit + ':' + $relative) 2>$null).Trim()
      if ($LASTEXITCODE -ne 0 -or $blob -cne
          [string]$want.($kind + '_git_blob')) {
        throw "Source contract Git blob differs: $($want.arm)/$($want.source)/$kind"
      }
    }
    if ($want.arm -ceq 'candidate') {
      $unitsPath = Join-Path ([string]$Config.repository_root) `
        ([string]$actual.units_relative_path).Replace('/', '\')
      $aggregationsPath = Join-Path ([string]$Config.repository_root) `
        ([string]$actual.aggregations_relative_path).Replace('/', '\')
      if ((Get-Issue13V5Sha256 $unitsPath) -cne
          [string]$want.units_sha256 -or
          (Get-Issue13V5Sha256 $aggregationsPath) -cne
          [string]$want.aggregations_sha256 -or
          (Get-Issue13V5SourceContractSha256 @(
            $unitsPath, $aggregationsPath)) -cne
          [string]$want.contract_sha256) {
        throw "Candidate source contract digest differs: $($want.source)"
      }
    }
  }
  [object[]]$configured
}

function Assert-Issue13V5SourceInventory(
  [object]$Config,
  [string]$Root,
  [ValidateSet('baseline', 'candidate')][string]$Arm = 'baseline',
  [switch]$PreparationOnly
) {
  $inventory = Get-Issue13V5TreeInventory $Root
  if ($PreparationOnly) {
    $caches = @($script:Issue13V5PreparationCaches)
    $expectedBytes = [int64](($caches |
      Measure-Object size_bytes -Sum).Sum)
    $expectedPaths = @($caches | ForEach-Object {
      $_.relative_path.Replace('\', '/')
    } | Sort-Object)
    $actualPaths = @($inventory.records.relative_path | Sort-Object)
    if ($inventory.file_count -ne 6 -or
        $inventory.directory_count -ne 3 -or
        $inventory.total_bytes -ne $expectedBytes -or
        [string]::Join("`n", $actualPaths) -cne
          [string]::Join("`n", $expectedPaths)) {
      throw "Preparation cache inventory differs: $Root"
    }
    foreach ($cache in $caches) {
      $path = Join-Path $Root $cache.relative_path
      if ((Get-Item -LiteralPath $path).Length -ne $cache.size_bytes -or
          (Get-Issue13V5Sha256 $path) -cne $cache.sha256) {
        throw "Preparation cache authentication failed: $($cache.relative_path)"
      }
    }
  } else {
    $expected = (Get-Issue13V5SourceBinding $Config $Arm).inventory
    if ($inventory.file_count -ne [long]$expected.file_count -or
        $inventory.directory_count -ne [long]$expected.directory_count -or
        $inventory.total_bytes -ne [long]$expected.total_bytes -or
        $inventory.inventory_sha256 -cne
          [string]$expected.inventory_sha256 -or
        $inventory.directory_list_sha256 -cne
          [string]$expected.directory_list_sha256) {
      throw "Official source inventory differs: $Root"
    }
  }
  $inventory
}

function Get-Issue13V5FileId([string]$Path) {
  $output = @(& fsutil.exe file queryFileID $Path 2>&1)
  if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) {
    throw "Cannot query physical file ID: $Path"
  }
  ([string]$output[0]).Trim()
}

function Get-Issue13V5HardlinkPaths([string]$Path) {
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  $drive = [IO.Path]::GetPathRoot($resolved).TrimEnd('\')
  $output = @(& fsutil.exe hardlink list $resolved 2>&1)
  if ($LASTEXITCODE -ne 0 -or $output.Count -eq 0) {
    throw "Cannot enumerate physical links: $resolved"
  }
  @($output | ForEach-Object {
    $value = ([string]$_).Trim()
    if ($value.StartsWith('\')) { $value = $drive + $value }
    ConvertTo-Issue13V5Path $value
  })
}

function Assert-Issue13V5PhysicalCopy(
  [string]$SourceRoot,
  [string]$DestinationRoot,
  [object]$Inventory
) {
  foreach ($record in @($Inventory.records)) {
    $relative = [string]$record.relative_path
    $source = Join-Path $SourceRoot $relative.Replace('/', '\')
    $destination = Join-Path $DestinationRoot $relative.Replace('/', '\')
    if ([string]::Equals(
        (Get-Issue13V5FileId $source),
        (Get-Issue13V5FileId $destination),
        [StringComparison]::OrdinalIgnoreCase)) {
      throw "Source and destination share a physical file: $relative"
    }
    $links = @(Get-Issue13V5HardlinkPaths $destination)
    if ($links.Count -ne 1 -or
        -not [string]::Equals($links[0],
          (ConvertTo-Issue13V5Path $destination),
          [StringComparison]::OrdinalIgnoreCase)) {
      throw "Destination has an external hardlink: $relative"
    }
  }
  $true
}

function Get-Issue13V5HarnessInventory([string]$RuntimeRoot) {
  $root = (Resolve-Path -LiteralPath $RuntimeRoot).Path.TrimEnd('\')
  $harness = Join-Path $root 'issue13-evidence-harness'
  Assert-Issue13V5NoReparse $root
  $rootDirectories = @(Get-ChildItem -LiteralPath $root -Directory -Force)
  $harnessDirectories = @(
    Get-ChildItem -LiteralPath $harness -Directory -Recurse -Force)
  if ($rootDirectories.Count -ne 1 -or
      $rootDirectories[0].Name -cne 'issue13-evidence-harness' -or
      $harnessDirectories.Count -ne 0) {
    throw 'V5 harness must be a flat, fully inventoried two-level tree.'
  }
  $files = @(
    @(Get-ChildItem -LiteralPath $root -File -Force | Where-Object {
      $_.Name -cne 'v5-harness-manifest.json'
    }),
    @(Get-ChildItem -LiteralPath $harness -File -Force)
  ) | ForEach-Object { $_ }
  $records = @($files | ForEach-Object {
    [pscustomobject]@{
      relative_path = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
      size_bytes = [long]$_.Length
      sha256 = Get-Issue13V5Sha256 $_.FullName
    }
  } | Sort-Object relative_path)
  $lines = @($records | ForEach-Object {
    [string]$_.relative_path + '|' + [string]$_.size_bytes + '|' +
      [string]$_.sha256
  })
  [pscustomobject]@{
    file_count = [long]$records.Count
    total_bytes = [long](($records | Measure-Object size_bytes -Sum).Sum)
    inventory_sha256 = Get-Issue13V5TextSha256 (
      [string]::Join("`n", $lines))
    records = [object[]]$records
  }
}

function Assert-Issue13V5HarnessBinding([object]$Config) {
  $runtime = (Resolve-Path -LiteralPath `
    ([string]$Config.harness_runtime_root)).Path
  $expectedHarness = (Resolve-Path -LiteralPath (
    Join-Path $runtime 'issue13-evidence-harness')).Path
  $expectedManifest = (Resolve-Path -LiteralPath (
    Join-Path $runtime 'v5-harness-manifest.json')).Path
  if (-not [string]::Equals(
      (ConvertTo-Issue13V5Path ([string]$Config.harness_root)),
      (ConvertTo-Issue13V5Path $expectedHarness),
      [StringComparison]::OrdinalIgnoreCase) -or
      -not [string]::Equals(
      (ConvertTo-Issue13V5Path ([string]$Config.harness_manifest_path)),
      (ConvertTo-Issue13V5Path $expectedManifest),
      [StringComparison]::OrdinalIgnoreCase) -or
      (Get-Issue13V5Sha256 $expectedManifest) -cne
        [string]$Config.harness_manifest_sha256) {
    throw 'Configured harness paths are not canonical for the runtime root.'
  }
  $manifest = Read-Issue13V5Json $expectedManifest
  $inventory = Get-Issue13V5HarnessInventory $runtime
  if ([string]$manifest.schema -cne
        'wlv-issue13-v5-harness-materialization/1' -or
      [string]$manifest.generation -cne 'v5' -or
      [string]$manifest.baseline_commit -cne $script:Issue13V5BaselineCommit -or
      [string]$manifest.baseline_policy -cne
        'authenticated-direct-child-compatibility-oracle' -or
      [string]$manifest.baseline_runtime_commit -cne
        $script:Issue13V5BaselineRuntimeCommit -or
      [string]$manifest.baseline_runtime_tree -cne
        $script:Issue13V5BaselineRuntimeTree -or
      [string]$manifest.baseline_overlay_sha256 -cne
        $script:Issue13V5BaselineOverlaySha256 -or
      [string]$manifest.baseline_overlay_patch_id -cne
        $script:Issue13V5BaselineOverlayPatchId -or
      -not [bool]$manifest.strict_negative_evidence_required -or
      -not [bool]$manifest.final_evidence_eligible -or
      [bool]$manifest.reuses_candidate_evidence -or
      [long]$manifest.output_tooling.file_count -ne
        $script:Issue13V5HarnessFileCount -or
      [long]$manifest.output_tooling.total_bytes -ne
        $script:Issue13V5HarnessTotalBytes -or
      [string]$manifest.output_tooling.inventory_sha256 -cne
        $script:Issue13V5HarnessInventorySha256 -or
      [long]$manifest.sealed_output_tooling.file_count -ne
        $script:Issue13V5HarnessFileCount -or
      [long]$manifest.sealed_output_tooling.total_bytes -ne
        $script:Issue13V5HarnessTotalBytes -or
      [string]$manifest.sealed_output_tooling.inventory_sha256 -cne
        $script:Issue13V5HarnessInventorySha256 -or
      $inventory.file_count -ne $script:Issue13V5HarnessFileCount -or
      $inventory.total_bytes -ne $script:Issue13V5HarnessTotalBytes -or
      $inventory.inventory_sha256 -cne
        $script:Issue13V5HarnessInventorySha256) {
    throw 'Materialized V5 harness changed after authentication.'
  }
  $controllerPins = @(Get-Issue13V5CoordinatorPins $Config)
  if ([string]$manifest.source_controller.candidate_commit -cne
        [string]$Config.candidate_commit -or
      [long]$manifest.source_controller.file_count -ne 11L -or
      @($manifest.source_controller.records).Count -ne 11 -or
      $controllerPins.Count -ne 11) {
    throw 'Materialized V5 harness lacks the sealed controller source binding.'
  }
  for ($index = 0; $index -lt $controllerPins.Count; $index++) {
    foreach ($field in @('name', 'relative_path', 'sha256', 'git_blob')) {
      if ([string]$manifest.source_controller.records[$index].$field -cne
          [string]$controllerPins[$index].$field) {
        throw "Materialized V5 controller source changed: $($controllerPins[$index].name)/$field"
      }
    }
  }
  [pscustomobject]@{ manifest = $manifest; inventory = $inventory }
}

function Get-Issue13V5CoordinatorPins([object]$Config) {
  $repository = (Resolve-Path -LiteralPath $Config.repository_root).Path
  $relativeRoot = $script:Issue13V5CoordinatorRoot.Substring(
    $repository.Length).TrimStart('\').Replace('\', '/')
  $records = [Collections.Generic.List[object]]::new()
  foreach ($name in $script:Issue13V5ControllerFiles) {
    $path = (Resolve-Path -LiteralPath (
      Join-Path $script:Issue13V5CoordinatorRoot $name)).Path
    $relative = $relativeRoot + '/' + $name
    $currentBlob = (& git -C $repository hash-object -- $path 2>$null).Trim()
    $committedBlob = (& git -C $repository rev-parse `
      ([string]$Config.candidate_commit + ':' + $relative) 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $currentBlob -cnotmatch '^[0-9a-f]{40}$' -or
        $currentBlob -cne $committedBlob) {
      throw "V5 coordinator is not byte-identical to the candidate: $relative"
    }
    $records.Add([ordered]@{
      name = $name
      relative_path = $relative
      path = $path
      sha256 = Get-Issue13V5Sha256 $path
      git_blob = $currentBlob
    })
  }
  $records.ToArray()
}

function Assert-Issue13V5CoordinatorPins(
  [object]$Config,
  [object[]]$Pins
) {
  $current = @(Get-Issue13V5CoordinatorPins $Config)
  if (@($Pins).Count -ne $current.Count) {
    throw 'V5 coordinator pin coverage changed.'
  }
  for ($index = 0; $index -lt $current.Count; $index++) {
    foreach ($field in @('name', 'relative_path', 'path', 'sha256', 'git_blob')) {
      if ([string]$Pins[$index].$field -cne [string]$current[$index].$field) {
        throw "V5 coordinator pin changed: $($current[$index].name)/$field"
      }
    }
  }
  $true
}

function Assert-Issue13V5BaselineSmokeEvidence(
  [object]$Config,
  [string]$Path,
  [string]$ExpectedPurpose,
  [string]$ExpectedRuntimeCommit,
  [string]$ExpectedHarnessManifestSha256,
  [bool]$ExpectedPassed,
  [string[]]$ExpectedFailedMethods,
  [string]$ExpectedSummarySha256 = ''
) {
  $summaryPath = (Resolve-Path -LiteralPath $Path).Path
  if (-not [string]::IsNullOrWhiteSpace($ExpectedSummarySha256) -and
      (Get-Issue13V5Sha256 $summaryPath) -cne $ExpectedSummarySha256) {
    throw "Baseline smoke summary seal changed: $summaryPath"
  }
  $summary = Read-Issue13V5Json $summaryPath
  $failedMethods = [string[]]@($ExpectedFailedMethods)
  $expectedPassedCount = 12L - [long]$failedMethods.Count
  $expectedStatus = if ($ExpectedPassed) { 'passed' } else { 'failed' }
  $expectedTree = (& git -C ([string]$Config.repository_root) rev-parse `
    ($ExpectedRuntimeCommit + '^{tree}') 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or $expectedTree -cnotmatch '^[0-9a-f]{40}$') {
    throw "Cannot authenticate smoke runtime tree: $ExpectedRuntimeCommit"
  }
  $baseProperty = $summary.PSObject.Properties['baseline_base_commit']
  $runtimeProperty = $summary.PSObject.Properties['baseline_runtime_commit']
  $removedEnvironmentProperty =
    $summary.PSObject.Properties['environment_removed']
  $isCompatibility = $ExpectedPurpose -ceq
    'compatibility-oracle-executability-preflight'
  if ([string]$summary.schema -cne 'wlv-issue13-v5-baseline-smoke/1' -or
      [bool]$summary.final_evidence_eligible -or
      [string]$summary.purpose -cne $ExpectedPurpose -or
      [string]$summary.baseline_commit -cne $script:Issue13V5BaselineCommit -or
      [string]$summary.status -cne $expectedStatus -or
      [bool]$summary.passed -ne $ExpectedPassed -or
      [long]$summary.method_count -ne 12L -or
      [long]$summary.passed_count -ne $expectedPassedCount -or
      [long]$summary.failed_count -ne [long]$failedMethods.Count -or
      [string]$summary.source_inventory_sha256 -cne
        $script:Issue13V5SourceInventorySha256 -or
      [string]$summary.harness_manifest_sha256 -cne
        $ExpectedHarnessManifestSha256 -or
      @($summary.records).Count -ne 12 -or
      [string]::Join("`n", @($summary.records.method)) -cne
        [string]::Join("`n", $script:Issue13V5Methods)) {
    throw "Baseline smoke header is not authenticated: $summaryPath"
  }
  if ($isCompatibility) {
    $expectedRemovedEnvironment = @('LANG', 'LC_ALL', 'LC_CTYPE')
    if ($null -eq $baseProperty -or $null -eq $runtimeProperty -or
        $null -eq $removedEnvironmentProperty -or
        [string]$baseProperty.Value -cne $script:Issue13V5BaselineCommit -or
        [string]$runtimeProperty.Value -cne $ExpectedRuntimeCommit -or
        [string]::Join("`n", @($removedEnvironmentProperty.Value)) -cne
          [string]::Join("`n", $expectedRemovedEnvironment)) {
      throw 'Compatibility smoke omits authenticated base/runtime/locale bindings.'
    }
  } else {
    if (($null -ne $baseProperty -and
          [string]$baseProperty.Value -cne $script:Issue13V5BaselineCommit) -or
        ($null -ne $runtimeProperty -and
          [string]$runtimeProperty.Value -cne $ExpectedRuntimeCommit)) {
      throw 'Strict smoke optional commit bindings are inconsistent.'
    }
  }
  $actualFailed = @($summary.records | Where-Object status -ceq 'failed' |
    ForEach-Object { [string]$_.method })
  if ([string]::Join("`n", $actualFailed) -cne
      [string]::Join("`n", $failedMethods)) {
    throw 'Baseline smoke failed-method classification changed.'
  }

  $smokeRoot = Split-Path -Parent $summaryPath
  foreach ($record in @($summary.records)) {
    $method = [string]$record.method
    $scenarioId = "baseline/calculate/$method/workers1"
    $shouldPass = $method -cnotin $failedMethods
    $recordStatus = if ($shouldPass) { 'passed' } else { 'failed' }
    $expectedProject = ConvertTo-Issue13V5Path (
      Join-Path (Join-Path $smokeRoot 'worktrees') $method)
    $expectedEvidence = ConvertTo-Issue13V5Path (
      Join-Path (Join-Path (Join-Path (Join-Path $smokeRoot 'attempts') `
        $method) 'evidence\scenarios') $scenarioId.Replace('/', '__'))
    if ([string]$record.scenario_id -cne $scenarioId -or
        [string]$record.status -cne $recordStatus -or
        -not [string]::Equals(
          (ConvertTo-Issue13V5Path ([string]$record.project_root)),
          $expectedProject, [StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals(
          (ConvertTo-Issue13V5Path ([string]$record.evidence_directory)),
          $expectedEvidence, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $expectedProject -PathType Container) -or
        -not (Test-Path -LiteralPath $expectedEvidence -PathType Container)) {
      throw "Baseline smoke record path or identity changed: $method"
    }
    $head = (& git -C $expectedProject rev-parse HEAD 2>$null).Trim()
    $tree = (& git -C $expectedProject rev-parse 'HEAD^{tree}' 2>$null).Trim()
    $tracked = @(& git -C $expectedProject status '--porcelain=v1' `
      '--untracked-files=no' 2>$null)
    if ($LASTEXITCODE -ne 0 -or $head -cne $ExpectedRuntimeCommit -or
        $tree -cne $expectedTree -or $tracked.Count -ne 0) {
      throw "Baseline smoke worktree is not pinned and tracked-clean: $method"
    }

    $resultPath = Join-Path $expectedEvidence 'scenario-result.json'
    $metricsPath = Join-Path $expectedEvidence 'process-metrics.json'
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $metricsPath -PathType Leaf)) {
      throw "Baseline smoke evidence files are missing: $method"
    }
    $result = Read-Issue13V5Json $resultPath
    $metrics = Read-Issue13V5Json $metricsPath
    if ([string]$result.schema -cne 'wlv-issue13-scenario-result/1' -or
        [string]$result.scenario_id -cne $scenarioId -or
        [string]$result.status -cne $recordStatus -or
        [bool]$result.passed -ne $shouldPass -or
        [string]$result.kind -cne 'calculate' -or
        [string]$result.expected_commit -cne $ExpectedRuntimeCommit -or
        [string]$result.observed_commit -cne $ExpectedRuntimeCommit -or
        [string]$result.request.method -cne $method -or
        [long]$result.request.workers -ne 1L -or
        [string]$metrics.schema -cne 'wlv-issue13-process-metrics/2' -or
        [string]$metrics.scenario_id -cne $scenarioId -or
        [string]$metrics.status -cne $recordStatus -or
        [bool]$metrics.passed -ne $shouldPass -or
        -not [bool]$metrics.cluster_closed -or
        -not [bool]$metrics.worker_count_matched -or
        [long]$metrics.expected_worker_processes -ne 0L -or
        [long]$metrics.max_concurrent_worker_processes -ne 0L -or
        @($metrics.lingering_pids).Count -ne 0) {
      throw "Baseline smoke scenario or metrics contract changed: $method"
    }
    $processSpec = Join-Path (
      Join-Path (Join-Path (Join-Path $smokeRoot 'attempts') $method) 'bundle') `
      'process-spec.json'
    $telemetryBindings = @(
      @($metrics.stdout_path, $metrics.stdout_sha256,
        (Join-Path $expectedEvidence 'stdout.log')),
      @($metrics.stderr_path, $metrics.stderr_sha256,
        (Join-Path $expectedEvidence 'stderr.log')),
      @($metrics.samples_path, $metrics.samples_sha256,
        (Join-Path $expectedEvidence 'process-samples.csv')),
      @($metrics.process_spec_path, $metrics.process_spec_sha256, $processSpec)
    )
    foreach ($telemetry in $telemetryBindings) {
      $observedPath = ConvertTo-Issue13V5Path ([string]$telemetry[0])
      $expectedPath = ConvertTo-Issue13V5Path ([string]$telemetry[2])
      if (-not [string]::Equals($observedPath, $expectedPath,
            [StringComparison]::OrdinalIgnoreCase) -or
          [string]$telemetry[1] -cnotmatch '^[0-9a-f]{64}$' -or
          -not (Test-Path -LiteralPath $expectedPath -PathType Leaf) -or
          (Get-Issue13V5Sha256 $expectedPath) -cne [string]$telemetry[1]) {
        throw "Baseline smoke telemetry changed: $method"
      }
    }
    if ($shouldPass) {
      if ([string]$record.scenario_result_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
          [string]$record.process_metrics_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
          (Get-Issue13V5Sha256 $resultPath) -cne
            [string]$record.scenario_result_sha256 -or
          (Get-Issue13V5Sha256 $metricsPath) -cne
            [string]$record.process_metrics_sha256 -or
          [double]$record.elapsed_seconds -ne [double]$metrics.elapsed_seconds -or
          [long]$record.peak_rss_bytes -ne [long]$metrics.peak_rss_bytes -or
          -not [string]::IsNullOrWhiteSpace([string]$record.detail)) {
        throw "Passed baseline smoke record hashes changed: $method"
      }
    } elseif ($null -ne $record.scenario_result_sha256 -or
        $null -ne $record.process_metrics_sha256 -or
        $null -ne $record.elapsed_seconds -or $null -ne $record.peak_rss_bytes -or
        [string]::IsNullOrWhiteSpace([string]$record.detail)) {
      throw "Sealed strict-smoke failure record changed: $method"
    }
  }
  $summary
}

function Get-Issue13V5ExpectedBaselineIds([object]$Config) {
  $ids = [Collections.Generic.List[string]]::new()
  foreach ($phase in @($Config.matrix.science_phases)) {
    $ids.Add('baseline/' + [string]$phase.phase)
  }
  $ids.Add('baseline/prepare/all')
  $ids.Add('baseline/paper/0')
  @($ids.ToArray() | Sort-Object)
}

function Get-Issue13V5ExpectedSciencePhases {
  $records = [Collections.Generic.List[object]]::new()
  foreach ($method in $script:Issue13V5Methods) {
    $records.Add([pscustomobject]@{
      phase = "calculate/$method/workers1"
      kind = 'calculate'; method = $method; workers = 1L
      stage = $null; variant = $null; sea_vars = @()
    })
    foreach ($recalculation in $script:Issue13V5Recalculations) {
      $records.Add([pscustomobject]@{
        phase = "recalculate/$method/stage$($recalculation.stage)/" +
          [string]$recalculation.variant
        kind = 'recalculate'; method = $method; workers = 1L
        stage = [long]$recalculation.stage
        variant = [string]$recalculation.variant
        sea_vars = [object[]]@($recalculation.sea_vars)
      })
    }
  }
  foreach ($method in @('wiodr13', 'wiodr16')) {
    $records.Add([pscustomobject]@{
      phase = "calculate/$method/workers2"
      kind = 'calculate'; method = $method; workers = 2L
      stage = $null; variant = $null; sea_vars = @()
    })
  }
  $records.ToArray()
}

function Get-Issue13V5PhaseFingerprint([object]$Phase) {
  $stage = if ($null -eq $Phase.stage) { '<null>' } else {
    [string][long]$Phase.stage
  }
  $variant = if ($null -eq $Phase.variant) { '<null>' } else {
    [string]$Phase.variant
  }
  [string]::Join('|', @(
      [string]$Phase.phase, [string]$Phase.kind, [string]$Phase.method,
      [string][long]$Phase.workers, $stage, $variant,
      [string]::Join(',', @($Phase.sea_vars | ForEach-Object { [string]$_ }))
    ))
}

function Get-Issue13V5ExpectedEvidenceIds {
  $phases = @(Get-Issue13V5ExpectedSciencePhases)
  $scenarios = [Collections.Generic.List[string]]::new()
  foreach ($arm in @('baseline', 'candidate')) {
    foreach ($phase in $phases) {
      $scenarios.Add("$arm/$($phase.phase)")
    }
    $scenarios.Add("$arm/prepare/all")
    $scenarios.Add("$arm/paper/0")
  }
  foreach ($fault in $script:Issue13V5Faults) {
    $scenarios.Add("candidate/fault/$fault")
  }
  $comparisons = [Collections.Generic.List[string]]::new()
  foreach ($phase in $phases) {
    $comparisons.Add("parity/$($phase.phase)")
    if ([string]$phase.kind -ceq 'recalculate') {
      foreach ($arm in @('baseline', 'candidate')) {
        $comparisons.Add("oracle/$arm/$($phase.phase)")
      }
    }
  }
  foreach ($source in @('wiodr13', 'wiodr16', 'euklems')) {
    $comparisons.Add("parity/prepare/$source")
  }
  $comparisons.Add('parity/paper/0')
  foreach ($arm in @('baseline', 'candidate')) {
    foreach ($method in @('wiodr13', 'wiodr16')) {
      $comparisons.Add(
        "equivalence/$arm/calculate/$method/workers2-vs-workers1")
    }
  }
  [pscustomobject]@{
    scenarios = [object[]]@($scenarios.ToArray() | Sort-Object)
    comparisons = [object[]]@($comparisons.ToArray() | Sort-Object)
  }
}

function Assert-Issue13V5Config([string]$ConfigPath) {
  $path = (Resolve-Path -LiteralPath $ConfigPath).Path
  $config = Read-Issue13V5Json $path
  $legacyPaths = @(Get-Issue13V5ConfiguredPaths $config | Where-Object {
    Test-Issue13V5LegacyPath $_
  })
  if ($legacyPaths.Count -ne 0) {
    throw 'V5 config contains a forbidden V4/V4R2 path.'
  }
  if ([string]$config.schema -cne 'wlv-issue13-native-gate-config/3' -or
      [string]$config.generation -cne 'v5' -or
      -not [bool]$config.final_evidence_eligible -or
      [bool]$config.reuse_policy.v4_evidence_allowed -or
      [bool]$config.reuse_policy.candidate_evidence_reuse_allowed -or
      [bool]$config.reuse_policy.imported_scenario_evidence_allowed -or
      -not [bool]$config.reuse_policy.fresh_roots_required -or
      [string]$config.baseline_commit -cne $script:Issue13V5BaselineCommit -or
      [string]$config.baseline_base_commit -cne
        $script:Issue13V5BaselineCommit -or
      [string]$config.baseline_runtime_commit -cnotmatch '^[0-9a-f]{40}$' -or
      [string]$config.baseline_runtime_commit -cne
        $script:Issue13V5BaselineRuntimeCommit -or
      [string]$config.baseline_profile -cne $script:Issue13V5BaselineProfile -or
      [string]$config.candidate_commit -cnotmatch '^[0-9a-f]{40}$' -or
      [string]$config.candidate_commit -ceq $script:Issue13V5BaselineCommit -or
      [string]$config.candidate_commit -ceq
        [string]$config.baseline_runtime_commit -or
      [string]$config.candidate_seed_commit -cne
        [string]$config.candidate_commit -or
      [long]$config.source_inventory.file_count -ne
        $script:Issue13V5SourceFileCount -or
      [long]$config.source_inventory.directory_count -ne
        $script:Issue13V5SourceDirectoryCount -or
      [long]$config.source_inventory.total_bytes -ne
        $script:Issue13V5SourceTotalBytes -or
      [string]$config.source_inventory.inventory_sha256 -cne
        $script:Issue13V5SourceInventorySha256 -or
      [string]$config.source_inventory.directory_list_sha256 -cne
        $script:Issue13V5SourceDirectorySha256 -or
      [long]$config.candidate_source_inventory.file_count -ne
        $script:Issue13V5CandidateSourceFileCount -or
      [long]$config.candidate_source_inventory.directory_count -ne
        $script:Issue13V5CandidateSourceDirectoryCount -or
      [long]$config.candidate_source_inventory.total_bytes -ne
        $script:Issue13V5CandidateSourceTotalBytes -or
      [string]$config.candidate_source_inventory.inventory_sha256 -cne
        $script:Issue13V5CandidateSourceInventorySha256 -or
      [string]$config.candidate_source_inventory.directory_list_sha256 -cne
        $script:Issue13V5CandidateSourceDirectorySha256) {
    throw 'V5 config header or no-reuse policy is invalid.'
  }
  if (@($config.methods).Count -ne 12 -or
      [string]::Join("`n", @($config.methods.method)) -cne
        [string]::Join("`n", $script:Issue13V5Methods) -or
      [long]$config.matrix.method_count -ne 12 -or
      [long]$config.matrix.science_phase_count -ne 74 -or
      [long]$config.matrix.paired_phase_count -ne 76 -or
      [long]$config.matrix.monitored_scenario_count -ne 162 -or
      [long]$config.matrix.authenticated_comparison_count -ne 202 -or
      [long]$config.matrix.fault_count -ne 10 -or
      @($config.matrix.science_phases).Count -ne 74 -or
      @($config.matrix.faults).Count -ne 10) {
    throw 'V5 matrix cardinality differs from 12/76/162/202/10.'
  }
  $phaseIds = @($config.matrix.science_phases.phase)
  if (@($phaseIds | Sort-Object -Unique).Count -ne 74) {
    throw 'V5 science phases are not unique.'
  }
  $expectedPhases = @(Get-Issue13V5ExpectedSciencePhases)
  $expectedFingerprints = @($expectedPhases | ForEach-Object {
    Get-Issue13V5PhaseFingerprint $_
  })
  $actualFingerprints = @($config.matrix.science_phases |
    ForEach-Object { Get-Issue13V5PhaseFingerprint $_ })
  if ([string]::Join("`n", $actualFingerprints) -cne
      [string]::Join("`n", $expectedFingerprints) -or
      [string]::Join("`n", @($config.matrix.supplemental_phases)) -cne
        "prepare/all`npaper/0" -or
      [string]::Join("`n", @($config.matrix.faults)) -cne
        [string]::Join("`n", $script:Issue13V5Faults)) {
    throw 'V5 matrix records differ from the sealed scientific matrix.'
  }
  $evidenceIds = Get-Issue13V5ExpectedEvidenceIds
  $scenarioSafe = @($evidenceIds.scenarios | ForEach-Object {
    Get-Issue13V5SafeId ([string]$_)
  })
  $comparisonSafe = @($evidenceIds.comparisons | ForEach-Object {
    Get-Issue13V5SafeId ([string]$_)
  })
  if (@($evidenceIds.scenarios).Count -ne 162 -or
      @($scenarioSafe | Sort-Object -Unique).Count -ne 162 -or
      @($evidenceIds.comparisons).Count -ne 202 -or
      @($comparisonSafe | Sort-Object -Unique).Count -ne 202) {
    throw 'V5 scenario/comparison identifiers are not collision-free.'
  }
  if ([string]$config.comparison.numerical_tolerance -cne
        'contract-only-no-new-tolerance' -or
      -not [bool]$config.comparison.compare_dimensions -or
      -not [bool]$config.comparison.compare_dimnames -or
      -not [bool]$config.comparison.compare_finite_values -or
      -not [bool]$config.comparison.distinguish_na_nan_posinf_neginf -or
      -not [bool]$config.comparison.compare_semantic_states -or
      -not [bool]$config.comparison.compare_metadata_and_contracts -or
      -not [bool]$config.comparison.compare_method_matrices -or
      -not [bool]$config.comparison.
        compare_diagnostics_as_duplicate_preserving_multisets -or
      -not [bool]$config.comparison.compare_unselected_cells -or
      [string]::Join("`n", @($config.comparison.ignore_only)) -cne
        "timestamps`npaths`nrun_id`nresult_id`n" +
          'provenance-dependent-container-bytes' -or
      [string]::Join("`n", @($config.comparison.candidate_only_artifacts)) `
        -cne "_nonfinite_resolution_diagnostics.csv`n_runtime_resources.rds" -or
      [string]::Join("`n", @(
        $config.comparison.preparation_architecture_projection)) -cne
        "module`naggregation_notes`nsource_generation_id`n" +
          "contract_sha256`n_unit_contract.csv:size_bytes`n" +
          "_unit_contract.csv:sha256`nm_io.fst.meta:size_bytes`n" +
          "m_io.fst.meta:sha256`nsea.fst.meta:size_bytes`n" +
          'sea.fst.meta:sha256') {
    throw 'V5 scientific comparison policy changed.'
  }
  if ([double]$config.performance.candidate_time_ratio_maximum -ne 1.2 -or
      [double]$config.performance.candidate_rss_baseline_ratio_allowance `
        -ne 0.1 -or
      [long]$config.performance.candidate_rss_minimum_allowance_bytes -ne
        536870912L -or
      [string]::Join("`n", @($config.performance.workers2_methods)) -cne
        "wiodr13`nwiodr16" -or
      -not [bool]$config.performance.require_cluster_closed -or
      [string]::Join("`n", @($config.preparation.sources)) -cne
        "wiodr13`nwiodr16`neuklems" -or
      -not [bool]$config.preparation.same_official_cache_inventory -or
      -not [bool]$config.preparation.bitwise_arrays -or
      -not [bool]$config.preparation.require_atomic_promotion -or
      [string]::Join("`n", @($config.paper0.methods)) -cne
        "ochoa_1`nochoa_2" -or
      [string]::Join("`n", @($config.paper0.unsupported_papers)) -cne
        "3`n4" -or
      -not [bool]$config.paper0.workbook_semantic_comparison) {
    throw 'V5 performance, preparation, or paper policy changed.'
  }
  if ([string]$config.report.required_path -cne
        'docs/validation/issue-13.md' -or
      [string]::Join("`n", @($config.report.required_fields)) -cne
        "baseline_commit`nbaseline_base_commit`nbaseline_runtime_commit`n" +
          "strict_baseline_smoke`ncompatibility_baseline_smoke`n" +
          "baseline_overlay_patch`ncandidate_commit`nsource_ids`ncommands`n" +
          "hashes`ntimes`npeak_rss`ndifferences`nfault_results`n" +
          "preparation_results`npaper0_results" -or
      -not (Test-Path -LiteralPath ([string]$config.rscript) -PathType Leaf) -or
      [IO.Path]::GetFileName([string]$config.rscript) -cne 'Rscript.exe' -or
      -not (Test-Path -LiteralPath ([string]$config.r_library) `
        -PathType Container)) {
    throw 'V5 report or R runtime binding changed.'
  }
  foreach ($method in @($config.methods)) {
    if ([string]$method.baseline_runtime_commit -cne
          [string]$config.baseline_runtime_commit -or
        [string]$method.baseline_seed_commit -cne
          [string]$config.baseline_runtime_commit -or
        [string]$method.candidate_runtime_commit -cne
          [string]$config.candidate_commit -or
        [string]$method.candidate_seed_commit -cne
          [string]$config.candidate_commit) {
      throw "Method commit binding differs: $($method.method)"
    }
  }
  foreach ($rootName in @('worktree_root', 'evidence_root', 'control_root')) {
    $root = ConvertTo-Issue13V5Path ([string]$config.$rootName)
    if (Test-Issue13V5LegacyPath $root) {
      throw "Forbidden legacy root: $root"
    }
  }
  $roots = @('worktree_root', 'evidence_root', 'control_root') |
    ForEach-Object { ConvertTo-Issue13V5Path ([string]$config.$_) }
  if (@($roots | Sort-Object -Unique).Count -ne 3) {
    throw 'Worktree, evidence, and control roots must be distinct.'
  }
  foreach ($root in $roots) {
    if ([string]::Equals($path, $root,
        [StringComparison]::OrdinalIgnoreCase) -or
        $path.StartsWith($root.TrimEnd('\') + '\',
          [StringComparison]::OrdinalIgnoreCase) -or
        $root.StartsWith($path.TrimEnd('\') + '\',
          [StringComparison]::OrdinalIgnoreCase)) {
      throw 'V5 config file must be outside worktree, evidence, and control roots.'
    }
  }
  for ($left = 0; $left -lt $roots.Count; $left++) {
    for ($right = 0; $right -lt $roots.Count; $right++) {
      if ($left -eq $right) { continue }
      $ancestor = $roots[$left].TrimEnd('\') + '\'
      if ($roots[$right].StartsWith(
          $ancestor, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Worktree, evidence, and control roots must not be nested.'
      }
    }
  }
  foreach ($immutable in @(
      (ConvertTo-Issue13V5Path ([string]$config.repository_root))
      (ConvertTo-Issue13V5Path ([string]$config.source_origin))
      (ConvertTo-Issue13V5Path ([string]$config.candidate_source_origin))
      (ConvertTo-Issue13V5Path ([string]$config.harness_runtime_root))
    )) {
    foreach ($root in $roots) {
      $immutablePrefix = $immutable.TrimEnd('\') + '\'
      $rootPrefix = $root.TrimEnd('\') + '\'
      if ([string]::Equals($root, $immutable,
          [StringComparison]::OrdinalIgnoreCase) -or
          $root.StartsWith($immutablePrefix,
            [StringComparison]::OrdinalIgnoreCase) -or
          $immutable.StartsWith($rootPrefix,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw 'V5 output roots must not overlap repository, sources, or harness.'
      }
    }
  }
  if (@($config.allowed_r_processes).Count -ne 1 -or
      [long]$config.allowed_r_processes[0].pid -ne 30272L -or
      [string]$config.allowed_r_processes[0].command_line_sha256 -cne
        $script:Issue13V5AllowedRCommandSha256) {
    throw 'V5 config does not preserve the sole allowed persistent R PID.'
  }
  $strictSmokePath = ConvertTo-Issue13V5Path (
    [string]$config.strict_baseline_smoke.path)
  $compatibilitySmokePath = ConvertTo-Issue13V5Path (
    [string]$config.compatibility_baseline_smoke.path)
  $overlayPath = ConvertTo-Issue13V5Path ([string]$config.baseline_overlay.path)
  foreach ($binding in @(
      @($strictSmokePath, [string]$config.strict_baseline_smoke.sha256,
        'strict baseline smoke'),
      @($compatibilitySmokePath,
        [string]$config.compatibility_baseline_smoke.sha256,
        'compatibility baseline smoke'),
      @($overlayPath, [string]$config.baseline_overlay.sha256,
        'baseline overlay patch')
    )) {
    if (-not (Test-Path -LiteralPath ([string]$binding[0]) -PathType Leaf) -or
        [string]$binding[1] -cnotmatch '^[0-9a-f]{64}$' -or
        (Get-Issue13V5Sha256 ([string]$binding[0])) -cne
          [string]$binding[1]) {
      throw "Authenticated $($binding[2]) changed or is missing."
    }
  }
  if ([string]$config.strict_baseline_smoke.sha256 -cne
        '973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d' -or
      [long]$config.strict_baseline_smoke.passed_count -ne 5 -or
      [long]$config.strict_baseline_smoke.failed_count -ne 7 -or
      [bool]$config.strict_baseline_smoke.final_evidence_eligible -or
      [long]$config.compatibility_baseline_smoke.passed_count -ne 12 -or
      [long]$config.compatibility_baseline_smoke.failed_count -ne 0 -or
      [bool]$config.compatibility_baseline_smoke.final_evidence_eligible -or
      [string]$config.baseline_overlay.sha256 -cne
        $script:Issue13V5BaselineOverlaySha256 -or
      [string]$config.baseline_overlay.patch_id -cne
        $script:Issue13V5BaselineOverlayPatchId) {
    throw 'Baseline smoke or compatibility-overlay policy changed.'
  }
  $strictFailedMethods = @(
    'alternative_1', 'alternative_2', 'norow_w13', 'ochoa_1', 'ochoa_2',
    'petrovic', 'wiodr13v09'
  )
  $null = Assert-Issue13V5BaselineSmokeEvidence $config $strictSmokePath `
    'strict-cc2-executability-preflight' $script:Issue13V5BaselineCommit `
    'a17a187621cdd4aff6f24efd6bf43ffbf9336de0a19189dfc7f5a82758a92c23' `
    $false $strictFailedMethods `
    '973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d'
  $null = Assert-Issue13V5BaselineSmokeEvidence $config `
    $compatibilitySmokePath 'compatibility-oracle-executability-preflight' `
    $script:Issue13V5BaselineRuntimeCommit `
    ([string]$config.harness_manifest_sha256) $true @() `
    ([string]$config.compatibility_baseline_smoke.sha256)
  $harnessBinding = Assert-Issue13V5HarnessBinding $config
  $harnessInventory = $harnessBinding.inventory
  $index = Read-Issue13V5Json $config.baseline_runtime_index
  if ((Get-Issue13V5Sha256 $config.baseline_runtime_index) -cne
        [string]$config.baseline_runtime_index_sha256 -or
      [string]$index.schema -cne
        'wlv-issue13-baseline-runtime-index/1' -or
      [string]$index.baseline_base_commit -cne
        $script:Issue13V5BaselineCommit -or
      @($index.profiles).Count -ne 1 -or
      [string]$index.profiles[0].id -cne $script:Issue13V5BaselineProfile -or
      [string]$index.profiles[0].inventory_value -cne
        $script:Issue13V5BaselineProfile -or
      [string]$index.profiles[0].source_commit -cne
        [string]$config.baseline_runtime_commit -or
      [string]$index.profiles[0].runtime_commit -cne
        [string]$config.baseline_runtime_commit -or
      [bool]$index.profiles[0].run_dirty -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path `
          ([string]$index.profiles[0].overlay_patch_path)),
        $overlayPath, [StringComparison]::OrdinalIgnoreCase) -or
      [string]$index.profiles[0].overlay_patch_sha256 -cne
        [string]$config.baseline_overlay.sha256 -or
      [string]$index.profiles[0].overlay_patch_id -cne
        [string]$config.baseline_overlay.patch_id -or
      @($index.scenarios).Count -ne 76 -or
      @($index.scenarios | Where-Object {
        [string]$_.runtime_commit -cne
          [string]$config.baseline_runtime_commit -or
        [string]$_.profile_id -cne $script:Issue13V5BaselineProfile
      }).Count -ne 0) {
    throw 'Baseline runtime index is not the authenticated compatibility oracle.'
  }
  $expectedIds = @(Get-Issue13V5ExpectedBaselineIds $config)
  $actualIds = @($index.scenarios.scenario_id | Sort-Object)
  if ([string]::Join("`n", $expectedIds) -cne
      [string]::Join("`n", $actualIds)) {
    throw 'Compatibility baseline index does not cover exactly 76 scenarios.'
  }
  $source = Assert-Issue13V5SourceInventory $config `
    ([string]$config.source_origin)
  if ($source.inventory_sha256 -cne
      [string]$config.source_inventory.inventory_sha256) {
    throw 'Official source origin changed after configuration.'
  }
  $candidateSource = Assert-Issue13V5SourceInventory $config `
    ([string]$config.candidate_source_origin) -Arm candidate
  if ($candidateSource.inventory_sha256 -cne
      [string]$config.candidate_source_inventory.inventory_sha256) {
    throw 'Candidate source origin changed after configuration.'
  }
  $null = Assert-Issue13V5SourceContractBindings $config
  $headExists = & git -C ([string]$config.repository_root) cat-file -e `
    ([string]$config.candidate_commit + '^{commit}') 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw 'Candidate commit is unavailable in the configured repository.'
  }
  $null = $headExists
  $runtimeExists = & git -C ([string]$config.repository_root) cat-file -e `
    ([string]$config.baseline_runtime_commit + '^{commit}') 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw 'Compatibility runtime commit is unavailable.'
  }
  $null = $runtimeExists
  $runtimeParent = (& git -C ([string]$config.repository_root) rev-parse `
    ([string]$config.baseline_runtime_commit + '^') 2>$null).Trim()
  $runtimeTree = (& git -C ([string]$config.repository_root) rev-parse `
    ([string]$config.baseline_runtime_commit + '^{tree}') 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or
      $runtimeParent -cne $script:Issue13V5BaselineCommit -or
      $runtimeTree -cne $script:Issue13V5BaselineRuntimeTree) {
    throw 'Compatibility runtime is not a direct child of cc2.'
  }
  $ancestor = & git -C ([string]$config.repository_root) merge-base `
    --is-ancestor $script:Issue13V5BaselineCommit `
    ([string]$config.candidate_commit) 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw 'Candidate is not a descendant of the strict cc2 baseline.'
  }
  $null = $ancestor
  $oracleAncestor = & git -C ([string]$config.repository_root) merge-base `
    --is-ancestor $script:Issue13V5BaselineRuntimeCommit `
    ([string]$config.candidate_commit) 2>$null
  $oracleAncestorExit = $LASTEXITCODE
  if ($oracleAncestorExit -eq 0) {
    throw 'Compatibility oracle commit must remain outside the candidate history.'
  }
  if ($oracleAncestorExit -ne 1) {
    throw 'Cannot prove that the compatibility oracle is outside the candidate history.'
  }
  $null = $oracleAncestor
  $null = Get-Issue13V5WorktreeBindings $config
  $null = Get-Issue13V5CoordinatorPins $config
  [pscustomobject]@{
    path = $path
    sha256 = Get-Issue13V5Sha256 $path
    config = $config
    harness_inventory = $harnessInventory
    source_inventory = $source
    candidate_source_inventory = $candidateSource
  }
}

function Get-Issue13V5SafeId([string]$Id) {
  $Id -replace '[^A-Za-z0-9._-]', '__'
}

function Get-Issue13V5WorktreeBindings([object]$Config) {
  $bindings = [Collections.Generic.List[object]]::new()
  foreach ($method in @($Config.methods)) {
    $bindings.Add([pscustomobject]@{
      id = 'baseline/' + [string]$method.method
      arm = 'baseline'; kind = 'full'; label = [string]$method.method
      root = [string]$method.baseline
      commit = [string]$method.baseline_runtime_commit
    })
    $bindings.Add([pscustomobject]@{
      id = 'candidate/' + [string]$method.method
      arm = 'candidate'; kind = 'full'; label = [string]$method.method
      root = [string]$method.candidate
      commit = [string]$method.candidate_runtime_commit
    })
  }
  foreach ($arm in @('baseline', 'candidate')) {
    $commit = if ($arm -ceq 'baseline') {
      [string]$Config.baseline_runtime_commit
    } else { [string]$Config.candidate_commit }
    $bindings.Add([pscustomobject]@{
      id = "$arm/preparation"; arm = $arm; kind = 'preparation'
      label = 'preparation'
      root = [string]$Config.supplemental_roots.($arm + '_preparation')
      commit = $commit
    })
    $bindings.Add([pscustomobject]@{
      id = "$arm/paper0"; arm = $arm; kind = 'full'; label = 'paper0'
      root = [string]$Config.supplemental_roots.($arm + '_paper0')
      commit = $commit
    })
  }
  $bindings.Add([pscustomobject]@{
    id = 'candidate/fault'; arm = 'candidate'; kind = 'fault'; label = 'fault'
    root = [string]$Config.supplemental_roots.candidate_fault
    commit = [string]$Config.candidate_commit
  })
  if ($bindings.Count -ne 29 -or
      @($bindings.root | Sort-Object -Unique).Count -ne 29) {
    throw 'Worktree bindings are not exactly 29 unique roots.'
  }
  $worktreeRoot = ConvertTo-Issue13V5Path ([string]$Config.worktree_root)
  $expectedNames = @(
    @($script:Issue13V5Methods | ForEach-Object { 'baseline-' + $_ }),
    @($script:Issue13V5Methods | ForEach-Object { 'candidate-' + $_ }),
    'baseline-preparation', 'candidate-preparation',
    'baseline-paper0', 'candidate-paper0', 'candidate-fault'
  ) | ForEach-Object { $_ } | Sort-Object
  $actualNames = @($bindings | ForEach-Object {
    $root = ConvertTo-Issue13V5Path ([string]$_.root)
    if (-not [string]::Equals(
        (ConvertTo-Issue13V5Path (Split-Path -Parent $root)), $worktreeRoot,
        [StringComparison]::OrdinalIgnoreCase)) {
      throw "Worktree is not a direct child of the V5 root: $root"
    }
    [IO.Path]::GetFileName($root)
  } | Sort-Object)
  if ([string]::Join("`n", $actualNames) -cne
      [string]::Join("`n", $expectedNames)) {
    throw 'The 29 V5 worktree names differ from the sealed topology.'
  }
  $bindings.ToArray()
}

function Assert-Issue13V5GitWorktree(
  [string]$Root,
  [string]$Commit
) {
  $resolved = (Resolve-Path -LiteralPath $Root).Path
  $head = (& git -C $resolved rev-parse HEAD 2>$null).Trim()
  $tree = (& git -C $resolved rev-parse 'HEAD^{tree}' 2>$null).Trim()
  $status = @(& git -C $resolved status '--porcelain=v1' `
    '--untracked-files=no' 2>$null)
  if ($LASTEXITCODE -ne 0 -or $head -cne $Commit -or
      $tree -cnotmatch '^[0-9a-f]{40}$' -or $status.Count -ne 0) {
    throw "Worktree is not pinned and tracked-clean: $resolved"
  }
  [pscustomobject]@{ root = $resolved; commit = $head; tree = $tree }
}

function Assert-Issue13V5NoTransactionResidue([string]$ProjectRoot) {
  foreach ($relative in @(
      'results\.staging', 'source_data\.preparation-staging'
    )) {
    $path = Join-Path $ProjectRoot $relative
    if (-not (Test-Path -LiteralPath $path)) { continue }
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
      throw "Transaction staging is not a directory: $path"
    }
    Assert-Issue13V5NoReparse $path
    if (@(Get-ChildItem -LiteralPath $path -Force).Count -ne 0) {
      throw "Transaction staging is not empty: $path"
    }
  }
  foreach ($relative in @('results\.lock-results')) {
    if (Test-Path -LiteralPath (Join-Path $ProjectRoot $relative)) {
      throw "Transaction lock remains visible: $relative"
    }
  }
  $source = Join-Path $ProjectRoot 'source_data'
  if (Test-Path -LiteralPath $source -PathType Container) {
    $locks = @(Get-ChildItem -LiteralPath $source -Force | Where-Object {
      $_.Name -cmatch '^\.prepare-lock-'
    })
    if ($locks.Count -ne 0) {
      throw "Preparation lock remains visible: $($locks[0].FullName)"
    }
  }
  $true
}

function Get-Issue13V5RProcesses {
  @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
    [string]$_.Name -cin @(
      'R.exe', 'Rscript.exe', 'Rterm.exe', 'Rgui.exe', 'Rcmd.exe', 'Rfe.exe'
    )
  })
}

function Assert-Issue13V5NoConcurrentR([object]$Config) {
  $allowed = @{}
  foreach ($record in @($Config.allowed_r_processes)) {
    $allowed[[int]$record.pid] = [string]$record.command_line_sha256
  }
  $unexpected = [Collections.Generic.List[string]]::new()
  foreach ($process in @(Get-Issue13V5RProcesses)) {
    $pidValue = [int]$process.ProcessId
    $hash = Get-Issue13V5TextSha256 ([string]$process.CommandLine)
    if (-not $allowed.ContainsKey($pidValue) -or
        [string]$allowed[$pidValue] -cne $hash) {
      $unexpected.Add("$pidValue/$($process.Name)/$hash")
    }
  }
  if ($unexpected.Count -ne 0) {
    throw ('Unexpected R processes are active: ' +
      ($unexpected.ToArray() -join ', '))
  }
  $true
}

function Wait-Issue13V5CoolState(
  [object]$Config,
  [int]$CoolingSeconds = 20,
  [int64]$RequiredFreeBytes = 4294967296L,
  [int]$TimeoutSeconds = 900
) {
  $started = [DateTime]::UtcNow
  $stableSince = $null
  while (([DateTime]::UtcNow - $started).TotalSeconds -lt $TimeoutSeconds) {
    $null = Assert-Issue13V5NoConcurrentR $Config
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $free = [int64]$os.FreePhysicalMemory * 1024L
    if ($free -ge $RequiredFreeBytes) {
      if ($null -eq $stableSince) { $stableSince = [DateTime]::UtcNow }
      if (([DateTime]::UtcNow - $stableSince).TotalSeconds -ge
          $CoolingSeconds) {
        return $free
      }
    } else {
      $stableSince = $null
    }
    Start-Sleep -Seconds 5
  }
  throw 'The machine did not reach the required cooled state.'
}

function Enter-Issue13V5Lock([object]$Config, [string]$Action) {
  $path = Join-Path ([string]$Config.control_root) '.issue13-v5-lock'
  if (Test-Path -LiteralPath $path) {
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
      throw "V5 coordinator lock is not a directory: $path"
    }
    $ownerPath = Join-Path $path 'owner.json'
    $entries = @(Get-ChildItem -LiteralPath $path -Force)
    if ($entries.Count -ne 1 -or $entries[0].PSIsContainer -or
        $entries[0].Name -cne 'owner.json') {
      throw 'Existing V5 coordinator lock has a foreign envelope.'
    }
    $owner = Read-Issue13V5Json $ownerPath
    $process = Get-CimInstance Win32_Process -Filter (
      'ProcessId=' + [string]$owner.pid) -ErrorAction SilentlyContinue
    $active = $false
    if ($null -ne $process) {
      $created = ([DateTime]$process.CreationDate).ToUniversalTime().ToString('o')
      $commandHash = Get-Issue13V5TextSha256 ([string]$process.CommandLine)
      $active = $created -ceq [string]$owner.creation_date_utc -and
        $commandHash -ceq [string]$owner.command_line_sha256
    }
    if ($active) {
      throw "V5 coordinator lock is owned by an active process: $path"
    }
    $archiveRoot = Join-Path ([string]$Config.control_root) 'orphan-locks'
    if (-not (Test-Path -LiteralPath $archiveRoot -PathType Container)) {
      $null = New-Item -ItemType Directory -Path $archiveRoot
    }
    $archive = Join-Path $archiveRoot (
      'orphan-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' +
        [Guid]::NewGuid().ToString('N'))
    [IO.Directory]::Move($path, $archive)
  }
  $null = New-Item -ItemType Directory -Path $path
  $hostProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$PID" `
    -ErrorAction Stop
  $record = [ordered]@{
    schema = 'wlv-issue13-v5-lock/1'
    pid = [long]$PID
    action = $Action
    creation_date_utc =
      ([DateTime]$hostProcess.CreationDate).ToUniversalTime().ToString('o')
    command_line_sha256 = Get-Issue13V5TextSha256 (
      [string]$hostProcess.CommandLine)
    acquired_at_utc = [DateTime]::UtcNow.ToString('o')
  }
  $null = Write-Issue13V5Json $record (Join-Path $path 'owner.json')
  [pscustomobject]@{ path = $path; pid = $PID }
}

function Exit-Issue13V5Lock([object]$Lock) {
  $owner = Read-Issue13V5Json (Join-Path $Lock.path 'owner.json')
  $hostProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$PID" `
    -ErrorAction Stop
  $created = ([DateTime]$hostProcess.CreationDate).ToUniversalTime().ToString('o')
  $commandHash = Get-Issue13V5TextSha256 ([string]$hostProcess.CommandLine)
  if ([string]$owner.schema -cne 'wlv-issue13-v5-lock/1' -or
      [long]$owner.pid -ne [long]$Lock.pid -or
      [string]$owner.creation_date_utc -cne $created -or
      [string]$owner.command_line_sha256 -cne $commandHash) {
    throw 'Refusing to release a V5 lock owned by another process.'
  }
  [IO.File]::Delete((Join-Path $Lock.path 'owner.json'))
  [IO.Directory]::Delete([string]$Lock.path, $false)
}

function Invoke-Issue13V5External(
  [object]$Config,
  [string]$Executable,
  [string[]]$Arguments,
  [string]$Label,
  [int]$TimeoutSeconds,
  [int[]]$ExpectedExitCodes = @(0),
  [string]$WorkingDirectory = $null,
  [hashtable]$Environment = @{}
) {
  $commandsRoot = Join-Path ([string]$Config.control_root) 'commands'
  if (-not (Test-Path -LiteralPath $commandsRoot -PathType Container)) {
    $null = New-Item -ItemType Directory -Path $commandsRoot
  }
  $token = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' +
    [Guid]::NewGuid().ToString('N')
  $safe = Get-Issue13V5SafeId $Label
  $stdout = Join-Path $commandsRoot ($token + '__' + $safe + '.stdout.log')
  $stderr = Join-Path $commandsRoot ($token + '__' + $safe + '.stderr.log')
  $started = [DateTime]::UtcNow
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $Executable
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $environmentRemoved = @('LANG', 'LC_ALL', 'LC_CTYPE')
  foreach ($name in $environmentRemoved) {
    if ($Environment.ContainsKey($name)) {
      throw "V5 commands cannot override sanitized locale variable: $name"
    }
    $null = $info.Environment.Remove($name)
  }
  if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
    $info.WorkingDirectory = $WorkingDirectory
  }
  foreach ($name in @($Environment.Keys)) {
    $info.Environment[[string]$name] = [string]$Environment[$name]
  }
  foreach ($name in $environmentRemoved) {
    if ($info.Environment.ContainsKey($name)) {
      throw "V5 command retained a sanitized locale variable: $name"
    }
  }
  foreach ($argument in $Arguments) {
    $info.ArgumentList.Add([string]$argument)
  }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  if (-not $process.Start()) {
    throw "Could not start command: $Label"
  }
  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
  if ($timedOut) {
    $process.Kill($true)
    $process.WaitForExit()
  }
  $stdoutText = $stdoutTask.GetAwaiter().GetResult()
  $stderrText = $stderrTask.GetAwaiter().GetResult()
  $utf8 = [Text.UTF8Encoding]::new($false, $true)
  [IO.File]::WriteAllText($stdout, $stdoutText, $utf8)
  [IO.File]::WriteAllText($stderr, $stderrText, $utf8)
  $exitCode = if ($timedOut) { -999 } else { [int]$process.ExitCode }
  $record = [ordered]@{
    schema = 'wlv-issue13-v5-command/1'
    label = $Label
    executable = ConvertTo-Issue13V5Path $Executable
    arguments = [object[]]$Arguments
    environment = [pscustomobject]$Environment
    environment_removed = [object[]]$environmentRemoved
    working_directory = $WorkingDirectory
    started_at_utc = $started.ToString('o')
    finished_at_utc = [DateTime]::UtcNow.ToString('o')
    timeout_seconds = [long]$TimeoutSeconds
    timed_out = $timedOut
    exit_code = [long]$exitCode
    expected_exit_codes = [object[]]$ExpectedExitCodes
    stdout_path = $stdout
    stdout_sha256 = Get-Issue13V5Sha256 $stdout
    stderr_path = $stderr
    stderr_sha256 = Get-Issue13V5Sha256 $stderr
  }
  $recordPath = Join-Path $commandsRoot ($token + '__' + $safe + '.json')
  $null = Write-Issue13V5Json $record $recordPath
  $process.Dispose()
  if ($timedOut -or $exitCode -notin $ExpectedExitCodes) {
    throw "Command failed: $Label (exit=$exitCode, record=$recordPath)"
  }
  [pscustomobject]@{
    exit_code = $exitCode
    stdout = $stdoutText
    stderr = $stderrText
    record_path = $recordPath
  }
}

function Invoke-Issue13V5R(
  [object]$Config,
  [string[]]$Arguments,
  [string]$Label,
  [int]$TimeoutSeconds,
  [int[]]$ExpectedExitCodes = @(0),
  [switch]$ConfirmExecuteR
) {
  if (-not $ConfirmExecuteR) {
    throw "$Label requires -ConfirmExecuteR."
  }
  $null = Assert-Issue13V5HarnessBinding $Config
  $null = Assert-Issue13V5NoConcurrentR $Config
  try {
    $result = Invoke-Issue13V5External $Config ([string]$Config.rscript) `
      $Arguments $Label $TimeoutSeconds $ExpectedExitCodes `
      ([string]$Config.repository_root) `
      @{ R_LIBS_USER = [string]$Config.r_library }
  } finally {
    $null = Assert-Issue13V5NoConcurrentR $Config
    $null = Assert-Issue13V5HarnessBinding $Config
  }
  $result
}

function Invoke-Issue13V5Pwsh(
  [object]$Config,
  [string[]]$Arguments,
  [string]$Label,
  [int]$TimeoutSeconds,
  [switch]$ConfirmExecuteR
) {
  if (-not $ConfirmExecuteR) {
    throw "$Label requires -ConfirmExecuteR."
  }
  $null = Assert-Issue13V5HarnessBinding $Config
  $null = Assert-Issue13V5NoConcurrentR $Config
  $pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source
  try {
    $result = Invoke-Issue13V5External $Config $pwsh $Arguments $Label `
      $TimeoutSeconds @(0) ([string]$Config.repository_root) `
      @{ R_LIBS_USER = [string]$Config.r_library }
  } finally {
    $null = Assert-Issue13V5NoConcurrentR $Config
    $null = Assert-Issue13V5HarnessBinding $Config
  }
  $result
}

function Get-Issue13V5StatePath([object]$Config) {
  Join-Path ([string]$Config.control_root) 'gate-state.json'
}

function Read-Issue13V5State([object]$Config, [string]$ConfigSha256) {
  $state = Read-Issue13V5Json (Get-Issue13V5StatePath $Config)
  if ([string]$state.schema -cne 'wlv-issue13-v5-coordinator-state/1' -or
      [string]$state.generation -cne 'v5' -or
      [string]$state.config_sha256 -cne $ConfigSha256 -or
      [string]$state.baseline_commit -cne $script:Issue13V5BaselineCommit -or
      [string]$state.baseline_runtime_commit -cne
        [string]$Config.baseline_runtime_commit -or
      [string]$state.candidate_commit -cne [string]$Config.candidate_commit -or
      @($state.phases).Count -ne 76 -or
      @($state.worktrees).Count -ne 29) {
    throw 'V5 coordinator state is invalid or stale.'
  }
  $null = Assert-Issue13V5CoordinatorPins $Config `
    @($state.coordinator_pins)
  $null = Assert-Issue13V5ReportBinding $Config $state
  if ([string]$state.final_aggregate.status -ceq 'passed') {
    $null = Assert-Issue13V5FinalBindings $Config $state
  }
  $state
}

function Save-Issue13V5State(
  [object]$Config,
  [object]$State
) {
  $null = Assert-Issue13V5CoordinatorPins $Config `
    @($State.coordinator_pins)
  $null = Assert-Issue13V5HarnessBinding $Config
  $null = Assert-Issue13V5ReportBinding $Config $State
  if ([string]$State.final_aggregate.status -ceq 'passed') {
    $null = Assert-Issue13V5FinalBindings $Config $State
  }
  $State.revision = [long]$State.revision + 1L
  $State.updated_at_utc = [DateTime]::UtcNow.ToString('o')
  $null = Write-Issue13V5Json $State (Get-Issue13V5StatePath $Config) -Replace
}

function Get-Issue13V5ScenarioDirectory([object]$Config, [string]$Id) {
  Join-Path (Join-Path ([string]$Config.evidence_root) 'scenarios') `
    (Get-Issue13V5SafeId $Id)
}

function Get-Issue13V5ComparisonDirectory([object]$Config, [string]$Id) {
  Join-Path (Join-Path ([string]$Config.evidence_root) 'comparisons') `
    (Get-Issue13V5SafeId $Id)
}

function Get-Issue13V5FileRecords(
  [string]$Root,
  [string[]]$Names
) {
  @($Names | ForEach-Object {
    $path = (Resolve-Path -LiteralPath (Join-Path $Root $_)).Path
    $item = Get-Item -LiteralPath $path
    [pscustomobject][ordered]@{
      name = [string]$_
      size_bytes = [int64]$item.Length
      sha256 = Get-Issue13V5Sha256 $path
    }
  })
}

function Assert-Issue13V5ReportBinding(
  [object]$Config,
  [object]$State
) {
  $status = [string]$State.report.status
  $expectedPath = ConvertTo-Issue13V5Path (
    Join-Path ([string]$Config.repository_root) `
      ([string]$Config.report.required_path))
  if ($status -ceq 'planned') {
    if ($null -ne $State.report.path -or $null -ne $State.report.sha256 -or
        [string]$State.status -ceq 'complete') {
      throw 'Planned report state has a foreign binding.'
    }
    return $true
  }
  if ($status -cne 'written' -or [string]$State.status -cne 'complete' -or
      [string]$State.report.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$State.report.path)),
        $expectedPath, [StringComparison]::OrdinalIgnoreCase) -or
      -not (Test-Path -LiteralPath $expectedPath -PathType Leaf) -or
      (Get-Issue13V5Sha256 $expectedPath) -cne
        [string]$State.report.sha256) {
    throw 'Written V5 report binding is invalid or changed.'
  }
  $text = [IO.File]::ReadAllText(
    $expectedPath, [Text.UTF8Encoding]::new($false, $true))
  foreach ($required in @(
      [string]$Config.baseline_commit,
      [string]$Config.baseline_runtime_commit,
      [string]$Config.candidate_commit,
      [string]$State.config_sha256,
      [string]$State.final_aggregate.sha256,
      [string]$Config.source_inventory.inventory_sha256,
      [string]$Config.candidate_source_inventory.inventory_sha256,
      [string]$Config.strict_baseline_smoke.sha256,
      [string]$Config.compatibility_baseline_smoke.sha256,
      [string]$Config.baseline_overlay.sha256,
      [string]$Config.baseline_overlay.patch_id
    ) + @($Config.report.required_fields | ForEach-Object { [string]$_ })) {
    if (-not $text.Contains([string]$required)) {
      throw "Written V5 report lacks authenticated content: $required"
    }
  }
  $true
}

function Assert-Issue13V5FinalBindings(
  [object]$Config,
  [object]$State
) {
  if ([string]$State.final_aggregate.status -cne 'passed' -or
      (Get-Issue13V5Sha256 $State.final_aggregate.path) -cne
        [string]$State.final_aggregate.sha256) {
    throw 'Final aggregate report binding changed.'
  }
  $aggregateRoot = Split-Path -Parent ([string]$State.final_aggregate.path)
  $names = @(
    'aggregate.json', 'checks.csv', 'oracle-classification.csv',
    'performance.csv')
  $currentFiles = @(Get-Issue13V5FileRecords $aggregateRoot $names)
  $recordedFiles = @($State.final_aggregate.files)
  if ($recordedFiles.Count -ne $currentFiles.Count) {
    throw 'Final aggregate file coverage changed.'
  }
  for ($index = 0; $index -lt $currentFiles.Count; $index++) {
    foreach ($field in @('name', 'size_bytes', 'sha256')) {
      if ([string]$recordedFiles[$index].$field -cne
          [string]$currentFiles[$index].$field) {
        throw "Final aggregate file changed: $($currentFiles[$index].name)"
      }
    }
  }
  foreach ($binding in @(
      @($State.prep_fault.aggregate_path,
        $State.final_aggregate.prep_fault_aggregate_sha256,
        'prep/fault aggregate'),
      @($State.prep_fault.preparation_comparison_path,
        $State.final_aggregate.preparation_comparison_sha256,
        'preparation comparison'),
      @((Join-Path (Get-Issue13V5ComparisonDirectory $Config `
          'parity/paper/0') 'comparison.json'),
        $State.final_aggregate.paper0_comparison_sha256,
        'paper 0 comparison')
    )) {
    if ((Get-Issue13V5Sha256 ([string]$binding[0])) -cne
        [string]$binding[1]) {
      throw "Final supporting evidence changed: $($binding[2])"
    }
  }
  foreach ($treeBinding in @(
      @([string]$Config.evidence_root,
        $State.final_aggregate.evidence_inventory, 'evidence'),
      @((Join-Path ([string]$Config.control_root) 'commands'),
        $State.final_aggregate.command_inventory, 'command')
    )) {
    $current = Get-Issue13V5TreeInventory ([string]$treeBinding[0])
    $recorded = $treeBinding[1]
    foreach ($field in @(
        'file_count', 'directory_count', 'total_bytes', 'inventory_sha256',
        'directory_list_sha256')) {
      if ([string]$current.$field -cne [string]$recorded.$field) {
        throw "Final $($treeBinding[2]) inventory changed: $field"
      }
    }
  }
  $null = Assert-Issue13V5ReportBinding $Config $State
  $true
}

function Copy-Issue13V5WriteOnceTree(
  [string]$Source,
  [string]$Destination
) {
  if (Test-Path -LiteralPath $Destination) {
    throw "Write-once destination already exists: $Destination"
  }
  $sourceRoot = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
  $parent = Split-Path -Parent $Destination
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    $null = New-Item -ItemType Directory -Path $parent
  }
  $staging = Join-Path $parent ('.issue13-v5-copy-' +
    [Guid]::NewGuid().ToString('N'))
  $null = New-Item -ItemType Directory -Path $staging
  foreach ($directory in @(Get-ChildItem -LiteralPath $sourceRoot -Recurse `
      -Directory -Force | Sort-Object FullName)) {
    $relative = $directory.FullName.Substring($sourceRoot.Length).TrimStart('\')
    $null = New-Item -ItemType Directory -Path (Join-Path $staging $relative)
  }
  foreach ($file in @(Get-ChildItem -LiteralPath $sourceRoot -Recurse `
      -File -Force | Sort-Object FullName)) {
    $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')
    Copy-Item -LiteralPath $file.FullName -Destination (
      Join-Path $staging $relative)
  }
  $before = Get-Issue13V5TreeInventory $sourceRoot
  $after = Get-Issue13V5TreeInventory $staging
  if ($before.file_count -ne $after.file_count -or
      $before.directory_count -ne $after.directory_count -or
      $before.total_bytes -ne $after.total_bytes -or
      $before.inventory_sha256 -cne $after.inventory_sha256 -or
      $before.directory_list_sha256 -cne $after.directory_list_sha256) {
    throw "Write-once copy authentication failed: $Destination"
  }
  [IO.Directory]::Move($staging, $Destination)
  $installed = Get-Issue13V5TreeInventory $Destination
  if ($installed.inventory_sha256 -cne $before.inventory_sha256) {
    throw "Promoted write-once copy differs: $Destination"
  }
  $installed
}

function Assert-Issue13V5ScenarioEvidence(
  [string]$Directory,
  [string]$ScenarioId,
  [string]$Commit,
  [int]$ExpectedWorkers
) {
  $resultPath = Join-Path $Directory 'scenario-result.json'
  $metricsPath = Join-Path $Directory 'process-metrics.json'
  $result = Read-Issue13V5Json $resultPath
  $metrics = Read-Issue13V5Json $metricsPath
  if ([string]$result.schema -cne 'wlv-issue13-scenario-result/1' -or
      [string]$result.scenario_id -cne $ScenarioId -or
      -not [bool]$result.passed -or [string]$result.status -cne 'passed' -or
      [string]$result.observed_commit -cne $Commit -or
      [string]$metrics.schema -cne 'wlv-issue13-process-metrics/2' -or
      [string]$metrics.scenario_id -cne $ScenarioId -or
      -not [bool]$metrics.passed -or -not [bool]$metrics.cluster_closed -or
      @($metrics.lingering_pids).Count -ne 0 -or
      [long]$metrics.expected_worker_processes -ne $ExpectedWorkers -or
      [long]$metrics.max_concurrent_worker_processes -ne $ExpectedWorkers -or
      -not [bool]$metrics.worker_count_matched) {
    throw "Scenario or process evidence is invalid: $ScenarioId"
  }
  foreach ($binding in @(
      @($metrics.stdout_path, $metrics.stdout_sha256),
      @($metrics.stderr_path, $metrics.stderr_sha256),
      @($metrics.samples_path, $metrics.samples_sha256),
      @($metrics.process_spec_path, $metrics.process_spec_sha256)
    )) {
    if ((Get-Issue13V5Sha256 ([string]$binding[0])) -cne
        [string]$binding[1]) {
      throw "Scenario telemetry hash differs: $ScenarioId"
    }
  }
  [pscustomobject]@{
    result_path = (Resolve-Path -LiteralPath $resultPath).Path
    result_sha256 = Get-Issue13V5Sha256 $resultPath
    metrics_path = (Resolve-Path -LiteralPath $metricsPath).Path
    metrics_sha256 = Get-Issue13V5Sha256 $metricsPath
    elapsed_seconds = [double]$metrics.elapsed_seconds
    peak_rss_bytes = [int64]$metrics.peak_rss_bytes
  }
}

function Assert-Issue13V5Performance(
  [object]$Config,
  [object]$Baseline,
  [object]$Candidate,
  [string]$Phase
) {
  $timeLimit = [double]$Baseline.elapsed_seconds *
    [double]$Config.performance.candidate_time_ratio_maximum
  $rssAllowance = [Math]::Max(
    [double]$Baseline.peak_rss_bytes *
      [double]$Config.performance.candidate_rss_baseline_ratio_allowance,
    [double]$Config.performance.candidate_rss_minimum_allowance_bytes)
  $rssLimit = [double]$Baseline.peak_rss_bytes + $rssAllowance
  if ([double]$Candidate.elapsed_seconds -gt $timeLimit -or
      [double]$Candidate.peak_rss_bytes -gt $rssLimit) {
    throw "Performance limit failed: $Phase"
  }
  [pscustomobject][ordered]@{
    baseline_seconds = [double]$Baseline.elapsed_seconds
    candidate_seconds = [double]$Candidate.elapsed_seconds
    time_limit_seconds = $timeLimit
    baseline_peak_rss_bytes = [int64]$Baseline.peak_rss_bytes
    candidate_peak_rss_bytes = [int64]$Candidate.peak_rss_bytes
    rss_limit_bytes = [int64][Math]::Floor($rssLimit)
  }
}
