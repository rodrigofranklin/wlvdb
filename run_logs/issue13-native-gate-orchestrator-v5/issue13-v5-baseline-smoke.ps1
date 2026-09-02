param(
  [Parameter(Mandatory = $true)][string]$HarnessRuntimeRoot,
  [Parameter(Mandatory = $true)][string]$SmokeRoot,
  [string]$RepositoryRoot = 'D:\Trabalho\Code\wlvdb',
  [string]$SourceOrigin =
    'D:\Trabalho\Code\wlvdb-issue13-baseline\source_data',
  [string]$Rscript =
    'C:\Users\rodri\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe',
  [string]$RLibrary =
    'D:\Trabalho\Code\wlvdb\renv\library\windows\R-4.6\x86_64-w64-mingw32',
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$BaselineRuntimeCommit =
    'e2f4d6dae9a6d35c966b305fabac52e489faa3e7',
  [ValidateSet('compatibility-oracle-executability-preflight')]
  [string]$Purpose = 'compatibility-oracle-executability-preflight',
  [switch]$ConfirmCreateWorktrees,
  [switch]$ConfirmExecuteR
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

if (-not $ConfirmCreateWorktrees -or -not $ConfirmExecuteR) {
  throw 'Baseline smoke requires -ConfirmCreateWorktrees and -ConfirmExecuteR.'
}

if (-not $IsWindows) {
  throw 'The V5 baseline smoke is Windows-only.'
}

$baselineSmokeNativePathAssembliesBefore =
  [Reflection.Assembly[]]@([AppDomain]::CurrentDomain.GetAssemblies())
$preexistingBaselineSmokeNativePathTypes = [type[]]@(
  [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
    $_.GetType('Issue13V5.BaselineSmokeNativePath', $false, $true)
  } | Where-Object { $null -ne $_ })
if ($preexistingBaselineSmokeNativePathTypes.Count -ne 0) {
  throw 'The baseline smoke native path type was preloaded.'
}
$baselineSmokeNativePathTypes = [object[]]@(
  Add-Type -PassThru -ErrorAction Stop -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace Issue13V5 {
  public static class BaselineSmokeNativePath {
    private const uint ShareAll = 0x00000007;
    private const uint OpenExisting = 3;
    private const uint BackupSemantics = 0x02000000;
    private const uint VolumeNameGuid = 0x00000001;

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFile(
      string fileName, uint desiredAccess, uint shareMode,
      IntPtr securityAttributes, uint creationDisposition,
      uint flagsAndAttributes, IntPtr templateFile);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint GetFinalPathNameByHandle(
      SafeFileHandle file, StringBuilder path, uint pathLength, uint flags);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint QueryDosDevice(
      string deviceName, StringBuilder targetPath, int maximumLength);

    public static string Resolve(string path) {
      using (SafeFileHandle handle = CreateFile(
        path, 0, ShareAll, IntPtr.Zero, OpenExisting,
        BackupSemantics, IntPtr.Zero)) {
        if (handle.IsInvalid) {
          throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        uint capacity = 512;
        while (true) {
          StringBuilder buffer = new StringBuilder((int)capacity);
          uint length = GetFinalPathNameByHandle(
            handle, buffer, capacity, VolumeNameGuid);
          if (length == 0) {
            throw new Win32Exception(Marshal.GetLastWin32Error());
          }
          if (length < capacity) {
            return buffer.ToString();
          }
          capacity = length + 1;
        }
      }
    }

    public static string DriveTarget(string driveName) {
      int capacity = 512;
      while (true) {
        StringBuilder buffer = new StringBuilder(capacity);
        uint length = QueryDosDevice(driveName, buffer, capacity);
        if (length != 0) {
          return buffer.ToString();
        }
        int error = Marshal.GetLastWin32Error();
        if (error != 122) {
          throw new Win32Exception(error);
        }
        capacity *= 2;
      }
    }
  }
}
'@)
$baselineSmokeNativePathType =
  'Issue13V5.BaselineSmokeNativePath' -as [type]
$baselineSmokeNativePathNonTypes = [object[]]@(
  $baselineSmokeNativePathTypes | Where-Object { $_ -isnot [type] })
$baselineSmokeNativePathReturnedAssemblies = [Reflection.Assembly[]]@(
  $baselineSmokeNativePathTypes | ForEach-Object { $_.Assembly } |
    Select-Object -Unique)
$baselineSmokeNativePathAssemblyWasPreexisting = [object[]]@(
  $baselineSmokeNativePathAssembliesBefore | Where-Object {
    [object]::ReferenceEquals(
      $_, $baselineSmokeNativePathReturnedAssemblies[0])
  })
$loadedBaselineSmokeNativePathTypes = [type[]]@(
  [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
    $_.GetType('Issue13V5.BaselineSmokeNativePath', $false, $true)
  } | Where-Object { $null -ne $_ })
$baselineSmokeNativePathMethods = [string[]]@(
  $baselineSmokeNativePathTypes[0].GetMethods(
    [Reflection.BindingFlags]'Public, Static, DeclaredOnly') |
    ForEach-Object { $_.ToString() } | Sort-Object)
if ($baselineSmokeNativePathTypes.Count -ne 1 -or
    $baselineSmokeNativePathTypes[0] -isnot [type] -or
    $baselineSmokeNativePathNonTypes.Count -ne 0 -or
    $baselineSmokeNativePathReturnedAssemblies.Count -ne 1 -or
    $baselineSmokeNativePathAssemblyWasPreexisting.Count -ne 0 -or
    [string]$baselineSmokeNativePathTypes[0].FullName -cne
      'Issue13V5.BaselineSmokeNativePath' -or
    $loadedBaselineSmokeNativePathTypes.Count -ne 1 -or
    $null -eq $baselineSmokeNativePathType -or
    -not [object]::ReferenceEquals(
      $baselineSmokeNativePathTypes[0], $baselineSmokeNativePathType) -or
    -not [object]::ReferenceEquals(
      $baselineSmokeNativePathTypes[0],
      $loadedBaselineSmokeNativePathTypes[0]) -or
    [string]::Join('|', $baselineSmokeNativePathMethods) -cne
      'System.String DriveTarget(System.String)|System.String Resolve(System.String)') {
  throw 'The baseline smoke native path type compilation was not singular.'
}
New-Variable -Name Issue13V5BaselineSmokeNativePathType `
  -Scope Script -Option Constant -Value $baselineSmokeNativePathTypes[0]

function Assert-Issue13V5BaselineSmokeLocalDrive(
  [string]$Path,
  [string]$Label
) {
  $full = [IO.Path]::GetFullPath($Path)
  $root = [IO.Path]::GetPathRoot($full)
  if ([string]::IsNullOrWhiteSpace($root) -or
      $root -cnotmatch '^[A-Za-z]:\\$') {
    throw "$Label must use a local drive-letter path: $full"
  }
  $drive = [IO.DriveInfo]::new($root)
  if (-not $drive.IsReady -or $drive.DriveType -ne [IO.DriveType]::Fixed) {
    throw "$Label must use a ready fixed local drive: $full"
  }
  $driveName = $root.Substring(0, 2)
  $target = $script:Issue13V5BaselineSmokeNativePathType::DriveTarget(
    $driveName)
  if ($target.StartsWith('\??\', [StringComparison]::OrdinalIgnoreCase) -or
      $target.StartsWith('\Device\Mup', [StringComparison]::OrdinalIgnoreCase) -or
      $target.StartsWith('\Device\LanmanRedirector',
        [StringComparison]::OrdinalIgnoreCase) -or
      $target.StartsWith('\Device\WebDavRedirector',
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "$Label must not use a SUBST or mapped-drive alias: $full"
  }
  $full
}

function ConvertTo-Issue13V5BaselineSmokePhysicalPath(
  [string]$Path,
  [string]$Label
) {
  $full = Assert-Issue13V5BaselineSmokeLocalDrive $Path $Label
  $missing = [Collections.Generic.List[string]]::new()
  $cursor = $full
  while (-not (Test-Path -LiteralPath $cursor)) {
    $leaf = [IO.Path]::GetFileName($cursor)
    if ([string]::IsNullOrWhiteSpace($leaf)) {
      throw "Cannot canonicalize $Label path: $full"
    }
    $missing.Add($leaf)
    $parent = [IO.Directory]::GetParent($cursor)
    if ($null -eq $parent) {
      throw "Cannot find an existing ancestor for $Label path: $full"
    }
    $cursor = $parent.FullName
  }
  $canonical =
    $script:Issue13V5BaselineSmokeNativePathType::Resolve($cursor).
    TrimEnd('\')
  for ($index = $missing.Count - 1; $index -ge 0; $index--) {
    $canonical = $canonical + '\' + $missing[$index]
  }
  $canonical.TrimEnd('\')
}

function Test-Issue13V5BaselineSmokePhysicalOverlap(
  [string]$Left,
  [string]$Right
) {
  $leftFull = $Left.TrimEnd('\')
  $rightFull = $Right.TrimEnd('\')
  [string]::Equals($leftFull, $rightFull,
    [StringComparison]::OrdinalIgnoreCase) -or
    $leftFull.StartsWith($rightFull + '\',
      [StringComparison]::OrdinalIgnoreCase) -or
    $rightFull.StartsWith($leftFull + '\',
      [StringComparison]::OrdinalIgnoreCase)
}

function Assert-Issue13V5BaselineSmokeRscriptSeal(
  [string]$Path,
  [object]$ExpectedIdentity,
  [string]$ExpectedSha256
) {
  $null = Assert-Issue13V5NoReparseAncestors $Path 'Rscript executable'
  $current = Get-Issue13V5PhysicalItemIdentity $Path 'Rscript executable'
  if ([uint64]$ExpectedIdentity.link_count -ne 1UL -or
      [uint64]$current.link_count -ne 1UL -or
      [string]$current.item_id -cne [string]$ExpectedIdentity.item_id -or
      -not [string]::Equals(
        [string]$current.physical_path,
        [string]$ExpectedIdentity.physical_path,
        [StringComparison]::OrdinalIgnoreCase) -or
      (Get-Issue13V5BaselineSmokeSha256 $Path) -cne $ExpectedSha256) {
    throw 'Rscript executable changed after its physical seal.'
  }
  $current
}

$baselineBaseCommit = 'cc2c86189a06676bcb9f0e05e08033d710a92509'
$compatibilityRuntimeCommit =
  'e2f4d6dae9a6d35c966b305fabac52e489faa3e7'
$baselineCommit = $BaselineRuntimeCommit
$sourceInventorySha256 =
  'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26'
$sourceDirectorySha256 =
  '8b3a622a748f2489fe8cfd2a8273ec98ad4c372b2378d587a5ee2e3c5c916640'
$expectedHarnessFileCount = 47L
$expectedHarnessTotalBytes = 2634087L
$expectedHarnessInventorySha256 =
  'c646c38f1aa5f3bdecd706036af81ac1cf9fc9b87e04f3b4f1f268eb97bb8722'
$methods = @(
  'wiodr13', 'wiodr16', 'alternative_1', 'alternative_2', 'norow_w13',
  'ochoa_1', 'ochoa_2', 'petrovic', 'wiodr13v09', 'wiodr16v09',
  'zerodep_1', 'zerodep_2'
)
$localeEnvironmentNames = @('LANG', 'LC_ALL', 'LC_CTYPE')
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function Get-Issue13V5BaselineSmokeSha256([string]$Path) {
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Issue13V5BaselineSmokeTextSha256([string]$Value) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
  [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($bytes)
  ).ToLowerInvariant()
}

function Get-Issue13V5SourceInventory([string]$Root) {
  $rootFull = (Resolve-Path -LiteralPath $Root).Path
  $directories = @(Get-ChildItem -LiteralPath $rootFull -Directory -Recurse -Force |
    ForEach-Object {
      $_.FullName.Substring($rootFull.Length + 1).Replace('\', '/')
    } | Sort-Object)
  $files = @(Get-ChildItem -LiteralPath $rootFull -File -Recurse -Force |
    ForEach-Object {
      [pscustomobject][ordered]@{
        relative_path = $_.FullName.Substring($rootFull.Length + 1).
          Replace('\', '/')
        size_bytes = [long]$_.Length
        sha256 = Get-Issue13V5BaselineSmokeSha256 $_.FullName
      }
    } | Sort-Object relative_path)
  $fileLines = @($files | ForEach-Object {
    [string]$_.relative_path + '|' + [string]$_.size_bytes + '|' +
      [string]$_.sha256
  })
  [pscustomobject][ordered]@{
    root = $rootFull
    file_count = [long]$files.Count
    directory_count = [long]$directories.Count
    total_bytes = [long](($files | Measure-Object size_bytes -Sum).Sum)
    inventory_sha256 = Get-Issue13V5BaselineSmokeTextSha256 (
      [string]::Join("`n", $fileLines))
    directory_list_sha256 = Get-Issue13V5BaselineSmokeTextSha256 (
      [string]::Join("`n", $directories))
    records = $files
  }
}

function Assert-Issue13V5BaselineSmokeSourceInventory(
  [object]$Inventory,
  [string]$Label
) {
  if ([long]$Inventory.file_count -ne 84 -or
      [long]$Inventory.directory_count -ne 5 -or
      [long]$Inventory.total_bytes -ne 2946498269L -or
      [string]$Inventory.inventory_sha256 -cne $sourceInventorySha256 -or
      [string]$Inventory.directory_list_sha256 -cne $sourceDirectorySha256) {
    throw "$Label does not match the authenticated official source inventory."
  }
}

function Write-Issue13V5BaselineSmokeJson(
  [object]$Value,
  [string]$Path
) {
  if (Test-Path -LiteralPath $Path) {
    throw "Refusing to overwrite V5 smoke JSON: $Path"
  }
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    $null = New-Item -ItemType Directory -Path $parent
  }
  $payload = ($Value | ConvertTo-Json -Depth 100) + "`n"
  $temporary = Join-Path $parent (
    '.' + [IO.Path]::GetFileName($Path) + '-' +
      [Guid]::NewGuid().ToString('N') + '.tmp'
  )
  [IO.File]::WriteAllText($temporary, $payload, $utf8)
  $roundtrip = [IO.File]::ReadAllText($temporary, $utf8)
  if (-not [string]::Equals($roundtrip, $payload,
      [StringComparison]::Ordinal)) {
    throw "UTF-8 smoke JSON round trip failed: $Path"
  }
  $null = $roundtrip | ConvertFrom-Json -DateKind String
  if ((Test-Path -LiteralPath $Path) -or
      -not (Move-Item -LiteralPath $temporary -Destination $Path -PassThru)) {
    throw "Cannot install V5 smoke JSON: $Path"
  }
  if (-not [string]::Equals(
      [IO.File]::ReadAllText($Path, $utf8),
      $payload,
      [StringComparison]::Ordinal)) {
    throw "Installed V5 smoke JSON changed: $Path"
  }
}

