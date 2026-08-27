param(
  [Parameter(Mandatory = $true)][string]$ConfigPath,
  [Parameter(Mandatory = $true)][string]$StatePath,
  [Parameter(Mandatory = $true)][string]$Output,
  [switch]$ConfirmWriteReport
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

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $ConfirmWriteReport) {
  throw 'Report generation requires -ConfirmWriteReport.'
}
$scriptRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path

function ConvertTo-Issue13V5RendererSourceToolingJson(
  [object]$Tooling,
  [string]$Label
) {
  $null = Assert-Issue13V5ExactPropertyNames $Tooling @(
    'candidate_commit', 'repository_relative_root', 'root', 'physical_root',
    'file_count', 'directory_count', 'total_bytes', 'path_list_sha256',
    'inventory_sha256', 'trees', 'records'
  ) $Label
  if (-not ($Tooling.candidate_commit -is [string]) -or
      [string]$Tooling.candidate_commit -cnotmatch '^[0-9a-f]{40}$' -or
      -not ($Tooling.repository_relative_root -is [string]) -or
      -not ($Tooling.root -is [string]) -or
      -not ($Tooling.physical_root -is [string]) -or
      -not ($Tooling.file_count -is [long]) -or
      -not ($Tooling.directory_count -is [long]) -or
      -not ($Tooling.total_bytes -is [long]) -or
      -not ($Tooling.path_list_sha256 -is [string]) -or
      [string]$Tooling.path_list_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      -not ($Tooling.inventory_sha256 -is [string]) -or
      [string]$Tooling.inventory_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      -not ($Tooling.trees -is [array]) -or
      -not ($Tooling.records -is [array])) {
    throw "$Label has a malformed source-tooling envelope."
  }
  $trees = @($Tooling.trees | ForEach-Object {
    $null = Assert-Issue13V5ExactPropertyNames $_ @(
      'relative_path', 'repository_path', 'mode', 'type', 'tree'
    ) "$Label tree"
    if (-not ($_.relative_path -is [string]) -or
        -not ($_.repository_path -is [string]) -or
        -not ($_.mode -is [string]) -or -not ($_.type -is [string]) -or
        -not ($_.tree -is [string])) {
      throw "$Label has a malformed Git tree record."
    }
    [ordered]@{
      relative_path = [string]$_.relative_path
      repository_path = [string]$_.repository_path
      mode = [string]$_.mode
      type = [string]$_.type
      tree = [string]$_.tree
    }
  })
  $records = @($Tooling.records | ForEach-Object {
    $null = Assert-Issue13V5ExactPropertyNames $_ @(
      'relative_path', 'repository_path', 'size_bytes', 'sha256', 'mode',
      'type', 'blob'
    ) "$Label file"
    if (-not ($_.relative_path -is [string]) -or
        -not ($_.repository_path -is [string]) -or
        -not ($_.size_bytes -is [long]) -or
        -not ($_.sha256 -is [string]) -or
        -not ($_.mode -is [string]) -or -not ($_.type -is [string]) -or
        -not ($_.blob -is [string])) {
      throw "$Label has a malformed Git blob record."
    }
    [ordered]@{
      relative_path = [string]$_.relative_path
      repository_path = [string]$_.repository_path
      size_bytes = [long]$_.size_bytes
      sha256 = [string]$_.sha256
      mode = [string]$_.mode
      type = [string]$_.type
      blob = [string]$_.blob
    }
  })
  $canonical = [ordered]@{
    candidate_commit = [string]$Tooling.candidate_commit
    repository_relative_root = [string]$Tooling.repository_relative_root
    root = [string]$Tooling.root
    physical_root = [string]$Tooling.physical_root
    file_count = [long]$Tooling.file_count
    directory_count = [long]$Tooling.directory_count
    total_bytes = [long]$Tooling.total_bytes
    path_list_sha256 = [string]$Tooling.path_list_sha256
    inventory_sha256 = [string]$Tooling.inventory_sha256
    trees = [object[]]$trees
    records = [object[]]$records
  }
  ConvertTo-Json -InputObject $canonical -Depth 20 -Compress
}

function ConvertTo-Issue13V5RendererRscriptJson(
  [object]$Identity,
  [string]$Label
) {
  $null = Assert-Issue13V5ExactPropertyNames $Identity @(
    'logical_path', 'physical_path', 'item_id', 'link_count', 'size_bytes',
    'sha256'
  ) $Label
  if (-not ($Identity.logical_path -is [string]) -or
      [string]::IsNullOrWhiteSpace([string]$Identity.logical_path) -or
      -not ($Identity.physical_path -is [string]) -or
      [string]::IsNullOrWhiteSpace([string]$Identity.physical_path) -or
      -not ($Identity.item_id -is [string]) -or
      [string]$Identity.item_id -cnotmatch '^[0-9a-f]{16}:[0-9a-f]{32}$' -or
      -not ($Identity.link_count -is [long]) -or
      [long]$Identity.link_count -le 0L -or
      -not ($Identity.size_bytes -is [long]) -or
      [long]$Identity.size_bytes -le 0L -or
      -not ($Identity.sha256 -is [string]) -or
      [string]$Identity.sha256 -cnotmatch '^[0-9a-f]{64}$') {
    throw "$Label has a malformed Rscript identity."
  }
  $canonical = [ordered]@{
    logical_path = [string]$Identity.logical_path
    physical_path = [string]$Identity.physical_path
    item_id = [string]$Identity.item_id
    link_count = [long]$Identity.link_count
    size_bytes = [long]$Identity.size_bytes
    sha256 = [string]$Identity.sha256
  }
  ConvertTo-Json -InputObject $canonical -Depth 5 -Compress
}

$initialConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$initialConfigSha256 = Get-Issue13V5Sha256 $initialConfigPath
$binding = Assert-Issue13V5Config $ConfigPath
$config = $binding.config
if (-not [string]::Equals(
    (ConvertTo-Issue13V5Path ([string]$binding.path)),
    (ConvertTo-Issue13V5Path $initialConfigPath),
    [StringComparison]::OrdinalIgnoreCase) -or
    [string]$binding.sha256 -cne $initialConfigSha256 -or
    (Get-Issue13V5Sha256 $initialConfigPath) -cne $initialConfigSha256) {
  throw 'Report config changed while its initial binding was authenticated.'
}
$initialConfigCanonical = ConvertTo-Json -InputObject $config -Depth 100 `
  -Compress
$initialConfigDiskCanonical = ConvertTo-Json -InputObject (
  Read-Issue13V5Json $initialConfigPath) -Depth 100 -Compress
if ($initialConfigCanonical -cne $initialConfigDiskCanonical -or
    (Get-Issue13V5Sha256 $initialConfigPath) -cne $initialConfigSha256) {
  throw 'Report config content changed after its initial binding was read.'
}
$expectedStatePath = ConvertTo-Issue13V5Path (Get-Issue13V5StatePath $config)
$providedStatePath = ConvertTo-Issue13V5Path (
  (Resolve-Path -LiteralPath $StatePath).Path)
if (-not [string]::Equals($providedStatePath, $expectedStatePath,
    [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Report state path is not the canonical control-root gate-state.json.'
}
$initialStateSha256 = Get-Issue13V5Sha256 $providedStatePath
$state = Read-Issue13V5State $config $binding.sha256
$initialStateCanonical = ConvertTo-Json -InputObject $state -Depth 100 `
  -Compress
$initialStateDiskCanonical = ConvertTo-Json -InputObject (
  Read-Issue13V5Json $providedStatePath) -Depth 100 -Compress
if ((Get-Issue13V5Sha256 $providedStatePath) -cne $initialStateSha256 -or
    $initialStateCanonical -cne $initialStateDiskCanonical) {
  throw 'Report state changed while its initial binding was authenticated.'
}
if ([string]$state.schema -cne 'wlv-issue13-v5-coordinator-state/1' -or
    [string]$state.config_sha256 -cne [string]$binding.sha256 -or
    [string]$state.final_aggregate.status -cne 'passed' -or
    [string]$state.prep_fault.aggregate_status -cne 'passed' -or
    @($state.phases | Where-Object comparison_status -cne 'completed').Count `
      -ne 0 -or
    @($state.prep_fault.faults | Where-Object status -cne 'executed').Count `
      -ne 0) {
  throw 'Only a complete passed V5 state can produce the report.'
}
if ((Get-Issue13V5Sha256 $state.final_aggregate.path) -cne
    [string]$state.final_aggregate.sha256) {
  throw 'Final aggregate changed before report generation.'
}
$null = Assert-Issue13V5FinalBindings $config $state

