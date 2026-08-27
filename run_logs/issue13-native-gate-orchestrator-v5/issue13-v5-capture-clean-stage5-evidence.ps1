[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $true)]
    [string]$Stage5CaptureRoot,

    [Parameter(Mandatory = $true)]
    [string]$BaselineSourceDataRoot,

    [Parameter(Mandatory = $true)]
    [string]$BridgeCaptureRoot,

    [Parameter(Mandatory = $true)]
    [string]$BridgeManifest,

    [Parameter(Mandatory = $true)]
    [string]$HarnessDir,

    [string]$RscriptCommand =
        "C:\Users\rodri\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe",

    [string]$RLibrary =
        "D:\Trabalho\Code\wlvdb\renv\library\windows\R-4.6\x86_64-w64-mingw32"
)

$issue13V5CommandCollisionGuard = {
  param([Management.Automation.Language.ScriptBlockAst]$Ast)
  $runtimeRoot =
    'C:\Users\rodri\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell'
  $moduleRoot = [IO.Path]::Combine($runtimeRoot, 'Modules')
  $expectedProcessPath = [IO.Path]::Combine($runtimeRoot, 'pwsh.exe')
  if (-not [string]::Equals(
      [IO.Path]::GetFullPath([Environment]::ProcessPath),
      $expectedProcessPath, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'V5 command bootstrap requires the sealed pwsh host.'
  }

  $trustedRuntimeFiles =
    [Collections.Generic.Dictionary[string, object]]::new(
      [StringComparer]::OrdinalIgnoreCase)
  foreach ($record in [object[]]@(
      [pscustomobject]@{
        relative_path = 'pwsh.exe'
        size_bytes = 301368L
        sha256 =
          'DB6DD81183FE57D22E03B911EC9A30A2FD7C40542E97743615355A6FB44F458F'
      },
      [pscustomobject]@{
        relative_path = 'System.Management.Automation.dll'
        size_bytes = 19597112L
        sha256 =
          '5AD53C0024367C81A9BEBA1FCEF3288DCF6A34966E4AB8CF8A31603A8358B317'
      },
      [pscustomobject]@{
        relative_path = 'Microsoft.PowerShell.Commands.Management.dll'
        size_bytes = 1124192L
        sha256 =
          '51120F70291FD7CE7FD96076FD043F9BFC8807C7B8590B18EAA7118D38457F60'
      },
      [pscustomobject]@{
        relative_path = 'Microsoft.PowerShell.Commands.Utility.dll'
        size_bytes = 1652576L
        sha256 =
          '34533CC9A47EB3F070ACA476ED77EE68A470F2749B3D1FC027C3FD991EB6EAD5'
      },
      [pscustomobject]@{
        relative_path = 'Microsoft.Management.Infrastructure.CimCmdlets.dll'
        size_bytes = 493368L
        sha256 =
          '7CE68B9940FD22D785C9AA702903063CB135BAD3AB56B53590B603C72AB9BF94'
      },
      [pscustomobject]@{
        relative_path = 'microsoft.management.infrastructure.dll'
        size_bytes = 309112L
        sha256 =
          'E997C2216F1D72CB1B483A812F80BE940A4D9643E3F6F8EA1258632EE5E1EC1C'
      },
      [pscustomobject]@{
        relative_path = 'microsoft.management.infrastructure.native.dll'
        size_bytes = 362320L
        sha256 =
          '3C86966B8C64ECE8E45C2CC87DAF528AE3651EE101EB08E42B98460CBCF995D9'
      },
      [pscustomobject]@{
        relative_path =
          'microsoft.management.infrastructure.native.unmanaged.dll'
        size_bytes = 28192L
        sha256 =
          '9BEE4E35576355156F00E2E47EF57AA2C8CA64390C112F083A772F2219026293'
      },
      [pscustomobject]@{
        relative_path =
          'Modules\Microsoft.PowerShell.Management\Microsoft.PowerShell.Management.psd1'
        size_bytes = 16100L
        sha256 =
          '9AF88C06CDC43CFB8DFFA2A07A40A92A7A2EEC015067DB0B37461614A73B74E1'
      },
      [pscustomobject]@{
        relative_path =
          'Modules\Microsoft.PowerShell.Utility\Microsoft.PowerShell.Utility.psd1'
        size_bytes = 16874L
        sha256 =
          '7C7A4982CA9C2FFD7FA5FF4ED5E65136A3B967988F9325A6F4DEFC02F887534F'
      },
      [pscustomobject]@{
        relative_path = 'Modules\CimCmdlets\CimCmdlets.psd1'
        size_bytes = 15295L
        sha256 =
          '35F52D09846EC3088DC1B4B976B62EA4209865A84E1DA47A3CD9637FFEB9BF7D'
      })) {
    $path = [IO.Path]::GetFullPath(
      [IO.Path]::Combine($runtimeRoot, [string]$record.relative_path))
    if (-not $path.StartsWith(
        $runtimeRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase) -or
        $trustedRuntimeFiles.ContainsKey($path)) {
      throw 'V5 trusted runtime file allowlist escaped or duplicated.'
    }
    $trustedRuntimeFiles.Add($path, $record)
  }
  if ($trustedRuntimeFiles.Count -ne 11) {
    throw 'V5 trusted runtime file allowlist is not exact.'
  }

  $cursor = [IO.DirectoryInfo]::new($runtimeRoot)
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw 'V5 trusted runtime has a reparse ancestor.'
    }
    $cursor = $cursor.Parent
  }
  $runtimeFileLeases = [Collections.Generic.List[IO.FileStream]]::new()
  try {
    foreach ($path in $trustedRuntimeFiles.Keys) {
      $fileCursor = [IO.DirectoryInfo]::new([IO.Path]::GetDirectoryName($path))
      while ($null -ne $fileCursor -and $fileCursor.FullName.StartsWith(
          $runtimeRoot, [StringComparison]::OrdinalIgnoreCase)) {
        if (($fileCursor.Attributes -band
            [IO.FileAttributes]::ReparsePoint) -ne 0) {
          throw 'V5 trusted runtime file has a reparse ancestor.'
        }
        $fileCursor = $fileCursor.Parent
      }
      $file = [IO.FileInfo]::new($path)
      if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'V5 trusted runtime file is a reparse point.'
      }
      $stream = $null
      $algorithm = $null
      try {
        $stream = [IO.File]::Open(
          $path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
          [IO.FileShare]::Read)
        $algorithm = [Security.Cryptography.SHA256]::Create()
        $digest = [Convert]::ToHexString($algorithm.ComputeHash($stream))
        $spec = $trustedRuntimeFiles[$path]
        if ($stream.Length -ne [long]$spec.size_bytes -or
            $digest -cne [string]$spec.sha256) {
          throw 'V5 trusted runtime file identity changed.'
        }
        $runtimeFileLeases.Add($stream)
        $stream = $null
      } finally {
        if ($null -ne $algorithm) { $algorithm.Dispose() }
        if ($null -ne $stream) { $stream.Dispose() }
      }
    }
  } catch {
    foreach ($lease in $runtimeFileLeases) { $lease.Dispose() }
    throw
  }
  if ($runtimeFileLeases.Count -ne 11) {
    foreach ($lease in $runtimeFileLeases) { $lease.Dispose() }
    $runtimeFileLeases.Clear()
    throw 'V5 bootstrap did not retain all eleven runtime file leases.'
  }
  $leaseSets = [AppDomain]::CurrentDomain.GetData(
    'wlv.issue13.v5.powershell.runtime.leases')
  if ($leaseSets -isnot [Collections.Generic.List[object]]) {
    $leaseSets = [Collections.Generic.List[object]]::new()
  }
  $leaseSets.Add($runtimeFileLeases)
  [AppDomain]::CurrentDomain.SetData(
    'wlv.issue13.v5.powershell.runtime.leases', $leaseSets)

  [Environment]::SetEnvironmentVariable(
    'PSModulePath', $moduleRoot, [EnvironmentVariableTarget]::Process)
  $global:PSModuleAutoLoadingPreference = 'None'

  $trustedCmdletAssemblies =
    [Collections.Generic.Dictionary[string, object]]::new(
      [StringComparer]::OrdinalIgnoreCase)
  $trustedCmdletAssemblies.Add(
    [IO.Path]::Combine($runtimeRoot, 'System.Management.Automation.dll'),
    [pscustomobject]@{
      full_name =
        'System.Management.Automation, Version=7.6.0.500, Culture=neutral, PublicKeyToken=31bf3856ad364e35'
      module_version_id = '7071448b-dbd2-48c8-9dff-f288a19a62d2'
    })
  $trustedCmdletAssemblies.Add(
    [IO.Path]::Combine(
      $runtimeRoot, 'Microsoft.PowerShell.Commands.Management.dll'),
    [pscustomobject]@{
      full_name =
        'Microsoft.PowerShell.Commands.Management, Version=7.6.0.500, Culture=neutral, PublicKeyToken=31bf3856ad364e35'
      module_version_id = '4c155aeb-1e5e-4023-8c7f-214e199b9530'
    })
  $trustedCmdletAssemblies.Add(
    [IO.Path]::Combine(
      $runtimeRoot, 'Microsoft.PowerShell.Commands.Utility.dll'),
    [pscustomobject]@{
      full_name =
        'Microsoft.PowerShell.Commands.Utility, Version=7.6.0.500, Culture=neutral, PublicKeyToken=31bf3856ad364e35'
      module_version_id = '99be7828-14d8-415d-ae6e-3f0185e7ef9f'
    })
  $trustedCmdletAssemblies.Add(
    [IO.Path]::Combine(
      $runtimeRoot, 'Microsoft.Management.Infrastructure.CimCmdlets.dll'),
    [pscustomobject]@{
      full_name =
        'Microsoft.Management.Infrastructure.CimCmdlets, Version=7.6.0.500, Culture=neutral, PublicKeyToken=31bf3856ad364e35'
      module_version_id = '3af4a3ba-947a-4e39-9400-da8fae0c56de'
    })
  if ($trustedCmdletAssemblies.Count -ne 4) {
    throw 'V5 trusted cmdlet assembly allowlist is not exact.'
  }

  $importModuleCandidates = [object[]](
    $ExecutionContext.InvokeCommand.GetCommands(
      'Import-Module', [Management.Automation.CommandTypes]::Cmdlet, $true))
  if ($importModuleCandidates.Count -ne 1) {
    throw 'V5 bootstrap Import-Module cmdlet is not singular.'
  }
  $importModuleCmdlet = $importModuleCandidates[0]
  $importAssembly = $importModuleCmdlet.ImplementingType.Assembly
  $importAssemblyPath = [IO.Path]::GetFullPath(
    [string]$importAssembly.Location)
  $importAssemblySpec = $trustedCmdletAssemblies[$importAssemblyPath]
  if ([string]$importModuleCmdlet.CommandType -cne 'Cmdlet' -or
      [string]$importModuleCmdlet.ModuleName -cne 'Microsoft.PowerShell.Core' -or
      [string]$importModuleCmdlet.Source -cne 'Microsoft.PowerShell.Core' -or
      [string]$importModuleCmdlet.ImplementingType.FullName -cne
        'Microsoft.PowerShell.Commands.ImportModuleCommand' -or
      $importAssemblyPath -cne
        [IO.Path]::Combine($runtimeRoot, 'System.Management.Automation.dll') -or
      [string]$importAssembly.FullName -cne [string]$importAssemblySpec.full_name -or
      $importAssembly.ManifestModule.ModuleVersionId.ToString('D') -cne
        [string]$importAssemblySpec.module_version_id) {
    throw 'V5 bootstrap Import-Module cmdlet identity changed.'
  }
  foreach ($kind in [Management.Automation.CommandTypes[]]@(
      [Management.Automation.CommandTypes]::Alias,
      [Management.Automation.CommandTypes]::Function,
      [Management.Automation.CommandTypes]::Filter,
      [Management.Automation.CommandTypes]::Application,
      [Management.Automation.CommandTypes]::ExternalScript)) {
    if (([object[]]($ExecutionContext.InvokeCommand.GetCommands(
        'Import-Module', $kind, $true))).Count -ne 0) {
      throw 'V5 bootstrap Import-Module has a competing command.'
    }
  }
  foreach ($manifest in [string[]]@(
      [IO.Path]::Combine(
        $moduleRoot,
        'Microsoft.PowerShell.Management\Microsoft.PowerShell.Management.psd1'),
      [IO.Path]::Combine(
        $moduleRoot,
        'Microsoft.PowerShell.Utility\Microsoft.PowerShell.Utility.psd1'),
      [IO.Path]::Combine($moduleRoot, 'CimCmdlets\CimCmdlets.psd1'))) {
    $null = & $importModuleCmdlet -Name $manifest -Global -Force -ErrorAction Stop
  }
  $global:PSModuleAutoLoadingPreference = 'None'

  $cmdletGroups =
    [Collections.Generic.Dictionary[string, object]]::new(
      [StringComparer]::Ordinal)
  $cmdletGroups.Add('core', [pscustomobject]@{
      module_name = 'Microsoft.PowerShell.Core'
      source = 'Microsoft.PowerShell.Core'
      module_path = ''
      version = '7.6.0.500'
      module_guid = ''
      assembly_path =
        [IO.Path]::Combine($runtimeRoot, 'System.Management.Automation.dll')
      commands = [string[]]@(
        'ForEach-Object', 'Out-Null', 'Set-StrictMode', 'Where-Object')
    })
  $cmdletGroups.Add('management', [pscustomobject]@{
      module_name = 'Microsoft.PowerShell.Management'
      source = 'Microsoft.PowerShell.Management'
      module_path = [IO.Path]::Combine(
        $moduleRoot,
        'Microsoft.PowerShell.Management\Microsoft.PowerShell.Management.psd1')
      version = '7.0.0.0'
      module_guid = 'eefcb906-b326-4e99-9f54-8b4bb6ef3c6d'
      assembly_path = [IO.Path]::Combine(
        $runtimeRoot, 'Microsoft.PowerShell.Commands.Management.dll')
      commands = [string[]]@(
        'Copy-Item', 'Get-ChildItem', 'Get-Content', 'Get-Item',
        'Get-Location', 'Get-Process', 'Join-Path', 'Move-Item', 'New-Item',
        'Remove-Item', 'Resolve-Path', 'Set-Content', 'Set-Item',
        'Set-Location', 'Split-Path', 'Start-Process', 'Stop-Process',
        'Test-Path')
    })
  $cmdletGroups.Add('utility', [pscustomobject]@{
      module_name = 'Microsoft.PowerShell.Utility'
      source = 'Microsoft.PowerShell.Utility'
      module_path = [IO.Path]::Combine(
        $moduleRoot,
        'Microsoft.PowerShell.Utility\Microsoft.PowerShell.Utility.psd1')
      version = '7.0.0.0'
      module_guid = '1da87e53-152b-403e-98dc-74d7b4d63d59'
      assembly_path = [IO.Path]::Combine(
        $runtimeRoot, 'Microsoft.PowerShell.Commands.Utility.dll')
      commands = [string[]]@(
        'Add-Member', 'Add-Type', 'Compare-Object', 'ConvertFrom-Json',
        'ConvertTo-Json', 'Format-List', 'Get-FileHash', 'Get-Variable',
        'Group-Object', 'Import-Csv', 'Invoke-Expression', 'Measure-Object',
        'New-Object', 'New-Variable', 'Select-Object', 'Set-Variable',
        'Sort-Object', 'Start-Sleep', 'Test-Json', 'Write-Error',
        'Write-Output')
    })
  $cmdletGroups.Add('cim', [pscustomobject]@{
      module_name = 'CimCmdlets'
      source = 'CimCmdlets'
      module_path = [IO.Path]::Combine(
        $runtimeRoot, 'Microsoft.Management.Infrastructure.CimCmdlets.dll')
      version = '7.0.0.0'
      module_guid = 'fb6cc51d-c096-4b38-b78d-0fed6277096a'
      assembly_path = [IO.Path]::Combine(
        $runtimeRoot, 'Microsoft.Management.Infrastructure.CimCmdlets.dll')
      commands = [string[]]@('Get-CimInstance')
    })

  $trustedCmdlets =
    [Collections.Generic.Dictionary[string, object]]::new(
      [StringComparer]::OrdinalIgnoreCase)
  foreach ($group in $cmdletGroups.Values) {
    foreach ($commandName in $group.commands) {
      if ($trustedCmdlets.ContainsKey($commandName)) {
        throw 'V5 trusted cmdlet allowlist contains a duplicate.'
      }
      $trustedCmdlets.Add($commandName, $group)
    }
  }
  if ($cmdletGroups.Count -ne 4 -or $trustedCmdlets.Count -ne 44) {
    throw 'V5 trusted cmdlet allowlist is not exact.'
  }

  $resolvedTrustedCmdlets =
    [Collections.Generic.Dictionary[string, object]]::new(
      [StringComparer]::OrdinalIgnoreCase)
  foreach ($commandName in $trustedCmdlets.Keys) {
    $candidates = [object[]](
      $ExecutionContext.InvokeCommand.GetCommands(
        $commandName, [Management.Automation.CommandTypes]::Cmdlet, $true))
    if ($candidates.Count -ne 1) {
      throw "V5 trusted cmdlet is not singular: $commandName"
    }
    $cmdlet = $candidates[0]
    $group = $trustedCmdlets[$commandName]
    $modulePath = if ($null -eq $cmdlet.Module) { '' } else {
      [IO.Path]::GetFullPath([string]$cmdlet.Module.Path)
    }
    $moduleGuid = if ($null -eq $cmdlet.Module) { '' } else {
      $cmdlet.Module.Guid.ToString('D')
    }
    $assembly = $cmdlet.ImplementingType.Assembly
    $assemblyPath = [IO.Path]::GetFullPath([string]$assembly.Location)
    $assemblySpec = if ($trustedCmdletAssemblies.ContainsKey($assemblyPath)) {
      $trustedCmdletAssemblies[$assemblyPath]
    } else { $null }
    $attributes = [object[]]$cmdlet.ImplementingType.GetCustomAttributes(
      [Management.Automation.CmdletAttribute], $false)
    $declaredName = if ($attributes.Count -eq 1) {
      [string]$attributes[0].VerbName + '-' + [string]$attributes[0].NounName
    } else { '' }
    if ([string]$cmdlet.CommandType -cne 'Cmdlet' -or
        [string]$cmdlet.Name -cne $commandName -or
        [string]$cmdlet.ModuleName -cne [string]$group.module_name -or
        [string]$cmdlet.Source -cne [string]$group.source -or
        -not [string]::Equals(
          $modulePath, [string]$group.module_path,
          [StringComparison]::OrdinalIgnoreCase) -or
        [string]$cmdlet.Version -cne [string]$group.version -or
        $moduleGuid -cne [string]$group.module_guid -or
        -not [string]::Equals(
          $assemblyPath, [string]$group.assembly_path,
          [StringComparison]::OrdinalIgnoreCase) -or
        $null -eq $assemblySpec -or
        [string]$assembly.FullName -cne [string]$assemblySpec.full_name -or
        $assembly.ManifestModule.ModuleVersionId.ToString('D') -cne
          [string]$assemblySpec.module_version_id -or
        $declaredName -cne $commandName) {
      throw "V5 trusted cmdlet identity changed: $commandName"
    }
    $resolvedTrustedCmdlets.Add($commandName, $cmdlet)
  }

  $names = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  $collisions = [Collections.Generic.List[string]]::new()
  $commandAsts = [object[]]$Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst]
    }, $true)
  foreach ($commandAst in $commandAsts) {
    $name = $commandAst.GetCommandName()
    if ([string]::IsNullOrWhiteSpace($name) -or -not $names.Add($name)) {
      continue
    }
    foreach ($kind in [Management.Automation.CommandTypes[]]@(
        [Management.Automation.CommandTypes]::Alias,
        [Management.Automation.CommandTypes]::Function,
        [Management.Automation.CommandTypes]::Filter,
        [Management.Automation.CommandTypes]::Application,
        [Management.Automation.CommandTypes]::ExternalScript)) {
      foreach ($collision in [object[]](
          $ExecutionContext.InvokeCommand.GetCommands($name, $kind, $true))) {
        $collisions.Add(([string]$kind + ':' + $name))
      }
    }
    $cmdlets = [object[]](
      $ExecutionContext.InvokeCommand.GetCommands(
        $name, [Management.Automation.CommandTypes]::Cmdlet, $true))
    if ($trustedCmdlets.ContainsKey($name)) {
      if ($cmdlets.Count -ne 1 -or
          $cmdlets[0].ImplementingType -ne
            $resolvedTrustedCmdlets[$name].ImplementingType) {
        $collisions.Add('Cmdlet:' + $name)
      }
    } elseif ($cmdlets.Count -ne 0) {
      $collisions.Add('Cmdlet:' + $name)
    }
  }
  if ($collisions.Count -ne 0) {
    throw ('V5 command collision bootstrap rejected inherited commands: ' +
      [string]::Join(', ', [string[]]$collisions.ToArray()))
  }
  if ([string][Environment]::GetEnvironmentVariable(
      'PSModulePath', [EnvironmentVariableTarget]::Process) -cne $moduleRoot -or
      [string]$global:PSModuleAutoLoadingPreference -cne 'None') {
    throw 'V5 command bootstrap did not retain its closed module resolver.'
  }
}
& $issue13V5CommandCollisionGuard $MyInvocation.MyCommand.ScriptBlock.Ast