function Assert-Issue13V5SmokeHarness(
  [string]$RuntimeRoot,
  [string]$ManifestPath,
  [string]$Repository,
  [string]$ExpectedManifestSha256 = ''
) {
  $manifest = Read-Issue13V5Json $ManifestPath
  $candidateCommit = [string]$manifest.source_controller.commit_sha256
  if ($candidateCommit -cnotmatch '^[0-9a-f]{40}$') {
    throw 'Baseline smoke harness lacks its candidate controller commit.'
  }
  $bindingConfig = [pscustomobject]@{
    repository_root = $Repository
    candidate_commit = $candidateCommit
    harness_runtime_root = $RuntimeRoot
    harness_root = (Join-Path $RuntimeRoot 'issue13-evidence-harness')
    harness_manifest_path = $ManifestPath
    harness_manifest_sha256 = Get-Issue13V5BaselineSmokeSha256 $ManifestPath
  }
  $binding = Assert-Issue13V5HarnessBinding $bindingConfig
  if ((-not [string]::IsNullOrWhiteSpace($ExpectedManifestSha256) -and
        (Get-Issue13V5BaselineSmokeSha256 $ManifestPath) -cne
          $ExpectedManifestSha256) -or
      [long]$binding.inventory.file_count -ne $expectedHarnessFileCount -or
      [long]$binding.inventory.total_bytes -ne $expectedHarnessTotalBytes -or
      [string]$binding.inventory.inventory_sha256 -cne
        $expectedHarnessInventorySha256) {
    throw 'Baseline smoke harness changed after its sealed authentication.'
  }
  $binding
}

