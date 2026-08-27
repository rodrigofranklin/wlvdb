[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $true)]
    [string]$CaptureRoot,

    [Parameter(Mandatory = $true)]
    [string]$BaselineSourceDataRoot,

    [Parameter(Mandatory = $true)]
    [string]$SeedEvidenceIndex,

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
$captureMethods = @(
    "alternative_1", "alternative_2", "norow_w13", "ochoa_1",
    "ochoa_2", "petrovic", "wiodr13v09"
)
$columns = @(
    "method", "candidate_project_root", "candidate_run_root",
    "baseline_project_root", "baseline_run_root"
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
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString(
            $algorithm.ComputeHash($bytes)
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
        throw "Tooling inventory contains a reparse point."
    }
    $records = @($items | Where-Object { -not $_.PSIsContainer } |
        ForEach-Object {
            $relative = $_.FullName.Substring($resolved.Length).TrimStart('\')
            $relative = $relative.Replace('\', '/')
            $relative + "|" + $_.Length + "|" + (Get-Sha256 $_.FullName)
        })
    [System.Array]::Sort($records, [System.StringComparer]::Ordinal)
    return (Get-TextSha256 ($records -join "`n"))
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
        -Label "Bridge capture sealed Rscript" `
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

function Assert-CleanWorktree([string]$Worktree, [string]$Label) {
    $status = @(Invoke-Issue13V5SealedGit `
      -C $Worktree status --porcelain=v1 --untracked-files=no)
    if ($LASTEXITCODE -ne 0 -or $status.Count -ne 0) {
        throw "$Label is not clean."
    }
    Assert-GitValue $Worktree "rev-parse HEAD" $baselineRuntimeCommit `
        "$Label runtime commit"
    Assert-GitValue $Worktree "rev-parse HEAD^{tree}" $baselineRuntimeTree `
        "$Label runtime tree"
}

function Get-RunDirectories([string]$Worktree, [string]$Method) {
    $root = Join-Path $Worktree ("results\runs\" + $Method)
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $root -Directory |
        ForEach-Object { $_.FullName })
}

function Quote-Csv([string]$Value) {
    return '"' + $Value.Replace('"', '""') + '"'
}

$repository = Resolve-PhysicalExistingDirectory $RepositoryRoot "Repository root"
$sourceData = Resolve-PhysicalExistingDirectory $BaselineSourceDataRoot "Source-data root"
$harness = Resolve-PhysicalExistingDirectory $HarnessDir "Harness directory"
$seedPath = Resolve-PhysicalExistingFile $SeedEvidenceIndex "Seed evidence index"
$controllerDir = Resolve-PhysicalExistingDirectory `
    $PSScriptRoot "Controller directory"
$verifier = Resolve-PhysicalExistingFile (Join-Path $controllerDir `
    "issue13-v5-verify-diagnostic-evidence.R") "Evidence verifier"
$rscriptBinding = Get-Issue13V5RscriptExecutableBinding $RscriptCommand
$rscriptPath = Resolve-PhysicalExistingFile $rscriptBinding.logical_path `
    "Rscript executable"
$systemDirectory = Resolve-PhysicalExistingDirectory `
    ([Environment]::SystemDirectory) "Windows system directory"
$fsutilPath = Resolve-PhysicalExistingFile `
    (Join-Path $systemDirectory "fsutil.exe") "fsutil executable"
$script:rscriptPath = $rscriptPath
$script:rLibrary = Resolve-PhysicalExistingDirectory $RLibrary `
    "R library"
