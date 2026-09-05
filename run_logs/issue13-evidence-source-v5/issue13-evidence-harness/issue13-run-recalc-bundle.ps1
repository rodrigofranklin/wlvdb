param(
  [Parameter(Mandatory = $true)][string]$BundlePath
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

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Issue13ProcessEnvironmentStateRecalc(
  [Parameter(Mandatory = $true)][string[]]$Names
) {
  $seen = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  $states = [Collections.Generic.List[object]]::new()
  foreach ($name in @($Names)) {
    if ([string]::IsNullOrWhiteSpace($name) -or
        $name -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or
        -not $seen.Add($name)) {
      throw "Invalid or duplicate environment variable name: $name"
    }
    $path = 'Env:' + $name
    $present = Test-Path -LiteralPath $path
    $value = [Environment]::GetEnvironmentVariable($name, 'Process')
    if ((-not $present) -and $null -ne $value) {
      throw "Environment absence disagrees with the process block: $name"
    }
    if ($present -and $null -eq $value) {
      throw "Environment presence disagrees with the process block: $name"
    }
    $states.Add([pscustomobject][ordered]@{
        name = $name
        present = [bool]$present
        value = if ($present) { [string]$value } else { $null }
      })
  }
  [object[]]$states.ToArray()
}

function Set-Issue13ProcessEnvironmentStateRecalc(
  [Parameter(Mandatory = $true)][object[]]$States
) {
  $records = @($States)
  $seen = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  foreach ($state in $records) {
    if ($null -eq $state) {
      throw 'Environment state cannot be null.'
    }
    $actual = @($state.PSObject.Properties.Name | Sort-Object)
    $expected = @('name', 'present', 'value') | Sort-Object
    if ([string]::Join("`n", $actual) -cne
        [string]::Join("`n", $expected) -or
        $state.name -isnot [string] -or
        [string]::IsNullOrWhiteSpace([string]$state.name) -or
        [string]$state.name -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or
        -not $seen.Add([string]$state.name) -or
        $state.present -isnot [bool] -or
        ([bool]$state.present -and $state.value -isnot [string]) -or
        ((-not [bool]$state.present) -and $null -ne $state.value)) {
      throw 'Environment state is invalid or duplicated.'
    }
  }
  foreach ($state in $records) {
    $name = [string]$state.name
    $path = 'Env:' + $name
    if ([bool]$state.present) {
      $value = [string]$state.value
      [Environment]::SetEnvironmentVariable($name, $value, 'Process')
      if (-not (Test-Path -LiteralPath $path) -or
          [Environment]::GetEnvironmentVariable($name, 'Process') -cne
            $value) {
        throw "Failed to set process environment variable: $name"
      }
    } else {
      if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath ('Env:' + $name) -Force -ErrorAction Stop
      }
      if ((Test-Path -LiteralPath $path) -or
          $null -ne [Environment]::GetEnvironmentVariable($name, 'Process')) {
        throw "Failed to remove process environment variable: $name"
      }
    }
  }
}

function Invoke-Issue13WithProcessEnvironmentRecalc(
  [AllowNull()][object]$Environment,
  [Parameter(Mandatory = $true)][scriptblock]$Action
) {
  if ($null -eq $Action) { throw 'Environment action cannot be null.' }
  $properties = @(
    if ($null -ne $Environment) {
      $Environment.PSObject.Properties
    }
  )
  if ($properties.Count -eq 0) { return (& $Action) }
  $names = @($properties | ForEach-Object { [string]$_.Name })
  $snapshot = @(Get-Issue13ProcessEnvironmentStateRecalc -Names $names)
  $desired = @($properties | ForEach-Object {
      [pscustomobject][ordered]@{
        name = [string]$_.Name
        present = $null -ne $_.Value
        value = if ($null -ne $_.Value) { $_.Value } else { $null }
      }
    })
  $result = $null
  $primary = $null
  try {
    Set-Issue13ProcessEnvironmentStateRecalc -States $desired
    $result = & $Action
  } catch {
    $primary = $_
  }
  $restoreFailures = [Collections.Generic.List[Exception]]::new()
  foreach ($state in $snapshot) {
    try {
      Set-Issue13ProcessEnvironmentStateRecalc -States @($state)
    } catch {
      $restoreFailures.Add($_.Exception)
    }
  }
  if ($restoreFailures.Count -ne 0) {
    $failures = [Collections.Generic.List[Exception]]::new()
    if ($null -ne $primary) { $failures.Add($primary.Exception) }
    foreach ($failure in $restoreFailures) { $failures.Add($failure) }
    throw [AggregateException]::new(
      'Process environment restoration failed.', $failures.ToArray())
  }
  if ($null -ne $primary) { throw $primary }
  $result
}