$null = Assert-Issue13V5NoReparseAncestors $RepositoryRoot 'Repository root'
$null = Assert-Issue13V5NoReparseAncestors $SourceOrigin 'Source origin'
$null = Assert-Issue13V5NoReparseAncestors $HarnessRuntimeRoot `
  'Harness runtime root'
$null = Assert-Issue13V5NoReparseAncestors $RLibrary 'R library'
$null = Assert-Issue13V5NoReparseAncestors $Rscript 'Rscript executable'
$null = Assert-Issue13V5NoReparseAncestors $SmokeRoot 'Smoke root'

$repository = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$source = (Resolve-Path -LiteralPath $SourceOrigin).Path
$runtimeRoot = (Resolve-Path -LiteralPath $HarnessRuntimeRoot).Path
$harness = Join-Path $runtimeRoot 'issue13-evidence-harness'
$harnessManifestPath = Join-Path $runtimeRoot 'v5-harness-manifest.json'
$rscriptBinding = Get-Issue13V5RscriptExecutableBinding $Rscript
$rscriptFull = [string]$rscriptBinding.logical_path
$rscriptIdentity = [pscustomobject][ordered]@{
  physical_path = [string]$rscriptBinding.physical_path
  item_id = [string]$rscriptBinding.item_id
  link_count = [uint64]$rscriptBinding.link_count
}
$rscriptSha256 = [string]$rscriptBinding.sha256
$library = (Resolve-Path -LiteralPath $RLibrary).Path
$smoke = [IO.Path]::GetFullPath($SmokeRoot)
if (-not (Test-Path -LiteralPath $harness -PathType Container) -or
    -not (Test-Path -LiteralPath $harnessManifestPath -PathType Leaf)) {
  throw 'The materialized V5 harness is incomplete.'
}
$null = Assert-Issue13V5NoReparseAncestors $harness 'Harness root'
$null = Assert-Issue13V5NoReparseAncestors $harnessManifestPath `
  'Harness manifest'