$harnessRuntime = Resolve-PhysicalExistingDirectory `
    (Split-Path -Parent $harness) "Harness runtime"
$toolPaths = @{
    bridge_builder = Resolve-PhysicalExistingFile (Join-Path $controllerDir `
        "issue13-v5-build-diagnostic-bridges.R") "Bridge builder"
    bridge_capture_script = Resolve-PhysicalExistingFile `
        $MyInvocation.MyCommand.Path "Bridge capture script"
    compare_override = Resolve-PhysicalExistingFile (Join-Path $controllerDir `
        "issue13-v5-compare-override.R") "Comparison override"
    coordinator_library = Resolve-PhysicalExistingFile (Join-Path `
        $controllerDir "issue13-v5-coordinator-lib.ps1") `
        "Coordinator physical-snapshot library"
    diagnostics_override = Resolve-PhysicalExistingFile (Join-Path $controllerDir `
        "issue13-v5-diagnostics-override.R") "Diagnostic override"
    metadata_equivalence = Resolve-PhysicalExistingFile (Join-Path $controllerDir `
        "issue13-v5-metadata-equivalence.json") `
        "Metadata equivalence manifest"
    verifier = $verifier
}
$toolRecordsBefore = @($toolPaths.Keys | Sort-Object | ForEach-Object {
    "tool_record;name=$_;sha256=$(Get-Sha256 $toolPaths[$_])"
})
$harnessInventoryBefore = Get-DirectoryInventorySha256 $harness
$harnessRuntimeInventoryBefore = `
    Get-DirectoryInventorySha256 $harnessRuntime
$rLibraryInventoryBefore = Get-DirectoryInventorySha256 $script:rLibrary
$rscriptSha256 = Get-Sha256 $rscriptPath
$fsutilSha256 = Get-Sha256 $fsutilPath
$officialSourceInventoryBefore =
    Assert-Issue13V5OfficialSourceDataInventory $sourceData
$sourceDataOriginInventoryBefore =
    [string]$officialSourceInventoryBefore.ordinal_inventory_sha256
foreach ($source in @("wiodr13", "wiodr16")) {
    $sourceManifest = Join-Path $sourceData (
        $source + "\normalized\_source_manifest.csv"
    )
    if (-not (Test-Path -LiteralPath $sourceManifest -PathType Leaf)) {
        throw "The normalized $source source manifest is missing."
    }
}
$sourceManifestHashes = @{}
$sourceInventoriesBefore = @{}
foreach ($source in @("wiodr13", "wiodr16")) {
    $sourceManifest = Join-Path $sourceData (
        $source + "\normalized\_source_manifest.csv"
    )
    $sourceManifestHashes[$source] = (Get-FileHash -LiteralPath `
        $sourceManifest -Algorithm SHA256).Hash.ToLowerInvariant()
    $sourceInventoriesBefore[$source] = Get-DirectoryInventorySha256 `
        (Join-Path $sourceData ($source + "\normalized"))
}
if (Test-Path -LiteralPath $CaptureRoot) {
    throw "CaptureRoot is write-once and must not already exist."
}
$captureParent = Split-Path -Parent $CaptureRoot
$captureParent = Resolve-PhysicalExistingDirectory `
    $captureParent "CaptureRoot parent"
$capture = [System.IO.Path]::GetFullPath($CaptureRoot)
$capturePhysicalExpected = ConvertTo-Issue13V5PhysicalPath `
    $capture "CaptureRoot"
Assert-Issue13V5NoReparseAncestors $capture "CaptureRoot"
foreach ($protectedRoot in @(
    $repository, $sourceData, $harnessRuntime, $script:rLibrary
)) {
    Assert-Issue13V5PathsDisjoint `
        $capture $protectedRoot "CaptureRoot/protected-root isolation"
}
$baselineRoot = Join-Path $capture "baseline-e2f4-runtime"
$logsRoot = Join-Path $capture "logs"
$outputIndex = Join-Path $capture "diagnostic-bridge-evidence.csv"

$seed = @(Import-Csv -LiteralPath $seedPath -Delimiter ';')
if ($seed.Count -ne $methods.Count -or
    (@($seed[0].PSObject.Properties.Name) -join "|") -cne
        ($columns -join "|") -or
    (@($seed.method | Sort-Object -Unique) -join "|") -cne
        (@($methods | Sort-Object) -join "|")) {
    throw "Seed evidence index does not have the exact 12-method schema."
}

New-Item -ItemType Directory -Path $capture | Out-Null
New-Item -ItemType Directory -Path $logsRoot | Out-Null
$capturePhysicalObserved = ConvertTo-Issue13V5PhysicalPath `
    $capture "Created CaptureRoot"
Assert-Issue13V5NoReparse $capture
if ($capturePhysicalObserved -cne $capturePhysicalExpected) {
    throw "CaptureRoot changed physical identity during creation."
}
$verifiedRecords = @()

Invoke-Issue13V5SealedGit `
  -C $repository cat-file -e ($baselineBaseCommit + "^{commit}")
if ($LASTEXITCODE -ne 0) {
    throw "The canonical baseline base commit is unavailable."
}
Invoke-Issue13V5SealedGit `
  -C $repository cat-file -e ($baselineRuntimeCommit + "^{commit}")
if ($LASTEXITCODE -ne 0) {
    throw "The authenticated baseline runtime commit is unavailable."
}
Assert-GitValue $repository ("rev-parse " + $baselineBaseCommit + "^{tree}") `
    $baselineBaseTree "Canonical baseline base tree"
Assert-GitValue $repository ("rev-parse " + $baselineRuntimeCommit + "^") `
    $baselineBaseCommit "Baseline runtime parent"
Assert-GitValue $repository ("rev-parse " + $baselineRuntimeCommit + "^{tree}") `
    $baselineRuntimeTree "Baseline runtime tree"
Invoke-Issue13V5SealedGit `
  -C $repository worktree add --detach $baselineRoot $baselineRuntimeCommit
if ($LASTEXITCODE -ne 0) {
    throw "Could not create the clean baseline evidence worktree."
}
Assert-CleanWorktree $baselineRoot "Fresh baseline evidence worktree"

$sourceSnapshot = Join-Path $baselineRoot "source_data"
if (Test-Path -LiteralPath $sourceSnapshot) {
    throw "Fresh baseline worktree unexpectedly contains source_data."
}
$sourceDataPhysicalBefore = Copy-Issue13V5PhysicalDirectorySnapshot `
    $sourceData $sourceSnapshot "Bridge source-data snapshot"
$sourceDataSnapshotInventoryBefore =
    Get-DirectoryInventorySha256 $sourceSnapshot
if ($sourceDataSnapshotInventoryBefore -cne
        $sourceDataOriginInventoryBefore -or
    [long]$sourceDataPhysicalBefore.file_count -ne 84L -or
    [long]$sourceDataPhysicalBefore.directory_count -ne 5L) {
    throw "Physical source-data snapshot differs from its authenticated origin."
}
Assert-CleanWorktree $baselineRoot "Baseline evidence worktree after source snapshot"

foreach ($method in $captureMethods) {
    Assert-CleanWorktree $baselineRoot "Baseline before $method"
    $before = @(Get-RunDirectories $baselineRoot $method)
    $logPath = Join-Path $logsRoot ($method + ".calculate.log")
    $channel = "issue13-v5d-parent-" + $method.Replace("_", "-")
    $arguments = @(
        "--vanilla", (Join-Path $baselineRoot "scripts\run_wlv.R"),
        "--method", $method, "--workers", "1", "--channel",
        $channel, "--allow-experimental"
    )
    $runOutput = @(Invoke-SealedRscript $arguments 18000 $baselineRoot)
    $runOutput | Set-Content -LiteralPath $logPath -Encoding utf8
    if ($script:rscriptExitCode -ne 0) {
        throw "Baseline calculation failed for $method. See $logPath"
    }
    $after = @(Get-RunDirectories $baselineRoot $method)
    $created = @($after | Where-Object { $_ -notin $before })
    if ($created.Count -ne 1) {
        throw "Baseline calculation for $method did not create exactly one run."
    }
    Assert-CleanWorktree $baselineRoot "Baseline after $method"
    $verifyLog = Join-Path $logsRoot ($method + ".verify.log")
    $verifyArguments = @(
        "--vanilla", $verifier, $harness, $controllerDir, $baselineRoot,
        $created[0], $method
    )
    $verifyOutput = @(Invoke-SealedRscript $verifyArguments 600 $baselineRoot)
    $verifyOutput | Set-Content -LiteralPath $verifyLog -Encoding utf8
    $evidenceRecord = @($verifyOutput | Where-Object {
        $_ -cmatch '^evidence_record;'
    })
    if ($script:rscriptExitCode -ne 0 -or $evidenceRecord.Count -ne 1) {
        throw "Evidence authentication failed for $method. See $verifyLog"
    }
    $verifyLogSha256 = (Get-FileHash -LiteralPath $verifyLog `
        -Algorithm SHA256).Hash.ToLowerInvariant()
    $verifiedRecords += (
        $evidenceRecord[0] + ";verify_log_sha256=" + $verifyLogSha256
    )
    $row = @($seed | Where-Object { $_.method -ceq $method })
    if ($row.Count -ne 1) {
        throw "Seed evidence lacks one row for $method."
    }
    $row[0].baseline_project_root = $baselineRoot.Replace('\', '/')
    $row[0].baseline_run_root = $created[0].Replace('\', '/')
}

Assert-CleanWorktree $baselineRoot "Completed baseline evidence worktree"
$ordered = foreach ($method in $methods) {
    $row = @($seed | Where-Object { $_.method -ceq $method })
    if ($row.Count -ne 1) {
        throw "Final evidence index lacks one row for $method."
    }
    $row[0]
}
$lines = @((($columns | ForEach-Object { Quote-Csv $_ }) -join ';'))
foreach ($row in $ordered) {
    $lines += (($columns | ForEach-Object {
        Quote-Csv ([string]$row.$_)
    }) -join ';')
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($outputIndex, $lines, $utf8)
$roundTrip = [System.IO.File]::ReadAllLines($outputIndex, $utf8)
if (($roundTrip -join "`n") -cne ($lines -join "`n")) {
    throw "Evidence index failed its UTF-8 byte round trip."
}

$toolRecordsAfter = @($toolPaths.Keys | Sort-Object | ForEach-Object {
    "tool_record;name=$_;sha256=$(Get-Sha256 $toolPaths[$_])"
})
$harnessInventoryAfter = Get-DirectoryInventorySha256 $harness
$harnessRuntimeInventoryAfter = `
    Get-DirectoryInventorySha256 $harnessRuntime
$rLibraryInventoryAfter = Get-DirectoryInventorySha256 $script:rLibrary
$sourceDataOriginInventoryAfter = Get-DirectoryInventorySha256 $sourceData
$sourceDataSnapshotInventoryAfter =
    Get-DirectoryInventorySha256 $sourceSnapshot
$sourceDataPhysicalAfter = Get-Issue13V5PhysicalSnapshotProof `
    $sourceData $sourceSnapshot "Bridge source-data snapshot"
$sourceInventoriesAfter = @{}
foreach ($source in @("wiodr13", "wiodr16")) {
    $sourceInventoriesAfter[$source] = Get-DirectoryInventorySha256 `
        (Join-Path $sourceData ($source + "\normalized"))
}
if (($toolRecordsAfter -join "`n") -cne ($toolRecordsBefore -join "`n") -or
    $harnessInventoryAfter -cne $harnessInventoryBefore -or
    $harnessRuntimeInventoryAfter -cne $harnessRuntimeInventoryBefore -or
    $rLibraryInventoryAfter -cne $rLibraryInventoryBefore -or
    $sourceDataOriginInventoryAfter -cne
        $sourceDataOriginInventoryBefore -or
    $sourceDataSnapshotInventoryAfter -cne
        $sourceDataSnapshotInventoryBefore -or
    $sourceDataSnapshotInventoryBefore -cne
        $sourceDataOriginInventoryBefore -or
    [string]$sourceDataPhysicalAfter.source_physical_path -cne
        [string]$sourceDataPhysicalBefore.source_physical_path -or
    [string]$sourceDataPhysicalAfter.snapshot_physical_path -cne
        [string]$sourceDataPhysicalBefore.snapshot_physical_path -or
    [long]$sourceDataPhysicalAfter.file_count -ne
        [long]$sourceDataPhysicalBefore.file_count -or
    [long]$sourceDataPhysicalAfter.directory_count -ne
        [long]$sourceDataPhysicalBefore.directory_count -or
    [string]$sourceDataPhysicalAfter.source_physical_inventory_sha256 -cne
        [string]$sourceDataPhysicalBefore.source_physical_inventory_sha256 -or
    [string]$sourceDataPhysicalAfter.snapshot_physical_inventory_sha256 -cne
        [string]$sourceDataPhysicalBefore.snapshot_physical_inventory_sha256 -or
    [string]$sourceDataPhysicalAfter.independence_sha256 -cne
        [string]$sourceDataPhysicalBefore.independence_sha256 -or
    $sourceInventoriesAfter['wiodr13'] -cne
        $sourceInventoriesBefore['wiodr13'] -or
    $sourceInventoriesAfter['wiodr16'] -cne
        $sourceInventoriesBefore['wiodr16'] -or
    (Get-Sha256 $rscriptPath) -cne $rscriptSha256 -or
    (Get-Sha256 $fsutilPath) -cne $fsutilSha256) {
    throw "Diagnostic capture tooling changed during execution."
}
$captureRecord = @(
    "schema=issue13-v5-clean-bridge-capture/2",
    "baseline_base_commit=$baselineBaseCommit",
    "baseline_base_tree=$baselineBaseTree",
    "baseline_runtime_commit=$baselineRuntimeCommit",
    "baseline_runtime_tree=$baselineRuntimeTree",
    "harness_path=$($harness.Replace('\', '/'))",
    "harness_inventory_sha256=$harnessInventoryBefore",
    "harness_runtime_path=$($harnessRuntime.Replace('\', '/'))",
    "harness_runtime_inventory_before_sha256=$harnessRuntimeInventoryBefore",
    "harness_runtime_inventory_after_sha256=$harnessRuntimeInventoryAfter",
    "rscript_path=$($rscriptPath.Replace('\', '/'))",
    "rscript_sha256=$rscriptSha256",
    "fsutil_path=$($fsutilPath.Replace('\', '/'))",
    "fsutil_sha256=$fsutilSha256",
    "r_library_path=$($script:rLibrary.Replace('\', '/'))",
    "r_library_inventory_before_sha256=$rLibraryInventoryBefore",
    "r_library_inventory_after_sha256=$rLibraryInventoryAfter",
    "tool_records=$($toolRecordsBefore.Count)",
    "baseline_worktree=$($baselineRoot.Replace('\', '/'))",
    "captured_methods=$($captureMethods -join ',')",
    "verified_records=$($verifiedRecords.Count)",
    "seed_evidence_index_sha256=$((Get-FileHash -LiteralPath $seedPath -Algorithm SHA256).Hash.ToLowerInvariant())",
    "source_data_origin_path=$($sourceData.Replace('\', '/'))",
    "source_data_snapshot_path=$($sourceSnapshot.Replace('\', '/'))",
    "source_data_origin_inventory_before_sha256=$sourceDataOriginInventoryBefore",
    "source_data_origin_inventory_after_sha256=$sourceDataOriginInventoryAfter",
    "source_data_snapshot_inventory_before_sha256=$sourceDataSnapshotInventoryBefore",
    "source_data_snapshot_inventory_after_sha256=$sourceDataSnapshotInventoryAfter",
    "source_data_origin_physical_path=$([string]$sourceDataPhysicalBefore.source_physical_path -replace '\\', '/')",
    "source_data_snapshot_physical_path=$([string]$sourceDataPhysicalBefore.snapshot_physical_path -replace '\\', '/')",
    "source_data_physical_file_count=$($sourceDataPhysicalBefore.file_count)",
    "source_data_physical_directory_count=$($sourceDataPhysicalBefore.directory_count)",
    "source_data_origin_physical_before_sha256=$($sourceDataPhysicalBefore.source_physical_inventory_sha256)",
    "source_data_origin_physical_after_sha256=$($sourceDataPhysicalAfter.source_physical_inventory_sha256)",
    "source_data_snapshot_physical_before_sha256=$($sourceDataPhysicalBefore.snapshot_physical_inventory_sha256)",
    "source_data_snapshot_physical_after_sha256=$($sourceDataPhysicalAfter.snapshot_physical_inventory_sha256)",
    "source_data_independence_before_sha256=$($sourceDataPhysicalBefore.independence_sha256)",
    "source_data_independence_after_sha256=$($sourceDataPhysicalAfter.independence_sha256)",
    "source_wiodr13_manifest_sha256=$($sourceManifestHashes['wiodr13'])",
    "source_wiodr16_manifest_sha256=$($sourceManifestHashes['wiodr16'])",
    "source_wiodr13_inventory_before_sha256=$($sourceInventoriesBefore['wiodr13'])",
    "source_wiodr13_inventory_after_sha256=$($sourceInventoriesAfter['wiodr13'])",
    "source_wiodr16_inventory_before_sha256=$($sourceInventoriesBefore['wiodr16'])",
    "source_wiodr16_inventory_after_sha256=$($sourceInventoriesAfter['wiodr16'])",
    "evidence_index=$($outputIndex.Replace('\', '/'))",
    "evidence_index_sha256=$((Get-FileHash -LiteralPath $outputIndex -Algorithm SHA256).Hash.ToLowerInvariant())"
) + $toolRecordsBefore + $verifiedRecords
$captureRecordPath = Join-Path $capture "capture-record.txt"
[System.IO.File]::WriteAllLines($captureRecordPath, $captureRecord, $utf8)
$captureRoundTrip = [System.IO.File]::ReadAllLines($captureRecordPath, $utf8)
if (($captureRoundTrip -join "`n") -cne ($captureRecord -join "`n")) {
    throw "Capture record failed its UTF-8 byte round trip."
}
Write-Output ("capture_root=" + $capture.Replace('\', '/'))
Write-Output ("evidence_index=" + $outputIndex.Replace('\', '/'))
Write-Output ("capture_record=" + $captureRecordPath.Replace('\', '/'))
Write-Output ("capture_record_sha256=" + (
    Get-FileHash -LiteralPath $captureRecordPath -Algorithm SHA256
).Hash.ToLowerInvariant())
Write-Output "captured_runs=7"
