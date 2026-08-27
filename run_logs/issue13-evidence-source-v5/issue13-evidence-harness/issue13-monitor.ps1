param(
  [Parameter(Mandatory = $true)][string]$SpecPath,
  [Parameter(Mandatory = $true)][string]$EvidenceDir
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

function Get-Issue13ProcessEnvironmentState(
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

function Set-Issue13ProcessEnvironmentState(
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

function Invoke-Issue13WithProcessEnvironment(
  [AllowNull()][object]$Environment,
  [Parameter(Mandatory = $true)][scriptblock]$Action
) {
  if ($null -eq $Action) { throw 'Environment action cannot be null.' }
  $properties = if ($null -eq $Environment) {
    @()
  } else {
    @($Environment.PSObject.Properties)
  }
  if ($properties.Count -eq 0) { return (& $Action) }
  $names = @($properties | ForEach-Object { [string]$_.Name })
  $snapshot = @(Get-Issue13ProcessEnvironmentState -Names $names)
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
    Set-Issue13ProcessEnvironmentState -States $desired
    $result = & $Action
  } catch {
    $primary = $_
  }
  $restoreFailures = [Collections.Generic.List[Exception]]::new()
  foreach ($state in $snapshot) {
    try {
      Set-Issue13ProcessEnvironmentState -States @($state)
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

function Get-Issue13FileSha256(
  [Parameter(Mandatory = $true)][string]$Path
) {
  $stream = [IO.FileStream]::new(
    $Path, [IO.FileMode]::Open, [IO.FileAccess]::Read,
    [IO.FileShare]::Read)
  try {
    [Convert]::ToHexString(
      [Security.Cryptography.SHA256]::HashData($stream)
    ).ToLowerInvariant()
  } finally {
    $stream.Dispose()
  }
}

function Resolve-ExistingFile([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "$Label does not exist: $Path"
  }
  return (Resolve-Path -LiteralPath $Path).Path
}

function Resolve-ExistingDirectory([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "$Label does not exist: $Path"
  }
  return (Resolve-Path -LiteralPath $Path).Path
}

function Quote-WindowsArgument([string]$Value) {
  if ($null -eq $Value) { $Value = '' }
  if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
    return $Value
  }
  $builder = [System.Text.StringBuilder]::new()
  [void]$builder.Append('"')
  $slashes = 0
  foreach ($character in $Value.ToCharArray()) {
    if ($character -eq '\') {
      $slashes++
      continue
    }
    if ($character -eq '"') {
      if ($slashes -gt 0) { [void]$builder.Append(('\' * ($slashes * 2))) }
      [void]$builder.Append('\"')
      $slashes = 0
      continue
    }
    if ($slashes -gt 0) {
      [void]$builder.Append(('\' * $slashes))
      $slashes = 0
    }
    [void]$builder.Append($character)
  }
  if ($slashes -gt 0) { [void]$builder.Append(('\' * ($slashes * 2))) }
  [void]$builder.Append('"')
  return $builder.ToString()
}

function Csv-Field([object]$Value) {
  if ($null -eq $Value) { return '""' }
  return '"' + ([string]$Value).Replace('"', '""') + '"'
}

function Process-Key([int]$ProcessId, [string]$Created) {
  return ([string]$ProcessId + '|' + $Created)
}

function Convert-CreationDate([object]$Value) {
  if ($null -eq $Value) { return '' }
  if ($Value -is [DateTime]) {
    return ([DateTime]$Value).ToUniversalTime().ToString('o')
  }
  $text = [string]$Value
  try {
    return ([System.Management.ManagementDateTimeConverter]::ToDateTime(
        $text
      )).ToUniversalTime().ToString('o')
  } catch {
    $parsed = [DateTime]::Parse(
      $text,
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::AssumeLocal
    )
    return $parsed.ToUniversalTime().ToString('o')
  }
}

function Get-ProcessTable {
  return @(Get-CimInstance Win32_Process -ErrorAction Stop | ForEach-Object {
    $created = Convert-CreationDate $_.CreationDate
    [pscustomobject]@{
      ProcessId = [int]$_.ProcessId
      ParentProcessId = [int]$_.ParentProcessId
      Name = [string]$_.Name
      Created = $created
    }
  })
}

function Add-Descendants(
  [object[]]$Table,
  [hashtable]$KnownByPid,
  [hashtable]$Observed
) {
  $activeByPid = @{}
  foreach ($record in $Table) {
    if ($KnownByPid.ContainsKey($record.ProcessId) -and
        [string]$KnownByPid[$record.ProcessId] -ceq [string]$record.Created) {
      $activeByPid[$record.ProcessId] = $record
    }
  }
  $changed = $true
  while ($changed) {
    $changed = $false
    foreach ($record in $Table) {
      if ($record.ProcessId -eq $record.ParentProcessId -or
          -not $activeByPid.ContainsKey($record.ParentProcessId)) {
        continue
      }
      $parent = $activeByPid[$record.ParentProcessId]
      $parentCreated = [DateTimeOffset]::Parse(
        [string]$parent.Created,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind
      )
      $childCreated = [DateTimeOffset]::Parse(
        [string]$record.Created,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind
      )
      if ($childCreated -le $parentCreated) { continue }
      $knownCurrentGeneration = $KnownByPid.ContainsKey($record.ProcessId) -and
        [string]$KnownByPid[$record.ProcessId] -ceq [string]$record.Created
      if (-not $knownCurrentGeneration) {
        $KnownByPid[$record.ProcessId] = $record.Created
        $key = Process-Key $record.ProcessId $record.Created
        $Observed[$key] = [ordered]@{
          pid = $record.ProcessId
          parent_pid = $record.ParentProcessId
          name = $record.Name
          created_at_utc = $record.Created
          first_seen_at_utc = [DateTime]::UtcNow.ToString('o')
          last_seen_at_utc = [DateTime]::UtcNow.ToString('o')
          peak_working_set_bytes = [int64]0
          peak_private_bytes = [int64]0
          peak_cpu_seconds = 0.0
        }
        $changed = $true
      }
      $activeByPid[$record.ProcessId] = $record
    }
  }
}

function Active-KnownRecords([object[]]$Table, [hashtable]$KnownByPid) {
  return @($Table | Where-Object {
    $KnownByPid.ContainsKey($_.ProcessId) -and
      $KnownByPid[$_.ProcessId] -eq $_.Created
  })
}

function Stop-KnownTree([object[]]$Records) {
  foreach ($record in ($Records | Sort-Object ProcessId -Descending)) {
    Stop-Process -Id $record.ProcessId -Force -ErrorAction SilentlyContinue
  }
}

function Stop-KnownTreeBounded(
  [hashtable]$KnownByPid,
  [hashtable]$Observed,
  [int]$GraceSeconds
) {
  $deadline = [DateTime]::UtcNow.AddSeconds([Math]::Max(1, $GraceSeconds))
  do {
    $table = Get-ProcessTable
    Add-Descendants $table $KnownByPid $Observed
    $active = @(Active-KnownRecords $table $KnownByPid)
    if ($active.Count -eq 0) { return }
    Stop-KnownTree $active
    Start-Sleep -Milliseconds 100
  } while ([DateTime]::UtcNow -lt $deadline)
  $table = Get-ProcessTable
  Add-Descendants $table $KnownByPid $Observed
  $active = @(Active-KnownRecords $table $KnownByPid)
  if ($active.Count -ne 0) {
    throw ('Authenticated process tree did not terminate: ' +
      [string]::Join(',', @($active | ForEach-Object ProcessId)))
  }
}

function Assert-KnownTreeStopped(
  [hashtable]$KnownByPid,
  [hashtable]$Observed
) {
  $table = Get-ProcessTable
  Add-Descendants $table $KnownByPid $Observed
  $active = @(Active-KnownRecords $table $KnownByPid)
  if ($active.Count -ne 0) {
    throw ('Authenticated process tree remains active after cleanup: ' +
      [string]::Join(',', @($active | ForEach-Object ProcessId)))
  }
}

$specResolved = Resolve-ExistingFile $SpecPath 'Process specification'
if (-not (Test-Path -LiteralPath $EvidenceDir -PathType Container)) {
  New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
}
$evidenceResolved = Resolve-ExistingDirectory $EvidenceDir 'Evidence directory'
$spec = Get-Content -LiteralPath $specResolved -Raw -Encoding UTF8 | ConvertFrom-Json
if ($spec.schema -ne 'wlv-issue13-process-spec/1') {
  throw 'Unsupported process specification schema.'
}
if ([string]$spec.scenario_id -notmatch '^[a-z0-9][a-z0-9._/-]*$') {
  throw 'Process scenario_id is invalid.'
}
$scenarioId = [string]$spec.scenario_id
$workingDirectory = Resolve-ExistingDirectory ([string]$spec.working_directory) 'Working directory'
if ($evidenceResolved.StartsWith(
    $workingDirectory + [System.IO.Path]::DirectorySeparatorChar,
    [System.StringComparison]::OrdinalIgnoreCase
  )) {
  throw 'EvidenceDir must be outside the evaluated working directory.'
}

$rscriptEnvironment = [Environment]::GetEnvironmentVariable(
  'ISSUE13_V5_RSCRIPT_EXECUTABLE', 'Process')
if ([string]::IsNullOrWhiteSpace($rscriptEnvironment) -or
    -not [IO.Path]::IsPathFullyQualified($rscriptEnvironment)) {
  throw 'ISSUE13_V5_RSCRIPT_EXECUTABLE must be an absolute path.'
}
$expectedExecutable = [IO.Path]::GetFullPath($rscriptEnvironment)
$declaredExecutable = [string]$spec.executable
if ([string]::IsNullOrWhiteSpace($declaredExecutable) -or
    -not [IO.Path]::IsPathFullyQualified($declaredExecutable)) {
  throw 'Scenario executable must be an absolute path.'
}
$executable = [IO.Path]::GetFullPath($declaredExecutable)
if (-not [string]::Equals(
      $executable, $expectedExecutable,
      [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Scenario executable differs from ISSUE13_V5_RSCRIPT_EXECUTABLE.'
}
if (-not [IO.File]::Exists($executable)) {
  throw 'ISSUE13_V5_RSCRIPT_EXECUTABLE does not identify an existing file.'
}
$arguments = @($spec.arguments | ForEach-Object { [string]$_ })
$expectedExitCodes = @($spec.expected_exit_codes | ForEach-Object { [int]$_ })
if ($expectedExitCodes.Count -eq 0) { throw 'expected_exit_codes cannot be empty.' }
$timeoutSeconds = [double]$spec.timeout_seconds
$sampleIntervalMs = [int]$spec.sample_interval_ms
$shutdownGraceSeconds = [double]$spec.shutdown_grace_seconds
if ($timeoutSeconds -le 0 -or $sampleIntervalMs -lt 100 -or
    $shutdownGraceSeconds -lt 0) {
  throw 'Invalid timeout/sample/grace values.'
}
$expectedWorkers = $null
if ($null -ne $spec.expected_worker_processes) {
  $expectedWorkers = [int]$spec.expected_worker_processes
  if ($expectedWorkers -lt 0) { throw 'expected_worker_processes cannot be negative.' }
}

$stdoutPath = Join-Path $evidenceResolved 'stdout.log'
$stderrPath = Join-Path $evidenceResolved 'stderr.log'
$metricsPath = Join-Path $evidenceResolved 'process-metrics.json'
$samplesPath = Join-Path $evidenceResolved 'process-samples.csv'
foreach ($path in @($stdoutPath, $stderrPath, $metricsPath, $samplesPath)) {
  if (Test-Path -LiteralPath $path) {
    throw "Refusing to overwrite scenario evidence: $path"
  }
}

$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$sampleWriter = $null
$process = $null
$rootPid = $null
$rootExitCode = $null
$lingering = @()
$clusterClosed = $false
$lifecycleError = $null
$knownByPid = @{}
$observed = @{}
try {
  $sampleWriter = [System.IO.StreamWriter]::new(
    $samplesPath, $false, $utf8)
  $sampleWriter.WriteLine(
    'sample_at_utc,pid,parent_pid,name,created_at_utc,working_set_bytes,private_bytes,cpu_seconds'
  )
  $sampleWriter.Flush()

  $quotedArguments = @($arguments | ForEach-Object { Quote-WindowsArgument $_ })
  $started = [DateTime]::UtcNow
  $process = Invoke-Issue13WithProcessEnvironment $spec.environment {
    Start-Process `
      -FilePath $executable `
      -ArgumentList $quotedArguments `
      -WorkingDirectory $workingDirectory `
      -RedirectStandardOutput $stdoutPath `
      -RedirectStandardError $stderrPath `
      -WindowStyle Hidden `
      -PassThru
  }
  $rootPid = [int]$process.Id

$rootCreated = ''
for ($attempt = 0; $attempt -lt 20 -and [string]::IsNullOrEmpty($rootCreated); $attempt++) {
  $record = Get-CimInstance Win32_Process -Filter "ProcessId=$($process.Id)" `
    -ErrorAction SilentlyContinue
  if ($null -ne $record) {
    $rootCreated = Convert-CreationDate $record.CreationDate
  } elseif (-not $process.HasExited) {
    Start-Sleep -Milliseconds 50
  }
}
if ([string]::IsNullOrEmpty($rootCreated)) {
  try {
    $rootCreated = $process.StartTime.ToUniversalTime().ToString('o')
  } catch {
    throw 'Cannot authenticate the monitored root process generation.'
  }
}
if ([string]::IsNullOrEmpty($rootCreated)) {
  throw 'Cannot authenticate the monitored root process generation.'
}
$knownByPid[$rootPid] = $rootCreated
$rootKey = Process-Key $rootPid $rootCreated
$observed[$rootKey] = [ordered]@{
  pid = $rootPid
  parent_pid = $null
  name = [System.IO.Path]::GetFileName($executable)
  created_at_utc = $rootCreated
  first_seen_at_utc = $started.ToString('o')
  last_seen_at_utc = $started.ToString('o')
  peak_working_set_bytes = [int64]0
  peak_private_bytes = [int64]0
  peak_cpu_seconds = 0.0
}

$peakWorkingSet = [int64]0
$peakPrivate = [int64]0
$peakCpu = 0.0
$maxConcurrentProcesses = 0
$maxConcurrentWorkers = 0
$sampleCount = 0
$timedOut = $false

  while (-not $process.HasExited) {
    $now = [DateTime]::UtcNow
    if (($now - $started).TotalSeconds -gt $timeoutSeconds) {
      $timedOut = $true
      $table = Get-ProcessTable
      Add-Descendants $table $knownByPid $observed
      Stop-KnownTreeBounded $knownByPid $observed $shutdownGraceSeconds
      break
    }
    $table = Get-ProcessTable
    Add-Descendants $table $knownByPid $observed
    $active = @(Active-KnownRecords $table $knownByPid)
    $totalWorkingSet = [int64]0
    $totalPrivate = [int64]0
    $totalCpu = 0.0
    $workerCount = 0
    foreach ($record in $active) {
      $current = Get-Process -Id $record.ProcessId -ErrorAction SilentlyContinue
      if ($null -eq $current) { continue }
      $workingSet = [int64]$current.WorkingSet64
      $private = [int64]$current.PrivateMemorySize64
      $cpu = if ($null -eq $current.CPU) { 0.0 } else { [double]$current.CPU }
      $totalWorkingSet += $workingSet
      $totalPrivate += $private
      $totalCpu += $cpu
      if ($record.ProcessId -ne $rootPid -and
          $record.Name -match '^(R|Rscript|Rterm)(\.exe)?$') {
        $workerCount++
      }
      $key = Process-Key $record.ProcessId $record.Created
      $entry = $observed[$key]
      $entry.last_seen_at_utc = $now.ToString('o')
      if ($workingSet -gt $entry.peak_working_set_bytes) {
        $entry.peak_working_set_bytes = $workingSet
      }
      if ($private -gt $entry.peak_private_bytes) {
        $entry.peak_private_bytes = $private
      }
      if ($cpu -gt $entry.peak_cpu_seconds) { $entry.peak_cpu_seconds = $cpu }
      $sampleWriter.WriteLine((@(
          (Csv-Field $now.ToString('o')),
          $record.ProcessId,
          $record.ParentProcessId,
          (Csv-Field $record.Name),
          (Csv-Field $record.Created),
          $workingSet,
          $private,
          $cpu.ToString('R', [Globalization.CultureInfo]::InvariantCulture)
        ) -join ','))
    }
    if ($totalWorkingSet -gt $peakWorkingSet) { $peakWorkingSet = $totalWorkingSet }
    if ($totalPrivate -gt $peakPrivate) { $peakPrivate = $totalPrivate }
    if ($totalCpu -gt $peakCpu) { $peakCpu = $totalCpu }
    if ($active.Count -gt $maxConcurrentProcesses) {
      $maxConcurrentProcesses = $active.Count
    }
    if ($workerCount -gt $maxConcurrentWorkers) {
      $maxConcurrentWorkers = $workerCount
    }
    $sampleCount++
    if (($sampleCount % 30) -eq 0) { $sampleWriter.Flush() }
    Start-Sleep -Milliseconds $sampleIntervalMs
    $process.Refresh()
  }
  if (-not $process.HasExited -and -not $process.WaitForExit(5000)) {
    try { $process.Kill($true) } catch { }
    if (-not $process.WaitForExit(10000)) {
      throw 'Root process did not terminate after the bounded tree kill.'
    }
  }
  $process.WaitForExit()

$rootExitCode = if ($timedOut) { $null } else { [int]$process.ExitCode }
$shutdownDeadline = [DateTime]::UtcNow.AddSeconds($shutdownGraceSeconds)
$lingering = @()
do {
  $table = Get-ProcessTable
  Add-Descendants $table $knownByPid $observed
  $lingering = @(Active-KnownRecords $table $knownByPid | Where-Object {
      $_.ProcessId -ne $rootPid
    })
  if ($lingering.Count -eq 0 -or [DateTime]::UtcNow -ge $shutdownDeadline) {
    break
  }
  Start-Sleep -Milliseconds ([Math]::Min($sampleIntervalMs, 500))
} while ($true)
$clusterClosed = $lingering.Count -eq 0
if (-not $clusterClosed) {
  Stop-KnownTreeBounded $knownByPid $observed $shutdownGraceSeconds
}
} catch {
  $lifecycleError = $_
}
$cleanupFailures = [Collections.Generic.List[Exception]]::new()
if ($null -ne $sampleWriter) {
  try { $sampleWriter.Flush() } catch {
    $cleanupFailures.Add($_.Exception)
  }
  try { $sampleWriter.Dispose() } catch {
    $cleanupFailures.Add($_.Exception)
  }
}
if ($null -ne $process) {
  if ($null -ne $lifecycleError) {
    try {
      if (-not $process.HasExited) {
        $process.Kill($true)
        if (-not $process.WaitForExit($shutdownGraceSeconds * 1000)) {
          throw 'Root process did not terminate during lifecycle cleanup.'
        }
      }
    } catch {
      $cleanupFailures.Add($_.Exception)
    }
    if ($knownByPid.Count -ne 0) {
      try {
        Stop-KnownTreeBounded $knownByPid $observed $shutdownGraceSeconds
      } catch {
        $cleanupFailures.Add($_.Exception)
      }
      try {
        Assert-KnownTreeStopped $knownByPid $observed
      } catch {
        $cleanupFailures.Add($_.Exception)
      }
    }
  }
  try { $process.Dispose() } catch {
    $cleanupFailures.Add($_.Exception)
  }
}
if ($cleanupFailures.Count -ne 0) {
  $failures = [Collections.Generic.List[Exception]]::new()
  if ($null -ne $lifecycleError) {
    $failures.Add($lifecycleError.Exception)
  }
  foreach ($failure in $cleanupFailures) { $failures.Add($failure) }
  throw [AggregateException]::new(
    'Monitor process lifecycle cleanup failed.', $failures.ToArray())
}
if ($null -ne $lifecycleError) { throw $lifecycleError }

$finished = [DateTime]::UtcNow
$workerCountMatched = $true
if ($null -ne $expectedWorkers) {
  $workerCountMatched = $maxConcurrentWorkers -eq $expectedWorkers
}
$exitMatched = $false
if ($null -ne $rootExitCode) {
  $exitMatched = $expectedExitCodes -contains $rootExitCode
}
$passed = $exitMatched -and (-not $timedOut) -and $clusterClosed -and
  $workerCountMatched

$processRecords = @($observed.Values | Sort-Object pid, created_at_utc)
$metrics = [ordered]@{
  schema = 'wlv-issue13-process-metrics/2'
  scenario_id = $scenarioId
  status = if ($passed) { 'passed' } else { 'failed' }
  passed = $passed
  executable = $executable
  arguments = $arguments
  working_directory = $workingDirectory
  root_pid = $rootPid
  exit_code = $rootExitCode
  expected_exit_codes = $expectedExitCodes
  exit_code_matched = $exitMatched
  timed_out = $timedOut
  timeout_seconds = $timeoutSeconds
  started_at_utc = $started.ToString('o')
  finished_at_utc = $finished.ToString('o')
  elapsed_seconds = ($finished - $started).TotalSeconds
  sample_interval_ms = $sampleIntervalMs
  samples = $sampleCount
  peak_rss_bytes = $peakWorkingSet
  peak_private_bytes = $peakPrivate
  cumulative_cpu_seconds_peak = $peakCpu
  max_concurrent_processes = $maxConcurrentProcesses
  expected_worker_processes = $expectedWorkers
  max_concurrent_worker_processes = $maxConcurrentWorkers
  worker_count_matched = $workerCountMatched
  cluster_closed = $clusterClosed
  lingering_pids = @($lingering | ForEach-Object { $_.ProcessId })
  observed_processes = $processRecords
  stdout_path = $stdoutPath
  stderr_path = $stderrPath
  stdout_sha256 = Get-Issue13FileSha256 $stdoutPath
  stderr_sha256 = Get-Issue13FileSha256 $stderrPath
  samples_path = $samplesPath
  samples_sha256 = Get-Issue13FileSha256 $samplesPath
  process_spec_path = $specResolved
  process_spec_sha256 = Get-Issue13FileSha256 $specResolved
}

$temporaryMetrics = Join-Path $evidenceResolved (
  '.process-metrics.json-' + [Guid]::NewGuid().ToString('N'))
$json = $metrics | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($temporaryMetrics, $json + [Environment]::NewLine, $utf8)
$roundtrip = Get-Content -LiteralPath $temporaryMetrics -Raw -Encoding UTF8 | ConvertFrom-Json
if ($roundtrip.schema -ne $metrics.schema -or
    $roundtrip.scenario_id -ne $metrics.scenario_id) {
  [IO.File]::Delete($temporaryMetrics)
  throw 'Process metrics failed UTF-8 JSON round-trip validation.'
}
[System.IO.File]::Move($temporaryMetrics, $metricsPath)
$metrics | Format-List
if ($passed) { exit 0 } else { exit 1 }