if (Test-Path -LiteralPath $smoke) {
  throw 'The disposable V5 smoke root already exists; reuse is forbidden.'
}
$smokePhysical = ConvertTo-Issue13V5BaselineSmokePhysicalPath $smoke `
  'Smoke root'
$protectedPhysicalPaths = @(
  [pscustomobject]@{
    label = 'repository root'
    path = ConvertTo-Issue13V5BaselineSmokePhysicalPath $repository `
      'Repository root'
  },
  [pscustomobject]@{
    label = 'source origin'
    path = ConvertTo-Issue13V5BaselineSmokePhysicalPath $source 'Source origin'
  },
  [pscustomobject]@{
    label = 'harness runtime root'
    path = ConvertTo-Issue13V5BaselineSmokePhysicalPath $runtimeRoot `
      'Harness runtime root'
  },
  [pscustomobject]@{
    label = 'harness root'
    path = ConvertTo-Issue13V5BaselineSmokePhysicalPath $harness 'Harness root'
  },
  [pscustomobject]@{
    label = 'harness manifest'
    path = ConvertTo-Issue13V5BaselineSmokePhysicalPath $harnessManifestPath `
      'Harness manifest'
  },
  [pscustomobject]@{
    label = 'Rscript executable'
    path = ConvertTo-Issue13V5BaselineSmokePhysicalPath `
      $rscriptFull 'Rscript executable'
  },
  [pscustomobject]@{
    label = 'R library'
    path = ConvertTo-Issue13V5BaselineSmokePhysicalPath $library 'R library'
  }
)
foreach ($protected in $protectedPhysicalPaths) {
  if (Test-Issue13V5BaselineSmokePhysicalOverlap $smokePhysical `
      ([string]$protected.path)) {
    throw "The disposable V5 smoke root physically overlaps the $($protected.label)."
  }
}
if ($Purpose -cne 'compatibility-oracle-executability-preflight' -or
    $baselineCommit -cne $compatibilityRuntimeCommit) {
  throw 'The live baseline smoke accepts only the sealed compatibility oracle.'
}
$null = Invoke-Issue13V5SealedGit `
  -C $repository cat-file -e ($baselineCommit + '^{commit}')
if ($LASTEXITCODE -ne 0) {
  throw "Baseline smoke runtime commit is unavailable: $baselineCommit"
}
$expectedRuntimeTree = (Invoke-Issue13V5SealedGit -C $repository rev-parse `
  ($baselineCommit + '^{tree}') 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $expectedRuntimeTree -cnotmatch '^[0-9a-f]{40}$') {
  throw 'Cannot authenticate the baseline smoke runtime tree.'
}
$parentCommit = (Invoke-Issue13V5SealedGit `
  -C $repository rev-parse ($baselineCommit + '^')).Trim()
$runtimeTree = (Invoke-Issue13V5SealedGit -C $repository rev-parse `
  ($baselineCommit + '^{tree}')).Trim()