. ([IO.Path]::Combine($PSScriptRoot, 'issue13-v5-coordinator-lib.ps1'))
$null = Assert-Issue13V5CurrentPwshHost

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$baselineBaseCommit = "cc2c86189a06676bcb9f0e05e08033d710a92509"
$baselineBaseTree = "0cb1142cdadd74bf95272010f5393ebe2af79f47"
$baselineRuntimeCommit = "e2f4d6dae9a6d35c966b305fabac52e489faa3e7"
$baselineRuntimeTree = "7da19c4f2913e857040ba228280f404b0e54eaab"
$methods = @(
    "wiodr13", "wiodr16", "alternative_1", "alternative_2",
    "norow_w13", "ochoa_1", "ochoa_2", "petrovic", "wiodr13v09",
    "wiodr16v09", "zerodep_1", "zerodep_2"
)
$runtimeMethods = @(
    "alternative_1", "alternative_2", "norow_w13", "ochoa_1",
    "ochoa_2", "petrovic", "wiodr13v09"
)
$stages = @(1, 4, 5)
$bridgeColumns = @(
    "method", "candidate_project_root", "candidate_run_root",
    "baseline_project_root", "baseline_run_root"
)
$stageColumns = @(
    "method", "candidate_reference_project_root",
    "candidate_reference_run_root", "baseline_reference_project_root",
    "baseline_reference_run_root", "baseline_target_project_root",
    "baseline_target_parent_run_root", "baseline_target_run_root"
)