function Get-CanonicalFullPath([string]$Path) {
  [IO.Path]::GetFullPath($Path).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar)
}

function Get-Sha256([string]$Path) {
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Read-JsonObject([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "$Label is missing."
  }
  $value = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($value -isnot [pscustomobject]) { throw "$Label is not a JSON object." }
  $value
}

function Assert-ExactProperties(
  [object]$Value,
  [string[]]$Expected,
  [string]$Label
) {
  $actual = @($Value.PSObject.Properties.Name | Sort-Object)
  $wanted = @($Expected | Sort-Object)
  if ([string]::Join("`n", $actual) -cne [string]::Join("`n", $wanted)) {
    throw "$Label property set differs."
  }
}

function Assert-NoReparse([string]$Path, [string]$Label) {
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "$Label is a reparse point."
  }
}

function Assert-NoExecutionCheckpointClaim(
  [string]$CheckpointPath,
  [string]$ScenarioId
) {
  $checkpoint = Get-CanonicalFullPath $CheckpointPath
  $parent = Split-Path -Parent $checkpoint
  $expected = Get-CanonicalFullPath (
    Join-Path (Split-Path -Parent (Split-Path -Parent $bundleResolved)) `
      'execution-checkpoint.json')
  if (-not [string]::Equals($checkpoint, $expected,
      [StringComparison]::OrdinalIgnoreCase)) {
    throw "Recalculation checkpoint path is non-canonical: $ScenarioId"
  }
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    throw "Recalculation checkpoint parent is missing: $ScenarioId"
  }
  Assert-NoReparse $parent 'Recalculation checkpoint parent'
  $claims = @(Get-ChildItem -LiteralPath $parent -File -Force | Where-Object {
      $_.Name -cin @(
        'execution-checkpoint.started.json', 'execution-checkpoint.json') -or
        $_.Name -cmatch
          '^\.execution-checkpoint(?:\.started)?\.json-[0-9a-f]+(?:\.tmp)?$'
    })
  $foreignClaims = @(Get-ChildItem -LiteralPath $parent -Force | Where-Object {
      $_.Name -cmatch '^\.?execution-checkpoint' -and $_ -notin $claims
    })
  if ($foreignClaims.Count -ne 0 -or $claims.Count -ne 0) {
    throw "Recalculation checkpoint prevents process replay: $ScenarioId"
  }
}

function Assert-CommittedSeedPublication([object]$SeedSpec) {
  Assert-ExactProperties $SeedSpec @(
    'schema', 'scenario_id', 'project_root', 'expected_commit',
    'expected_seed_commit', 'method', 'channel', 'seed_result_path') `
    'Recalculation seed specification'
  if ($SeedSpec.schema -cne 'wlv-issue13-channel-seed/1' -or
      $SeedSpec.scenario_id -cne [string]$bundle.scenario_id -or
      $SeedSpec.expected_commit -cne [string]$bundle.runtime_commit -or
      $SeedSpec.expected_seed_commit -cne [string]$bundle.seed_commit -or
      $SeedSpec.channel -cne [string]$bundle.channel -or
      $SeedSpec.project_root -isnot [string] -or
      $SeedSpec.seed_result_path -isnot [string] -or
      $SeedSpec.method -isnot [string] -or
      $SeedSpec.channel -isnot [string] -or
      [string]$SeedSpec.channel -cnotmatch '^[a-z0-9][a-z0-9._/-]*$' -or
      [string]$SeedSpec.channel -match '(^|/)\.\.?(/|$)' -or
      [string]$SeedSpec.method -cnotmatch '^[a-z][a-z0-9_]*$') {
    throw 'Seed-result staging lacks a canonical seed specification.'
  }
  $project = Get-CanonicalFullPath ([string]$SeedSpec.project_root)
  $results = Get-CanonicalFullPath (Join-Path $project 'results')
  $channelDirectory = Get-CanonicalFullPath (Join-Path (
      Join-Path $results 'channels') ([string]$SeedSpec.channel).Replace('/', '\'))
  if (-not (Test-Path -LiteralPath $channelDirectory -PathType Container)) {
    throw 'Seed-result staging has no committed channel marker.'
  }
  foreach ($path in @($project, $results, (Join-Path $results 'channels'),
      $channelDirectory)) {
    Assert-NoReparse $path 'Seed publication path'
  }
  $markers = @(Get-ChildItem -LiteralPath $channelDirectory -Force)
  if ($markers.Count -ne 1 -or $markers[0].PSIsContainer -or
      $markers[0].Name -cnotmatch
        '^[0-9]{20}-release-[0-9]{8}T[0-9]{9}Z-[0-9a-f]{16}\.json$') {
    throw 'Seed-result staging requires exactly one canonical channel marker.'
  }
  Assert-NoReparse $markers[0].FullName 'Seed channel marker'
  $marker = Read-JsonObject $markers[0].FullName 'Seed channel marker'
  Assert-ExactProperties $marker @(
    'schema', 'schema_version', 'channel', 'sequence', 'release_id',
    'release_manifest_path', 'release_manifest_sha256', 'published_at_utc') `
    'Seed channel marker'
  $expectedMarkerName = [string]$marker.sequence + '-' +
    [string]$marker.release_id + '.json'
  $expectedReleaseRelative = 'releases/' + [string]$marker.release_id +
    '/release_manifest.json'
  if ($marker.schema -cne 'wlv-channel-marker' -or
      $marker.schema_version -cne '1' -or
      $marker.channel -cne [string]$SeedSpec.channel -or
      $marker.sequence -isnot [string] -or
      $marker.sequence -cnotmatch '^[0-9]{20}$' -or
      $marker.release_id -isnot [string] -or
      $marker.release_id -cnotmatch
        '^release-[0-9]{8}T[0-9]{9}Z-[0-9a-f]{16}$' -or
      $markers[0].Name -cne $expectedMarkerName -or
      $marker.release_manifest_path -cne $expectedReleaseRelative -or
      $marker.release_manifest_sha256 -isnot [string] -or
      $marker.release_manifest_sha256 -cnotmatch '^[0-9a-f]{64}$') {
    throw 'Seed channel marker identity is invalid.'
  }
  $releasePath = Get-CanonicalFullPath (Join-Path $results (
      $expectedReleaseRelative.Replace('/', '\')))
  if (-not (Test-Path -LiteralPath $releasePath -PathType Leaf) -or
      (Get-Sha256 $releasePath) -cne
        [string]$marker.release_manifest_sha256) {
    throw 'Seed channel marker does not authenticate its release manifest.'
  }
  Assert-NoReparse (Split-Path -Parent $releasePath) 'Seed release directory'
  Assert-NoReparse $releasePath 'Seed release manifest'
  $release = Read-JsonObject $releasePath 'Seed release manifest'
  Assert-ExactProperties $release @(
    'schema', 'schema_version', 'release_id', 'channel', 'sequence',
    'created_at_utc', 'metadata', 'runs', 'artifacts') 'Seed release manifest'
  if ($release.schema -cne 'wlv-release-manifest' -or
      $release.schema_version -cne '1' -or
      $release.release_id -cne [string]$marker.release_id -or
      $release.channel -cne [string]$SeedSpec.channel -or
      $release.sequence -cne [string]$marker.sequence -or
      $release.runs -isnot [object[]] -or @($release.runs).Count -ne 1 -or
      $release.artifacts -isnot [object[]]) {
    throw 'Seed release manifest identity is invalid.'
  }
  $run = $release.runs[0]
  Assert-ExactProperties $run @(
    'method', 'run_id', 'result_id', 'manifest_path', 'manifest_sha256') `
    'Seed release run reference'
  if ($run.method -cne [string]$SeedSpec.method -or
      $run.manifest_sha256 -isnot [string] -or
      $run.manifest_sha256 -cnotmatch '^[0-9a-f]{64}$') {
    throw 'Seed release run reference is invalid.'
  }
}

$bundleResolved = (Resolve-Path -LiteralPath $BundlePath).Path
$bundle = Get-Content -LiteralPath $bundleResolved -Raw -Encoding UTF8 |
  ConvertFrom-Json
if ($bundle.schema -ne 'wlv-issue13-recalc-bundle/1') {
  throw 'Unsupported recalculation bundle schema.'
}
foreach ($path in @($bundle.seed_spec, $bundle.process_spec, $bundle.seed_script)) {
  if (-not (Test-Path -LiteralPath ([string]$path) -PathType Leaf)) {
    throw "Bundle input is missing: $path"
  }
}
if (Test-Path -LiteralPath ([string]$bundle.scenario_evidence)) {
  throw "Refusing to reuse scenario evidence directory: $($bundle.scenario_evidence)"
}
$processSpec = Get-Content -LiteralPath ([string]$bundle.process_spec) -Raw `
  -Encoding UTF8 | ConvertFrom-Json
$processArguments = @($processSpec.arguments | ForEach-Object { [string]$_ })
if ($processSpec.schema -cne 'wlv-issue13-process-spec/1' -or
    $processSpec.scenario_id -cne [string]$bundle.scenario_id -or
    $processArguments.Count -ne 4) {
  throw 'Recalculation process specification is invalid.'
}
$scenarioSpecPath = (Resolve-Path -LiteralPath $processArguments[2]).Path
if (-not [string]::Equals(
    (Get-CanonicalFullPath $scenarioSpecPath),
    (Get-CanonicalFullPath (Join-Path (Split-Path -Parent $bundleResolved) `
        'scenario-spec.json')),
    [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Recalculation process spec has a foreign scenario specification.'
}
$scenarioSpec = Read-JsonObject $scenarioSpecPath `
  'Recalculation scenario specification'
if ($scenarioSpec.schema -cne 'wlv-issue13-scenario/1' -or
    $scenarioSpec.scenario_id -cne [string]$bundle.scenario_id -or
    $scenarioSpec.checkpoint_path -isnot [string]) {
  throw 'Recalculation scenario checkpoint binding is invalid.'
}
Assert-NoExecutionCheckpointClaim ([string]$scenarioSpec.checkpoint_path) `
  ([string]$bundle.scenario_id)
$seedRequired = -not (Test-Path -LiteralPath ([string]$bundle.seed_evidence))
if (-not $seedRequired) {
  if (-not (Test-Path -LiteralPath ([string]$bundle.seed_evidence) `
      -PathType Container)) {
    throw 'Recalculation seed evidence is not a directory.'
  }
  $seedEntries = @(Get-ChildItem -LiteralPath ([string]$bundle.seed_evidence) `
    -Force)
  if ($seedEntries.Count -eq 0) {
    [IO.Directory]::Delete([string]$bundle.seed_evidence, $false)
    $seedRequired = $true
  } elseif ($seedEntries.Count -eq 1 -and
      -not $seedEntries[0].PSIsContainer -and
      $seedEntries[0].Name -cmatch
        '^\.seed-result\.json-[0-9a-f]+(?:\.tmp)?$') {
    # The channel seeder authenticates the already-visible release/marker and
    # either promotes an exact staged result or reconstructs an unreadable one.
    # No calculation is repeated by this recovery path.
    $seedSpec = Read-JsonObject ([string]$bundle.seed_spec) `
      'Recalculation seed specification'
    Assert-CommittedSeedPublication $seedSpec
    $seedRequired = $true
  } elseif ($seedEntries.Count -ne 1 -or $seedEntries[0].PSIsContainer -or
      $seedEntries[0].Name -cne 'seed-result.json') {
    throw 'Recalculation seed evidence is partial or contains foreign entries.'
  }
  if (-not $seedRequired) {
    $seedResult = Get-Content -LiteralPath $seedEntries[0].FullName -Raw `
      -Encoding UTF8 | ConvertFrom-Json
    if ($seedResult.schema -cne 'wlv-issue13-channel-seed-result/1' -or
        $seedResult.scenario_id -cne [string]$bundle.scenario_id -or
        $seedResult.status -cne 'passed' -or
        $seedResult.passed -isnot [bool] -or -not $seedResult.passed -or
        $seedResult.expected_commit -cne [string]$bundle.runtime_commit -or
        $seedResult.expected_seed_commit -cne [string]$bundle.seed_commit -or
        $seedResult.channel -cne [string]$bundle.channel) {
      throw 'Recalculation seed evidence is not reusable.'
    }
  }
}
$rscriptEnvironment = [Environment]::GetEnvironmentVariable(
  'ISSUE13_V5_RSCRIPT_EXECUTABLE', 'Process')
if ([string]::IsNullOrWhiteSpace($rscriptEnvironment) -or
    -not [IO.Path]::IsPathFullyQualified($rscriptEnvironment)) {
  throw 'ISSUE13_V5_RSCRIPT_EXECUTABLE must be an absolute path.'
}
$expectedRscript = [IO.Path]::GetFullPath($rscriptEnvironment)
$declaredRscript = [string]$processSpec.executable
if ([string]::IsNullOrWhiteSpace($declaredRscript) -or
    -not [IO.Path]::IsPathFullyQualified($declaredRscript)) {
  throw 'Recalculation process executable must be an absolute path.'
}
$declaredRscript = [IO.Path]::GetFullPath($declaredRscript)
if (-not [string]::Equals(
      $declaredRscript, $expectedRscript,
      [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Recalculation process executable differs from the sealed Rscript.'
}
if (-not [IO.File]::Exists($expectedRscript)) {
  throw 'ISSUE13_V5_RSCRIPT_EXECUTABLE does not identify an existing file.'
}
$rscript = $expectedRscript
Invoke-Issue13WithProcessEnvironmentRecalc $processSpec.environment {
  if ($seedRequired) {
    Assert-NoExecutionCheckpointClaim ([string]$scenarioSpec.checkpoint_path) `
      ([string]$bundle.scenario_id)
    & $rscript --vanilla ([string]$bundle.seed_script) `
      ([string]$bundle.seed_spec) ([string]$bundle.seed_evidence)
    if ($LASTEXITCODE -ne 0) {
      throw "Channel seeding failed for $($bundle.scenario_id)."
    }
    $installedSeedEntries = @(Get-ChildItem -LiteralPath `
      ([string]$bundle.seed_evidence) -Force)
    if ($installedSeedEntries.Count -ne 1 -or
        $installedSeedEntries[0].PSIsContainer -or
        $installedSeedEntries[0].Name -cne 'seed-result.json') {
      throw "Channel seeding left partial evidence for $($bundle.scenario_id)."
    }
  }
}
Assert-NoExecutionCheckpointClaim ([string]$scenarioSpec.checkpoint_path) `
  ([string]$bundle.scenario_id)
& (Join-Path $PSScriptRoot 'issue13-monitor.ps1') `
  -SpecPath ([string]$bundle.process_spec) `
  -EvidenceDir ([string]$bundle.scenario_evidence)
if ($LASTEXITCODE -ne 0) {
  throw "Recalculation scenario failed for $($bundle.scenario_id)."
}
Write-Output ([string]$bundle.scenario_evidence)
