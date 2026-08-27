param([switch]$SkipSyntheticProcess)

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

function Read-Issue13ScriptAst([string]$Path, [string]$Label) {
  $tokens = $null
  $parseErrors = $null
  $resolved = Resolve-Path -LiteralPath $Path
  $ast = [Management.Automation.Language.Parser]::ParseFile(
    $resolved, [ref]$tokens, [ref]$parseErrors)
  if ($parseErrors.Count -ne 0) {
    throw "$Label parser self-test failed."
  }
  $ast
}

function Get-Issue13TopLevelFunction(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string]$Name,
  [string]$Label
) {
  $definitions = @($Ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
          $node.Name -ceq $Name
      }, $true))
  if ($definitions.Count -ne 1 -or
      $definitions[0].Parent -isnot
        [Management.Automation.Language.NamedBlockAst] -or
      $definitions[0].Parent.Parent -ne $Ast) {
    throw "$Label must define exactly one top-level $Name helper."
  }
  $definitions[0]
}

function Assert-Issue13EnvironmentState(
  [string]$Name,
  [bool]$Present,
  [AllowNull()][string]$Value,
  [string]$Label
) {
  $state = @(Get-Issue13ProcessEnvironmentState -Names @($Name))
  if ($state.Count -ne 1 -or $state[0].present -ne $Present -or
      ($Present -and [string]$state[0].value -cne $Value) -or
      ((-not $Present) -and $null -ne $state[0].value)) {
    throw "$Label environment state differs."
  }
}