if ($LASTEXITCODE -ne 0 -or $parentCommit -cne $baselineBaseCommit -or
    $runtimeTree -cne $expectedRuntimeTree -or
    $runtimeTree -cne '7da19c4f2913e857040ba228280f404b0e54eaab') {
  throw 'The compatibility oracle must be a direct child of cc2.'
}
if ($smoke -match '(?i)(^|[\\/])[^\\/]*v4(?:r[0-9]+)?[^\\/]*($|[\\/])' -or
    $smoke.StartsWith($repository + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase)) {
  throw 'The disposable V5 smoke root must be outside the repository and V4 roots.'
}
$harnessBinding = Assert-Issue13V5SmokeHarness $runtimeRoot `
  $harnessManifestPath $repository
$harnessManifest = $harnessBinding.manifest
$harnessManifestSha256 =
  Get-Issue13V5BaselineSmokeSha256 $harnessManifestPath

$sourceInventory = Get-Issue13V5SourceInventory $source
Assert-Issue13V5BaselineSmokeSourceInventory $sourceInventory 'Source origin'
$null = New-Item -ItemType Directory -Path $smoke
$null = Assert-Issue13V5NoReparseAncestors $smoke 'Created smoke root'
$createdSmokePhysical = ConvertTo-Issue13V5BaselineSmokePhysicalPath $smoke `
  'Created smoke root'
if (-not [string]::Equals($createdSmokePhysical, $smokePhysical,
    [StringComparison]::OrdinalIgnoreCase)) {
  throw 'The created V5 smoke root changed physical identity.'
}
$worktreeRoot = Join-Path $smoke 'worktrees'
$attemptRoot = Join-Path $smoke 'attempts'
$null = New-Item -ItemType Directory -Path $worktreeRoot
$null = New-Item -ItemType Directory -Path $attemptRoot