$repository = (Resolve-Path -LiteralPath $config.repository_root).Path
$head = (Invoke-Issue13V5SealedGit `
  -C $repository rev-parse HEAD 2>$null).Trim()
$trackedStatus = @(Invoke-Issue13V5SealedGit `
  -C $repository status '--porcelain=v1' `
  '--untracked-files=no' 2>$null)
if ($LASTEXITCODE -ne 0 -or $head -cne [string]$config.candidate_commit -or
    $trackedStatus.Count -ne 0) {
  throw 'Report generation requires the pinned candidate HEAD and tracked-clean tree.'
}

$outputPath = ConvertTo-Issue13V5Path $Output
if (Test-Path -LiteralPath $outputPath) {
  throw "Report output already exists: $outputPath"
}
$expectedOutput = ConvertTo-Issue13V5Path (
  Join-Path $repository ([string]$config.report.required_path))
if (-not [string]::Equals($outputPath, $expectedOutput,
    [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Report output differs from the configured required path.'
}

$aggregatePath = [string]$state.final_aggregate.path
$aggregateRoot = Split-Path -Parent $aggregatePath
$aggregate = Read-Issue13V5Json $aggregatePath
$prepFault = Read-Issue13V5Json $state.prep_fault.aggregate_path
$strictSmoke = Read-Issue13V5Json $config.strict_baseline_smoke.path
$compatibilitySmoke = Read-Issue13V5Json `
  $config.compatibility_baseline_smoke.path
$preparation = Read-Issue13V5Json `
  $state.prep_fault.preparation_comparison_path
$preparationPassed = [string]$preparation.status -ceq 'passed'
$paperComparisonPath = Join-Path (
  Get-Issue13V5ComparisonDirectory $config 'parity/paper/0') 'comparison.json'
$paperComparison = Read-Issue13V5Json $paperComparisonPath
$performance = @(Import-Csv -LiteralPath (
  Join-Path $aggregateRoot 'performance.csv'))
$oracle = @(Import-Csv -LiteralPath (
  Join-Path $aggregateRoot 'oracle-classification.csv'))
$checks = @(Import-Csv -LiteralPath (Join-Path $aggregateRoot 'checks.csv'))
$expectedSciencePhases = @(Get-Issue13V5ExpectedSciencePhases)
$expectedPerformanceScenarios = @(
  @($expectedSciencePhases.phase) + @('prepare/all', 'paper/0') | Sort-Object)
$observedPerformanceScenarios = @($performance.scenario | Sort-Object)
$expectedOraclePhases = @($expectedSciencePhases |
  Where-Object kind -ceq 'recalculate' | ForEach-Object phase | Sort-Object)
$observedOraclePhases = @($oracle.phase | Sort-Object)
if ($performance.Count -ne 76 -or
    @($performance.scenario | Sort-Object -Unique).Count -ne 76 -or
    [string]::Join("`n", $observedPerformanceScenarios) -cne
      [string]::Join("`n", $expectedPerformanceScenarios) -or
    @($performance | Where-Object {
      [string]$_.time_passed -cne 'TRUE' -or
      [string]$_.rss_passed -cne 'TRUE' -or
      [string]$_.rss_recomputed_from_authenticated_samples -cne 'TRUE' -or
      [long]$_.baseline_rss_sample_count -le 0L -or
      [long]$_.candidate_rss_sample_count -le 0L -or
      [string]$_.baseline_samples_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$_.candidate_samples_sha256 -cnotmatch '^[0-9a-f]{64}$'
    }).Count -ne 0 -or
    $oracle.Count -ne 60 -or
    @($oracle.phase | Sort-Object -Unique).Count -ne 60 -or
    [string]::Join("`n", $observedOraclePhases) -cne
      [string]::Join("`n", $expectedOraclePhases) -or
    @($oracle | Where-Object {
      [string]$_.delta_schema -cne
        'wlv-issue13-complete-recalculation-delta/1' -or
      [string]$_.complete_delta_equal -cne 'TRUE' -or
      [string]$_.baseline_delta_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$_.candidate_delta_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$_.baseline_delta_sha256 -cne
        [string]$_.candidate_delta_sha256
    }).Count -ne 0 -or
    $checks.Count -le 0 -or
    $checks.Count -ne [long]$aggregate.check_count -or
    @($checks | Where-Object { [string]$_.passed -cne 'TRUE' }).Count -ne 0 -or
    -not $preparationPassed -or
    -not (Test-Issue13V5ExactBoolean $paperComparison.passed $true) -or
    -not (Test-Issue13V5ExactBoolean $strictSmoke.passed $false) -or
    [long]$strictSmoke.passed_count -ne 5 -or
    [long]$strictSmoke.failed_count -ne 7 -or
    -not (Test-Issue13V5ExactBoolean $compatibilitySmoke.passed $true) -or
    [long]$compatibilitySmoke.passed_count -ne 12 -or
    [long]$compatibilitySmoke.failed_count -ne 0) {
  throw 'Passed aggregate tables or paper comparison are inconsistent.'
}

$oraclePath = Join-Path $aggregateRoot 'oracle-classification.csv'
$performancePath = Join-Path $aggregateRoot 'performance.csv'
$oracleDeltaPayload = [string]::Join("`n", @($oracle | Sort-Object phase |
  ForEach-Object {
    [string]$_.phase + '|' + [string]$_.method + '|' +
      [string]$_.delta_schema + '|' +
      [string]$_.baseline_delta_sha256 + '|' +
      [string]$_.candidate_delta_sha256 + '|' +
      [string]$_.complete_delta_equal
  }))
$rssEvidencePayload = [string]::Join("`n", @($performance |
  Sort-Object scenario | ForEach-Object {
    [string]$_.scenario + '|' + [string]$_.baseline_rss_sample_count + '|' +
      [string]$_.candidate_rss_sample_count + '|' +
      [string]$_.baseline_samples_sha256 + '|' +
      [string]$_.candidate_samples_sha256
  }))
$oracleDeltaInventorySha256 = Get-Issue13V5TextSha256 $oracleDeltaPayload
$rssEvidenceInventorySha256 = Get-Issue13V5TextSha256 $rssEvidencePayload

$commandRoot = Join-Path ([string]$config.control_root) 'commands'
$commandEntries = @(Get-ChildItem -LiteralPath $commandRoot -Filter '*.json' `
  -File | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{
      path = $_.FullName
      sha256 = Get-Issue13V5Sha256 $_.FullName
      document = Read-Issue13V5Json $_.FullName
    }
  })
$commandRecords = @($commandEntries | ForEach-Object document)
$expectedCommandFields = [string[]]@(
  'schema', 'label', 'executable', 'arguments', 'environment_set',
  'environment_cleared', 'working_directory', 'started_at_utc',
  'finished_at_utc', 'timeout_seconds', 'timed_out', 'exit_code',
  'expected_exit_codes', 'stdout_path', 'stdout_sha256', 'stderr_path',
  'stderr_sha256'
)
if ($commandRecords.Count -le 0) {
  throw 'No V5 command record is available for the report.'
}
foreach ($record in $commandRecords) {
  $null = Assert-Issue13V5ExactPropertyNames $record $expectedCommandFields `
    'V5 command record'
  if ([string]$record.schema -cne 'wlv-issue13-v5-command/1' -or
      -not ($record.label -is [string]) -or
      [string]::IsNullOrWhiteSpace([string]$record.label) -or
      -not ($record.executable -is [string]) -or
      [string]::IsNullOrWhiteSpace([string]$record.executable) -or
      -not ($record.arguments -is [array]) -or
      @($record.arguments | Where-Object { -not ($_ -is [string]) }).Count `
        -ne 0 -or
      -not ($record.environment_set -is [array]) -or
      -not ($record.environment_cleared -is [array]) -or
      -not ($record.expected_exit_codes -is [array]) -or
      @($record.expected_exit_codes).Count -le 0 -or
      @($record.expected_exit_codes | Where-Object {
        -not ($_ -is [long])
      }).Count -ne 0 -or
      @($record.expected_exit_codes | Sort-Object -Unique).Count -ne
        @($record.expected_exit_codes).Count -or
      -not ($record.working_directory -is [string]) -or
      [string]::IsNullOrWhiteSpace([string]$record.working_directory) -or
      -not ($record.started_at_utc -is [string]) -or
      -not ($record.finished_at_utc -is [string]) -or
      -not ($record.timeout_seconds -is [long]) -or
      [long]$record.timeout_seconds -le 0L -or
      -not ($record.exit_code -is [long]) -or
      [long]$record.exit_code -notin @([long[]]$record.expected_exit_codes) -or
      -not (Test-Issue13V5ExactBoolean $record.timed_out $false) -or
      -not ($record.stdout_path -is [string]) -or
      -not ($record.stderr_path -is [string]) -or
      [string]$record.stdout_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$record.stderr_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      (Get-Issue13V5Sha256 ([string]$record.stdout_path)) -cne
        [string]$record.stdout_sha256 -or
      (Get-Issue13V5Sha256 ([string]$record.stderr_path)) -cne
        [string]$record.stderr_sha256) {
    throw "Command record is incomplete, failed, or changed: $($record.label)"
  }
  $setNames = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  foreach ($entry in @($record.environment_set)) {
    $null = Assert-Issue13V5ExactPropertyNames $entry @('name', 'value') `
      "Command environment_set item: $($record.label)"
    if (-not ($entry.name -is [string]) -or
        [string]$entry.name -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or
        -not ($entry.value -is [string]) -or
        -not $setNames.Add([string]$entry.name)) {
      throw "Invalid or duplicate environment_set item: $($record.label)"
    }
  }
  $clearedNames = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  foreach ($name in @($record.environment_cleared)) {
    if (-not ($name -is [string]) -or
        [string]$name -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or
        -not $clearedNames.Add([string]$name) -or
        $setNames.Contains([string]$name)) {
      throw ('Invalid, duplicate, or overlapping environment_cleared item: ' +
        [string]$record.label)
    }
  }
}
$commandInventory = Get-Issue13V5TreeInventory $commandRoot
$evidenceInventory = Get-Issue13V5TreeInventory $config.evidence_root
$aggregateInventory = Get-Issue13V5TreeInventory $aggregateRoot
$oracleEffectProof = Read-Issue13V5Json $config.oracle_effect.proof.path
$oracleEffectControl = Assert-Issue13V5OracleEffectControlRecord $config $state `
  $binding.oracle_effect_validation
$oracleWorkflow = $oracleEffectProof.evidence.comparison_workflow
$oracleCommon = @($oracleWorkflow.comparisons)
$oracleCommands = @($oracleWorkflow.commands)
$oracleApprovedRuns = @($oracleEffectProof.evidence.approved_run_immutability)
$oracleRecovered = @($oracleEffectProof.evidence.recovered_methods)
$oracleTerminalRuntime = $oracleEffectProof.evidence.terminal_runtime
$oracleTerminalHarness =
  $oracleTerminalRuntime.comparison_harness
$oracleSourceController = $oracleTerminalHarness.source_controller
$oracleRLibrary = $oracleTerminalRuntime.r_library
$oracleRuntimeImmutability = $oracleTerminalRuntime.runtime_immutability
if ([string]$oracleEffectProof.schema -cne
      'wlv-issue13-v5-oracle-effect-proof/2' -or
    $oracleCommon.Count -ne 5 -or $oracleCommands.Count -ne 10 -or
    $oracleApprovedRuns.Count -ne 17 -or $oracleRecovered.Count -ne 7 -or
    @($oracleCommon.method | Sort-Object -Unique).Count -ne 5 -or
    @($oracleApprovedRuns | Where-Object {
      -not (Test-Issue13V5ExactBoolean $_.immutable $true)
    }).Count `
      -ne 0 -or
    @($oracleRecovered.method | Sort-Object -Unique).Count -ne 7 -or
    -not (Test-Issue13V5ExactBoolean $oracleWorkflow.generator_created_both_roots $true) -or
    -not (Test-Issue13V5ExactBoolean $oracleEffectProof.conclusion.strict_common_primary_and_replay_passed $true) -or
    [long]$oracleEffectProof.conclusion.approved_run_count -ne 17L -or
    -not (Test-Issue13V5ExactBoolean $oracleEffectProof.conclusion.approved_runs_immutable $true) -or
    [string]$oracleTerminalHarness.generation -cne 'v5-terminal' -or
    [string]$oracleTerminalHarness.expected_candidate_commit -cne
      [string]$config.candidate_commit -or
    -not (Test-Issue13V5ExactBoolean $oracleEffectProof.final_evidence_eligible $false) -or
    -not (Test-Issue13V5ExactBoolean $oracleEffectProof.conclusion.oracle_effect_closed $true) -or
    -not (Test-Issue13V5ExactBoolean $oracleEffectProof.conclusion.final_v5_gate_substituted $false)) {
  throw 'Oracle-effect proof does not contain the exact closed 5+7 partition.'
}
$oracleControllerRecords = @($oracleSourceController.records)
$configuredOracleController =
  $config.oracle_effect.comparison_harness.source_controller