& {
$monitorAst = Read-Issue13ScriptAst `
  (Join-Path $PSScriptRoot 'issue13-monitor.ps1') 'Monitor'
$recalcAst = Read-Issue13ScriptAst `
  (Join-Path $PSScriptRoot 'issue13-run-recalc-bundle.ps1') `
  'Recalculation bundle runner'
$environmentHelpers = [ordered]@{
  'Get-Issue13ProcessEnvironmentState' =
    'Get-Issue13ProcessEnvironmentStateRecalc'
  'Set-Issue13ProcessEnvironmentState' =
    'Set-Issue13ProcessEnvironmentStateRecalc'
  'Invoke-Issue13WithProcessEnvironment' =
    'Invoke-Issue13WithProcessEnvironmentRecalc'
}
foreach ($mapping in $environmentHelpers.GetEnumerator()) {
  $name = [string]$mapping.Key
  $monitorDefinition = Get-Issue13TopLevelFunction $monitorAst $name 'Monitor'
  $recalcDefinition = Get-Issue13TopLevelFunction `
    $recalcAst ([string]$mapping.Value) `
    'Recalculation bundle runner'
  $normalizedRecalcText = [string]$recalcDefinition.Extent.Text
  foreach ($normalization in $environmentHelpers.GetEnumerator()) {
    $normalizedRecalcText = $normalizedRecalcText.Replace(
      [string]$normalization.Value, [string]$normalization.Key)
  }
  if ($monitorDefinition.Extent.Text -cne $normalizedRecalcText) {
    throw "Process-environment helper differs between runners: $name"
  }
  Invoke-Expression $monitorDefinition.Extent.Text
}

$testSuffix = [Guid]::NewGuid().ToString('N')
$absentName = 'WLV13_ENV_ABSENT_' + $testSuffix
$emptyName = 'WLV13_ENV_EMPTY_' + $testSuffix
$valueName = 'WLV13_ENV_VALUE_' + $testSuffix
$removedName = 'WLV13_ENV_REMOVED_' + $testSuffix
$controlName = 'WLV13_ENV_CONTROL_' + $testSuffix
$externalState = @(Get-Issue13ProcessEnvironmentState -Names @(
      $absentName, $emptyName, $valueName, $removedName, $controlName))
try {
  Set-Issue13ProcessEnvironmentState -States @(
    [pscustomobject][ordered]@{
      name = $absentName; present = $false; value = $null
    },
    [pscustomobject][ordered]@{
      name = $emptyName; present = $true; value = ''
    },
    [pscustomobject][ordered]@{
      name = $valueName; present = $true; value = 'outside'
    },
    [pscustomobject][ordered]@{
      name = $removedName; present = $true; value = 'remove-me'
    },
    [pscustomobject][ordered]@{
      name = $controlName; present = $true; value = 'control'
    }
  )
  $environment = [pscustomobject][ordered]@{}
  $environment.PSObject.Properties.Add(
    [Management.Automation.PSNoteProperty]::new($absentName, 'inside'))
  $environment.PSObject.Properties.Add(
    [Management.Automation.PSNoteProperty]::new($emptyName, 'filled'))
  $environment.PSObject.Properties.Add(
    [Management.Automation.PSNoteProperty]::new($valueName, ''))
  $environment.PSObject.Properties.Add(
    [Management.Automation.PSNoteProperty]::new($removedName, $null))
  $actionResult = Invoke-Issue13WithProcessEnvironment $environment {
    Assert-Issue13EnvironmentState $absentName $true 'inside' 'Absent input'
    Assert-Issue13EnvironmentState $emptyName $true 'filled' 'Empty input'
    Assert-Issue13EnvironmentState $valueName $true '' 'Value input'
    Assert-Issue13EnvironmentState $removedName $false $null 'Null input'
    Assert-Issue13EnvironmentState $controlName $true 'control' `
      'Undeclared control'
    'environment-action-result'
  }
  if ($actionResult -cne 'environment-action-result') {
    throw 'Environment action result was not preserved.'
  }
  Assert-Issue13EnvironmentState $absentName $false $null 'Absent restore'
  Assert-Issue13EnvironmentState $emptyName $true '' 'Empty restore'
  Assert-Issue13EnvironmentState $valueName $true 'outside' 'Value restore'
  Assert-Issue13EnvironmentState $removedName $true 'remove-me' `
    'Null restore'
  Assert-Issue13EnvironmentState $controlName $true 'control' `
    'Undeclared control restore'

  $actionFailed = $false
  try {
    Invoke-Issue13WithProcessEnvironment $environment {
      throw 'issue13-environment-action-failure'
    }
  } catch {
    $actionFailed = $_.Exception.Message -match
      'issue13-environment-action-failure'
  }
  if (-not $actionFailed) {
    throw 'Environment action exception was not propagated.'
  }
  Assert-Issue13EnvironmentState $absentName $false $null `
    'Exceptional absent restore'
  Assert-Issue13EnvironmentState $emptyName $true '' `
    'Exceptional empty restore'
  Assert-Issue13EnvironmentState $valueName $true 'outside' `
    'Exceptional value restore'
  Assert-Issue13EnvironmentState $removedName $true 'remove-me' `
    'Exceptional null restore'
  Assert-Issue13EnvironmentState $controlName $true 'control' `
    'Exceptional undeclared control restore'

  foreach ($invalidValue in @([int64]7, $true)) {
    $invalidEnvironment = [pscustomobject][ordered]@{}
    $invalidEnvironment.PSObject.Properties.Add(
      [Management.Automation.PSNoteProperty]::new(
        $valueName, $invalidValue))
    $invalidRan = $false
    $invalidRejected = $false
    try {
      Invoke-Issue13WithProcessEnvironment $invalidEnvironment {
        $invalidRan = $true
      }
    } catch {
      $invalidRejected = $true
    }
    if (-not $invalidRejected -or $invalidRan) {
      throw 'Non-string environment value was accepted.'
    }
    Assert-Issue13EnvironmentState $valueName $true 'outside' `
      'Invalid value rollback'
  }
  $presentNullRejected = $false
  try {
    Set-Issue13ProcessEnvironmentState -States @(
      [pscustomobject][ordered]@{
        name = $valueName; present = $true; value = $null
      }
    )
  } catch {
    $presentNullRejected = $true
  }
  if (-not $presentNullRejected) {
    throw 'Present environment state with a null value was accepted.'
  }
  Assert-Issue13EnvironmentState $valueName $true 'outside' `
    'Present-null rejection'

  $partialEnvironment = [pscustomobject][ordered]@{}
  $partialEnvironment.PSObject.Properties.Add(
    [Management.Automation.PSNoteProperty]::new($absentName, 'partial'))
  $partialEnvironment.PSObject.Properties.Add(
    [Management.Automation.PSNoteProperty]::new(
      $valueName, "truncated`0value"))
  $partialFailed = $false
  $partialProbe = [pscustomobject]@{ ran = $false }
  try {
    Invoke-Issue13WithProcessEnvironment $partialEnvironment {
      $partialProbe.ran = $true
    }
  } catch {
    $partialFailed = $true
  }
  if (-not $partialFailed -or $partialProbe.ran) {
    throw 'Partial environment application did not fail before its action.'
  }
  Assert-Issue13EnvironmentState $absentName $false $null `
    'Partial absent rollback'
  Assert-Issue13EnvironmentState $valueName $true 'outside' `
    'Partial value rollback'
  Assert-Issue13EnvironmentState $controlName $true 'control' `
    'Partial undeclared control rollback'
} finally {
  Set-Issue13ProcessEnvironmentState -States $externalState
}

$wantedFunctions = @('Process-Key', 'Add-Descendants')
foreach ($name in $wantedFunctions) {
  $definition = Get-Issue13TopLevelFunction $monitorAst $name 'Monitor'
  Invoke-Expression $definition.Extent.Text
}
$parentOld = '2026-08-19T12:00:00.0000000+00:00'
$parentCurrent = '2026-08-24T12:00:00.0000000+00:00'
$childEarlier = '2026-08-20T12:00:00.0000000+00:00'
$childLater = '2026-08-24T12:00:01.0000000+00:00'
$rootRecord = [pscustomobject]@{
  ProcessId = 41700; ParentProcessId = 1; Name = 'Rscript.exe'
  Created = $parentCurrent
}
$persistentRecord = [pscustomobject]@{
  ProcessId = 30272; ParentProcessId = 41700; Name = 'Rscript.exe'
  Created = $childEarlier
}
$known = @{ 41700 = $parentCurrent }
$observed = @{}
Add-Descendants @($rootRecord, $persistentRecord) $known $observed
if ($known.ContainsKey(30272)) {
  throw 'Monitor adopted a child created before its authenticated parent.'
}
$laterChild = [pscustomobject]@{
  ProcessId = 50001; ParentProcessId = 41700; Name = 'Rscript.exe'
  Created = $childLater
}
$known = @{ 41700 = $parentOld }
$observed = @{}
Add-Descendants @($rootRecord, $laterChild) $known $observed
if ($known.ContainsKey(50001)) {
  throw 'Monitor adopted a child through a reused parent PID.'
}
$known = @{ 41700 = $parentCurrent }
$observed = @{}
Add-Descendants @($rootRecord, $laterChild) $known $observed
if (-not $known.ContainsKey(50001) -or
    [string]$known[50001] -cne $childLater) {
  throw 'Monitor rejected a valid authenticated parent/child generation.'
}
}
if ($SkipSyntheticProcess) {
  Write-Output 'issue13 monitor environment self-test: PASS'
  return
}
$temporaryParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$temporaryRoot = Join-Path $temporaryParent `
  ('wlv13-monitor-selftest-' + [Guid]::NewGuid().ToString('N'))