$started = [DateTime]::UtcNow
$records = [Collections.Generic.List[object]]::new()
$smokeEnvironment = New-Issue13V5ClosedREnvironment $library
$baselineCleanup = @(
  {
    $null = Assert-Issue13V5SmokeHarness $runtimeRoot `
      $harnessManifestPath $repository $harnessManifestSha256
  },
  {
    $null = Assert-Issue13V5BaselineSmokeRscriptSeal `
      $rscriptFull $rscriptIdentity $rscriptSha256
  }
)
$smokeAction = {
  foreach ($method in $methods) {
    $methodStarted = [DateTime]::UtcNow
    $project = Join-Path $worktreeRoot $method
    # Every timed scenario is a distinct attempt. Its bundle and evidence are
    # siblings below the attempt root so the canonical checkpoint binding is
    # both unique and exactly where issue13-scenario.R requires it.
    $methodAttempt = Join-Path $attemptRoot $method
    $methodEvidence = Join-Path $methodAttempt 'evidence'
    $methodSpecs = Join-Path $methodAttempt 'bundle'
    $scenarioId = "baseline/calculate/$method/workers1"
    $safeScenario = $scenarioId.Replace('/', '__')
    $scenarioEvidence = Join-Path (Join-Path $methodEvidence 'scenarios') `
      $safeScenario
    $status = 'failed'
    $detail = $null
    $resultSha = $null
    $metricsSha = $null
    $elapsedSeconds = $null
    $peakRssBytes = $null
    try {
      $null = Assert-Issue13V5SmokeHarness $runtimeRoot `
        $harnessManifestPath $repository $harnessManifestSha256
      $null = Invoke-Issue13V5SealedGit `
        -C $repository worktree add --detach $project $baselineCommit
      if ($LASTEXITCODE -ne 0) {
        throw "Cannot create baseline runtime worktree for $method."
      }
      $head = (Invoke-Issue13V5SealedGit `
        -C $project rev-parse HEAD).Trim()
      if ($LASTEXITCODE -ne 0 -or $head -cne $baselineCommit) {
        throw "Baseline worktree commit differs for $method."
      }
      $tracked = @(Invoke-Issue13V5SealedGit `
        -C $project status '--porcelain=v1' `
        '--untracked-files=no')
      if ($LASTEXITCODE -ne 0 -or $tracked.Count -ne 0) {
        throw "Baseline worktree is tracked-dirty for $method."
      }

      $targetSource = Join-Path $project 'source_data'
      $null = New-Item -ItemType Directory -Path $targetSource
      foreach ($sourceRecord in @($sourceInventory.records)) {
        $relativeNative = ([string]$sourceRecord.relative_path).Replace('/', '\')
        $from = Join-Path $source $relativeNative
        $to = Join-Path $targetSource $relativeNative
        $toParent = Split-Path -Parent $to
        if (-not (Test-Path -LiteralPath $toParent -PathType Container)) {
          $null = New-Item -ItemType Directory -Path $toParent
        }
        Copy-Item -LiteralPath $from -Destination $to
        if ((Get-Item -LiteralPath $to).Length -ne
              [long]$sourceRecord.size_bytes -or
            (Get-Issue13V5BaselineSmokeSha256 $to) -cne
              [string]$sourceRecord.sha256) {
          throw "Copied source file differs for $method/$relativeNative."
        }
      }
      $copiedInventory = Get-Issue13V5SourceInventory $targetSource
      Assert-Issue13V5BaselineSmokeSourceInventory $copiedInventory `
        "Copied source for $method"

      $null = New-Item -ItemType Directory -Path $methodEvidence
      $null = New-Item -ItemType Directory -Path $methodSpecs
      $channel = 'issue13-v5-smoke-b-' + $method.Replace('_', '-')
      $builder = Join-Path $harness 'issue13-build-calculate-bundle.R'
      $null = Assert-Issue13V5BaselineSmokeRscriptSeal `
        $rscriptFull $rscriptIdentity $rscriptSha256
      $builderEnvironment = New-Issue13V5ClosedREnvironment $library
      $builderArguments = [string[]]@(
        '--vanilla', $builder,
        '--arm', 'baseline',
        '--method', $method,
        '--workers', '1',
        '--project-root', $project,
        '--runtime-commit', $baselineCommit,
        '--channel', $channel,
        '--output', $methodSpecs,
        '--evidence-root', $methodEvidence,
        '--rscript', $rscriptFull,
        '--r-library', $library,
        '--timeout-seconds', '14400'
      )
      $builderExecution = [pscustomobject]@{ result = $null }
      $null = Invoke-Issue13V5WithCleanup `
        -Label "Baseline smoke builder for $method" `
        -Action {
          $builderExecution.result = Invoke-Issue13V5RscriptBounded `
            -RscriptPath $rscriptFull `
            -Arguments $builderArguments `
            -Label "Baseline smoke builder for $method" `
            -TimeoutSeconds 600 `
            -ExpectedExitCodes $null `
            -WorkingDirectory $project `
            -Environment $builderEnvironment
        } `
        -Cleanup @({
          $null = Assert-Issue13V5BaselineSmokeRscriptSeal `
            $rscriptFull $rscriptIdentity $rscriptSha256
        })
      if ($null -eq $builderExecution.result -or
          [int]$builderExecution.result.exit_code -ne 0) {
        throw "Cannot build baseline smoke bundle for $method."
      }
      $null = Assert-Issue13V5SmokeHarness $runtimeRoot `
        $harnessManifestPath $repository $harnessManifestSha256
      $bundle = Get-Content -LiteralPath (
        Join-Path $methodSpecs 'bundle.json') -Raw |
        ConvertFrom-Json -DateKind String
      $monitor = Join-Path $harness 'issue13-monitor.ps1'
      $null = Assert-Issue13V5BaselineSmokeRscriptSeal `
        $rscriptFull $rscriptIdentity $rscriptSha256
      $monitorExecution = [pscustomobject]@{ result = $null }
      $null = Invoke-Issue13V5WithCleanup `
        -Label "Baseline smoke monitor for $method" `
        -Action {
          $monitorExecution.result = Invoke-Issue13V5PwshTransient @(
            '-NoLogo', '-NoProfile', '-NonInteractive', '-File', $monitor,
            '-SpecPath', [string]$bundle.process_spec,
            '-EvidenceDir', [string]$bundle.scenario_evidence
          ) ("baseline-smoke-monitor/$method") 18000 @(0) $repository `
            $null $rscriptFull
        } `
        -Cleanup @(
          {
            $null = Assert-Issue13V5BaselineSmokeRscriptSeal `
              $rscriptFull $rscriptIdentity $rscriptSha256
          }
        )
      $null = Assert-Issue13V5SmokeHarness $runtimeRoot `
        $harnessManifestPath $repository $harnessManifestSha256
      if ($null -eq $monitorExecution.result -or
          [int]$monitorExecution.result.exit_code -ne 0) {
        throw "Baseline smoke monitor failed for $method."
      }
      $resultPath = Join-Path $scenarioEvidence 'scenario-result.json'
      $metricsPath = Join-Path $scenarioEvidence 'process-metrics.json'
      $result = Get-Content -LiteralPath $resultPath -Raw |
        ConvertFrom-Json -DateKind String
      $metrics = Get-Content -LiteralPath $metricsPath -Raw |
        ConvertFrom-Json -DateKind String
      if ([string]$result.schema -cne 'wlv-issue13-scenario-result/1' -or
          [string]$result.scenario_id -cne $scenarioId -or
          -not (Test-Issue13V5ExactBoolean $result.passed $true) -or
          [string]$result.status -cne 'passed' -or
          [string]$result.expected_commit -cne $baselineCommit -or
          [string]$result.observed_commit -cne $baselineCommit -or
          [string]$result.kind -cne 'calculate' -or
          [string]$result.request.method -cne $method -or
          [long]$result.request.workers -ne 1L -or
          [string]$metrics.schema -cne 'wlv-issue13-process-metrics/2' -or
          [string]$metrics.scenario_id -cne $scenarioId -or
          -not (Test-Issue13V5ExactBoolean $metrics.passed $true) -or
          [string]$metrics.status -cne 'passed' -or
          -not (Test-Issue13V5ExactBoolean `
            $metrics.cluster_closed $true) -or
          -not (Test-Issue13V5ExactBoolean `
            $metrics.worker_count_matched $true) -or
          [int]$metrics.expected_worker_processes -ne 0 -or
          [int]$metrics.max_concurrent_worker_processes -ne 0 -or
          @($metrics.lingering_pids).Count -ne 0) {
        throw "Baseline smoke evidence is not closed and passed for $method."
      }
      $telemetryBindings = @(
        @($metrics.stdout_path, $metrics.stdout_sha256,
          (Join-Path $scenarioEvidence 'stdout.log')),
        @($metrics.stderr_path, $metrics.stderr_sha256,
          (Join-Path $scenarioEvidence 'stderr.log')),
        @($metrics.samples_path, $metrics.samples_sha256,
          (Join-Path $scenarioEvidence 'process-samples.csv')),
        @($metrics.process_spec_path, $metrics.process_spec_sha256,
          (Join-Path $methodSpecs 'process-spec.json'))
      )
      foreach ($telemetry in $telemetryBindings) {
        $observedPath = [IO.Path]::GetFullPath([string]$telemetry[0])
        $expectedPath = [IO.Path]::GetFullPath([string]$telemetry[2])
        if (-not [string]::Equals($observedPath, $expectedPath,
              [StringComparison]::OrdinalIgnoreCase) -or
            [string]$telemetry[1] -cnotmatch '^[0-9a-f]{64}$' -or
            -not (Test-Path -LiteralPath $expectedPath -PathType Leaf) -or
            (Get-Issue13V5BaselineSmokeSha256 $expectedPath) -cne
              [string]$telemetry[1]) {
          throw "Baseline smoke telemetry binding differs for $method."
        }
      }
      $finalHead = (Invoke-Issue13V5SealedGit `
        -C $project rev-parse HEAD 2>$null).Trim()
      $finalTree = (Invoke-Issue13V5SealedGit `
        -C $project rev-parse 'HEAD^{tree}' 2>$null).Trim()
      $finalTracked = @(Invoke-Issue13V5SealedGit `
        -C $project status '--porcelain=v1' `
        '--untracked-files=no' 2>$null)
      if ($LASTEXITCODE -ne 0 -or $finalHead -cne $baselineCommit -or
          $finalTree -cne $expectedRuntimeTree -or $finalTracked.Count -ne 0) {
        throw "Baseline smoke worktree changed during execution for $method."
      }
      $afterInventory = Get-Issue13V5SourceInventory $targetSource
      Assert-Issue13V5BaselineSmokeSourceInventory $afterInventory `
        "Post-execution source for $method"
      if ([string]$afterInventory.inventory_sha256 -cne
          [string]$copiedInventory.inventory_sha256) {
        throw "Baseline smoke changed source_data for $method."
      }
      $status = 'passed'
      $resultSha = Get-Issue13V5BaselineSmokeSha256 $resultPath
      $metricsSha = Get-Issue13V5BaselineSmokeSha256 $metricsPath
      $elapsedSeconds = [double]$metrics.elapsed_seconds
      $peakRssBytes = [long]$metrics.peak_rss_bytes
    } catch {
      $detail = $_.Exception.Message
    }
    $records.Add([ordered]@{
      method = $method
      scenario_id = $scenarioId
      status = $status
      detail = $detail
      project_root = $project
      evidence_directory = $scenarioEvidence
      scenario_result_sha256 = $resultSha
      process_metrics_sha256 = $metricsSha
      elapsed_seconds = $elapsedSeconds
      peak_rss_bytes = $peakRssBytes
      started_at_utc = $methodStarted.ToString('o')
      finished_at_utc = [DateTime]::UtcNow.ToString('o')
    })
  }
}
$environmentAction = {
  $null = Invoke-Issue13V5WithProcessEnvironment `
    -Environment $smokeEnvironment `
    -Label 'Baseline smoke process environment' `
    -Action $smokeAction
}
$null = Invoke-Issue13V5WithCleanup `
  -Label 'Baseline smoke execution' `
  -Cleanup $baselineCleanup `
  -Action $environmentAction

$null = Assert-Issue13V5BaselineSmokeRscriptSeal `
  $rscriptFull $rscriptIdentity $rscriptSha256
$null = Assert-Issue13V5SmokeHarness $runtimeRoot `
  $harnessManifestPath $repository $harnessManifestSha256
$passedCount = @($records | Where-Object status -ceq 'passed').Count
$summary = [ordered]@{
  schema = 'wlv-issue13-v5-baseline-smoke/1'
  status = if ($passedCount -eq 12) { 'passed' } else { 'failed' }
  passed = $passedCount -eq 12
  final_evidence_eligible = $false
  purpose = $Purpose
  baseline_commit = $baselineBaseCommit
  baseline_base_commit = $baselineBaseCommit
  baseline_runtime_commit = $baselineCommit
  started_at_utc = $started.ToString('o')
  finished_at_utc = [DateTime]::UtcNow.ToString('o')
  source_inventory_sha256 = $sourceInventorySha256
  rscript_path = $rscriptFull
  rscript_physical_path = [string]$rscriptIdentity.physical_path
  rscript_item_id = [string]$rscriptIdentity.item_id
  rscript_link_count = [uint64]$rscriptIdentity.link_count
  rscript_sha256 = $rscriptSha256
  harness_manifest_path = $harnessManifestPath
  harness_manifest_sha256 = $harnessManifestSha256
  environment_removed = [object[]]$localeEnvironmentNames
  method_count = 12
  passed_count = $passedCount
  failed_count = 12 - $passedCount
  records = $records.ToArray()
  disposition =
    'Disposable smoke worktrees must never be reused by the final V5 gate.'
}
$summaryPath = Join-Path $smoke 'baseline-smoke-summary.json'
Write-Issue13V5BaselineSmokeJson $summary $summaryPath

[pscustomobject][ordered]@{
  status = [string]$summary.status
  summary_path = (Resolve-Path -LiteralPath $summaryPath).Path
  summary_sha256 = Get-Issue13V5BaselineSmokeSha256 $summaryPath
  passed_count = $passedCount
  failed_count = 12 - $passedCount
}
if ($passedCount -ne 12) {
  throw "Baseline smoke failed for $([int](12 - $passedCount)) method(s)."
}