if ([long]$oracleSourceController.file_count -ne 34L -or
    $oracleControllerRecords.Count -ne 34 -or
    @($oracleControllerRecords.name | Sort-Object -Unique).Count -ne 34 -or
    [string]$oracleSourceController.commit_sha256 -cne
      [string]$config.candidate_commit -or
    [string]$oracleTerminalHarness.source_controller_commit_sha256 -cne
      [string]$config.candidate_commit -or
    [string]$oracleSourceController.inventory_sha256 -cne
      [string]$configuredOracleController.inventory_sha256 -or
    ($oracleSourceController | ConvertTo-Json -Depth 30 -Compress) -cne
      ($configuredOracleController | ConvertTo-Json -Depth 30 -Compress)) {
  throw 'Oracle-effect terminal source-controller inventory changed.'
}
$harnessManifest = Read-Issue13V5Json $config.harness_manifest_path
$manifestSourceTooling = $harnessManifest.source_tooling
$configuredSourceTooling =
  $config.oracle_effect.comparison_harness.source_tooling
$oracleSourceTooling = $oracleTerminalHarness.source_tooling
$manifestSourceToolingJson =
  ConvertTo-Issue13V5RendererSourceToolingJson `
    $manifestSourceTooling 'Harness-manifest source tooling'
$configuredSourceToolingJson =
  ConvertTo-Issue13V5RendererSourceToolingJson `
    $configuredSourceTooling 'Configured source tooling'
$oracleSourceToolingJson =
  ConvertTo-Issue13V5RendererSourceToolingJson `
    $oracleSourceTooling 'Oracle-proof source tooling'
if ($manifestSourceToolingJson -cne $configuredSourceToolingJson -or
    $manifestSourceToolingJson -cne $oracleSourceToolingJson) {
  throw 'Source-tooling bindings differ among manifest, config, and proof.'
}
$sourceToolingRoot = (Resolve-Path -LiteralPath (
  [string]$oracleSourceTooling.root)).Path
$expectedSourceToolingRoot = (Resolve-Path -LiteralPath (
  Join-Path $repository 'run_logs/issue13-evidence-source-v5')).Path
$sourceToolingRecords = @($oracleSourceTooling.records)
$sourceToolingTrees = @($oracleSourceTooling.trees)
$sourceToolingRelativePaths = [string[]]@(
  $sourceToolingRecords | ForEach-Object { [string]$_.relative_path })
$sourceToolingPathListSha256 = Get-Issue13V5TextSha256 (
  [string]::Join("`n", $sourceToolingRelativePaths))