$resolvedCandidate = [IO.Path]::GetFullPath($temporaryRoot)
if (-not $resolvedCandidate.StartsWith(
    $temporaryParent,
    [StringComparison]::OrdinalIgnoreCase
  )) {
  throw 'Self-test root escaped the system temporary directory.'
}
$working = Join-Path $temporaryRoot 'work'
$evidence = Join-Path $temporaryRoot 'evidence'
$specPath = Join-Path $temporaryRoot 'process-spec.json'
try {
  New-Item -ItemType Directory -Path $working | Out-Null
  $rscriptEnvironment = [Environment]::GetEnvironmentVariable(
    'ISSUE13_V5_RSCRIPT_EXECUTABLE', 'Process')
  if ([string]::IsNullOrWhiteSpace($rscriptEnvironment) -or
      -not [IO.Path]::IsPathFullyQualified($rscriptEnvironment)) {
    throw 'ISSUE13_V5_RSCRIPT_EXECUTABLE must be an absolute path.'
  }
  $rscript = [IO.Path]::GetFullPath($rscriptEnvironment)
  if (-not [IO.File]::Exists($rscript)) {
    throw 'ISSUE13_V5_RSCRIPT_EXECUTABLE does not identify an existing file.'
  }
  $spec = [ordered]@{
    schema = 'wlv-issue13-process-spec/1'
    scenario_id = 'selftest/monitor'
    executable = $rscript
    arguments = @('--vanilla', '-e', 'Sys.sleep(0.35)')
    working_directory = $working
    environment = $null
    expected_exit_codes = @(0)
    timeout_seconds = 10
    sample_interval_ms = 100
    shutdown_grace_seconds = 2
    expected_worker_processes = 0
  }
  $utf8 = [Text.UTF8Encoding]::new($false, $true)
  [IO.File]::WriteAllText(
    $specPath,
    ($spec | ConvertTo-Json -Depth 8) + [Environment]::NewLine,
    $utf8
  )
  & (Join-Path $PSScriptRoot 'issue13-monitor.ps1') `
    -SpecPath $specPath -EvidenceDir $evidence | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Monitor self-test process failed.' }
  $metricsPath = Join-Path $evidence 'process-metrics.json'
  $metrics = Get-Content -LiteralPath $metricsPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
  if (-not $metrics.passed -or $metrics.timed_out -or
      -not $metrics.cluster_closed -or
      $metrics.max_concurrent_worker_processes -ne 0 -or
      $metrics.samples -lt 1) {
    throw 'Monitor self-test metrics violated an invariant.'
  }
  Write-Output 'issue13 monitor synthetic self-test: PASS'
} finally {
  if (Test-Path -LiteralPath $temporaryRoot) {
    $resolved = [IO.Path]::GetFullPath($temporaryRoot)
    if (-not $resolved.StartsWith(
        $temporaryParent,
        [StringComparison]::OrdinalIgnoreCase
      )) {
      throw 'Refusing to clean a self-test path outside the temporary root.'
    }
    [IO.Directory]::Delete($resolved, $true)
  }
}