function Resolve-ExistingDirectory([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Label does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Resolve-ExistingFile([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Resolve-PhysicalExistingDirectory([string]$Path, [string]$Label) {
    $resolved = Resolve-ExistingDirectory $Path $Label
    $null = ConvertTo-Issue13V5PhysicalPath $resolved $Label
    Assert-Issue13V5NoReparseAncestors $resolved $Label
    return $resolved.TrimEnd('\')
}

function Resolve-PhysicalExistingFile([string]$Path, [string]$Label) {
    $resolved = Resolve-ExistingFile $Path $Label
    $null = ConvertTo-Issue13V5PhysicalPath $resolved $Label
    Assert-Issue13V5NoReparseAncestors $resolved $Label
    return $resolved
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path `
        -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TextSha256([string]$Value) {
    $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString(
            $algorithm.ComputeHash($utf8Bytes)
        ) -replace '-', '').ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

function Get-DirectoryInventorySha256([string]$Root) {
    $resolved = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
    $items = @(Get-ChildItem -LiteralPath $resolved -Recurse -Force)
    if (@($items | Where-Object {
        ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    }).Count -ne 0) {
        throw "Source inventory contains a reparse point."
    }
    $records = @($items | Where-Object { -not $_.PSIsContainer } |
        ForEach-Object {
            $relative = $_.FullName.Substring($resolved.Length).TrimStart('\')
            $relative = $relative.Replace('\', '/')
            $hash = Get-Sha256 $_.FullName
            $relative + "|" + $_.Length + "|" + $hash
        })
    [System.Array]::Sort($records, [System.StringComparer]::Ordinal)
    $recordText = $records -join "`n"
    return (Get-TextSha256 $recordText)
}

function Invoke-SealedRscript(
    [string[]]$Arguments,
    [int]$TimeoutSeconds,
    [string]$WorkingDirectory
) {
    $environment = New-Issue13V5ClosedREnvironment $script:rLibrary
    $result = Invoke-Issue13V5RscriptBounded `
        -RscriptPath $script:rscriptPath `
        -Arguments $Arguments `
        -Label "Stage 5 capture sealed Rscript" `
        -TimeoutSeconds $TimeoutSeconds `
        -ExpectedExitCodes $null `
        -WorkingDirectory $WorkingDirectory `
        -Environment $environment
    $script:rscriptExitCode = [int]$result.exit_code
    return [object[]]$result.combined_lines
}

function Assert-GitValue(
    [string]$Worktree,
    [string]$Arguments,
    [string]$Expected,
    [string]$Label
) {
    [string[]]$gitArguments = @('-C', $Worktree) +
        [string[]]$Arguments.Split(' ')
    $actual = (Invoke-Issue13V5SealedGit @gitArguments) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $actual -cne $Expected) {
        throw "$Label mismatch. Expected $Expected; observed $actual."
    }
}

function Assert-CleanWorktree(
    [string]$Worktree,
    [string]$Commit,
    [string]$Tree,
    [string]$Label
) {
    $status = @(Invoke-Issue13V5SealedGit `
      -C $Worktree status --porcelain=v1 `
        --untracked-files=no)
    if ($LASTEXITCODE -ne 0 -or $status.Count -ne 0) {
        throw "$Label is not clean."
    }
    Assert-GitValue $Worktree "rev-parse HEAD" $Commit "$Label commit"
    Assert-GitValue $Worktree "rev-parse HEAD^{tree}" $Tree "$Label tree"
}

function Convert-EvidenceRecord([string]$Line) {
    $parts = @($Line.Split(';'))
    if ($parts.Count -lt 2 -or $parts[0] -cne "evidence_record") {
        throw "Invalid diagnostic evidence record."
    }
    $result = @{}
    for ($index = 1; $index -lt $parts.Count; $index++) {
        $pair = @($parts[$index].Split(@('='), 2))
        if ($pair.Count -ne 2 -or -not $pair[0] -or
            $result.ContainsKey($pair[0])) {
            throw "Invalid or duplicate diagnostic evidence field."
        }
        $result[$pair[0]] = $pair[1]
    }
    return $result
}

function Get-CaptureValue(
    [string[]]$Lines,
    [string]$Key
) {
    $matches = @($Lines | Where-Object {
        $_ -clike ($Key + "=*")
    })
    if ($matches.Count -ne 1) {
        throw "Capture record lacks singular field $Key."
    }
    return $matches[0].Substring($Key.Length + 1)
}

function Invoke-EvidenceVerifier(
    [string]$ProjectRoot,
    [string]$RunRoot,
    [string]$Method,
    [string]$Mode = "calculate",
    [string]$ParentRunId = "-",
    [string]$Stage = "-",
    [string]$LogPath
) {
    $arguments = @(
        "--vanilla", $script:verifier, $script:harness,
        $script:controllerDir, $ProjectRoot, $RunRoot, $Method, $Mode,
        $ParentRunId, $Stage
    )
    $output = @(Invoke-SealedRscript $arguments 600 $ProjectRoot)
    $output | Set-Content -LiteralPath $LogPath -Encoding utf8
    $records = @($output | Where-Object { $_ -cmatch '^evidence_record;' })
    if ($script:rscriptExitCode -ne 0 -or $records.Count -ne 1) {
        throw "Evidence verification failed for $Method/$Mode. See $LogPath"
    }
    return [pscustomobject]@{
        Line = [string]$records[0]
        Fields = Convert-EvidenceRecord ([string]$records[0])
        LogSha256 = Get-Sha256 $LogPath
    }
}

function Quote-Csv([string]$Value) {
    return '"' + $Value.Replace('"', '""') + '"'
}

function Assert-Within(
    [string]$Path,
    [string]$Root,
    [string]$Label
) {
    if (-not (Test-Issue13V5PathContained $Path $Root)) {
        throw "$Label escapes its expected root."
    }
}

function Copy-HardLinkedTree(
    [string]$Source,
    [string]$Destination,
    [string]$AllowedSourceRoot,
    [string]$AllowedDestinationRoot
) {
    $sourceFull = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
    $destinationFull = [System.IO.Path]::GetFullPath($Destination).TrimEnd('\')
    Assert-Within $sourceFull $AllowedSourceRoot "Hard-link source"
    Assert-Within $destinationFull $AllowedDestinationRoot `
        "Hard-link destination"
    if ((Split-Path -Qualifier $sourceFull) -cne
        (Split-Path -Qualifier $destinationFull)) {
        throw "Hard-link evidence clone must remain on one volume."
    }
    if (Test-Path -LiteralPath $destinationFull) {
        throw "Hard-link evidence destination already exists."
    }
    $items = @(Get-ChildItem -LiteralPath $sourceFull -Recurse -Force)
    if (@($items | Where-Object {
        ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    }).Count -ne 0) {
        throw "Evidence parent contains a reparse point."
    }
    New-Item -ItemType Directory -Path $destinationFull | Out-Null
    $directories = @($items | Where-Object { $_.PSIsContainer } |
        Sort-Object { $_.FullName.Length })
    foreach ($directory in $directories) {
        $relative = $directory.FullName.Substring($sourceFull.Length).TrimStart('\')
        New-Item -ItemType Directory -Path (Join-Path $destinationFull `
            $relative) | Out-Null
    }
    foreach ($file in @($items | Where-Object { -not $_.PSIsContainer })) {
        $relative = $file.FullName.Substring($sourceFull.Length).TrimStart('\')
        $target = Join-Path $destinationFull $relative
        New-Item -ItemType HardLink -Path $target `
            -Target $file.FullName | Out-Null
    }
}

function Get-SealedBridgeValue(
    [object[]]$Rows,
    [string]$Column,
    [string]$Label
) {
    $values = @($Rows | ForEach-Object { [string]$_.$Column } |
        Sort-Object -Unique)
    if ($values.Count -ne 1 -or -not $values[0]) {
        throw "$Label lacks a singular sealed $Column."
    }
    return $values[0]
}

$repository = Resolve-PhysicalExistingDirectory $RepositoryRoot "Repository root"
$sourceData = Resolve-PhysicalExistingDirectory $BaselineSourceDataRoot `
    "Source-data root"
$bridgeCapture = Resolve-PhysicalExistingDirectory $BridgeCaptureRoot `
    "Bridge capture root"
$script:harness = Resolve-PhysicalExistingDirectory `
    $HarnessDir "Harness directory"
$harnessRuntime = Resolve-PhysicalExistingDirectory `
    (Split-Path -Parent $script:harness) "Harness runtime"
$rscriptBinding = Get-Issue13V5RscriptExecutableBinding $RscriptCommand
$script:rscriptPath = Resolve-PhysicalExistingFile $rscriptBinding.logical_path `
    "Rscript executable"
$systemDirectory = Resolve-PhysicalExistingDirectory `
    ([Environment]::SystemDirectory) "Windows system directory"
$fsutilPath = Resolve-PhysicalExistingFile `
    (Join-Path $systemDirectory "fsutil.exe") "fsutil executable"
$script:rLibrary = Resolve-PhysicalExistingDirectory $RLibrary `
    "R library"
$rscriptSha256 = Get-Sha256 $script:rscriptPath
$fsutilSha256 = Get-Sha256 $fsutilPath
$harnessInventoryBefore = Get-DirectoryInventorySha256 $script:harness
$harnessRuntimeInventoryBefore = `
    Get-DirectoryInventorySha256 $harnessRuntime
$rLibraryInventoryBefore = Get-DirectoryInventorySha256 $script:rLibrary
$officialSourceInventoryBefore =
    Assert-Issue13V5OfficialSourceDataInventory $sourceData
$sourceDataOriginInventoryBefore =
    [string]$officialSourceInventoryBefore.ordinal_inventory_sha256
$bridgeManifestPath = Resolve-PhysicalExistingFile `
    $BridgeManifest "Bridge manifest"
$script:controllerDir = Resolve-PhysicalExistingDirectory `
    $PSScriptRoot "Controller directory"
$script:verifier = Resolve-PhysicalExistingFile (Join-Path $script:controllerDir `
    "issue13-v5-verify-diagnostic-evidence.R") "Evidence verifier"
$launcher = Resolve-PhysicalExistingFile (Join-Path $script:controllerDir `
    "issue13-v5-run-stage5-evidence.R") "Stage-five launcher"
$recipePaths = @{
    bridge_capture_script = Resolve-PhysicalExistingFile (Join-Path `
        $script:controllerDir "issue13-v5-capture-clean-bridge-evidence.ps1") `
        "Bridge capture recipe"
    bridge_builder = Resolve-PhysicalExistingFile (Join-Path $script:controllerDir `
        "issue13-v5-build-diagnostic-bridges.R") "Bridge builder recipe"
    coordinator_library = Resolve-PhysicalExistingFile (Join-Path `
        $script:controllerDir "issue13-v5-coordinator-lib.ps1") `
        "Coordinator physical-snapshot library"
    stage5_capture_script = Resolve-PhysicalExistingFile `
        $MyInvocation.MyCommand.Path "Stage-five capture recipe"
    stage5_builder = Resolve-PhysicalExistingFile (Join-Path $script:controllerDir `
        "issue13-v5-build-stage5-profiles.R") "Stage-five builder recipe"
    verifier = $script:verifier
    launcher = $launcher
    diagnostics_override = Resolve-PhysicalExistingFile (Join-Path `
        $script:controllerDir "issue13-v5-diagnostics-override.R") `
        "Diagnostic runtime override"
    compare_override = Resolve-PhysicalExistingFile (Join-Path `
        $script:controllerDir "issue13-v5-compare-override.R") `
        "Comparison runtime override"
    metadata_equivalence = Resolve-PhysicalExistingFile (Join-Path `
        $script:controllerDir "issue13-v5-metadata-equivalence.json") `
        "Metadata equivalence manifest"
}
$recipeRecordsBefore = @($recipePaths.Keys | Sort-Object | ForEach-Object {
    "recipe_record;name=$_;sha256=$(Get-Sha256 $recipePaths[$_])"
})
$bridgeIndexPath = Resolve-PhysicalExistingFile (Join-Path $bridgeCapture `
    "diagnostic-bridge-evidence.csv") "Bridge evidence index"
$bridgeRecordPath = Resolve-PhysicalExistingFile (Join-Path $bridgeCapture `
    "capture-record.txt") "Bridge capture record"
$bridgeRecordLines = @([System.IO.File]::ReadAllLines(
    $bridgeRecordPath, [System.Text.Encoding]::UTF8
))
$bridgeSourceOriginPath = Get-CaptureValue $bridgeRecordLines "source_data_origin_path"
$bridgeSourceSnapshotPath = Resolve-PhysicalExistingDirectory (
    Get-CaptureValue $bridgeRecordLines "source_data_snapshot_path"
) "Bridge source-data snapshot"
$bridgeSourceSnapshotInventoryBefore =
    Get-DirectoryInventorySha256 $bridgeSourceSnapshotPath
$bridgeSourcePhysicalBefore = Get-Issue13V5PhysicalSnapshotProof `
    $sourceData $bridgeSourceSnapshotPath "Bridge source-data snapshot"
if ($bridgeRecordLines[0] -cne "schema=issue13-v5-clean-bridge-capture/2" -or
    (Get-CaptureValue $bridgeRecordLines "verified_records") -cne "7" -or
    (Get-CaptureValue $bridgeRecordLines "tool_records") -cne "7" -or
    (Get-CaptureValue $bridgeRecordLines "harness_path") -cne
        $script:harness.Replace('\', '/') -or
    (Get-CaptureValue $bridgeRecordLines "harness_inventory_sha256") -cne
        $harnessInventoryBefore -or
    (Get-CaptureValue $bridgeRecordLines "harness_runtime_path") -cne
        $harnessRuntime.Replace('\', '/') -or
    (Get-CaptureValue $bridgeRecordLines `
        "harness_runtime_inventory_before_sha256") -cne
        $harnessRuntimeInventoryBefore -or
    (Get-CaptureValue $bridgeRecordLines `
        "harness_runtime_inventory_after_sha256") -cne
        $harnessRuntimeInventoryBefore -or
    (Get-CaptureValue $bridgeRecordLines "rscript_path") -cne
        $script:rscriptPath.Replace('\', '/') -or
    (Get-CaptureValue $bridgeRecordLines "rscript_sha256") -cne
        $rscriptSha256 -or
    (Get-CaptureValue $bridgeRecordLines "fsutil_path") -cne
        $fsutilPath.Replace('\', '/') -or
    (Get-CaptureValue $bridgeRecordLines "fsutil_sha256") -cne
        $fsutilSha256 -or
    (Get-CaptureValue $bridgeRecordLines "r_library_path") -cne
        $script:rLibrary.Replace('\', '/') -or
    (Get-CaptureValue $bridgeRecordLines `
        "r_library_inventory_before_sha256") -cne
        $rLibraryInventoryBefore -or
    (Get-CaptureValue $bridgeRecordLines `
        "r_library_inventory_after_sha256") -cne
        $rLibraryInventoryBefore -or
    $bridgeSourceOriginPath -cne $sourceData.Replace('\', '/') -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_snapshot_path") -cne
        $bridgeSourceSnapshotPath.Replace('\', '/') -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_origin_inventory_before_sha256") -cne
        $sourceDataOriginInventoryBefore -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_origin_inventory_after_sha256") -cne
        $sourceDataOriginInventoryBefore -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_snapshot_inventory_before_sha256") -cne
        $bridgeSourceSnapshotInventoryBefore -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_snapshot_inventory_after_sha256") -cne
        $bridgeSourceSnapshotInventoryBefore -or
    $bridgeSourceSnapshotInventoryBefore -cne
        $sourceDataOriginInventoryBefore -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_origin_physical_path") -cne
        ([string]$bridgeSourcePhysicalBefore.source_physical_path).
            Replace('\', '/') -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_snapshot_physical_path") -cne
        ([string]$bridgeSourcePhysicalBefore.snapshot_physical_path).
            Replace('\', '/') -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_physical_file_count") -cne "84" -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_physical_directory_count") -cne "5" -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_origin_physical_before_sha256") -cne
        [string]$bridgeSourcePhysicalBefore.source_physical_inventory_sha256 -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_origin_physical_after_sha256") -cne
        [string]$bridgeSourcePhysicalBefore.source_physical_inventory_sha256 -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_snapshot_physical_before_sha256") -cne
        [string]$bridgeSourcePhysicalBefore.snapshot_physical_inventory_sha256 -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_snapshot_physical_after_sha256") -cne
        [string]$bridgeSourcePhysicalBefore.snapshot_physical_inventory_sha256 -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_independence_before_sha256") -cne
        [string]$bridgeSourcePhysicalBefore.independence_sha256 -or
    (Get-CaptureValue $bridgeRecordLines `
        "source_data_independence_after_sha256") -cne
        [string]$bridgeSourcePhysicalBefore.independence_sha256 -or
    (Get-CaptureValue $bridgeRecordLines "evidence_index_sha256") -cne
        (Get-Sha256 $bridgeIndexPath)) {
    throw "Bridge capture record is not bound to its evidence index."
}
$bridgeToolRecords = @($bridgeRecordLines | Where-Object {
    $_ -cmatch '^tool_record;'
})
$bridgeToolNames = @(
    "bridge_builder", "bridge_capture_script", "compare_override",
    "coordinator_library", "diagnostics_override", "metadata_equivalence",
    "verifier"
)
$expectedBridgeToolRecords = @($bridgeToolNames | ForEach-Object {
    "tool_record;name=$_;sha256=$(Get-Sha256 $recipePaths[$_])"
})
if (($bridgeToolRecords -join "`n") -cne
    ($expectedBridgeToolRecords -join "`n")) {
    throw "Bridge capture tooling differs from its recorded bytes."
}
$bridgeCaptureRecords = @($bridgeRecordLines | Where-Object {
    $_ -cmatch '^evidence_record;'
})
if ($bridgeCaptureRecords.Count -ne 7) {
    throw "Bridge capture record lacks the exact seven run records."
}
if (Test-Path -LiteralPath $Stage5CaptureRoot) {
    throw "Stage5CaptureRoot is write-once and must not already exist."
}
$captureParent = Split-Path -Parent $Stage5CaptureRoot
$captureParent = Resolve-PhysicalExistingDirectory `
    $captureParent "Stage5CaptureRoot parent"
$capture = [System.IO.Path]::GetFullPath($Stage5CaptureRoot)
$capturePhysicalExpected = ConvertTo-Issue13V5PhysicalPath `
    $capture "Stage5CaptureRoot"
Assert-Issue13V5NoReparseAncestors $capture "Stage5CaptureRoot"
foreach ($protectedRoot in @(
    $repository, $sourceData, $bridgeCapture, $harnessRuntime,
    $script:rLibrary
)) {
    Assert-Issue13V5PathsDisjoint `
        $capture $protectedRoot "Stage5CaptureRoot/protected-root isolation"
}
$logsRoot = Join-Path $capture "logs"
$worktreesRoot = Join-Path $capture "worktrees"
$stageIndexPath = Join-Path $capture "stage5-evidence-index.csv"
New-Item -ItemType Directory -Path $capture | Out-Null
New-Item -ItemType Directory -Path $logsRoot | Out-Null
New-Item -ItemType Directory -Path $worktreesRoot | Out-Null
$capturePhysicalObserved = ConvertTo-Issue13V5PhysicalPath `
    $capture "Created Stage5CaptureRoot"
Assert-Issue13V5NoReparse $capture
if ($capturePhysicalObserved -cne $capturePhysicalExpected) {
    throw "Stage5CaptureRoot changed physical identity during creation."
}

foreach ($source in @("wiodr13", "wiodr16")) {
    Resolve-ExistingFile (Join-Path $sourceData (
        $source + "\normalized\_source_manifest.csv"
    )) "Normalized $source source manifest" | Out-Null
}
$sourceInventoriesBefore = @{}
foreach ($source in @("wiodr13", "wiodr16")) {
    $sourceInventoriesBefore[$source] = Get-DirectoryInventorySha256 `
        (Join-Path $sourceData ($source + "\normalized"))
    if ((Get-CaptureValue $bridgeRecordLines `
            ("source_" + $source + "_inventory_before_sha256")) -cne
            $sourceInventoriesBefore[$source] -or
        (Get-CaptureValue $bridgeRecordLines `
            ("source_" + $source + "_inventory_after_sha256")) -cne
            $sourceInventoriesBefore[$source]) {
        throw "Bridge and stage-five source inventories differ for $source."
    }
}
Assert-GitValue $repository ("rev-parse " + $baselineBaseCommit +
    "^{tree}") $baselineBaseTree "Baseline base tree"
Assert-GitValue $repository ("rev-parse " + $baselineRuntimeCommit +
    "^{tree}") $baselineRuntimeTree "Baseline runtime tree"
Assert-GitValue $repository ("rev-parse " + $baselineRuntimeCommit +
    "^") $baselineBaseCommit "Baseline runtime parent"

$bridgeIndex = @(Import-Csv -LiteralPath $bridgeIndexPath -Delimiter ';')
if ($bridgeIndex.Count -ne 12 -or
    (@($bridgeIndex[0].PSObject.Properties.Name) -join "|") -cne
        ($bridgeColumns -join "|") -or
    (@($bridgeIndex.method | Sort-Object -Unique) -join "|") -cne
        (@($methods | Sort-Object) -join "|")) {
    throw "Bridge evidence index lacks the exact 12-method schema."
}
$bridgeRows = @(Import-Csv -LiteralPath $bridgeManifestPath -Delimiter ';')
if (-not $bridgeRows.Count) {
    throw "The sealed diagnostic bridge manifest is empty."
}

$referenceRecords = @()
$referenceByMethod = @{}
foreach ($method in $methods) {
    $row = @($bridgeIndex | Where-Object { $_.method -ceq $method })
    if ($row.Count -ne 1) {
        throw "Bridge evidence index lacks one row for $method."
    }
    $logPath = Join-Path $logsRoot ($method + ".reference.verify.log")
    $verified = Invoke-EvidenceVerifier $row[0].baseline_project_root `
        $row[0].baseline_run_root $method "calculate" "-" "-" $logPath
    $referenceByMethod[$method] = $verified
    $expectedCommit = if ($method -cin $runtimeMethods) {
        $baselineRuntimeCommit
    } else {
        $baselineBaseCommit
    }
    $expectedTree = if ($method -cin $runtimeMethods) {
        $baselineRuntimeTree
    } else {
        $baselineBaseTree
    }
    if ($verified.Fields.commit -cne $expectedCommit -or
        $verified.Fields.tree -cne $expectedTree -or
        $verified.Fields.mode -cne "calculate" -or
        $verified.Fields.at_stage -cne "" -or
        $verified.Fields.parent_run_id -cne "") {
        throw "Baseline reference identity is invalid for $method."
    }
    $sealed = @($bridgeRows | Where-Object {
        $_.method -ceq $method -and
        $_.artifact_name -ceq "_anomalies.csv"
    })
    if (-not $sealed.Count) {
        throw "Diagnostic bridges lack anomaly ownership for $method."
    }
    $bindings = @{
        run_id = "evidence_baseline_run_id"
        anomalies_sha256 = "evidence_baseline_artifact_sha256"
        request_sha256 = "evidence_baseline_request_sha256"
        source_sha256 = "evidence_baseline_source_sha256"
        commit = "evidence_baseline_commit"
        tree = "evidence_baseline_tree"
    }
    foreach ($field in $bindings.Keys) {
        $sealedValue = Get-SealedBridgeValue $sealed $bindings[$field] $method
        if ($verified.Fields[$field] -cne $sealedValue) {
            throw "Baseline reference $field differs from bridge for $method."
        }
    }
    if ($method -cin $runtimeMethods) {
        $captured = @($bridgeCaptureRecords | Where-Object {
            (Convert-EvidenceRecord ($_ -replace
                ';verify_log_sha256=[0-9a-f]{64}$', '')).method -ceq $method
        })
        if ($captured.Count -ne 1 -or
            ($captured[0] -replace
                ';verify_log_sha256=[0-9a-f]{64}$', '') -cne
                $verified.Line) {
            throw "Reused calculate parent differs from bridge capture for $method."
        }
    }
    $referenceRecords += (
        $verified.Line.Replace("evidence_record;",
            "evidence_record;role=baseline_reference;") +
        ";verify_log_sha256=" + $verified.LogSha256
    )
}

$commitTrees = @{
    $baselineBaseCommit = $baselineBaseTree
    $baselineRuntimeCommit = $baselineRuntimeTree
}
$worktrees = @{}
$sourceSnapshotsBefore = @{}
foreach ($stage in $stages) {
    foreach ($commit in @($baselineBaseCommit, $baselineRuntimeCommit)) {
        $root = Join-Path $worktreesRoot (
            "stage-" + $stage + "-" + $commit.Substring(0, 12)
        )
        Invoke-Issue13V5SealedGit `
          -C $repository worktree add --detach $root $commit
        if ($LASTEXITCODE -ne 0) {
            throw "Could not create isolated stage-$stage worktree."
        }
        Assert-CleanWorktree $root $commit $commitTrees[$commit] `
            "Fresh stage-$stage worktree"
        $sourceSnapshot = Join-Path $root "source_data"
        if (Test-Path -LiteralPath $sourceSnapshot) {
            throw "Fresh stage-$stage worktree unexpectedly has source_data."
        }
        $sourceSnapshotPhysical =
            Copy-Issue13V5PhysicalDirectorySnapshot `
                $sourceData $sourceSnapshot `
                "Stage-$stage source-data snapshot"
        $sourceSnapshotInventory =
            Get-DirectoryInventorySha256 $sourceSnapshot
        if ($sourceSnapshotInventory -cne
                $sourceDataOriginInventoryBefore -or
            [long]$sourceSnapshotPhysical.file_count -ne 84L -or
            [long]$sourceSnapshotPhysical.directory_count -ne 5L) {
            throw "Stage-$stage source-data snapshot differs from its origin."
        }
        Assert-CleanWorktree $root $commit $commitTrees[$commit] `
            "Stage-$stage worktree after source snapshot"
        $worktreeKey = [string]$stage + "|" + $commit
        $worktrees[$worktreeKey] = $root
        $sourceSnapshotsBefore[$worktreeKey] = [pscustomobject]@{
            path = $sourceSnapshot
            inventory_sha256 = $sourceSnapshotInventory
            physical = $sourceSnapshotPhysical
        }
    }
}

$stageRows = @()
$seedRecords = @()
$targetRecords = @()
foreach ($method in $methods) {
    $bridgeRow = @($bridgeIndex | Where-Object { $_.method -ceq $method })[0]
    $reference = $referenceByMethod[$method]
    $commit = $reference.Fields.commit
    foreach ($stage in $stages) {
        $worktree = $worktrees[([string]$stage + "|" + $commit)]
        Assert-CleanWorktree $worktree $commit $commitTrees[$commit] `
            "Before stage-$stage $method"
        $parentDestination = Join-Path $worktree (
            "results\runs\" + $method + "\" + $reference.Fields.run_id
        )
        Copy-HardLinkedTree $bridgeRow.baseline_run_root `
            $parentDestination $bridgeRow.baseline_project_root $worktree
        $parentVerifyLog = Join-Path $logsRoot (
            $method + ".stage-" + $stage + ".parent.verify.log"
        )
        $cloned = Invoke-EvidenceVerifier $worktree $parentDestination `
            $method "calculate" "-" "-" $parentVerifyLog
        if ($cloned.Line -cne $reference.Line) {
            throw "Cloned parent differs from sealed reference for $method."
        }
        $methodRoot = Split-Path -Parent $parentDestination
        $before = @(Get-ChildItem -LiteralPath $methodRoot -Directory |
            ForEach-Object { $_.FullName })
        $runLog = Join-Path $logsRoot (
            $method + ".stage-" + $stage + ".recalculate.log"
        )
        $channel = "issue13-v5d-stage-" + $stage + "-" +
            $method.Replace("_", "-")
        $runArguments = @(
            "--vanilla", $launcher, $worktree, $method,
            $reference.Fields.run_id, ([string]$stage), $channel
        )
        $runOutput = @(Invoke-SealedRscript $runArguments 18000 $worktree)
        $runOutput | Set-Content -LiteralPath $runLog -Encoding utf8
        if ($script:rscriptExitCode -ne 0) {
            throw "Stage-$stage recalculation failed for $method. See $runLog"
        }
        $aliasRecords = @($runOutput | Where-Object {
            $_ -cmatch '^recalculation_record;'
        })
        if ($aliasRecords.Count -ne 1) {
            throw "Stage-$stage $method lacks one parent alias record."
        }
        $after = @(Get-ChildItem -LiteralPath $methodRoot -Directory |
            ForEach-Object { $_.FullName })
        $created = @($after | Where-Object { $_ -notin $before })
        if ($created.Count -ne 1) {
            throw "Stage-$stage $method did not create exactly one child."
        }
        Assert-CleanWorktree $worktree $commit $commitTrees[$commit] `
            "After stage-$stage $method"
        $verifyLog = Join-Path $logsRoot (
            $method + ".stage-" + $stage + ".target.verify.log"
        )
        $target = Invoke-EvidenceVerifier $worktree $created[0] $method `
            "recalculate" $reference.Fields.run_id ([string]$stage) `
            $verifyLog
        $seedRecords += (
            ([string]$aliasRecords[0]).Replace("recalculation_record;",
                "seed_record;role=parent_alias;channel=$channel;") +
            ";parent_verify_log_sha256=" + $cloned.LogSha256 +
            ";run_log_sha256=" + (Get-Sha256 $runLog)
        )
        $targetRecords += (
            $target.Line.Replace("evidence_record;",
                "evidence_record;role=baseline_target;") +
            ";run_log_sha256=" + (Get-Sha256 $runLog) +
            ";verify_log_sha256=" + $target.LogSha256
        )
        $stageRows += [pscustomobject]@{
            method = $method
            candidate_reference_project_root =
                $bridgeRow.candidate_project_root.Replace('\', '/')
            candidate_reference_run_root =
                $bridgeRow.candidate_run_root.Replace('\', '/')
            baseline_reference_project_root =
                $bridgeRow.baseline_project_root.Replace('\', '/')
            baseline_reference_run_root =
                $bridgeRow.baseline_run_root.Replace('\', '/')
            baseline_target_project_root = $worktree.Replace('\', '/')
            baseline_target_parent_run_root =
                $parentDestination.Replace('\', '/')
            baseline_target_run_root = $created[0].Replace('\', '/')
        }
    }
}
if ($stageRows.Count -ne 36 -or $seedRecords.Count -ne 36 -or
    $targetRecords.Count -ne 36) {
    throw "Stage-five capture lacks its exact 12 x 3 target matrix."
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$lines = @((($stageColumns | ForEach-Object { Quote-Csv $_ }) -join ';'))
foreach ($row in $stageRows) {
    $lines += (($stageColumns | ForEach-Object {
        Quote-Csv ([string]$row.$_)
    }) -join ';')
}
[System.IO.File]::WriteAllLines($stageIndexPath, $lines, $utf8)
if (([System.IO.File]::ReadAllLines($stageIndexPath, $utf8) -join "`n") `
    -cne ($lines -join "`n")) {
    throw "Stage-five evidence index failed its UTF-8 round trip."
}

$emptyStatusSha256 = Get-TextSha256 ""
$worktreeRecords = foreach ($key in @($worktrees.Keys | Sort-Object)) {
    $parts = @($key.Split('|'))
    "worktree_record;key=$key;path=$($worktrees[$key].Replace('\', '/'))" +
        ";commit=$($parts[1]);tree=$($commitTrees[$parts[1]])" +
        ";git_status_sha256=$emptyStatusSha256"
}
$sourceSnapshotRecords = foreach ($key in @($worktrees.Keys | Sort-Object)) {
    $before = $sourceSnapshotsBefore[$key]
    $after = Get-DirectoryInventorySha256 $before.path
    $physicalAfter = Get-Issue13V5PhysicalSnapshotProof `
        $sourceData $before.path "Stage source-data snapshot $key"
    if ($after -cne $before.inventory_sha256 -or
        $after -cne $sourceDataOriginInventoryBefore -or
        [string]$physicalAfter.source_physical_path -cne
            [string]$before.physical.source_physical_path -or
        [string]$physicalAfter.snapshot_physical_path -cne
            [string]$before.physical.snapshot_physical_path -or
        [long]$physicalAfter.file_count -ne
            [long]$before.physical.file_count -or
        [long]$physicalAfter.directory_count -ne
            [long]$before.physical.directory_count -or
        [string]$physicalAfter.source_physical_inventory_sha256 -cne
            [string]$before.physical.source_physical_inventory_sha256 -or
        [string]$physicalAfter.snapshot_physical_inventory_sha256 -cne
            [string]$before.physical.snapshot_physical_inventory_sha256 -or
        [string]$physicalAfter.independence_sha256 -cne
            [string]$before.physical.independence_sha256) {
        throw "Stage source-data snapshot changed or differs: $key"
    }
    "source_snapshot_record;key=$key;path=$($before.path.Replace('\', '/'))" +
        ";physical_path=$([string]$before.physical.snapshot_physical_path -replace '\\', '/')" +
        ";file_count=$($before.physical.file_count)" +
        ";directory_count=$($before.physical.directory_count)" +
        ";inventory_before_sha256=$($before.inventory_sha256)" +
        ";inventory_after_sha256=$after" +
        ";physical_before_sha256=$($before.physical.snapshot_physical_inventory_sha256)" +
        ";physical_after_sha256=$($physicalAfter.snapshot_physical_inventory_sha256)" +
        ";independence_before_sha256=$($before.physical.independence_sha256)" +
        ";independence_after_sha256=$($physicalAfter.independence_sha256)"
}
$sourceDataOriginInventoryAfter = Get-DirectoryInventorySha256 $sourceData
$bridgeSourceSnapshotInventoryAfter =
    Get-DirectoryInventorySha256 $bridgeSourceSnapshotPath
$bridgeSourcePhysicalAfter = Get-Issue13V5PhysicalSnapshotProof `
    $sourceData $bridgeSourceSnapshotPath "Bridge source-data snapshot"
$sourceInventoriesAfter = @{}
foreach ($source in @("wiodr13", "wiodr16")) {
    $sourceInventoriesAfter[$source] = Get-DirectoryInventorySha256 `
        (Join-Path $sourceData ($source + "\normalized"))
    if ($sourceInventoriesAfter[$source] -cne
        $sourceInventoriesBefore[$source]) {
        throw "Normalized $source source inventory changed during capture."
    }
}
$harnessInventoryAfter = Get-DirectoryInventorySha256 $script:harness
$harnessRuntimeInventoryAfter = `
    Get-DirectoryInventorySha256 $harnessRuntime
$rLibraryInventoryAfter = Get-DirectoryInventorySha256 $script:rLibrary
if ($harnessInventoryAfter -cne $harnessInventoryBefore -or
    $harnessRuntimeInventoryAfter -cne $harnessRuntimeInventoryBefore -or
    $rLibraryInventoryAfter -cne $rLibraryInventoryBefore -or
    $sourceDataOriginInventoryAfter -cne
        $sourceDataOriginInventoryBefore -or
    $bridgeSourceSnapshotInventoryAfter -cne
        $bridgeSourceSnapshotInventoryBefore -or
    $bridgeSourceSnapshotInventoryAfter -cne
        $sourceDataOriginInventoryBefore -or
    [string]$bridgeSourcePhysicalAfter.source_physical_path -cne
        [string]$bridgeSourcePhysicalBefore.source_physical_path -or
    [string]$bridgeSourcePhysicalAfter.snapshot_physical_path -cne
        [string]$bridgeSourcePhysicalBefore.snapshot_physical_path -or
    [string]$bridgeSourcePhysicalAfter.source_physical_inventory_sha256 -cne
        [string]$bridgeSourcePhysicalBefore.source_physical_inventory_sha256 -or
    [string]$bridgeSourcePhysicalAfter.snapshot_physical_inventory_sha256 -cne
        [string]$bridgeSourcePhysicalBefore.snapshot_physical_inventory_sha256 -or
    [string]$bridgeSourcePhysicalAfter.independence_sha256 -cne
        [string]$bridgeSourcePhysicalBefore.independence_sha256 -or
    (Get-Sha256 $script:rscriptPath) -cne $rscriptSha256 -or
    (Get-Sha256 $fsutilPath) -cne $fsutilSha256) {
    throw "Stage-five capture tooling changed during execution."
}
$recipeRecordsAfter = @($recipePaths.Keys | Sort-Object | ForEach-Object {
    "recipe_record;name=$_;sha256=$(Get-Sha256 $recipePaths[$_])"
})
if (($recipeRecordsAfter -join "`n") -cne
    ($recipeRecordsBefore -join "`n")) {
    throw "Stage-five capture recipes changed during execution."
}
$recipeRecords = $recipeRecordsBefore
$captureRecord = @(
    "schema=issue13-v5-clean-stage5-capture/2",
    "baseline_base_commit=$baselineBaseCommit",
    "baseline_base_tree=$baselineBaseTree",
    "baseline_runtime_commit=$baselineRuntimeCommit",
    "baseline_runtime_tree=$baselineRuntimeTree",
    "harness_path=$($script:harness.Replace('\', '/'))",
    "harness_inventory_sha256=$harnessInventoryBefore",
    "harness_runtime_path=$($harnessRuntime.Replace('\', '/'))",
    "harness_runtime_inventory_before_sha256=$harnessRuntimeInventoryBefore",
    "harness_runtime_inventory_after_sha256=$harnessRuntimeInventoryAfter",
    "rscript_path=$($script:rscriptPath.Replace('\', '/'))",
    "rscript_sha256=$rscriptSha256",
    "fsutil_path=$($fsutilPath.Replace('\', '/'))",
    "fsutil_sha256=$fsutilSha256",
    "r_library_path=$($script:rLibrary.Replace('\', '/'))",
    "r_library_inventory_before_sha256=$rLibraryInventoryBefore",
    "r_library_inventory_after_sha256=$rLibraryInventoryAfter",
    "methods=$($methods -join ',')",
    "stages=$($stages -join ',')",
    "bridge_capture_record_sha256=$(Get-Sha256 $bridgeRecordPath)",
    "bridge_evidence_index_sha256=$(Get-Sha256 $bridgeIndexPath)",
    "bridge_manifest_sha256=$(Get-Sha256 $bridgeManifestPath)",
    "stage5_evidence_index_sha256=$(Get-Sha256 $stageIndexPath)",
    "source_data_origin_path=$($sourceData.Replace('\', '/'))",
    "source_data_origin_inventory_before_sha256=$sourceDataOriginInventoryBefore",
    "source_data_origin_inventory_after_sha256=$sourceDataOriginInventoryAfter",
    "bridge_source_data_snapshot_path=$($bridgeSourceSnapshotPath.Replace('\', '/'))",
    "bridge_source_data_snapshot_inventory_before_sha256=$bridgeSourceSnapshotInventoryBefore",
    "bridge_source_data_snapshot_inventory_after_sha256=$bridgeSourceSnapshotInventoryAfter",
    "source_data_origin_physical_path=$([string]$bridgeSourcePhysicalBefore.source_physical_path -replace '\\', '/')",
    "source_data_physical_file_count=$($bridgeSourcePhysicalBefore.file_count)",
    "source_data_physical_directory_count=$($bridgeSourcePhysicalBefore.directory_count)",
    "source_data_origin_physical_before_sha256=$($bridgeSourcePhysicalBefore.source_physical_inventory_sha256)",
    "source_data_origin_physical_after_sha256=$($bridgeSourcePhysicalAfter.source_physical_inventory_sha256)",
    "bridge_source_data_snapshot_physical_path=$([string]$bridgeSourcePhysicalBefore.snapshot_physical_path -replace '\\', '/')",
    "bridge_source_data_snapshot_physical_before_sha256=$($bridgeSourcePhysicalBefore.snapshot_physical_inventory_sha256)",
    "bridge_source_data_snapshot_physical_after_sha256=$($bridgeSourcePhysicalAfter.snapshot_physical_inventory_sha256)",
    "bridge_source_data_independence_before_sha256=$($bridgeSourcePhysicalBefore.independence_sha256)",
    "bridge_source_data_independence_after_sha256=$($bridgeSourcePhysicalAfter.independence_sha256)",
    "source_wiodr13_inventory_before_sha256=$($sourceInventoriesBefore['wiodr13'])",
    "source_wiodr13_inventory_after_sha256=$($sourceInventoriesAfter['wiodr13'])",
    "source_wiodr16_inventory_before_sha256=$($sourceInventoriesBefore['wiodr16'])",
    "source_wiodr16_inventory_after_sha256=$($sourceInventoriesAfter['wiodr16'])",
    "recipe_records=$($recipeRecords.Count)",
    "reference_records=$($referenceRecords.Count)",
    "seed_records=$($seedRecords.Count)",
    "target_records=$($targetRecords.Count)",
    "worktree_records=$($worktreeRecords.Count)",
    "source_snapshot_records=$($sourceSnapshotRecords.Count)"
) + $recipeRecords + $worktreeRecords + $sourceSnapshotRecords + $referenceRecords +
    $seedRecords + $targetRecords
$captureRecordPath = Join-Path $capture "capture-record.txt"
[System.IO.File]::WriteAllLines($captureRecordPath, $captureRecord, $utf8)
if (([System.IO.File]::ReadAllLines($captureRecordPath, $utf8) -join "`n") `
    -cne ($captureRecord -join "`n")) {
    throw "Stage-five capture record failed its UTF-8 round trip."
}

foreach ($key in $worktrees.Keys) {
    $parts = @($key.Split('|'))
    Assert-CleanWorktree $worktrees[$key] $parts[1] `
        $commitTrees[$parts[1]] "Completed stage-five worktree"
}
Write-Output ("capture_root=" + $capture.Replace('\', '/'))
Write-Output ("evidence_index=" + $stageIndexPath.Replace('\', '/'))
Write-Output ("capture_record=" + $captureRecordPath.Replace('\', '/'))
Write-Output ("capture_record_sha256=" + (Get-Sha256 $captureRecordPath))
Write-Output "reference_runs_reauthenticated=12"
Write-Output "baseline_recalculations=36"