$sourceToolingInventory = Get-Issue13V5TreeInventory $sourceToolingRoot
$sourceToolingPhysicalRoot = ConvertTo-Issue13V5PhysicalPath `
  $sourceToolingRoot 'Issue #13 source tooling root'
if ([long]$oracleSourceTooling.file_count -ne 37L -or
    [long]$oracleSourceTooling.directory_count -ne 1L -or
    $sourceToolingRecords.Count -ne 37 -or
    $sourceToolingTrees.Count -ne 2 -or
    @($sourceToolingRelativePaths | Sort-Object -Unique).Count -ne 37 -or
    [string]$oracleSourceTooling.candidate_commit -cne
      [string]$config.candidate_commit -or
    [string]$oracleSourceTooling.repository_relative_root -cne
      'run_logs/issue13-evidence-source-v5' -or
    -not [string]::Equals(
      (ConvertTo-Issue13V5Path $sourceToolingRoot),
      (ConvertTo-Issue13V5Path $expectedSourceToolingRoot),
      [StringComparison]::OrdinalIgnoreCase) -or
    -not [string]::Equals(
      [string]$oracleSourceTooling.physical_root,
      $sourceToolingPhysicalRoot,
      [StringComparison]::OrdinalIgnoreCase) -or
    [string]$oracleSourceTooling.path_list_sha256 -cne
      $sourceToolingPathListSha256 -or
    [string]$oracleSourceTooling.path_list_sha256 -cne
      '7bf2e27807e9bc36d3d3766789439d0d9afdd7b2cc5127145ce0e0f6819db00d' -or
    [string]$oracleSourceTooling.inventory_sha256 -cnotmatch
      '^[0-9a-f]{64}$' -or
    [long]$sourceToolingInventory.file_count -ne 37L -or
    [long]$sourceToolingInventory.directory_count -ne 1L -or
    [long]$sourceToolingInventory.total_bytes -ne
      [long]$oracleSourceTooling.total_bytes -or
    [string]$sourceToolingInventory.inventory_sha256 -cne
      [string]$oracleSourceTooling.inventory_sha256) {
  throw 'The exact 37-file Git-bound source-tooling inventory changed.'
}
$expectedSourceTreePaths = [string[]]@(
  '.', 'issue13-evidence-harness')
for ($index = 0; $index -lt $sourceToolingTrees.Count; $index++) {
  $tree = $sourceToolingTrees[$index]
  $relativeTree = [string]$tree.relative_path
  $expectedRepositoryPath = if ($relativeTree -ceq '.') {
    'run_logs/issue13-evidence-source-v5'
  } else {
    'run_logs/issue13-evidence-source-v5/' + $relativeTree
  }
  $gitTree = (Invoke-Issue13V5SealedGit -C $repository rev-parse (
    [string]$config.candidate_commit + ':' + $expectedRepositoryPath) `
    2>$null).Trim()
  $gitTreeType = if ($LASTEXITCODE -eq 0) {
    (Invoke-Issue13V5SealedGit `
      -C $repository cat-file -t $gitTree 2>$null).Trim()
  } else { '' }
  if ($relativeTree -cne $expectedSourceTreePaths[$index] -or
      [string]$tree.repository_path -cne $expectedRepositoryPath -or
      [string]$tree.mode -cne '040000' -or
      [string]$tree.type -cne 'tree' -or
      [string]$tree.tree -cnotmatch '^[0-9a-f]{40}$' -or
      $gitTree -cne [string]$tree.tree -or $gitTreeType -cne 'tree') {
    throw "Source-tooling Git tree binding changed: $relativeTree"
  }
}
foreach ($record in $sourceToolingRecords) {
  $relative = [string]$record.relative_path
  $expectedRepositoryPath =
    'run_logs/issue13-evidence-source-v5/' + $relative
  $localPath = Join-Path $sourceToolingRoot $relative.Replace('/', '\')
  $gitIdentity = Get-Issue13V5GitBlobIdentity $repository `
    ([string]$config.candidate_commit) $expectedRepositoryPath
  if ($relative -notmatch '^[^\\/:]+(?:/[^\\/:]+)*$' -or
      $relative -match '(^|/)\.\.?(?:/|$)' -or
      [string]$record.repository_path -cne $expectedRepositoryPath -or
      [string]$record.mode -cne '100644' -or
      [string]$record.type -cne 'blob' -or
      [string]$record.blob -cne [string]$gitIdentity.git_blob -or
      [long]$record.size_bytes -ne [long]$gitIdentity.size_bytes -or
      [string]$record.sha256 -cne [string]$gitIdentity.sha256 -or
      -not (Test-Path -LiteralPath $localPath -PathType Leaf) -or
      [long](Get-Item -LiteralPath $localPath).Length -ne
        [long]$record.size_bytes -or
      (Get-Issue13V5Sha256 $localPath) -cne [string]$record.sha256) {
    throw "Source-tooling Git blob binding changed: $relative"
  }
}

$expectedStrictSmokeSha256 =
  '973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d'
$null = Assert-Issue13V5ExactPropertyNames $config.strict_baseline_smoke @(
  'path', 'sha256', 'passed_count', 'failed_count',
  'final_evidence_eligible', 'rscript_path', 'rscript_physical_path',
  'rscript_item_id', 'rscript_link_count', 'rscript_sha256'
) 'Strict historical smoke config binding'
$null = Assert-Issue13V5ExactPropertyNames $strictSmoke @(
  'schema', 'status', 'passed', 'final_evidence_eligible', 'purpose',
  'baseline_commit', 'started_at_utc', 'finished_at_utc',
  'source_inventory_sha256', 'harness_manifest_path',
  'harness_manifest_sha256', 'method_count', 'passed_count', 'failed_count',
  'records', 'disposition'
) 'Strict historical smoke summary'
if ([string]$config.strict_baseline_smoke.sha256 -cne
      $expectedStrictSmokeSha256 -or
    (Get-Issue13V5Sha256 ([string]$config.strict_baseline_smoke.path)) -cne
      $expectedStrictSmokeSha256 -or
    [string]$strictSmoke.schema -cne 'wlv-issue13-v5-baseline-smoke/1' -or
    [string]$strictSmoke.status -cne 'failed' -or
    -not (Test-Issue13V5ExactBoolean $strictSmoke.passed $false) -or
    -not (Test-Issue13V5ExactBoolean `
      $strictSmoke.final_evidence_eligible $false) -or
    [string]$strictSmoke.purpose -cne 'strict-cc2-executability-preflight' -or
    [string]$strictSmoke.baseline_commit -cne
      'cc2c86189a06676bcb9f0e05e08033d710a92509' -or
    [long]$strictSmoke.method_count -ne 12L -or
    [long]$strictSmoke.passed_count -ne 5L -or
    [long]$strictSmoke.failed_count -ne 7L -or
    @($strictSmoke.records).Count -ne 12) {
  throw 'The sealed strict historical smoke summary changed.'
}
$strictHarnessManifestPath = (Resolve-Path -LiteralPath (
  [string]$strictSmoke.harness_manifest_path)).Path
$strictHarnessRuntime = (Resolve-Path -LiteralPath (
  Split-Path -Parent $strictHarnessManifestPath)).Path
$null = Assert-Issue13V5NoReparseAncestors $strictHarnessRuntime `
  'Strict historical harness runtime'
$strictHarnessManifest = Read-Issue13V5Json $strictHarnessManifestPath
$strictHarnessInventory = Get-Issue13V5HarnessInventory $strictHarnessRuntime
$strictHarnessPathListSha256 = Get-Issue13V5TextSha256 (
  [string]::Join("`n", @($strictHarnessInventory.records.relative_path)))
$strictHarnessDirectories = @(
  Get-ChildItem -LiteralPath $strictHarnessRuntime -Directory -Force)
if ((Get-Issue13V5Sha256 $strictHarnessManifestPath) -cne
      'a17a187621cdd4aff6f24efd6bf43ffbf9336de0a19189dfc7f5a82758a92c23' -or
    [string]$strictSmoke.harness_manifest_sha256 -cne
      'a17a187621cdd4aff6f24efd6bf43ffbf9336de0a19189dfc7f5a82758a92c23' -or
    [string]$strictHarnessManifest.schema -cne
      'wlv-issue13-v5-harness-materialization/1' -or
    [string]$strictHarnessManifest.generation -cne 'v5' -or
    [string]$strictHarnessManifest.status -cne 'materialized' -or
    [string]$strictHarnessManifest.baseline_commit -cne
      'cc2c86189a06676bcb9f0e05e08033d710a92509' -or
    -not (Test-Issue13V5ExactBoolean `
      $strictHarnessManifest.final_evidence_eligible $true) -or
    -not (Test-Issue13V5ExactBoolean `
      $strictHarnessManifest.reuses_candidate_evidence $false) -or
    $strictHarnessDirectories.Count -ne 1 -or
    [string]$strictHarnessDirectories[0].Name -cne
      'issue13-evidence-harness' -or
    [long]$strictHarnessInventory.file_count -ne 39L -or
    [long]$strictHarnessInventory.total_bytes -ne 586873L -or
    [string]$strictHarnessInventory.inventory_sha256 -cne
      '7ba02db2ad97cd59bc93405057d5cc127fbefaac0e4e72331c13a10e5f8d495b' -or
    $strictHarnessPathListSha256 -cne
      'd6fe55884678c1300f661bd4b1ff1f42694af9d49dabd739fad7630ebfd2b416' -or
    [long]$strictHarnessManifest.output_tooling.file_count -ne 39L -or
    [long]$strictHarnessManifest.output_tooling.total_bytes -ne 586873L -or
    [string]$strictHarnessManifest.output_tooling.inventory_sha256 -cne
      '7ba02db2ad97cd59bc93405057d5cc127fbefaac0e4e72331c13a10e5f8d495b') {
  throw 'The separate strict historical harness changed.'
}
$strictSmokeRoot = Split-Path -Parent (
  [string]$config.strict_baseline_smoke.path)
$strictAttemptsRoot = Join-Path $strictSmokeRoot 'attempts'
$strictAttemptsInventory = Get-Issue13V5TreeInventory $strictAttemptsRoot
$strictAttemptPaths = [string[]]@(
  $strictAttemptsInventory.records | ForEach-Object {
    [string]$_.relative_path
  })
[Array]::Sort($strictAttemptPaths, [StringComparer]::Ordinal)
$strictAttemptsPathListSha256 = Get-Issue13V5TextSha256 (
  [string]::Join("`n", $strictAttemptPaths))
if ([long]$strictAttemptsInventory.file_count -ne 120L -or
    [long]$strictAttemptsInventory.directory_count -ne 60L -or
    [long]$strictAttemptsInventory.total_bytes -ne 2255912L -or
    [string]$strictAttemptsInventory.inventory_sha256 -cne
      '12b63f23e87b12b6afc0beabec9e64518b0ce114f1ae8b7fa481c01c78320edf' -or
    [string]$strictAttemptsInventory.directory_list_sha256 -cne
      '7bdb481081e12c4522f6dfdace2ec2c00015127139b574356f76e019754592ea' -or
    $strictAttemptsPathListSha256 -cne
      '5b805a5b9c7d2e1d09b111392b8d0795e60b4866e55f606ac8db9dc4e7cf7657') {
  throw 'The write-once strict-smoke attempts archive changed.'
}
$strictWorktreeRoot = Join-Path $strictSmokeRoot 'worktrees'
$strictWorktreeDirectories = @(Get-ChildItem -LiteralPath `
  $strictWorktreeRoot -Directory -Force | Sort-Object Name)
$strictWorktreeFiles = @(Get-ChildItem -LiteralPath `
  $strictWorktreeRoot -File -Force)
$expectedStrictMethods = [string[]]@(
  $config.methods | ForEach-Object { [string]$_.method })
[Array]::Sort($expectedStrictMethods, [StringComparer]::Ordinal)
$observedStrictMethods = [string[]]@(
  $strictWorktreeDirectories | ForEach-Object { [string]$_.Name })
[Array]::Sort($observedStrictMethods, [StringComparer]::Ordinal)
if ($strictWorktreeDirectories.Count -ne 12 -or
    $strictWorktreeFiles.Count -ne 0 -or
    [string]::Join("`n", $observedStrictMethods) -cne
      [string]::Join("`n", $expectedStrictMethods)) {
  throw 'The strict-smoke worktree set changed.'
}
foreach ($worktree in $strictWorktreeDirectories) {
  $worktreeHead = (Invoke-Issue13V5SealedGit `
    -C $worktree.FullName rev-parse HEAD 2>$null).Trim()
  $worktreeTree = (Invoke-Issue13V5SealedGit `
    -C $worktree.FullName rev-parse 'HEAD^{tree}' `
    2>$null).Trim()
  $worktreeStatus = @(Invoke-Issue13V5SealedGit `
    -C $worktree.FullName status '--porcelain=v1' `
    '--untracked-files=all' 2>$null)
  $summaryRecord = @($strictSmoke.records | Where-Object {
    [string]$_.method -ceq [string]$worktree.Name
  })
  if ($LASTEXITCODE -ne 0 -or
      $worktreeHead -cne 'cc2c86189a06676bcb9f0e05e08033d710a92509' -or
      $worktreeTree -cne '0cb1142cdadd74bf95272010f5393ebe2af79f47' -or
      $worktreeStatus.Count -ne 0 -or $summaryRecord.Count -ne 1 -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$summaryRecord[0].project_root)),
        (ConvertTo-Issue13V5Path $worktree.FullName),
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Strict historical smoke worktree changed: $($worktree.Name)"
  }
}

$oracleRscript = $oracleTerminalRuntime.rscript
$oracleRscriptBefore = $oracleRuntimeImmutability.before.rscript
$oracleRscriptAfter = $oracleRuntimeImmutability.after.rscript
$oracleRscriptJson = ConvertTo-Issue13V5RendererRscriptJson `
  $oracleRscript 'Oracle terminal Rscript identity'
$oracleRscriptBeforeJson = ConvertTo-Issue13V5RendererRscriptJson `
  $oracleRscriptBefore 'Oracle before Rscript identity'
$oracleRscriptAfterJson = ConvertTo-Issue13V5RendererRscriptJson `
  $oracleRscriptAfter 'Oracle after Rscript identity'
$currentRscriptPath = (Resolve-Path -LiteralPath ([string]$config.rscript)).Path
$currentRscriptItem = Get-Issue13V5PhysicalItemIdentity `
  $currentRscriptPath 'Report Rscript executable'
$currentRscript = [ordered]@{
  logical_path = $currentRscriptPath
  physical_path = [string]$currentRscriptItem.physical_path
  item_id = [string]$currentRscriptItem.item_id
  link_count = [long]$currentRscriptItem.link_count
  size_bytes = [long](Get-Item -LiteralPath $currentRscriptPath).Length
  sha256 = Get-Issue13V5Sha256 $currentRscriptPath
}
$currentRscriptJson = ConvertTo-Issue13V5RendererRscriptJson `
  $currentRscript 'Current Rscript identity'
if ($oracleRscriptJson -cne $oracleRscriptBeforeJson -or
    $oracleRscriptJson -cne $oracleRscriptAfterJson -or
    $oracleRscriptJson -cne $currentRscriptJson -or
    -not ($config.strict_baseline_smoke.rscript_path -is [string]) -or
    -not ($config.strict_baseline_smoke.rscript_physical_path -is [string]) -or
    -not ($config.strict_baseline_smoke.rscript_item_id -is [string]) -or
    -not ($config.strict_baseline_smoke.rscript_link_count -is [long]) -or
    -not ($config.strict_baseline_smoke.rscript_sha256 -is [string]) -or
    [long]$oracleRscript.link_count -ne 1L -or
    [long]$oracleRscript.size_bytes -ne 94720L -or
    [string]$oracleRscript.sha256 -cne
      '3ad097e10d867e09eb7e54d8ed1f8ef933779b82be56482a04a27d65536d15f9' -or
    -not [string]::Equals(
      (ConvertTo-Issue13V5Path (
        [string]$config.strict_baseline_smoke.rscript_path)),
      (ConvertTo-Issue13V5Path ([string]$oracleRscript.logical_path)),
      [StringComparison]::OrdinalIgnoreCase) -or
    -not [string]::Equals(
      [string]$config.strict_baseline_smoke.rscript_physical_path,
      [string]$oracleRscript.physical_path,
      [StringComparison]::OrdinalIgnoreCase) -or
    [string]$config.strict_baseline_smoke.rscript_item_id -cne
      [string]$oracleRscript.item_id -or
    [long]$config.strict_baseline_smoke.rscript_link_count -ne
      [long]$oracleRscript.link_count -or
    [string]$config.strict_baseline_smoke.rscript_sha256 -cne
      [string]$oracleRscript.sha256) {
  throw 'The exact current Rscript identity or its before/after seal changed.'
}
$expectedOracleCleared = [string[]]@(
  'LANG', 'LC_ALL', 'LC_CTYPE', 'R_ARCH', 'R_DEFAULT_PACKAGES',
  'R_ENVIRON', 'R_ENVIRON_USER', 'R_HOME', 'R_LIBS', 'R_LIBS_SITE',
  'R_PROFILE', 'R_PROFILE_USER', 'R_STARTUP_DEBUG',
  'RENV_ACTIVATE_PROJECT', 'RENV_AUTOLOAD_ENABLED',
  'RENV_AUTOLOADER_ENABLED',
  'RENV_CONFIG_AUTOLOADER_ENABLED', 'RENV_CONFIG_EXTERNAL_LIBRARIES',
  'RENV_CONFIG_STARTUP_QUIET', 'RENV_CONFIG_SYNCHRONIZED_CHECK',
  'RENV_CONFIG_USER_PROFILE', 'RENV_PATHS_LIBRARY_ROOT',
  'RENV_PATHS_LIBRARY_ROOT_ASIS', 'RENV_PATHS_LOCKFILE',
  'RENV_PATHS_PREFIX', 'RENV_PATHS_PREFIX_AUTO', 'RENV_PATHS_RENV',
  'RENV_PATHS_ROOT', 'RENV_PATHS_SANDBOX', 'RENV_PATHS_VERSION',
  'RENV_PROCESS_TYPE', 'RENV_PROFILE', 'RENV_PROJECT',
  'RENV_SANDBOX_LOCKING_ENABLED', 'RENV_STARTUP_DIAGNOSTICS'
) | Sort-Object
$observedOracleCleared = [string[]]@(
  $oracleRLibrary.environment.cleared) | Sort-Object
$oracleEnvironmentSet = @($oracleRLibrary.environment.set)
$oracleLibsUserSet = @($oracleEnvironmentSet | Where-Object {
  [string]$_.name -ceq 'R_LIBS_USER' -and
  [string]$_.value -ceq [string]$config.r_library
})
$oracleRenvLibrarySet = @($oracleEnvironmentSet | Where-Object {
  [string]$_.name -ceq 'RENV_PATHS_LIBRARY' -and
  [string]$_.value -ceq
    (Get-Issue13V5RenvLibraryRoot ([string]$config.r_library))
})
$oracleSandboxSet = @($oracleEnvironmentSet | Where-Object {
  [string]$_.name -ceq 'RENV_CONFIG_SANDBOX_ENABLED' -and
  [string]$_.value -ceq 'FALSE'
})
$oracleAutoSnapshotSet = @($oracleEnvironmentSet | Where-Object {
  [string]$_.name -ceq 'RENV_CONFIG_AUTO_SNAPSHOT' -and
  [string]$_.value -ceq 'FALSE'
})
$oracleCacheSet = @($oracleEnvironmentSet | Where-Object {
  [string]$_.name -ceq 'RENV_CONFIG_CACHE_ENABLED' -and
  [string]$_.value -ceq 'FALSE'
})
$oracleLockingSet = @($oracleEnvironmentSet | Where-Object {
  [string]$_.name -ceq 'RENV_CONFIG_LOCKING_ENABLED' -and
  [string]$_.value -ceq 'FALSE'
})
$oracleUpdatesSet = @($oracleEnvironmentSet | Where-Object {
  [string]$_.name -ceq 'RENV_CONFIG_UPDATES_CHECK' -and
  [string]$_.value -ceq 'FALSE'
})
$oracleUserEnvironSet = @($oracleEnvironmentSet | Where-Object {
  [string]$_.name -ceq 'RENV_CONFIG_USER_ENVIRON' -and
  [string]$_.value -ceq 'FALSE'
})
$oracleUserLibrarySet = @($oracleEnvironmentSet | Where-Object {
  [string]$_.name -ceq 'RENV_CONFIG_USER_LIBRARY' -and
  [string]$_.value -ceq 'FALSE'
})
$oracleTzSet = @($oracleEnvironmentSet | Where-Object {
  [string]$_.name -ceq 'TZ' -and [string]$_.value -ceq 'UTC'
})
$oracleRequiredPackages = [string[]]@(
  $oracleRLibrary.required_packages | Sort-Object)
$expectedOraclePackages = [string[]]@('fst', 'jsonlite', 'openssl') |
  Sort-Object
$oracleLoadedPackages = @($oracleRLibrary.loaded_packages)
$oracleLoadedRequiredPackages = [string[]]@(
  $oracleLoadedPackages | Where-Object {
    Test-Issue13V5ExactBoolean $_.required $true
  } |
    ForEach-Object { [string]$_.name } | Sort-Object)
if ([string]$oracleRLibrary.path -cne [string]$config.r_library -or
    [string]$oracleRLibrary.environment_variable -cne 'R_LIBS_USER' -or
    [string]$oracleRLibrary.activation.mode -cne 'isolated-project-copy' -or
    -not (Test-Issue13V5ExactBoolean `
      $oracleRLibrary.activation.verified $true) -or
    [string]$oracleRLibrary.activation.renv_version -cne '1.2.4' -or
    [long]$oracleRLibrary.activation.captured_console_line_count -lt 0L -or
    [string]$oracleRLibrary.activation.renv_library_root -cne
      (Get-Issue13V5RenvLibraryRoot ([string]$config.r_library)) -or
    [string]$oracleRLibrary.activation.project_inventory_sha256 -cnotmatch
      '^[0-9a-f]{64}$' -or
    -not (Test-Issue13V5ExactBoolean `
      $oracleRLibrary.activation.project_library_absent_before $true) -or
    -not (Test-Issue13V5ExactBoolean `
      $oracleRLibrary.activation.project_library_absent_after $true) -or
    [string]$oracleRLibrary.activation.r_library_inventory_before_sha256 `
      -cne [string]$oracleRLibrary.activation.
        r_library_inventory_after_sha256 -or
    $oracleEnvironmentSet.Count -ne 10 -or $oracleLibsUserSet.Count -ne 1 -or
    $oracleRenvLibrarySet.Count -ne 1 -or $oracleSandboxSet.Count -ne 1 -or
    $oracleAutoSnapshotSet.Count -ne 1 -or $oracleCacheSet.Count -ne 1 -or
    $oracleLockingSet.Count -ne 1 -or $oracleUpdatesSet.Count -ne 1 -or
    $oracleUserEnvironSet.Count -ne 1 -or
    $oracleUserLibrarySet.Count -ne 1 -or $oracleTzSet.Count -ne 1 -or
    @(Compare-Object $expectedOracleCleared $observedOracleCleared `
      -CaseSensitive).Count -ne 0 -or
    @(Compare-Object $expectedOraclePackages $oracleRequiredPackages `
      -CaseSensitive).Count -ne 0 -or
    @(Compare-Object $expectedOraclePackages $oracleLoadedRequiredPackages `
      -CaseSensitive).Count -ne 0 -or
    $oracleLoadedPackages.Count -lt 3 -or
    [string]$oracleRLibrary.r_version -notmatch '^R version ' -or
    [string]::IsNullOrWhiteSpace([string]$oracleRLibrary.platform) -or
    [string]$oracleRLibrary.inventory_sha256 -cne
      [string]$config.oracle_effect.r_library.inventory_sha256) {
  throw 'Oracle-effect terminal R runtime inventory changed.'
}
$oracleEnvironmentSetJson = $oracleRLibrary.environment.set |
  ConvertTo-Json -Depth 10 -Compress
$oracleCommandEnvironmentFailures = @($oracleCommands | Where-Object {
  @($_.arguments) -cnotcontains '--vanilla' -or
  [string]$_.r_library_environment.name -cne 'R_LIBS_USER' -or
  [string]$_.r_library_environment.value -cne [string]$config.r_library -or
  ($_.environment_set | ConvertTo-Json -Depth 10 -Compress) -cne
    $oracleEnvironmentSetJson -or
  @(Compare-Object $expectedOracleCleared `
      ([string[]]@($_.environment_cleared) | Sort-Object) `
      -CaseSensitive).Count -ne 0
})
if ($oracleCommandEnvironmentFailures.Count -ne 0) {
  throw 'Oracle-effect commands do not share the sealed --vanilla R environment.'
}
$oracleRuntimeBeforeJson = $oracleRuntimeImmutability.before |
  ConvertTo-Json -Depth 50 -Compress
$oracleRuntimeAfterJson = $oracleRuntimeImmutability.after |
  ConvertTo-Json -Depth 50 -Compress
if (-not (Test-Issue13V5ExactBoolean $oracleRuntimeImmutability.immutable $true) -or
    $oracleRuntimeBeforeJson -cne $oracleRuntimeAfterJson -or
    ($oracleRuntimeImmutability.before.r_library |
      ConvertTo-Json -Depth 30 -Compress) -cne
      ($oracleRLibrary | ConvertTo-Json -Depth 30 -Compress)) {
  throw 'Oracle-effect terminal R runtime is not immutable.'
}
$oracleRuntimeInventorySha256 =
  Get-Issue13V5TextSha256 $oracleRuntimeBeforeJson

$baselineSeconds = [double](($performance | Measure-Object `
  baseline_seconds -Sum).Sum)
$candidateSeconds = [double](($performance | Measure-Object `
  candidate_seconds -Sum).Sum)
$maximumTimeRatio = ($performance | ForEach-Object {
  [double]$_.candidate_seconds / [double]$_.baseline_seconds
} | Measure-Object -Maximum).Maximum
$maximumCandidateRss = ($performance | ForEach-Object {
  [int64]$_.candidate_peak_rss_bytes
} | Measure-Object -Maximum).Maximum
$maximumRssUtilization = ($performance | ForEach-Object {
  [double]$_.candidate_peak_rss_bytes / [double]$_.rss_limit_bytes
} | Measure-Object -Maximum).Maximum
$oracleGroups = @($oracle | Group-Object classification | Sort-Object Name)
$faultRows = @($state.prep_fault.faults | Sort-Object fault_id)

$sourceIdentityLines = [Collections.Generic.List[string]]::new()
$preparationEquivalenceBinding =
  $config.comparison.preparation_equivalence_profile
$preparationEquivalencePath = ConvertTo-Issue13V5Path (
  [string]$preparationEquivalenceBinding.path)
$preparationEquivalenceSha = Get-Issue13V5Sha256 $preparationEquivalencePath
if ($preparationEquivalenceSha -cne
      [string]$preparationEquivalenceBinding.sha256 -or
    -not (Test-Issue13V5ExactBoolean `
      $preparationEquivalenceBinding.all_rows_fields_and_order_exact $true) -or
    @($preparationEquivalenceBinding.architecture_projection).Count -ne 0 -or
    [string]$preparationEquivalenceBinding.source_unit_contract_bridge -cne
      'exhaustive-source-unit-contract-bridge') {
  throw 'Preparation equivalence report binding changed.'
}
foreach ($sourceName in @('wiodr13', 'wiodr16')) {
  $sourceComparison =
    $preparation.sources.PSObject.Properties[$sourceName].Value
  $baselineManifest = $sourceComparison.baseline_manifest
  $candidateManifest = $sourceComparison.candidate_manifest
  $manifestComparison =
    $sourceComparison.csv.PSObject.Properties['_source_manifest.csv'].Value
  $unitComparison =
    $sourceComparison.csv.PSObject.Properties['_unit_contract.csv'].Value
  $unitBridge = $unitComparison.cross_engine_bridge
  $baselineBinding = @($config.source_contract_bindings | Where-Object {
    [string]$_.arm -ceq 'baseline' -and
      [string]$_.source -ceq $sourceName
  })
  $candidateBinding = @($config.source_contract_bindings | Where-Object {
    [string]$_.arm -ceq 'candidate' -and
      [string]$_.source -ceq $sourceName
  })
  $arrayComparisons = @(
    $sourceComparison.arrays.PSObject.Properties | ForEach-Object {
      $_.Value
    })
  $sealedTableComparisons = @($manifestComparison, $unitComparison)
  $sealedArmComparisons = @($sealedTableComparisons | ForEach-Object {
    @($_.baseline, $_.candidate)
  })
  if (-not (Test-Issue13V5ExactBoolean $sourceComparison.passed $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $sourceComparison.manifest_tables_equivalence_profile_exact $true) -or
      -not (Test-Issue13V5ExactBoolean $baselineManifest.passed $true) -or
      -not (Test-Issue13V5ExactBoolean $candidateManifest.passed $true) -or
      -not (Test-Issue13V5ExactBoolean $manifestComparison.passed $true) -or
      [string]$manifestComparison.comparison_mode -cne
        'sealed-exhaustive-source-manifest-equivalence' -or
      -not (Test-Issue13V5ExactBoolean $unitComparison.passed $true) -or
      [string]$unitComparison.comparison_mode -cne
        'sealed-exhaustive-unit-contract-equivalence' -or
      -not (Test-Issue13V5ExactBoolean $unitBridge.passed $true) -or
      [string]$unitBridge.comparison_mode -cne
        'exhaustive-source-unit-contract-bridge' -or
      [string]$unitBridge.source -cne $sourceName -or
      -not (Test-Issue13V5ExactBoolean `
        $unitBridge.all_columns_compared $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $unitBridge.exact_order_after_bridge $true) -or
      [long]$unitBridge.aggregation_note_bridge_rows -ne 0L -or
      -not (Test-Issue13V5ExactBoolean `
        $manifestComparison.raw_semantic_equal $false) -or
      -not (Test-Issue13V5ExactBoolean `
        $unitComparison.raw_semantic_equal $false) -or
      @($sealedTableComparisons | Where-Object {
        [string]$_.profile_sha256 -cne $preparationEquivalenceSha
      }).Count -ne 0 -or
      @($sealedArmComparisons | Where-Object {
        -not (Test-Issue13V5ExactBoolean $_.passed $true) -or
        -not (Test-Issue13V5ExactBoolean $_.exact_table $true) -or
        [long]$_.rows -le 0L -or @($_.columns).Count -le 0 -or
        [string]$_.file_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        [string]$_.table_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        [string]$_.file_sha256 -cne [string]$_.expected_file_sha256 -or
        [string]$_.table_sha256 -cne [string]$_.expected_table_sha256
      }).Count -ne 0 -or
      $baselineBinding.Count -ne 1 -or $candidateBinding.Count -ne 1) {
    throw "Preparation source equivalence profile is invalid: $sourceName"
  }
  if ($arrayComparisons.Count -ne 2 -or
      @($arrayComparisons | Where-Object {
        -not (Test-Issue13V5ExactBoolean $_.passed $true) -or
        -not (Test-Issue13V5ExactBoolean `
          $_.dimension_names_identical $true) -or
        -not (Test-Issue13V5ExactBoolean `
          $_.fst_column_schema_identical $true) -or
        -not (Test-Issue13V5ExactBoolean `
          $_.bitwise_values_identical $true) -or
        [long]$_.compared_values -ne [long]$_.flattened_values -or
        -not (Test-Issue13V5ExactBoolean `
          $_.baseline_internal_hash_ok $true) -or
        -not (Test-Issue13V5ExactBoolean `
          $_.candidate_internal_hash_ok $true) -or
        -not (Test-Issue13V5ExactBoolean `
          $_.sidecar_architecture_valid $true) -or
        -not (Test-Issue13V5ExactBoolean `
          $_.sidecars_semantically_identical $false) -or
        [string]$_.baseline_sidecar_format -cne 'legacy-positional' -or
        [string]$_.candidate_sidecar_format -cne 'versioned-v1' -or
        [string]$_.baseline_sha256 -cne [string]$_.candidate_sha256 -or
        [string]$_.baseline_sidecar_sha256 -ceq
          [string]$_.candidate_sidecar_sha256
      }).Count -ne 0) {
    throw "Prepared FST sidecar architecture is invalid: $sourceName"
  }
  foreach ($record in @(
      @($baselineManifest, $baselineBinding[0]),
      @($candidateManifest, $candidateBinding[0])
    )) {
    foreach ($field in @(
        'source_generation_id', 'contract_id', 'contract_version',
        'contract_sha256'
      )) {
      if ([string]$record[0].$field -cne [string]$record[1].$field) {
        throw "Preparation source identity differs from its binding: $sourceName/$field"
      }
    }
  }
  if ([string]$baselineManifest.contract_id -cne
        [string]$candidateManifest.contract_id -or
      [string]$baselineManifest.contract_version -cne
        [string]$candidateManifest.contract_version) {
    throw "Preparation contract ID/version differs: $sourceName"
  }
  $sourceIdentityLines.Add(
    '- `' + $sourceName + '`: contract_id `' +
      [string]$baselineManifest.contract_id + '`, contract_version `' +
      [string]$baselineManifest.contract_version + '`. Baseline: geração `' +
      [string]$baselineManifest.source_generation_id + '`, contrato `' +
      [string]$baselineManifest.contract_sha256 + '`, manifest `' +
      [string]$baselineBinding[0].manifest_sha256 + '`. Candidato: geração `' +
      [string]$candidateManifest.source_generation_id + '`, contrato `' +
      [string]$candidateManifest.contract_sha256 + '`, manifest `' +
      [string]$candidateBinding[0].manifest_sha256 +
      '`. `_unit_contract.csv` e `_source_manifest.csv` correspondem célula ' +
      'por célula aos perfis completos de cada braço (`' +
      $preparationEquivalenceSha + '`); o bridge tipado entre braços também ' +
      'compara todas as colunas e nenhuma projeção arquitetural é autorizada. ' +
      'Sidecars FST `legacy-positional` → `versioned-v1` validados.'
  )
}
$euklemsArtifacts = @(
  $preparation.euklems.artifacts.PSObject.Properties | ForEach-Object {
    $_.Value
  })
if (-not (Test-Issue13V5ExactBoolean $preparation.euklems.passed $true) -or
    [long]$preparation.euklems.artifact_count -ne 42L -or
    $euklemsArtifacts.Count -ne 42 -or
    [string]::Join(',', @($preparation.euklems.expected_years)) -cne
      [string]::Join(',', (1995..2015)) -or
    [string]::Join(',', @($preparation.euklems.expected_series)) -cne
      'ekk,ekdeprate' -or
    @($euklemsArtifacts | Where-Object {
      -not (Test-Issue13V5ExactBoolean $_.passed $true) -or
      [string]$_.baseline_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$_.candidate_sha256 -cnotmatch '^[0-9a-f]{64}$'
    }).Count -ne 0) {
  throw 'EU KLEMS prepared artifact identity is incomplete or differs.'
}
$euklemsIdentityPayload = [string]::Join("`n", @(
  $euklemsArtifacts | Sort-Object artifact | ForEach-Object {
    [string]$_.artifact + '|' + [string]$_.baseline_sha256 + '|' +
      [string]$_.candidate_sha256
  }))
$euklemsIdentitySha256 = Get-Issue13V5TextSha256 $euklemsIdentityPayload
$sourceIdentityLines.Add(
  '- `euklems`: 42 FSTs (1995–2015, `ekk`/`ekdeprate`) com esquemas e ' +
    'células idênticos; identidade agregada dos hashes de ambos os braços `' +
    $euklemsIdentitySha256 +
    '`. O contrato atual não publica `_source_manifest.csv` para EU KLEMS; ' +
    'as duas caches oficiais e cada artefato preparado são autenticados.'
)

$sourceCacheLines = @($script:Issue13V5PreparationCaches | ForEach-Object {
  '- `' + $_.relative_path.Replace('\', '/') + '`: `' + $_.sha256 +
    '` (' + [string]$_.size_bytes + ' bytes)'
})
$commandLines = @($commandEntries | ForEach-Object {
  $record = $_.document
  $argumentsJson = ConvertTo-Json -InputObject @($record.arguments) -Compress
  $environmentSetJson = ConvertTo-Json -InputObject `
    @($record.environment_set) -Depth 5 -Compress
  $environmentClearedJson = ConvertTo-Json -InputObject `
    @($record.environment_cleared) -Compress
  '- registro `' + [string]$_.sha256 + '`; label `' +
    [string]$record.label + '`; executável `' +
    [string]$record.executable + '`; cwd `' +
    [string]$record.working_directory + '`; exit `' +
    [string]$record.exit_code + '`; argumentos `' + $argumentsJson +
    '`; `environment_set` `' + $environmentSetJson +
    '`; `environment_cleared` `' + $environmentClearedJson +
    '`; stdout `' +
    [string]$record.stdout_sha256 + '`; stderr `' +
    [string]$record.stderr_sha256 + '`.'
})
$oracleValidationArguments = ConvertTo-Json -InputObject @(
  $oracleEffectControl.validation.command.arguments) -Compress
$oracleValidationCommandLine = '- validação oracle-effect; executável `' +
  [string]$oracleEffectControl.validation.command.executable + '`; cwd `' +
  [string]$oracleEffectControl.validation.command.working_directory +
  '`; exit `0`; argumentos `' + $oracleValidationArguments +
  '`; stdout `' +
  [string]$oracleEffectControl.validation.command.stdout_sha256 + '`.'
$oracleCommonLines = @($oracleCommon | Sort-Object method | ForEach-Object {
  $comparisonFile = @($_.files | Where-Object name -ceq 'comparison.json')
  if ($comparisonFile.Count -ne 1 -or
      [string]$comparisonFile[0].primary_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$comparisonFile[0].replay_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$comparisonFile[0].normalized_sha256 -cnotmatch
        '^[0-9a-f]{64}$' -or
      -not (Test-Issue13V5ExactBoolean `
        $comparisonFile[0].normalized_identical $true)) {
    throw "Oracle-effect common comparison file is missing: $($_.method)"
  }
  '- `' + [string]$_.method + '`: strict primary/replay `passed`; ' +
    'comparison normalizada `' +
    [string]$comparisonFile[0].normalized_sha256 + '` (primary `' +
    [string]$comparisonFile[0].primary_sha256 + '`, replay `' +
    [string]$comparisonFile[0].replay_sha256 + '`); cc2 manifest `' +
    [string]$_.baseline_manifest_sha256 + '`; e2f manifest `' +
    [string]$_.candidate_manifest_sha256 + '`.'
})
$oracleRecoveredLines = @($oracleRecovered | Sort-Object method |
  ForEach-Object {
    '- `' + [string]$_.method + '`: falha cc2 `' +
      [string]$_.strict_failure_id + '` (`' +
      [string]$_.strict_scenario_sha256 + '`); run e2f manifest `' +
      [string]$_.oracle_manifest_sha256 + '`, inventário `' +
      [string]$_.oracle_inventory_sha256 + '`; mudanças `' +
      ([string]::Join(',', @($_.change_ids))) + '`.'
  })
$oracleLines = if ($oracleGroups.Count) {
  @($oracleGroups | ForEach-Object {
    '- `' + $_.Name + '`: ' + [string]$_.Count
  })
} else { @('- Nenhuma classificação de oracle foi emitida.') }
$faultLines = @($faultRows | ForEach-Object {
  '- `' + $_.fault_id + '`: `passed`, resultado `' + $_.result_sha256 + '`'
})

$text = @"
# Issue #13 — relatório integral de paridade V5

Este documento registra o gate real, write-once e sem reutilização de evidência
do rework atômico do motor. O merge do issue #12 permanece a origem histórica
imutável. Como ele falha antes de produzir sete oráculos, a execução final do
baseline usa um único filho direto de compatibilidade, autenticado pela íntegra
de seu diff. O smoke estrito 5/7 é preservado como evidência negativa e nunca é
importado como resultado científico final.

## Identidade

- `baseline_commit`: `$($config.baseline_commit)`
- `baseline_base_commit`: `$($config.baseline_base_commit)`
- `baseline_runtime_commit`: `$($config.baseline_runtime_commit)`
- `candidate_commit`: `$($config.candidate_commit)`
- Gate: 12 métodos, 76 pares, 162 cenários monitorados, 202 comparações e 10
  falhas injetadas.
- Agregado: `$aggregatePath`
- Estado final: `$StatePath`

## source_ids

- Inventário baseline oficial: `$($config.source_inventory.inventory_sha256)`
  ($($config.source_inventory.file_count) arquivos,
  $($config.source_inventory.total_bytes) bytes).
- Inventário de diretórios baseline:
  `$($config.source_inventory.directory_list_sha256)`.
- Inventário candidato nativo:
  `$($config.candidate_source_inventory.inventory_sha256)`
  ($($config.candidate_source_inventory.file_count) arquivos,
  $($config.candidate_source_inventory.total_bytes) bytes).
- Inventário de diretórios candidato:
  `$($config.candidate_source_inventory.directory_list_sha256)`.
- Tooling-fonte Git-bound: commit `$($oracleSourceTooling.candidate_commit)`,
  raiz de repositório `$($oracleSourceTooling.repository_relative_root)`, raiz
  lógica `$($oracleSourceTooling.root)` e raiz física
  `$($oracleSourceTooling.physical_root)`.
- Tooling-fonte fechado: `$($oracleSourceTooling.file_count)` arquivos,
  `$($oracleSourceTooling.directory_count)` diretório descendente,
  `$($sourceToolingTrees.Count)` árvores Git,
  `$($oracleSourceTooling.total_bytes)` bytes; lista de caminhos
  `$($oracleSourceTooling.path_list_sha256)` e inventário
  `$($oracleSourceTooling.inventory_sha256)`. Manifesto, configuração e prova
  contêm exatamente o mesmo objeto.
$([string]::Join("`n", $sourceCacheLines))

Identidades das gerações preparadas. Cada braço foi validado contra seu
contrato; a comparação científica usa a ponte tipada e exaustiva selada, sem
qualquer projeção de linha, campo, ordem ou tolerância:

$([string]::Join("`n", $sourceIdentityLines))

## commands

Os comandos foram registrados individualmente com argumentos, código de saída,
tempo, `environment_set`, `environment_cleared` e hashes de stdout/stderr.
Ausência, remoção e string vazia são estados distintos: valores vazios aparecem
explicitamente como `""` em `environment_set`, e nenhum nome pode ocorrer nas
duas coleções. Inventário autenticado:
`$($commandInventory.inventory_sha256)` ($($commandInventory.file_count) arquivos).

$([string]::Join("`n", $commandLines))
$oracleValidationCommandLine

## hashes

- Configuração V5: `$($binding.sha256)`
- Harness materializado: `$($binding.harness_inventory.inventory_sha256)`
- Índice baseline compatibility-oracle-cc2: `$($config.baseline_runtime_index_sha256)`
- `baseline_overlay_patch`: `$($config.baseline_overlay.sha256)`
  (stable patch-id `$($config.baseline_overlay.patch_id)`).
- `strict_baseline_smoke`: `$($config.strict_baseline_smoke.sha256)`.
- Harness físico separado do smoke estrito: manifesto
  `$(Get-Issue13V5Sha256 $strictHarnessManifestPath)`; inventário
  `$($strictHarnessInventory.inventory_sha256)`
  (`$($strictHarnessInventory.file_count)` arquivos, `1` diretório,
  `$($strictHarnessInventory.total_bytes)` bytes; lista de caminhos
  `$strictHarnessPathListSha256`). Esse runtime histórico não é reutilizado
  como evidência terminal.
- Archive write-once `attempts` do smoke estrito:
  `$($strictAttemptsInventory.inventory_sha256)`
  (`$($strictAttemptsInventory.file_count)` arquivos,
  `$($strictAttemptsInventory.directory_count)` diretórios,
  `$($strictAttemptsInventory.total_bytes)` bytes; lista de caminhos
  `$strictAttemptsPathListSha256`; diretórios
  `$($strictAttemptsInventory.directory_list_sha256)`).
- Worktrees históricos do smoke estrito: `12/12`, commit
  `cc2c86189a06676bcb9f0e05e08033d710a92509`, árvore
  `0cb1142cdadd74bf95272010f5393ebe2af79f47`, todos integralmente limpos.
- `compatibility_baseline_smoke`:
  `$($config.compatibility_baseline_smoke.sha256)`.
- Smoke dedicado da prova do efeito do oráculo:
  `$($config.oracle_effect.oracle_smoke.sha256)`.
- Prova auxiliar do efeito do oráculo: `$($config.oracle_effect.proof.sha256)`.
- Inventário agregado do par primary/replay:
  `$($config.oracle_effect.comparisons.inventory.inventory_sha256)`.
- Inventário da raiz primary (cinco comparações strict):
  `$($config.oracle_effect.comparisons.primary.inventory.inventory_sha256)`.
- Inventário da raiz replay (cinco comparações strict):
  `$($config.oracle_effect.comparisons.replay.inventory.inventory_sha256)`.
- Manifesto do harness terminal do comparador:
  `$($config.oracle_effect.comparison_harness.manifest_sha256)`.
- Inventário dos 34 controladores-fonte do harness terminal:
  `$($oracleSourceController.inventory_sha256)`.
- Inventário dos 37 arquivos do tooling-fonte Git-bound:
  `$($oracleSourceTooling.inventory_sha256)`; árvores Git: `2`;
  path-list: `$($oracleSourceTooling.path_list_sha256)`.
- Identidade atual do Rscript: caminho lógico
  `$($oracleRscript.logical_path)`, caminho físico
  `$($oracleRscript.physical_path)`, item `$($oracleRscript.item_id)`, links
  `$($oracleRscript.link_count)`, tamanho `$($oracleRscript.size_bytes)` bytes e
  SHA-256 `$($oracleRscript.sha256)`; snapshots before/after idênticos.
- Inventário do runtime R isolado: `$($oracleRLibrary.inventory_sha256)`;
  snapshot imutável `$oracleRuntimeInventorySha256`.
- Perfil exaustivo de equivalência da preparação:
  `$($preparationEquivalenceBinding.sha256)`; projeções autorizadas: `0`.
- Registro de controle da prova:
  `$($state.oracle_effect.control_record_sha256)`.
- Tabela de 60 deltas de recálculo: `$(Get-Issue13V5Sha256 $oraclePath)`;
  projeção agregada `$oracleDeltaInventorySha256`.
- Tabela RSS autenticada: `$(Get-Issue13V5Sha256 $performancePath)`;
  projeção agregada `$rssEvidenceInventorySha256`.
- Evidência final: `$($evidenceInventory.inventory_sha256)`
- Agregado final: `$($state.final_aggregate.sha256)`
- Envelope do agregado: `$($aggregateInventory.inventory_sha256)`
- Subagregado preparação/falhas: `$(Get-Issue13V5Sha256 $state.prep_fault.aggregate_path)`
- Comparação paper 0: `$(Get-Issue13V5Sha256 $paperComparisonPath)`

## times

- Tempo baseline somado: `$([Math]::Round($baselineSeconds, 3))` segundos.
- Tempo candidato somado: `$([Math]::Round($candidateSeconds, 3))` segundos.
- Maior razão candidato/baseline: `$([Math]::Round($maximumTimeRatio, 6))`
  (limite `1.2`).
- Todos os 76 limites de tempo passaram: `TRUE`.

## peak_rss

- Maior RSS candidato: `$maximumCandidateRss` bytes.
- Maior utilização do limite RSS: `$([Math]::Round($maximumRssUtilization, 6))`.
- Regra: baseline + `max(10%, 512 MiB)`; todos os 76 pares passaram.
- Os 76 picos foram recomputados de `process-samples.csv` autenticado; todas as
  contagens por braço são positivas e todos os hashes de amostras têm 64
  dígitos hexadecimais. Projeção RSS: `$rssEvidenceInventorySha256`.
- WIOD13/WIOD16 com `workers=2`: equivalentes a `workers=1`, contagem exata de
  workers e `cluster_closed=true`.

## differences

- Checks executados: `$($aggregate.check_count)`; falhas: `0`.
- O smoke estrito em `cc2c861` passou 5 métodos e falhou 7; sua evidência é
  negativa e `final_evidence_eligible=false`.
- O resumo 5/7 é o registro histórico imutável. O selo integral do diretório
  `attempts` foi calculado posteriormente sobre o archive preservado; ele prova
  o estado atual do archive, não constitui prova contemporânea dos bytes
  físicos de `Rscript.exe` usados em 25/08/2026. A identidade de Rscript acima
  é o vínculo atual, reaberto e validado antes/depois do workflow.
- O smoke do oráculo filho passou os 12 métodos; ele também é apenas preflight
  e `final_evidence_eligible=false`.
- A alteração do baseline executável é o patch integral autenticado do filho
  direto; nenhuma alteração dele pertence ao candidato ou ao PR.
- As diferenças arquiteturais são exclusivamente as transformações
  explicitamente declaradas: `_runtime_resources.rds`,
  `_nonfinite_resolution_diagnostics.csv`, os campos de identidade/proveniência
  não científicos do envelope e a transição de sidecar descrita abaixo.
  A preparação não autoriza projeções: sua ponte tipada compara todas as linhas,
  colunas e a ordem integral. Cada transformação possui validação própria; não
  existe fallback genérico.
- As fontes normalizadas têm manifests/contratos próprios por braço.
  `_unit_contract.csv` e `_source_manifest.csv` são comparados integralmente
  contra tabelas arm-specific controller-pinned; `module`,
  `aggregation_notes`, identidades, tamanhos, hashes, ordem e todas as demais
  células permanecem vinculados. Os sidecars são aceitos somente após validar
  a transição autenticada
  `legacy-positional` → `versioned-v1`, dimensões, dimnames, hash interno e o
  array bit a bit; todos os demais artefatos e campos permanecem estritos.
- `_nonfinite_resolution_diagnostics.csv` é candidato-only conforme contrato.
- Não foi introduzida tolerância numérica nova.
- Os 60 oráculos de recálculo têm schema
  `wlv-issue13-complete-recalculation-delta/1`,
  `complete_delta_equal=TRUE` e digests baseline/candidato idênticos. Projeção
  agregada: `$oracleDeltaInventorySha256`.
$([string]::Join("`n", $oracleLines))

## oracle_effect_proof

A prova auxiliar fecha o efeito do patch autorizado `cc2 → e2f`, mas conserva
`final_evidence_eligible=false`; ela é uma pré-condição obrigatória e não
substitui o gate V5 final.

- Prova: `$($config.oracle_effect.proof.path)`; SHA-256
  `$($config.oracle_effect.proof.sha256)`.
- Patch autorizado: `$($config.baseline_overlay.sha256)`; stable patch-id
  `$($config.baseline_overlay.patch_id)`.
- Spec: `$($oracleEffectProof.evidence.spec.sha256)`; schema da prova:
  `$($oracleEffectProof.evidence.proof_schema.sha256)`.
- Pares strict comuns: `5/5`; execuções primary/replay: `10/10`; inventários de
  runs aprovados e imutáveis: `17/17`; métodos recuperados: `7/7`; efeito
  fechado: `TRUE`; substituição do gate final: `FALSE`.
- Raiz primary: `$($config.oracle_effect.comparisons.primary.root)`; inventário
  `$($config.oracle_effect.comparisons.primary.inventory.inventory_sha256)`
  ($($config.oracle_effect.comparisons.primary.inventory.file_count) arquivos).
- Raiz replay: `$($config.oracle_effect.comparisons.replay.root)`; inventário
  `$($config.oracle_effect.comparisons.replay.inventory.inventory_sha256)`
  ($($config.oracle_effect.comparisons.replay.inventory.file_count) arquivos).
- Inventário agregado primary/replay:
  `$($config.oracle_effect.comparisons.inventory.inventory_sha256)`.
- Harness terminal: geração `$($oracleTerminalHarness.generation)`, commit
  `$($oracleTerminalHarness.expected_candidate_commit)`, manifesto
  `$($oracleTerminalHarness.manifest_sha256)`, inventários output/sealed/instalado
  `$($oracleTerminalHarness.output_tooling.inventory_sha256)` /
  `$($oracleTerminalHarness.sealed_output_tooling.inventory_sha256)` /
  `$($oracleTerminalHarness.installed_inventory.inventory_sha256)`.
- Controladores-fonte: `34/34`, commit
  `$($oracleSourceController.commit_sha256)`, inventário
  `$($oracleSourceController.inventory_sha256)`.
- Tooling-fonte: `37/37`, um diretório descendente e duas árvores Git; commit
  `$($oracleSourceTooling.candidate_commit)`, inventário
  `$($oracleSourceTooling.inventory_sha256)`, idêntico no manifesto, na
  configuração e na prova.
- Rscript autenticado:
  `$($oracleRscript.logical_path)` → `$($oracleRscript.physical_path)`, item
  `$($oracleRscript.item_id)`, links `$($oracleRscript.link_count)`,
  `$($oracleRscript.size_bytes)` bytes, SHA-256 `$($oracleRscript.sha256)`;
  biblioteca R
  `$($oracleRLibrary.path)` via `R_LIBS_USER`, com raiz `renv` explícita em
  `RENV_PATHS_LIBRARY`; inventário
  `$($oracleRLibrary.inventory_sha256)`; os dez comandos usam `--vanilla`,
  `TZ=UTC` e removem as 35 variáveis de ambiente seladas.
- Runtime R antes/depois: `$oracleRuntimeInventorySha256`; imutável: `TRUE`;
  versão `$($oracleRLibrary.r_version)`; plataforma
  `$($oracleRLibrary.platform)`; pacotes obrigatórios `fst,jsonlite,openssl`.
- Smoke da prova: `$($config.oracle_effect.oracle_smoke.sha256)`; smoke terminal
  do gate: `$($config.compatibility_baseline_smoke.sha256)`.

Cinco métodos comuns, comparados integralmente em modo strict:

$([string]::Join("`n", $oracleCommonLines))

Sete métodos recuperados, com falha cc2 e efeitos/diagnósticos e2f autenticados:

$([string]::Join("`n", $oracleRecoveredLines))

## preparation_results

- Status: `$($preparation.status)`; passed: `$preparationPassed`.
- WIOD13, WIOD16 e EU KLEMS foram preparados a partir das mesmas seis caches
  oficiais autenticadas.
- As gerações normalizadas baseline e candidata foram autenticadas
  separadamente antes da execução científica.
- Arrays normativos foram comparados bit a bit, preservando `NA`, `NaN`,
  infinitos e zero assinado; a extensão versionada dos sidecars candidatos foi
  validada contra os payloads FST.
- Promoção atômica e ausência de staging/locks foram verificadas.

## paper0_results

- Status da comparação semântica do workbook: `$($paperComparison.status)`.
- Métodos: `ochoa_1` e `ochoa_2`.
- O release e as células/sheets do workbook foram comparados semanticamente.
- Papers 3 e 4 permanecem não suportados no preflight.

## fault_results

- Falhas injetadas aprovadas: `$($prepFault.summary.fault_gates_passed)`.
- Rollbacks aprovados: `$($prepFault.summary.rollback_gates_passed)`.
- Releases parciais visíveis: `$($prepFault.summary.visible_partial_releases)`.
- Entradas de staging/lock remanescentes: `$($prepFault.summary.staging_entries)`.
$([string]::Join("`n", $faultLines))

## Conclusão

O agregado V5 passou integralmente. A evidência está vinculada à origem
`cc2c861`, ao runtime-oráculo filho autenticado, ao commit candidato acima, às
fontes oficiais e ao tooling V5 materializado. Qualquer alteração posterior em
configuração, harness, cenários, comparações, logs ou artefatos invalida os
hashes registrados neste relatório.
"@

$parent = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $parent
}
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$temporary = Join-Path $parent ('.issue-13.md-' +
  [Guid]::NewGuid().ToString('N') + '.tmp')
$writePrimary = $null
$reportResult = $null
try {
  [IO.File]::WriteAllText($temporary, $text, $utf8)
  $roundtrip = [IO.File]::ReadAllText($temporary, $utf8)
  if (-not [string]::Equals($roundtrip, $text,
      [StringComparison]::Ordinal) -or $roundtrip.Contains([char]0xFFFD)) {
    throw 'Issue #13 report UTF-8 round trip failed.'
  }
  foreach ($field in @($config.report.required_fields)) {
    if ($roundtrip -cnotmatch [regex]::Escape([string]$field)) {
      throw "Report lacks configured field: $field"
    }
  }

  $finalBinding = Assert-Issue13V5Config $initialConfigPath
  $finalConfig = $finalBinding.config
  $finalConfigCanonical = ConvertTo-Json -InputObject $finalConfig -Depth 100 `
    -Compress
  $finalConfigDiskCanonical = ConvertTo-Json -InputObject (
    Read-Issue13V5Json $initialConfigPath) -Depth 100 -Compress
  if (-not [string]::Equals(
      (ConvertTo-Issue13V5Path ([string]$finalBinding.path)),
      (ConvertTo-Issue13V5Path $initialConfigPath),
      [StringComparison]::OrdinalIgnoreCase) -or
      [string]$finalBinding.sha256 -cne $initialConfigSha256 -or
      (Get-Issue13V5Sha256 $initialConfigPath) -cne $initialConfigSha256 -or
      $finalConfigCanonical -cne $initialConfigCanonical -or
      $finalConfigDiskCanonical -cne $initialConfigCanonical) {
    throw 'Report config changed before atomic installation.'
  }

  $finalStatePath = ConvertTo-Issue13V5Path (
    Get-Issue13V5StatePath $finalConfig)
  if (-not [string]::Equals($finalStatePath, $providedStatePath,
      [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Report state binding changed before atomic installation.'
  }
  $finalStateSha256 = Get-Issue13V5Sha256 $finalStatePath
  $finalState = Read-Issue13V5Json $finalStatePath
  $finalStateCanonical = ConvertTo-Json -InputObject $finalState -Depth 100 `
    -Compress
  $finalStateDiskCanonical = ConvertTo-Json -InputObject (
    Read-Issue13V5Json $finalStatePath) -Depth 100 -Compress
  if ($finalStateSha256 -cne $initialStateSha256 -or
      (Get-Issue13V5Sha256 $finalStatePath) -cne $initialStateSha256 -or
      $finalStateCanonical -cne $initialStateCanonical -or
      $finalStateDiskCanonical -cne $initialStateCanonical) {
    throw 'Report state changed before atomic installation.'
  }
  $null = Assert-Issue13V5FinalBindings $finalConfig $finalState
  if ((Get-Issue13V5Sha256 $initialConfigPath) -cne
        $initialConfigSha256 -or
      (Get-Issue13V5Sha256 $finalStatePath) -cne $initialStateSha256) {
    throw 'Report config or state changed during final binding validation.'
  }

  $finalRepository = (Resolve-Path -LiteralPath (
    [string]$finalConfig.repository_root)).Path
  if (-not [string]::Equals($finalRepository, $repository,
      [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Report repository binding changed before atomic installation.'
  }
  $finalHead = (Invoke-Issue13V5SealedGit `
    -C $finalRepository rev-parse HEAD 2>$null).Trim()
  $finalHeadExitCode = $LASTEXITCODE
  $finalTrackedStatus = @(Invoke-Issue13V5SealedGit `
    -C $finalRepository status `
    '--porcelain=v1' '--untracked-files=no' 2>$null)
  $finalStatusExitCode = $LASTEXITCODE
  if ($finalHeadExitCode -ne 0 -or $finalStatusExitCode -ne 0 -or
      $finalHead -cne [string]$finalConfig.candidate_commit -or
      $finalTrackedStatus.Count -ne 0) {
    throw 'Report repository changed before atomic installation.'
  }
  if (Test-Path -LiteralPath $outputPath) {
    throw "Report output appeared before atomic installation: $outputPath"
  }
  [IO.File]::Move($temporary, $outputPath)
  if (-not [string]::Equals(
      [IO.File]::ReadAllText($outputPath, $utf8), $text,
      [StringComparison]::Ordinal)) {
    throw 'Installed Issue #13 report differs from verified UTF-8 payload.'
  }
  $reportResult = [pscustomobject]@{
    status = 'written'
    path = (Resolve-Path -LiteralPath $outputPath).Path
    sha256 = Get-Issue13V5Sha256 $outputPath
    baseline_commit = [string]$config.baseline_commit
    baseline_runtime_commit = [string]$config.baseline_runtime_commit
    candidate_commit = [string]$config.candidate_commit
  }
} catch {
  $writePrimary = $_
}
$writeCleanupFailures = [Collections.Generic.List[Exception]]::new()
try {
  if (Test-Path -LiteralPath $temporary) {
    [IO.File]::Delete($temporary)
  }
  if (Test-Path -LiteralPath $temporary) {
    throw 'Issue #13 report temporary file survived cleanup.'
  }
} catch {
  $writeCleanupFailures.Add($_.Exception)
}
if ($writeCleanupFailures.Count -ne 0) {
  $writeFailures = [Collections.Generic.List[Exception]]::new()
  if ($null -ne $writePrimary) {
    $writeFailures.Add($writePrimary.Exception)
  }
  foreach ($failure in $writeCleanupFailures) {
    $writeFailures.Add($failure)
  }
  throw [AggregateException]::new(
    'Issue #13 report write or temporary cleanup failed.',
    $writeFailures.ToArray())
}
if ($null -ne $writePrimary) { throw $writePrimary }
$reportResult
