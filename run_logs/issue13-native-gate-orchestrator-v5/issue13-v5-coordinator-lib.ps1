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

$issue13V5BootstrapPwshPath =
  'C:\Users\rodri\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
$issue13V5CurrentProcessPath = [IO.Path]::GetFullPath(
  [Environment]::ProcessPath)
$issue13V5CurrentProcess = [Diagnostics.Process]::GetCurrentProcess()
try {
  $issue13V5CurrentMainModulePath = [IO.Path]::GetFullPath(
    [string]$issue13V5CurrentProcess.MainModule.FileName)
} finally {
  $issue13V5CurrentProcess.Dispose()
}
if (-not [string]::Equals(
      $issue13V5CurrentProcessPath, $issue13V5BootstrapPwshPath,
      [StringComparison]::OrdinalIgnoreCase) -or
    -not [string]::Equals(
      $issue13V5CurrentMainModulePath, $issue13V5BootstrapPwshPath,
      [StringComparison]::OrdinalIgnoreCase)) {
  throw 'The V5 authority bootstrap requires its fixed pwsh host.'
}
$issue13V5BootstrapPwshStream = [IO.File]::Open(
  $issue13V5BootstrapPwshPath, [IO.FileMode]::Open,
  [IO.FileAccess]::Read, [IO.FileShare]::Read)
$issue13V5BootstrapPwshHasher = $null
try {
  $issue13V5BootstrapPwshSize = [int64]$issue13V5BootstrapPwshStream.Length
  $issue13V5BootstrapPwshHasher = [Security.Cryptography.SHA256]::Create()
  $issue13V5BootstrapPwshSha256 = [Convert]::ToHexString(
    $issue13V5BootstrapPwshHasher.ComputeHash(
      $issue13V5BootstrapPwshStream)).ToLowerInvariant()
} finally {
  if ($null -ne $issue13V5BootstrapPwshHasher) {
    $issue13V5BootstrapPwshHasher.Dispose()
  }
  $issue13V5BootstrapPwshStream.Dispose()
}
if ($issue13V5BootstrapPwshSize -ne 301368L -or
    $issue13V5BootstrapPwshSha256 -cne
      'db6dd81183fe57d22e03b911ec9a30a2fd7c40542e97743615355a6fb44f458f') {
  throw 'The V5 authority bootstrap pwsh bytes do not match their seal.'
}

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
# Terminal harness fixture. Keep this one coordinator triplet synchronized with
# materialize-harness and sealed_inventory when the terminal dry-run reseals it.
$script:Issue13V5HarnessFileCount = 47L
$script:Issue13V5HarnessTotalBytes = 2629957L
$script:Issue13V5HarnessInventorySha256 =
  '926ff38a659b7ab8c52af906ed00ddf45d9c4ec2d1daacf2ae2d2a98b63a401c'
$script:Issue13V5SourceToolingRelativeRoot =
  'run_logs/issue13-evidence-source-v5'
$script:Issue13V5SourceToolingPathListSha256 =
  '7bf2e27807e9bc36d3d3766789439d0d9afdd7b2cc5127145ce0e0f6819db00d'
$script:Issue13V5SourceToolingFiles = @(
  'issue13-evidence-harness/issue13-aggregate-prep-fault.R',
  'issue13-evidence-harness/issue13-aggregate.R',
  'issue13-evidence-harness/issue13-audit-prep-fault-plan.R',
  'issue13-evidence-harness/issue13-baseline-runtime-index-lib.R',
  'issue13-evidence-harness/issue13-build-calculate-bundle.R',
  'issue13-evidence-harness/issue13-build-fault-seed-specs.R',
  'issue13-evidence-harness/issue13-build-paper-bundle.R',
  'issue13-evidence-harness/issue13-build-prep-fault-specs.R',
  'issue13-evidence-harness/issue13-build-recalc-bundle.R',
  'issue13-evidence-harness/issue13-compare-lib.R',
  'issue13-evidence-harness/issue13-compare-results.R',
  'issue13-evidence-harness/issue13-compare.R',
  'issue13-evidence-harness/issue13-import-baseline-lib.R',
  'issue13-evidence-harness/issue13-import-baseline-run.R',
  'issue13-evidence-harness/issue13-import-baseline-selftest.R',
  'issue13-evidence-harness/issue13-import-fault-inputs.R',
  'issue13-evidence-harness/issue13-lib.R',
  'issue13-evidence-harness/issue13-matrix.R',
  'issue13-evidence-harness/issue13-monitor-selftest.ps1',
  'issue13-evidence-harness/issue13-monitor.ps1',
  'issue13-evidence-harness/issue13-run-fault-seed-record.ps1',
  'issue13-evidence-harness/issue13-run-fault-seeds.ps1',
  'issue13-evidence-harness/issue13-run-plan.ps1',
  'issue13-evidence-harness/issue13-run-prep-fault-record.ps1',
  'issue13-evidence-harness/issue13-run-recalc-bundle.ps1',
  'issue13-evidence-harness/issue13-scenario.R',
  'issue13-evidence-harness/issue13-seed-channel.R',
  'issue13-evidence-harness/issue13-seed-runtime-lib.R',
  'issue13-evidence-harness/issue13-seed-runtime-selftest.R',
  'issue13-evidence-harness/issue13-selftest.R',
  'issue13-evidence-harness/issue13-snapshot.R',
  'issue13-evidence-harness/README.md',
  'issue13-prep-paper-lib.R',
  'issue13-preparation-auth-lib.R',
  'issue13-preparation-compare.R',
  'issue13-preparation-rule-matrix.json',
  'issue13-runtime-loader-selftest.R'
)
$script:Issue13V5StrictSmokeSha256 =
  '973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d'
$script:Issue13V5StrictSmokeHarnessSha256 =
  'a17a187621cdd4aff6f24efd6bf43ffbf9336de0a19189dfc7f5a82758a92c23'
$script:Issue13V5StrictAttemptsInventorySha256 =
  '12b63f23e87b12b6afc0beabec9e64518b0ce114f1ae8b7fa481c01c78320edf'
$script:Issue13V5StrictAttemptsDirectoryListSha256 =
  '7bdb481081e12c4522f6dfdace2ec2c00015127139b574356f76e019754592ea'
$script:Issue13V5StrictAttemptsPathListSha256 =
  '5b805a5b9c7d2e1d09b111392b8d0795e60b4866e55f606ac8db9dc4e7cf7657'
$script:Issue13V5StrictWorktreeTree =
  '0cb1142cdadd74bf95272010f5393ebe2af79f47'
$script:Issue13V5RscriptSha256 =
  '3ad097e10d867e09eb7e54d8ed1f8ef933779b82be56482a04a27d65536d15f9'
function Set-Issue13V5ScriptConstant(
  [Parameter(Mandatory)][string]$Name,
  [Parameter(Mandatory)][object]$Value
) {
  $existing = Get-Variable -Name $Name -Scope Script `
    -ErrorAction SilentlyContinue
  if ($null -eq $existing) {
    New-Variable -Name $Name -Scope Script -Option Constant -Value $Value
    return
  }
  if ($existing.Options -ne
      [Management.Automation.ScopedItemOptions]::Constant -or
      -not [object]::Equals($existing.Value, $Value)) {
    throw "Script constant is already bound differently: $Name"
  }
}

Set-Issue13V5ScriptConstant Issue13V5SourceFileCount 84L
Set-Issue13V5ScriptConstant Issue13V5SourceDirectoryCount 5L
Set-Issue13V5ScriptConstant Issue13V5SourceTotalBytes 2946498269L
Set-Issue13V5ScriptConstant Issue13V5SourceInventorySha256 `
  'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26'
Set-Issue13V5ScriptConstant Issue13V5SourceOrdinalInventorySha256 `
  'd7fc0ba48bed304cf3975f2189ee975b14c16522443b28379d26329ea661b97a'
Set-Issue13V5ScriptConstant Issue13V5SourceDirectorySha256 `
  '8b3a622a748f2489fe8cfd2a8273ec98ad4c372b2378d587a5ee2e3c5c916640'
Set-Issue13V5ScriptConstant Issue13V5GitLogicalPath `
  'C:\Program Files\Git\cmd\git.exe'
Set-Issue13V5ScriptConstant Issue13V5GitPhysicalPath `
  '\\?\Volume{7a3529b3-025c-4979-af5e-15727f2f665d}\Program Files\Git\cmd\git.exe'
Set-Issue13V5ScriptConstant Issue13V5GitItemId `
  '0000000034ee9270:00000000000000000002000000058d31'
Set-Issue13V5ScriptConstant Issue13V5GitLinkCount 2L
Set-Issue13V5ScriptConstant Issue13V5GitSizeBytes 46936L
Set-Issue13V5ScriptConstant Issue13V5GitSha256 `
  '22fead8244ef3a7225fb800099a4e43eca8bcec0466774917669599c2f19a05a'
Set-Issue13V5ScriptConstant Issue13V5PwshLogicalPath `
  'C:\Users\rodri\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
Set-Issue13V5ScriptConstant Issue13V5PwshPhysicalPath `
  '\\?\Volume{7a3529b3-025c-4979-af5e-15727f2f665d}\Users\rodri\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
Set-Issue13V5ScriptConstant Issue13V5PwshItemId `
  '0000000034ee9270:000000000000000000060000000d10a9'
Set-Issue13V5ScriptConstant Issue13V5PwshLinkCount 1L
Set-Issue13V5ScriptConstant Issue13V5PwshSizeBytes 301368L
Set-Issue13V5ScriptConstant Issue13V5PwshSha256 `
  'db6dd81183fe57d22e03b911ec9a30a2fd7c40542e97743615355a6fb44f458f'
Set-Issue13V5ScriptConstant Issue13V5RscriptLogicalPath `
  'C:\Users\rodri\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe'
Set-Issue13V5ScriptConstant Issue13V5RscriptPhysicalPath `
  '\\?\Volume{7a3529b3-025c-4979-af5e-15727f2f665d}\Users\rodri\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe'
Set-Issue13V5ScriptConstant Issue13V5RscriptItemId `
  '0000000034ee9270:0000000000000000000200000005ebe0'
Set-Issue13V5ScriptConstant Issue13V5RscriptLinkCount 1L
Set-Issue13V5ScriptConstant Issue13V5RscriptSizeBytes 94720L
$script:Issue13V5CandidateSourceFileCount = 76L
$script:Issue13V5CandidateSourceDirectoryCount = 6L
$script:Issue13V5CandidateSourceTotalBytes = 2035522216L
$script:Issue13V5CandidateSourceInventorySha256 =
  '22e90e9485d7cee19d1de786c3464106d9a857ad3d85d0c9f2b3d912a0f38026'
$script:Issue13V5CandidateSourceDirectorySha256 =
  'c75aa417f14cded3c3bb6028effc8acadd64a32e86fddc0f1278079acdb6f114'
$script:Issue13V5AllowedRCommandSha256 =
  'cb09e749c6c1d9e1d5b93ea7c1cf4333d9f57f816fcc25967b04adb4e2595fc1'
$script:Issue13V5OracleEffectFiles = @(
  'issue13-v5-oracle-effect-README.md',
  'issue13-v5-oracle-effect-generate.ps1',
  'issue13-v5-oracle-effect-lib.ps1',
  'issue13-v5-oracle-effect-proof.schema.json',
  'issue13-v5-oracle-effect-spec.json',
  'issue13-v5-oracle-effect-validate.ps1'
)
$script:Issue13V5ControllerFiles = @(
  'README.md',
  'issue13-v5-aggregate-hardening.R',
  'issue13-v5-attest-delivery.ps1',
  'issue13-v5-baseline-smoke.ps1',
  'issue13-v5-build-baseline-index.R',
  'issue13-v5-build-diagnostic-bridges.R',
  'issue13-v5-build-metadata-equivalence.R',
  'issue13-v5-build-preparation-equivalence.R',
  'issue13-v5-build-stage5-profiles.R',
  'issue13-v5-capture-clean-bridge-evidence.ps1',
  'issue13-v5-capture-clean-stage5-evidence.ps1',
  'issue13-v5-compare-override.R',
  'issue13-v5-compatibility-baseline-override.R',
  'issue13-v5-coordinator-lib.ps1',
  'issue13-v5-coordinator.ps1',
  'issue13-v5-diagnostic-module-bridges.csv',
  'issue13-v5-diagnostics-override.R',
  'issue13-v5-difference-fingerprint.R',
  'issue13-v5-materialize-harness.ps1',
  'issue13-v5-metadata-equivalence.json',
  'issue13-v5-new-config.ps1',
  'issue13-v5-oracle-effect-README.md',
  'issue13-v5-oracle-effect-generate.ps1',
  'issue13-v5-oracle-effect-lib.ps1',
  'issue13-v5-oracle-effect-proof.schema.json',
  'issue13-v5-oracle-effect-spec.json',
  'issue13-v5-oracle-effect-validate.ps1',
  'issue13-v5-preparation-equivalence.R',
  'issue13-v5-preparation-equivalence.json',
  'issue13-v5-render-report.ps1',
  'issue13-v5-run-stage5-evidence.R',
  'issue13-v5-stage5-multiplicity-profiles.csv',
  'issue13-v5-static-verify.ps1',
  'issue13-v5-verify-diagnostic-evidence.R'
)
$script:Issue13V5OracleRequiredRPackages = @('fst', 'jsonlite', 'openssl')
$script:Issue13V5OracleClearedREnvironment = @(
  'LANG', 'LC_ALL', 'LC_CTYPE',
  'R_ARCH', 'R_DEFAULT_PACKAGES', 'R_ENVIRON', 'R_ENVIRON_USER', 'R_HOME',
  'R_LIBS', 'R_LIBS_SITE', 'R_PROFILE', 'R_PROFILE_USER', 'R_STARTUP_DEBUG',
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

function Test-Issue13V5ExactBoolean {
  param(
    [Parameter(Mandatory = $true)][AllowNull()][object]$Value,
    [Parameter(Mandatory = $true)][AllowNull()][object]$Expected
  )
  ($Value -is [bool]) -and ($Expected -is [bool]) -and
    ([bool]$Value -eq [bool]$Expected)
}

if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
  $coordinatorNativePathAssembliesBefore =
    [Reflection.Assembly[]]@([AppDomain]::CurrentDomain.GetAssemblies())
  $preexistingCoordinatorNativePathTypes = [type[]]@(
    [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
      $_.GetType('Issue13V5.CoordinatorNativePath', $false, $true)
    } | Where-Object { $null -ne $_ })
  if ($preexistingCoordinatorNativePathTypes.Count -ne 0) {
    throw 'The coordinator native path type was preloaded.'
  }
  $coordinatorNativePathTypes = [object[]]@(
    Add-Type -PassThru -ErrorAction Stop -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace Issue13V5 {
  public static class CoordinatorNativePath {
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

    [StructLayout(LayoutKind.Sequential)]
    private struct ByHandleFileInformation {
      public uint FileAttributes;
      public System.Runtime.InteropServices.ComTypes.FILETIME CreationTime;
      public System.Runtime.InteropServices.ComTypes.FILETIME LastAccessTime;
      public System.Runtime.InteropServices.ComTypes.FILETIME LastWriteTime;
      public uint VolumeSerialNumber;
      public uint FileSizeHigh;
      public uint FileSizeLow;
      public uint NumberOfLinks;
      public uint FileIndexHigh;
      public uint FileIndexLow;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetFileInformationByHandle(
      SafeFileHandle file, out ByHandleFileInformation information);

    [StructLayout(LayoutKind.Sequential)]
    private struct FileIdInformation {
      public ulong VolumeSerialNumber;
      [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
      public byte[] FileId;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetFileInformationByHandleEx(
      SafeFileHandle file, int informationClass,
      out FileIdInformation information, uint bufferSize);

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

    public static string Identity(string path) {
      using (SafeFileHandle handle = CreateFile(
        path, 0, ShareAll, IntPtr.Zero, OpenExisting,
        BackupSemantics, IntPtr.Zero)) {
        if (handle.IsInvalid) {
          throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        ByHandleFileInformation information;
        if (!GetFileInformationByHandle(handle, out information)) {
          throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        FileIdInformation fileId;
        uint fileIdSize = (uint)Marshal.SizeOf(typeof(FileIdInformation));
        if (!GetFileInformationByHandleEx(
          handle, 18, out fileId, fileIdSize)) {
          throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        Array.Reverse(fileId.FileId);
        string fileIdHex = BitConverter.ToString(fileId.FileId).
          Replace("-", "").ToLowerInvariant();
        uint rawVolume = information.VolumeSerialNumber;
        uint volume = ((rawVolume & 0x000000ffU) << 24) |
          ((rawVolume & 0x0000ff00U) << 8) |
          ((rawVolume & 0x00ff0000U) >> 8) |
          ((rawVolume & 0xff000000U) >> 24);
        return ((ulong)volume).ToString("x16") + ":" +
          fileIdHex + ":" + information.NumberOfLinks.ToString();
      }
    }
  }
}
'@)
  $coordinatorNativePathTargetTypes = [type[]]@(
    $coordinatorNativePathTypes | Where-Object {
      [string]$_.FullName -ceq 'Issue13V5.CoordinatorNativePath'
    })
  $coordinatorNativePathReturnedNames = [string[]]@(
    $coordinatorNativePathTypes | ForEach-Object { $_.FullName } |
      Sort-Object)
  $coordinatorNativePathNonTypes = [object[]]@(
    $coordinatorNativePathTypes | Where-Object { $_ -isnot [type] })
  $coordinatorNativePathReturnedAssemblies = [Reflection.Assembly[]]@(
    $coordinatorNativePathTypes | ForEach-Object { $_.Assembly } |
      Select-Object -Unique)
  $coordinatorNativePathAssemblyWasPreexisting = [object[]]@(
    $coordinatorNativePathAssembliesBefore | Where-Object {
      [object]::ReferenceEquals(
        $_, $coordinatorNativePathReturnedAssemblies[0])
    })
  $coordinatorNativePathType =
    'Issue13V5.CoordinatorNativePath' -as [type]
  $loadedCoordinatorNativePathTypes = [type[]]@(
    [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
      $_.GetType('Issue13V5.CoordinatorNativePath', $false, $true)
    } | Where-Object { $null -ne $_ })
  $coordinatorNativePathMethods = [string[]]@(
    $coordinatorNativePathTargetTypes[0].GetMethods(
      [Reflection.BindingFlags]'Public, Static, DeclaredOnly') |
      ForEach-Object { $_.ToString() } | Sort-Object)
  if ($coordinatorNativePathTypes.Count -ne 3 -or
      $coordinatorNativePathTargetTypes.Count -ne 1 -or
      $coordinatorNativePathNonTypes.Count -ne 0 -or
      $coordinatorNativePathReturnedAssemblies.Count -ne 1 -or
      $coordinatorNativePathAssemblyWasPreexisting.Count -ne 0 -or
      [string]::Join(',', $coordinatorNativePathReturnedNames) -cne
        ('Issue13V5.CoordinatorNativePath,' +
          'Issue13V5.CoordinatorNativePath+ByHandleFileInformation,' +
          'Issue13V5.CoordinatorNativePath+FileIdInformation') -or
      $loadedCoordinatorNativePathTypes.Count -ne 1 -or
      $null -eq $coordinatorNativePathType -or
      -not [object]::ReferenceEquals(
        $coordinatorNativePathTargetTypes[0], $coordinatorNativePathType) -or
      -not [object]::ReferenceEquals(
        $coordinatorNativePathTargetTypes[0],
        $loadedCoordinatorNativePathTypes[0]) -or
      [string]::Join('|', $coordinatorNativePathMethods) -cne
        'System.String DriveTarget(System.String)|System.String Identity(System.String)|System.String Resolve(System.String)') {
    throw 'The coordinator native path type compilation was not singular.'
  }
  Set-Issue13V5ScriptConstant Issue13V5CoordinatorNativePathType `
    $coordinatorNativePathTargetTypes[0]
}

$boundedStreamCaptureAssembliesBefore =
  [Reflection.Assembly[]]@([AppDomain]::CurrentDomain.GetAssemblies())
$preexistingBoundedStreamCaptureTypes = [type[]]@(
  [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
    $_.GetType('Issue13V5.BoundedStreamCapture', $false, $true)
  } | Where-Object { $null -ne $_ })
if ($preexistingBoundedStreamCaptureTypes.Count -ne 0) {
  throw 'The bounded stream capture type was preloaded.'
}
$boundedStreamCaptureTypes = [object[]]@(
  Add-Type -PassThru -ErrorAction Stop -TypeDefinition @'
using System;
using System.IO;
using System.Threading.Tasks;

namespace Issue13V5 {
  public static class BoundedStreamCapture {
    public static async Task<long> CopyAsync(
      Stream source, Stream destination, long maximumBytes) {
      if (source == null) throw new ArgumentNullException(nameof(source));
      if (destination == null) {
        throw new ArgumentNullException(nameof(destination));
      }
      if (maximumBytes <= 0) {
        throw new ArgumentOutOfRangeException(nameof(maximumBytes));
      }
      byte[] buffer = new byte[81920];
      long total = 0;
      while (true) {
        int read = await source.ReadAsync(
          buffer, 0, buffer.Length).ConfigureAwait(false);
        if (read == 0) break;
        if (total > maximumBytes - read) {
          throw new InvalidDataException(
            "Bounded process output exceeded its byte limit.");
        }
        await destination.WriteAsync(
          buffer, 0, read).ConfigureAwait(false);
        total += read;
      }
      await destination.FlushAsync().ConfigureAwait(false);
      return total;
    }
  }
}
'@)
$boundedStreamCaptureType = 'Issue13V5.BoundedStreamCapture' -as [type]
$boundedStreamCaptureNonTypes = [object[]]@(
  $boundedStreamCaptureTypes | Where-Object { $_ -isnot [type] })
$boundedStreamCaptureReturnedAssemblies = [Reflection.Assembly[]]@(
  $boundedStreamCaptureTypes | ForEach-Object { $_.Assembly } |
    Select-Object -Unique)
$boundedStreamCaptureAssemblyWasPreexisting = [object[]]@(
  $boundedStreamCaptureAssembliesBefore | Where-Object {
    [object]::ReferenceEquals(
      $_, $boundedStreamCaptureReturnedAssemblies[0])
  })
$loadedBoundedStreamCaptureTypes = [type[]]@(
  [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
    $_.GetType('Issue13V5.BoundedStreamCapture', $false, $true)
  } | Where-Object { $null -ne $_ })
$boundedStreamCaptureMethods = [string[]]@(
  $boundedStreamCaptureTypes[0].GetMethods(
    [Reflection.BindingFlags]'Public, Static, DeclaredOnly') |
    ForEach-Object { $_.ToString() } | Sort-Object)
if ($boundedStreamCaptureTypes.Count -ne 1 -or
    $boundedStreamCaptureTypes[0] -isnot [type] -or
    $boundedStreamCaptureNonTypes.Count -ne 0 -or
    $boundedStreamCaptureReturnedAssemblies.Count -ne 1 -or
    $boundedStreamCaptureAssemblyWasPreexisting.Count -ne 0 -or
    [string]$boundedStreamCaptureTypes[0].FullName -cne
      'Issue13V5.BoundedStreamCapture' -or
    $loadedBoundedStreamCaptureTypes.Count -ne 1 -or
    $null -eq $boundedStreamCaptureType -or
    -not [object]::ReferenceEquals(
      $boundedStreamCaptureTypes[0], $boundedStreamCaptureType) -or
    -not [object]::ReferenceEquals(
      $boundedStreamCaptureTypes[0], $loadedBoundedStreamCaptureTypes[0]) -or
    [string]::Join('|', $boundedStreamCaptureMethods) -cne
      'System.Threading.Tasks.Task`1[System.Int64] CopyAsync(System.IO.Stream, System.IO.Stream, Int64)') {
  throw 'The bounded stream capture type compilation was not singular.'
}
Set-Issue13V5ScriptConstant Issue13V5BoundedStreamCaptureType `
  $boundedStreamCaptureTypes[0]

function Test-Issue13V5ForbiddenDriveTarget([string]$Target) {
  $Target.StartsWith('\??\', [StringComparison]::OrdinalIgnoreCase) -or
    $Target.StartsWith('\Device\Mup',
      [StringComparison]::OrdinalIgnoreCase) -or
    $Target.StartsWith('\Device\LanmanRedirector',
      [StringComparison]::OrdinalIgnoreCase) -or
    $Target.StartsWith('\Device\WebDavRedirector',
      [StringComparison]::OrdinalIgnoreCase)
}

function Assert-Issue13V5LocalDriveAliasFree(
  [string]$Path,
  [string]$Label
) {
  $full = ConvertTo-Issue13V5Path $Path
  if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    return $full
  }
  $root = [IO.Path]::GetPathRoot($full)
  if ([string]::IsNullOrWhiteSpace($root) -or
      $root -cnotmatch '^[A-Za-z]:\\$') {
    throw "$Label must use a local drive-letter path: $full"
  }
  $drive = [IO.DriveInfo]::new($root)
  if (-not $drive.IsReady -or $drive.DriveType -ne [IO.DriveType]::Fixed) {
    throw "$Label must use a ready fixed local drive: $full"
  }
  $target = $script:Issue13V5CoordinatorNativePathType::DriveTarget(
    $root.Substring(0, 2))
  if (Test-Issue13V5ForbiddenDriveTarget $target) {
    throw "$Label must not use a SUBST or mapped-drive alias: $full"
  }
  $full
}

function ConvertTo-Issue13V5PhysicalPath(
  [string]$Path,
  [string]$Label
) {
  $full = Assert-Issue13V5LocalDriveAliasFree $Path $Label
  if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    return $full.TrimEnd([IO.Path]::DirectorySeparatorChar)
  }
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
  $canonical = $script:Issue13V5CoordinatorNativePathType::Resolve($cursor).
    TrimEnd('\')
  for ($index = $missing.Count - 1; $index -ge 0; $index--) {
    $canonical = $canonical + '\' + $missing[$index]
  }
  $canonical.TrimEnd('\')
}

function Test-Issue13V5PathContained([string]$Child, [string]$Parent) {
  $childFull = ConvertTo-Issue13V5PhysicalPath $Child 'child'
  $parentFull = ConvertTo-Issue13V5PhysicalPath $Parent 'parent'
  $comparison = if (
    [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
  ) { [StringComparison]::OrdinalIgnoreCase } else {
    [StringComparison]::Ordinal
  }
  if ([string]::Equals($childFull, $parentFull,
      $comparison)) { return $true }
  $separator = [IO.Path]::DirectorySeparatorChar
  $childFull.StartsWith($parentFull + $separator, $comparison)
}

function Assert-Issue13V5PathsDisjoint(
  [string]$Left,
  [string]$Right,
  [string]$Label
) {
  if ((Test-Issue13V5PathContained $Left $Right) -or
      (Test-Issue13V5PathContained $Right $Left)) {
    throw "$Label paths overlap: $Left ; $Right"
  }
}

function Assert-Issue13V5ConfigPathIsolation(
  [string]$ConfigPath,
  [string[]]$ImmutableRoots
) {
  if ([string]::IsNullOrWhiteSpace($ConfigPath) -or
      $ImmutableRoots.Count -eq 0) {
    throw 'V5 config-path isolation inputs are incomplete.'
  }
  foreach ($immutableRoot in $ImmutableRoots) {
    if ([string]::IsNullOrWhiteSpace($immutableRoot)) {
      throw 'V5 config-path isolation contains an empty immutable root.'
    }
    Assert-Issue13V5PathsDisjoint $ConfigPath $immutableRoot `
      'V5 config/immutable-root isolation'
  }
  $true
}

function Assert-Issue13V5NoReparseAncestors(
  [string]$Path,
  [string]$Label
) {
  $full = ConvertTo-Issue13V5Path $Path
  $current = if (Test-Path -LiteralPath $full) {
    $full
  } else {
    Split-Path -Parent $full
  }
  while (-not [string]::IsNullOrWhiteSpace($current)) {
    if (Test-Path -LiteralPath $current) {
      $item = Get-Item -LiteralPath $current -Force
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "$Label has a reparse-point ancestor: $($item.FullName)"
      }
    }
    $parent = Split-Path -Parent $current
    if ([string]::IsNullOrWhiteSpace($parent) -or
        [string]::Equals($parent, $current,
          [StringComparison]::OrdinalIgnoreCase)) { break }
    $current = $parent
  }
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
      $Config.oracle_effect.oracle_smoke.path,
      $Config.oracle_effect.proof.path,
      $Config.oracle_effect.comparisons.primary.root,
      $Config.oracle_effect.comparisons.replay.root,
      $Config.oracle_effect.comparison_harness.manifest_path,
      $Config.comparison.preparation_equivalence_profile.path,
      $Config.report.required_path
    )) {
    $paths.Add([string]$value)
  }
  foreach ($tool in @($Config.oracle_effect.tooling)) {
    $paths.Add([string]$tool.path)
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

function Get-Issue13V5PhysicalItemIdentity(
  [string]$Path,
  [string]$Label
) {
  if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw "$Label physical identity requires Windows."
  }
  $full = (Resolve-Path -LiteralPath $Path).Path
  $physical = ConvertTo-Issue13V5PhysicalPath $full $Label
  $identity = $script:Issue13V5CoordinatorNativePathType::Identity($full)
  $parts = [string[]]$identity.Split(':')
  if ($parts.Count -ne 3 -or $parts[0] -cnotmatch '^[0-9a-f]{16}$' -or
      $parts[1] -cnotmatch '^[0-9a-f]{32}$' -or
      $parts[2] -cnotmatch '^[0-9]+$') {
    throw "$Label returned an invalid physical identity."
  }
  [pscustomobject][ordered]@{
    physical_path = $physical
    identity = $identity
    item_id = $parts[0] + ':' + $parts[1]
    volume_serial = $parts[0]
    file_id = $parts[1]
    link_count = [uint64]$parts[2]
  }
}

function Enter-Issue13V5GitExecutableLease {
  $logical = [IO.Path]::GetFullPath(
    [string]$script:Issue13V5GitLogicalPath)
  if (-not [string]::Equals(
      $logical, [string]$script:Issue13V5GitLogicalPath,
      [StringComparison]::OrdinalIgnoreCase) -or
      -not [IO.File]::Exists($logical)) {
    throw 'The sealed V5 Git executable is unavailable at its fixed path.'
  }
  Assert-Issue13V5NoReparseAncestors $logical 'sealed V5 Git executable'
  $before = Get-Issue13V5PhysicalItemIdentity `
    $logical 'sealed V5 Git executable'
  $stream = $null
  $hasher = $null
  try {
    $stream = [IO.File]::Open(
      $logical, [IO.FileMode]::Open, [IO.FileAccess]::Read,
      [IO.FileShare]::Read)
    $size = [int64]$stream.Length
    $hasher = [Security.Cryptography.SHA256]::Create()
    $sha256 = [Convert]::ToHexString(
      $hasher.ComputeHash($stream)).ToLowerInvariant()
  } catch {
    if ($null -ne $hasher) { $hasher.Dispose() }
    if ($null -ne $stream) { $stream.Dispose() }
    throw
  }
  $hasher.Dispose()
  try {
    $after = Get-Issue13V5PhysicalItemIdentity `
      $logical 'sealed V5 Git executable'
    if (-not [string]::Equals(
          [string]$before.physical_path, [string]$after.physical_path,
          [StringComparison]::OrdinalIgnoreCase) -or
        [string]$before.item_id -cne [string]$after.item_id -or
        [uint64]$before.link_count -ne [uint64]$after.link_count) {
      throw 'The sealed V5 Git executable changed while it was authenticated.'
    }
    $binding = [pscustomobject][ordered]@{
      logical_path = $logical
      physical_path = [string]$after.physical_path
      item_id = [string]$after.item_id
      link_count = [long]$after.link_count
      size_bytes = $size
      sha256 = $sha256
    }
    if (-not [string]::Equals(
          [string]$binding.logical_path,
          [string]$script:Issue13V5GitLogicalPath,
          [StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals(
          [string]$binding.physical_path,
          [string]$script:Issue13V5GitPhysicalPath,
          [StringComparison]::OrdinalIgnoreCase) -or
        [string]$binding.item_id -cne [string]$script:Issue13V5GitItemId -or
        [long]$binding.link_count -ne [long]$script:Issue13V5GitLinkCount -or
        [long]$binding.size_bytes -ne [long]$script:Issue13V5GitSizeBytes -or
        [string]$binding.sha256 -cne [string]$script:Issue13V5GitSha256) {
      throw 'The V5 Git executable does not match its sealed authority.'
    }
    [pscustomobject][ordered]@{
      binding = $binding
      handle = $stream
    }
  } catch {
    $stream.Dispose()
    throw
  }
}

function Get-Issue13V5GitExecutableBinding {
  $lease = Enter-Issue13V5GitExecutableLease
  try {
    $binding = $lease.binding
  } finally {
    $lease.handle.Dispose()
  }
  $binding
}

function Assert-Issue13V5GitExecutableBinding(
  [AllowNull()][object]$Expected = $null
) {
  $actual = Get-Issue13V5GitExecutableBinding
  if ($null -ne $Expected) {
    $expectedNames = [string[]]@(
      'logical_path', 'physical_path', 'item_id', 'link_count',
      'size_bytes', 'sha256')
    $actualNames = [string[]]@($Expected.PSObject.Properties.Name)
    if ([string]::Join("`n", $actualNames) -cne
          [string]::Join("`n", $expectedNames) -or
        -not [string]::Equals(
          [string]$Expected.logical_path, [string]$actual.logical_path,
          [StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals(
          [string]$Expected.physical_path, [string]$actual.physical_path,
          [StringComparison]::OrdinalIgnoreCase) -or
        [string]$Expected.item_id -cne [string]$actual.item_id -or
        [long]$Expected.link_count -ne [long]$actual.link_count -or
        [long]$Expected.size_bytes -ne [long]$actual.size_bytes -or
        [string]$Expected.sha256 -cne [string]$actual.sha256) {
      throw 'The sealed V5 Git binding changed across a critical operation.'
    }
  }
  $actual
}

function Exit-Issue13V5GitExecutableLease([object]$Lease) {
  $failures = [Collections.Generic.List[Exception]]::new()
  try {
    $null = Assert-Issue13V5GitExecutableBinding $Lease.binding
  } catch {
    $failures.Add($_.Exception)
  }
  try {
    $Lease.handle.Dispose()
  } catch {
    $failures.Add($_.Exception)
  }
  if ($failures.Count -eq 1) { throw $failures[0] }
  if ($failures.Count -gt 1) {
    throw [AggregateException]::new(
      'The sealed V5 Git lease could not be closed safely.',
      $failures.ToArray())
  }
}

function Enter-Issue13V5PwshExecutableLease {
  $logical = [IO.Path]::GetFullPath(
    [string]$script:Issue13V5PwshLogicalPath)
  if (-not [string]::Equals(
      $logical, [string]$script:Issue13V5PwshLogicalPath,
      [StringComparison]::OrdinalIgnoreCase) -or
      -not [IO.File]::Exists($logical)) {
    throw 'The sealed V5 pwsh executable is unavailable at its fixed path.'
  }
  Assert-Issue13V5NoReparseAncestors $logical 'sealed V5 pwsh executable'
  $before = Get-Issue13V5PhysicalItemIdentity `
    $logical 'sealed V5 pwsh executable'
  $stream = $null
  $hasher = $null
  try {
    $stream = [IO.File]::Open(
      $logical, [IO.FileMode]::Open, [IO.FileAccess]::Read,
      [IO.FileShare]::Read)
    $size = [int64]$stream.Length
    $hasher = [Security.Cryptography.SHA256]::Create()
    $sha256 = [Convert]::ToHexString(
      $hasher.ComputeHash($stream)).ToLowerInvariant()
  } catch {
    if ($null -ne $hasher) { $hasher.Dispose() }
    if ($null -ne $stream) { $stream.Dispose() }
    throw
  }
  $hasher.Dispose()
  try {
    $after = Get-Issue13V5PhysicalItemIdentity `
      $logical 'sealed V5 pwsh executable'
    if (-not [string]::Equals(
          [string]$before.physical_path, [string]$after.physical_path,
          [StringComparison]::OrdinalIgnoreCase) -or
        [string]$before.item_id -cne [string]$after.item_id -or
        [uint64]$before.link_count -ne [uint64]$after.link_count) {
      throw 'The sealed V5 pwsh executable changed while it was authenticated.'
    }
    $binding = [pscustomobject][ordered]@{
      logical_path = $logical
      physical_path = [string]$after.physical_path
      item_id = [string]$after.item_id
      link_count = [long]$after.link_count
      size_bytes = $size
      sha256 = $sha256
    }
    if (-not [string]::Equals(
          [string]$binding.logical_path,
          [string]$script:Issue13V5PwshLogicalPath,
          [StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals(
          [string]$binding.physical_path,
          [string]$script:Issue13V5PwshPhysicalPath,
          [StringComparison]::OrdinalIgnoreCase) -or
        [string]$binding.item_id -cne [string]$script:Issue13V5PwshItemId -or
        [long]$binding.link_count -ne [long]$script:Issue13V5PwshLinkCount -or
        [long]$binding.size_bytes -ne [long]$script:Issue13V5PwshSizeBytes -or
        [string]$binding.sha256 -cne [string]$script:Issue13V5PwshSha256) {
      throw 'The V5 pwsh executable does not match its sealed authority.'
    }
    [pscustomobject][ordered]@{
      binding = $binding
      handle = $stream
    }
  } catch {
    $stream.Dispose()
    throw
  }
}

function Get-Issue13V5PwshExecutableBinding {
  $lease = Enter-Issue13V5PwshExecutableLease
  try {
    $binding = $lease.binding
  } finally {
    $lease.handle.Dispose()
  }
  $binding
}

function Assert-Issue13V5PwshExecutableBinding(
  [AllowNull()][object]$Expected = $null
) {
  $actual = Get-Issue13V5PwshExecutableBinding
  if ($null -ne $Expected) {
    $expectedNames = [string[]]@(
      'logical_path', 'physical_path', 'item_id', 'link_count',
      'size_bytes', 'sha256')
    $actualNames = [string[]]@($Expected.PSObject.Properties.Name)
    if ([string]::Join("`n", $actualNames) -cne
          [string]::Join("`n", $expectedNames) -or
        -not [string]::Equals(
          [string]$Expected.logical_path, [string]$actual.logical_path,
          [StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals(
          [string]$Expected.physical_path, [string]$actual.physical_path,
          [StringComparison]::OrdinalIgnoreCase) -or
        [string]$Expected.item_id -cne [string]$actual.item_id -or
        [long]$Expected.link_count -ne [long]$actual.link_count -or
        [long]$Expected.size_bytes -ne [long]$actual.size_bytes -or
        [string]$Expected.sha256 -cne [string]$actual.sha256) {
      throw 'The sealed V5 pwsh binding changed across a critical operation.'
    }
  }
  $actual
}

function Exit-Issue13V5PwshExecutableLease([object]$Lease) {
  $failures = [Collections.Generic.List[Exception]]::new()
  try {
    $null = Assert-Issue13V5PwshExecutableBinding $Lease.binding
  } catch {
    $failures.Add($_.Exception)
  }
  try {
    $Lease.handle.Dispose()
  } catch {
    $failures.Add($_.Exception)
  }
  if ($failures.Count -eq 1) { throw $failures[0] }
  if ($failures.Count -gt 1) {
    throw [AggregateException]::new(
      'The sealed V5 pwsh lease could not be closed safely.',
      $failures.ToArray())
  }
}

function Assert-Issue13V5CurrentPwshHost {
  $processPath = [IO.Path]::GetFullPath([Environment]::ProcessPath)
  $process = [Diagnostics.Process]::GetCurrentProcess()
  try {
    $mainModulePath = [IO.Path]::GetFullPath(
      [string]$process.MainModule.FileName)
  } finally {
    $process.Dispose()
  }
  $binding = Get-Issue13V5PwshExecutableBinding
  if (-not [string]::Equals(
        $processPath, [string]$binding.logical_path,
        [StringComparison]::OrdinalIgnoreCase) -or
      -not [string]::Equals(
        $mainModulePath, [string]$binding.logical_path,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The current PowerShell host is not the sealed V5 pwsh authority.'
  }
  $binding
}

$null = Assert-Issue13V5CurrentPwshHost

function Enter-Issue13V5RscriptExecutableLease([string]$Path) {
  $logical = [IO.Path]::GetFullPath($Path)
  if (-not [string]::Equals(
      $logical, [string]$script:Issue13V5RscriptLogicalPath,
      [StringComparison]::OrdinalIgnoreCase) -or
      -not [IO.File]::Exists($logical)) {
    throw 'The sealed V5 Rscript executable is unavailable at its fixed path.'
  }
  Assert-Issue13V5NoReparseAncestors $logical 'sealed V5 Rscript executable'
  $before = Get-Issue13V5PhysicalItemIdentity `
    $logical 'sealed V5 Rscript executable'
  $stream = $null
  $hasher = $null
  try {
    $stream = [IO.File]::Open(
      $logical, [IO.FileMode]::Open, [IO.FileAccess]::Read,
      [IO.FileShare]::Read)
    $size = [int64]$stream.Length
    $hasher = [Security.Cryptography.SHA256]::Create()
    $sha256 = [Convert]::ToHexString(
      $hasher.ComputeHash($stream)).ToLowerInvariant()
  } catch {
    if ($null -ne $hasher) { $hasher.Dispose() }
    if ($null -ne $stream) { $stream.Dispose() }
    throw
  }
  $hasher.Dispose()
  try {
    $after = Get-Issue13V5PhysicalItemIdentity `
      $logical 'sealed V5 Rscript executable'
    if (-not [string]::Equals(
          [string]$before.physical_path, [string]$after.physical_path,
          [StringComparison]::OrdinalIgnoreCase) -or
        [string]$before.item_id -cne [string]$after.item_id -or
        [uint64]$before.link_count -ne [uint64]$after.link_count) {
      throw 'The sealed V5 Rscript executable changed while it was authenticated.'
    }
    $binding = [pscustomobject][ordered]@{
      logical_path = $logical
      physical_path = [string]$after.physical_path
      item_id = [string]$after.item_id
      link_count = [long]$after.link_count
      size_bytes = $size
      sha256 = $sha256
    }
    if (-not [string]::Equals(
          [string]$binding.logical_path,
          [string]$script:Issue13V5RscriptLogicalPath,
          [StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals(
          [string]$binding.physical_path,
          [string]$script:Issue13V5RscriptPhysicalPath,
          [StringComparison]::OrdinalIgnoreCase) -or
        [string]$binding.item_id -cne [string]$script:Issue13V5RscriptItemId -or
        [long]$binding.link_count -ne [long]$script:Issue13V5RscriptLinkCount -or
        [long]$binding.size_bytes -ne [long]$script:Issue13V5RscriptSizeBytes -or
        [string]$binding.sha256 -cne [string]$script:Issue13V5RscriptSha256) {
      throw 'The V5 Rscript executable does not match its sealed authority.'
    }
    [pscustomobject][ordered]@{
      binding = $binding
      handle = $stream
    }
  } catch {
    $stream.Dispose()
    throw
  }
}

function Get-Issue13V5RscriptExecutableBinding([string]$Path) {
  $lease = Enter-Issue13V5RscriptExecutableLease $Path
  try {
    $binding = $lease.binding
  } finally {
    $lease.handle.Dispose()
  }
  $binding
}

function Assert-Issue13V5RscriptExecutableBinding(
  [string]$Path,
  [AllowNull()][object]$Expected = $null
) {
  $actual = Get-Issue13V5RscriptExecutableBinding $Path
  if ($null -ne $Expected) {
    $expectedNames = [string[]]@(
      'logical_path', 'physical_path', 'item_id', 'link_count',
      'size_bytes', 'sha256')
    $actualNames = [string[]]@($Expected.PSObject.Properties.Name)
    if ([string]::Join("`n", $actualNames) -cne
          [string]::Join("`n", $expectedNames) -or
        -not [string]::Equals(
          [string]$Expected.logical_path, [string]$actual.logical_path,
          [StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals(
          [string]$Expected.physical_path, [string]$actual.physical_path,
          [StringComparison]::OrdinalIgnoreCase) -or
        [string]$Expected.item_id -cne [string]$actual.item_id -or
        [long]$Expected.link_count -ne [long]$actual.link_count -or
        [long]$Expected.size_bytes -ne [long]$actual.size_bytes -or
        [string]$Expected.sha256 -cne [string]$actual.sha256) {
      throw 'The sealed V5 Rscript binding changed across a critical operation.'
    }
  }
  $actual
}

function Exit-Issue13V5RscriptExecutableLease([object]$Lease) {
  $failures = [Collections.Generic.List[Exception]]::new()
  try {
    $null = Assert-Issue13V5RscriptExecutableBinding `
      ([string]$Lease.binding.logical_path) $Lease.binding
  } catch {
    $failures.Add($_.Exception)
  }
  try {
    $Lease.handle.Dispose()
  } catch {
    $failures.Add($_.Exception)
  }
  if ($failures.Count -eq 1) { throw $failures[0] }
  if ($failures.Count -gt 1) {
    throw [AggregateException]::new(
      'The sealed V5 Rscript lease could not be closed safely.',
      $failures.ToArray())
  }
}

function Invoke-Issue13V5SealedGit {
  $gitArguments = [string[]]@($args)
  $timeoutSeconds = 120
  $lease = Enter-Issue13V5GitExecutableLease
  $binding = $lease.binding
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = [string]$binding.logical_path
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
  $start.StandardOutputEncoding = $strictUtf8
  $start.StandardErrorEncoding = $strictUtf8
  foreach ($argument in $gitArguments) {
    $start.ArgumentList.Add($argument)
  }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $start
  $processStarted = $false
  $stdoutTask = $null
  $stderrTask = $null
  $primary = $null
  $stdoutText = $null
  $stderrText = $null
  $exitCode = $null
  try {
    if (-not $process.Start()) {
      throw 'The sealed V5 Git invocation could not be started.'
    }
    $processStarted = $true
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timeoutMilliseconds = [int]([int64]$timeoutSeconds * 1000L)
    if (-not $process.WaitForExit($timeoutMilliseconds)) {
      throw "The sealed V5 Git invocation exceeded its $timeoutSeconds-second timeout."
    }
    $outputTasks = [Threading.Tasks.Task[]]@($stdoutTask, $stderrTask)
    if (-not [Threading.Tasks.Task]::WaitAll($outputTasks, 30000)) {
      throw 'The sealed V5 Git output streams did not close within 30 seconds.'
    }
    $stdoutText = $stdoutTask.GetAwaiter().GetResult()
    $stderrText = $stderrTask.GetAwaiter().GetResult()
    $exitCode = [int]$process.ExitCode
  } catch {
    $primary = $_
  }
  $cleanupFailures = [Collections.Generic.List[Exception]]::new()
  if ($processStarted) {
    try {
      Stop-Issue13V5ExternalProcess $process
    } catch {
      $cleanupFailures.Add($_.Exception)
    }
  }
  foreach ($task in @($stdoutTask, $stderrTask)) {
    if ($null -eq $task) { continue }
    try {
      if (-not $task.IsCompleted -and
          -not $task.Wait(30000)) {
        throw 'A sealed V5 Git output task did not close during cleanup.'
      }
    } catch {
      $cleanupFailures.Add($_.Exception)
    }
    if ($task.IsCompleted) {
      try { $task.Dispose() } catch { $cleanupFailures.Add($_.Exception) }
    }
  }
  try {
    $process.Dispose()
  } catch {
    $cleanupFailures.Add($_.Exception)
  }
  try {
    $null = Assert-Issue13V5GitExecutableBinding $binding
  } catch {
    $cleanupFailures.Add($_.Exception)
  }
  try {
    $lease.handle.Dispose()
  } catch {
    $cleanupFailures.Add($_.Exception)
  }
  if ($cleanupFailures.Count -ne 0) {
    $failures = [Collections.Generic.List[Exception]]::new()
    if ($null -ne $primary) { $failures.Add($primary.Exception) }
    foreach ($failure in $cleanupFailures) { $failures.Add($failure) }
    throw [AggregateException]::new(
      'The sealed V5 Git invocation failed its lifecycle recheck.',
      $failures.ToArray())
  }
  if ($null -ne $primary) { throw $primary }
  $global:LASTEXITCODE = [int]$exitCode
  if (-not [string]::IsNullOrEmpty($stdoutText)) {
    $lines = [regex]::Split($stdoutText, "\r?\n")
    $lineCount = $lines.Count
    if ($lineCount -gt 0 -and $lines[$lineCount - 1] -ceq '') {
      $lineCount--
    }
    for ($index = 0; $index -lt $lineCount; $index++) {
      $lines[$index]
    }
  }
}

function Get-Issue13V5PhysicalSnapshotProof(
  [string]$Source,
  [string]$Snapshot,
  [string]$Label
) {
  if (-not (Test-Path -LiteralPath $Source -PathType Container) -or
      -not (Test-Path -LiteralPath $Snapshot -PathType Container)) {
    throw "$Label source and snapshot must be existing directories."
  }
  $sourceRoot = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
  $snapshotRoot = (Resolve-Path -LiteralPath $Snapshot).Path.TrimEnd('\')
  $sourcePhysical = ConvertTo-Issue13V5PhysicalPath `
    $sourceRoot "$Label source"
  $snapshotPhysical = ConvertTo-Issue13V5PhysicalPath `
    $snapshotRoot "$Label snapshot"
  Assert-Issue13V5NoReparse $sourceRoot
  Assert-Issue13V5NoReparse $snapshotRoot
  Assert-Issue13V5PathsDisjoint $sourceRoot $snapshotRoot $Label
  $volumePattern = '^(\\\\\?\\Volume\{[^}]+\}\\)'
  $sourceVolume = [regex]::Match($sourcePhysical, $volumePattern)
  $snapshotVolume = [regex]::Match($snapshotPhysical, $volumePattern)
  if (-not $sourceVolume.Success -or -not $snapshotVolume.Success -or
      $sourceVolume.Groups[1].Value -cne
        $snapshotVolume.Groups[1].Value) {
    throw "$Label source and snapshot must share one fixed physical volume."
  }
  $physicalVolume = $sourceVolume.Groups[1].Value.Replace('\', '/').
    ToLowerInvariant()

  $sourceItems = @((Get-Item -LiteralPath $sourceRoot -Force)) +
    @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Force)
  $snapshotItems = @((Get-Item -LiteralPath $snapshotRoot -Force)) +
    @(Get-ChildItem -LiteralPath $snapshotRoot -Recurse -Force)
  $sourceMap = @{}
  foreach ($item in $sourceItems) {
    $relative = if ($item.FullName -ceq $sourceRoot) {
      '.'
    } else {
      $item.FullName.Substring($sourceRoot.Length).TrimStart('\').
        Replace('\', '/')
    }
    if ($sourceMap.ContainsKey($relative)) {
      throw "$Label source has a duplicate physical path: $relative"
    }
    $sourceMap[$relative] = $item
  }
  $snapshotMap = @{}
  foreach ($item in $snapshotItems) {
    $relative = if ($item.FullName -ceq $snapshotRoot) {
      '.'
    } else {
      $item.FullName.Substring($snapshotRoot.Length).TrimStart('\').
        Replace('\', '/')
    }
    if ($snapshotMap.ContainsKey($relative)) {
      throw "$Label snapshot has a duplicate physical path: $relative"
    }
    $snapshotMap[$relative] = $item
  }
  $sourceNames = [string[]]@($sourceMap.Keys)
  $snapshotNames = [string[]]@($snapshotMap.Keys)
  [Array]::Sort($sourceNames, [StringComparer]::Ordinal)
  [Array]::Sort($snapshotNames, [StringComparer]::Ordinal)
  if ([string]::Join("`n", $sourceNames) -cne
      [string]::Join("`n", $snapshotNames)) {
    throw "$Label source and snapshot paths differ."
  }

  $sourceRecords = [Collections.Generic.List[string]]::new()
  $snapshotRecords = [Collections.Generic.List[string]]::new()
  $independenceRecords = [Collections.Generic.List[string]]::new()
  $fileCount = 0L
  $directoryCount = 0L
  foreach ($relative in $sourceNames) {
    $sourceItem = $sourceMap[$relative]
    $snapshotItem = $snapshotMap[$relative]
    $sourceIsDirectory = Test-Issue13V5ExactBoolean `
      $sourceItem.PSIsContainer $true
    $snapshotIsDirectory = Test-Issue13V5ExactBoolean `
      $snapshotItem.PSIsContainer $true
    if ($sourceIsDirectory -ne $snapshotIsDirectory) {
      throw "$Label item type differs: $relative"
    }
    $sourceIdentity = Get-Issue13V5PhysicalItemIdentity `
      $sourceItem.FullName "$Label source item"
    $snapshotIdentity = Get-Issue13V5PhysicalItemIdentity `
      $snapshotItem.FullName "$Label snapshot item"
    if ($sourceIdentity.item_id -ceq $snapshotIdentity.item_id) {
      throw "$Label snapshot reuses the source physical item: $relative"
    }
    $kind = if ($sourceIsDirectory) { 'directory' } else { 'file' }
    if ($relative -cne '.') {
      if ($sourceIsDirectory) {
        $directoryCount++
      } else {
        $fileCount++
        if ($snapshotIdentity.link_count -ne 1L) {
          throw "$Label snapshot file has external hard links: $relative"
        }
      }
    }
    $recordPrefix = if ($sourceIsDirectory) { 'D|' } else { 'F|' }
    $sourceRecord = $recordPrefix + $relative + '|' + $physicalVolume +
      '|' + $sourceIdentity.file_id
    $snapshotRecord = $recordPrefix + $relative + '|' + $physicalVolume +
      '|' + $snapshotIdentity.file_id
    if (-not $sourceIsDirectory) {
      $sourceRecord += '|' + [string]$sourceIdentity.link_count
      $snapshotRecord += '|' + [string]$snapshotIdentity.link_count
    }
    $sourceRecords.Add($sourceRecord)
    $snapshotRecords.Add($snapshotRecord)
    $independenceRecords.Add(
      $relative + '|' + $kind + '|' + $physicalVolume + ':' +
        $sourceIdentity.file_id + '|' + $physicalVolume + ':' +
        $snapshotIdentity.file_id
    )
  }
  [pscustomobject][ordered]@{
    source_physical_path = $sourcePhysical
    snapshot_physical_path = $snapshotPhysical
    file_count = [long]$fileCount
    directory_count = [long]$directoryCount
    source_physical_inventory_sha256 = Get-Issue13V5TextSha256 `
      ([string]::Join("`n", $sourceRecords.ToArray()))
    snapshot_physical_inventory_sha256 = Get-Issue13V5TextSha256 `
      ([string]::Join("`n", $snapshotRecords.ToArray()))
    independence_sha256 = Get-Issue13V5TextSha256 `
      ([string]::Join("`n", $independenceRecords.ToArray()))
  }
}

function Copy-Issue13V5PhysicalDirectorySnapshot(
  [string]$Source,
  [string]$Destination,
  [string]$Label
) {
  if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "$Label source does not exist: $Source"
  }
  if (Test-Path -LiteralPath $Destination) {
    throw "$Label destination already exists: $Destination"
  }
  $sourceRoot = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
  $destinationRoot = ConvertTo-Issue13V5Path $Destination
  $destinationParent = Split-Path -Parent $destinationRoot
  if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
    throw "$Label destination parent does not exist: $destinationParent"
  }
  $null = ConvertTo-Issue13V5PhysicalPath $sourceRoot "$Label source"
  $null = ConvertTo-Issue13V5PhysicalPath `
    $destinationRoot "$Label destination"
  Assert-Issue13V5NoReparse $sourceRoot
  Assert-Issue13V5NoReparseAncestors `
    $destinationRoot "$Label destination"
  Assert-Issue13V5PathsDisjoint $sourceRoot $destinationRoot $Label
  $sourceItems = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Force)
  $null = [IO.Directory]::CreateDirectory($destinationRoot)
  foreach ($directory in @($sourceItems | Where-Object {
      $_.PSIsContainer
    } | Sort-Object @{ Expression = { $_.FullName.Length } }, FullName)) {
    $relative = $directory.FullName.Substring($sourceRoot.Length).
      TrimStart('\')
    $null = [IO.Directory]::CreateDirectory(
      (Join-Path $destinationRoot $relative))
  }
  foreach ($file in @($sourceItems | Where-Object {
      -not $_.PSIsContainer
    } | Sort-Object FullName)) {
    $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')
    [IO.File]::Copy(
      $file.FullName, (Join-Path $destinationRoot $relative), $false)
  }
  Get-Issue13V5PhysicalSnapshotProof `
    $sourceRoot $destinationRoot $Label
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
  Assert-Issue13V5NoReparseAncestors $Root 'V5 tree'
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

function Assert-Issue13V5OfficialSourceDataInventory([string]$Root) {
  $inventory = Get-Issue13V5TreeInventory $Root
  $ordinalLines = [string[]]@($inventory.records | ForEach-Object {
    [string]$_.relative_path + '|' + [string]$_.size_bytes + '|' +
      [string]$_.sha256
  })
  [Array]::Sort($ordinalLines, [StringComparer]::Ordinal)
  $ordinalInventorySha256 = Get-Issue13V5TextSha256 (
    [string]::Join("`n", $ordinalLines))
  if ([long]$inventory.file_count -ne $script:Issue13V5SourceFileCount -or
      [long]$inventory.directory_count -ne
        $script:Issue13V5SourceDirectoryCount -or
      [int64]$inventory.total_bytes -ne $script:Issue13V5SourceTotalBytes -or
      [string]$inventory.inventory_sha256 -cne
        $script:Issue13V5SourceInventorySha256 -or
      $ordinalInventorySha256 -cne
        $script:Issue13V5SourceOrdinalInventorySha256 -or
      [string]$inventory.directory_list_sha256 -cne
        $script:Issue13V5SourceDirectorySha256) {
    throw "Official source_data inventory differs: $Root"
  }
  $inventory | Add-Member -NotePropertyName ordinal_inventory_sha256 `
    -NotePropertyValue $ordinalInventorySha256
  $inventory
}

function Get-Issue13V5OracleEffectToolRecords {
  @($script:Issue13V5OracleEffectFiles | ForEach-Object {
    $path = (Resolve-Path -LiteralPath (
      Join-Path $script:Issue13V5CoordinatorRoot $_)).Path
    [pscustomobject][ordered]@{
      name = [string]$_
      path = $path
      size_bytes = [int64](Get-Item -LiteralPath $path).Length
      sha256 = Get-Issue13V5Sha256 $path
    }
  })
}

function Get-Issue13V5OraclePackageInventory([string]$Root) {
  $resolved = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
  Assert-Issue13V5NoReparse $resolved
  $records = @(Get-ChildItem -LiteralPath $resolved -File -Recurse -Force |
    ForEach-Object {
      [pscustomobject][ordered]@{
        relative_path = $_.FullName.Substring($resolved.Length + 1).
          Replace('\', '/')
        size_bytes = [int64]$_.Length
        sha256 = Get-Issue13V5Sha256 $_.FullName
      }
    })
  [Array]::Sort($records, [Comparison[object]]{
    param($left, $right)
    [StringComparer]::Ordinal.Compare(
      [string]$left.relative_path, [string]$right.relative_path)
  })
  $payload = [string]::Join("`n", @($records | ForEach-Object {
    [string]$_.relative_path + '|' + [string]$_.size_bytes + '|' +
      [string]$_.sha256
  }))
  [pscustomobject][ordered]@{
    file_count = [int64]$records.Count
    total_bytes = [int64](($records | Measure-Object size_bytes -Sum).Sum)
    inventory_sha256 = Get-Issue13V5TextSha256 $payload
  }
}

function Get-Issue13V5GitBlobIdentity(
  [string]$RepositoryRoot,
  [string]$Commit,
  [string]$RelativePath
) {
  if ($RelativePath -notmatch '^[^\\/:]+(?:/[^\\/:]+)+$' -or
      $RelativePath -match '(^|/)\.\.?(?:/|$)') {
    throw "Unsafe terminal controller Git path: $RelativePath"
  }
  $objectSpec = "$Commit`:$RelativePath"
  $blob = (Invoke-Issue13V5SealedGit `
    -C $RepositoryRoot rev-parse $objectSpec 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or $blob -cnotmatch '^[0-9a-f]{40}$') {
    throw "Unavailable terminal controller Git blob: $RelativePath"
  }
  $sizeText = (Invoke-Issue13V5SealedGit `
    -C $RepositoryRoot cat-file -s $objectSpec 2>$null).Trim()
  $size = [int64]0
  if ($LASTEXITCODE -ne 0 -or -not [int64]::TryParse(
      $sizeText, [Globalization.NumberStyles]::None,
      [Globalization.CultureInfo]::InvariantCulture, [ref]$size)) {
    throw "Malformed terminal controller Git blob size: $RelativePath"
  }
  $raw = Invoke-Issue13V5GitRaw $RepositoryRoot @(
    'cat-file', 'blob', $objectSpec)
  if ([long]$raw.stdout.LongLength -ne $size) {
    throw "Git blob length changed for terminal controller: $RelativePath"
  }
  $sha256 = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
      [byte[]]$raw.stdout)).ToLowerInvariant()
  [pscustomobject][ordered]@{
    git_blob = $blob
    size_bytes = $size
    sha256 = $sha256
  }
}

function Get-Issue13V5ControllerIdentity(
  [string]$RepositoryRoot,
  [string]$CandidateCommit
) {
  $repository = ConvertTo-Issue13V5Path $RepositoryRoot
  $controllerRoot = ConvertTo-Issue13V5Path $script:Issue13V5CoordinatorRoot
  if (-not (Test-Issue13V5PathContained $controllerRoot $repository)) {
    throw 'V5 controller root is outside the configured repository.'
  }
  Assert-Issue13V5NoReparseAncestors $repository 'repository root'
  Assert-Issue13V5NoReparseAncestors $controllerRoot 'V5 controller root'
  $relativeRoot = $controllerRoot.Substring($repository.Length).
    TrimStart('\').Replace('\', '/')
  $records = @(
    foreach ($name in $script:Issue13V5ControllerFiles) {
      if ($name -cnotmatch '^[A-Za-z0-9._-]+$') {
        throw "Unsafe V5 controller filename: $name"
      }
      $path = (Resolve-Path -LiteralPath (Join-Path $controllerRoot $name)).Path
      Assert-Issue13V5NoReparseAncestors $path "V5 controller $name"
      $relative = $relativeRoot + '/' + $name
      $blob = Get-Issue13V5GitBlobIdentity $repository $CandidateCommit $relative
      if ([int64](Get-Item -LiteralPath $path).Length -ne
            [int64]$blob.size_bytes -or
          (Get-Issue13V5Sha256 $path) -cne [string]$blob.sha256) {
        throw "V5 controller bytes differ from candidate blob: $relative"
      }
      $localBlob = (Invoke-Issue13V5SealedGit `
        -C $repository hash-object -- $path 2>$null).Trim()
      if ($LASTEXITCODE -ne 0 -or $localBlob -cne [string]$blob.git_blob) {
        throw "V5 controller Git identity differs from candidate blob: $relative"
      }
      [pscustomobject][ordered]@{
        name = [string]$name
        relative_path = $relative
        size_bytes = [int64]$blob.size_bytes
        sha256 = [string]$blob.sha256
        git_blob = [string]$blob.git_blob
      }
    }
  )
  $payload = [string]::Join("`n", @($records | ForEach-Object {
    [string]$_.name + '|' + [string]$_.relative_path + '|' +
      [string]$_.size_bytes + '|' + [string]$_.sha256 + '|' +
      [string]$_.git_blob
  }))
  [pscustomobject][ordered]@{
    commit_sha256 = $CandidateCommit
    file_count = [int64]$records.Count
    inventory_sha256 = Get-Issue13V5TextSha256 $payload
    records = $records
  }
}

function Assert-Issue13V5ControllerIdentity(
  [object]$Observed,
  [object]$Expected,
  [string]$Label
) {
  $null = Assert-Issue13V5ExactPropertyNames $Observed @(
    'commit_sha256', 'file_count', 'inventory_sha256', 'records'
  ) $Label
  if ([string]$Observed.commit_sha256 -cne [string]$Expected.commit_sha256 -or
      [int64]$Observed.file_count -ne [int64]$Expected.file_count -or
      [string]$Observed.inventory_sha256 -cne
        [string]$Expected.inventory_sha256 -or
      @($Observed.records).Count -ne @($Expected.records).Count) {
    throw "$Label aggregate identity differs."
  }
  foreach ($expectedRecord in @($Expected.records)) {
    $matches = @($Observed.records | Where-Object {
      [string]$_.name -ceq [string]$expectedRecord.name
    })
    if ($matches.Count -ne 1) {
      throw "$Label record is missing or duplicated: $($expectedRecord.name)"
    }
    $null = Assert-Issue13V5ExactPropertyNames $matches[0] @(
      'name', 'relative_path', 'size_bytes', 'sha256', 'git_blob'
    ) "$Label record $($expectedRecord.name)"
    foreach ($field in @(
        'name', 'relative_path', 'size_bytes', 'sha256', 'git_blob')) {
      if ([string]$matches[0].$field -cne [string]$expectedRecord.$field) {
        throw "$Label record differs: $($expectedRecord.name)/$field"
      }
    }
  }
  $true
}

function Assert-Issue13V5OracleComparisonIsolation([object]$Config) {
  $primary = ConvertTo-Issue13V5Path `
    ([string]$Config.oracle_effect.comparisons.primary.root)
  $replay = ConvertTo-Issue13V5Path `
    ([string]$Config.oracle_effect.comparisons.replay.root)
  Assert-Issue13V5PathsDisjoint $primary $replay `
    'Oracle-effect primary/replay isolation'
  $protected = @(
    [pscustomobject]@{
      label = 'repository root'; path = [string]$Config.repository_root
    }
    [pscustomobject]@{
      label = 'harness runtime root'; path = [string]$Config.harness_runtime_root
    }
    [pscustomobject]@{
      label = 'R library root'; path = [string]$Config.r_library
    }
    [pscustomobject]@{
      label = 'strict smoke root'
      path = Split-Path -Parent ([string]$Config.strict_baseline_smoke.path)
    }
    [pscustomobject]@{
      label = 'oracle smoke root'
      path = Split-Path -Parent ([string]$Config.oracle_effect.oracle_smoke.path)
    }
  )
  foreach ($output in @(
      [pscustomobject]@{ label = 'primary comparison root'; path = $primary }
      [pscustomobject]@{ label = 'replay comparison root'; path = $replay }
    )) {
    Assert-Issue13V5NoReparse $output.path
    foreach ($protectedRoot in $protected) {
      Assert-Issue13V5NoReparseAncestors $protectedRoot.path $protectedRoot.label
      Assert-Issue13V5PathsDisjoint $output.path $protectedRoot.path `
        "$($output.label)/$($protectedRoot.label) isolation"
    }
  }
  $true
}

function Assert-Issue13V5InventoryBinding(
  [object]$Expected,
  [object]$Observed,
  [string]$Label
) {
  if (-not [string]::Equals(
      (ConvertTo-Issue13V5Path ([string]$Expected.root)),
      (ConvertTo-Issue13V5Path ([string]$Observed.root)),
      [StringComparison]::OrdinalIgnoreCase)) {
    throw "$Label root changed."
  }
  foreach ($field in @(
      'file_count', 'directory_count', 'total_bytes', 'inventory_sha256',
      'directory_list_sha256')) {
    if ([string]$Expected.$field -cne [string]$Observed.$field) {
      throw "$Label inventory changed: $field"
    }
  }
  if (@($Expected.records).Count -ne [long]$Observed.file_count -or
      @($Expected.directory_records).Count -ne
        [long]$Observed.directory_count) {
    throw "$Label stored inventory is incomplete."
  }
  $true
}

function Assert-Issue13V5ExactPropertyNames(
  [object]$Value,
  [string[]]$Expected,
  [string]$Label
) {
  $observedNames = if ($Value -is [Collections.IDictionary]) {
    [string[]]@($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)
  } else {
    [string[]]@($Value.PSObject.Properties.Name | Sort-Object)
  }
  $expectedNames = [string[]]@($Expected | Sort-Object)
  if ([string]::Join("`n", $observedNames) -cne
      [string]::Join("`n", $expectedNames)) {
    throw "$Label properties changed."
  }
  $true
}

function Assert-Issue13V5EnvironmentName(
  [Parameter(Mandatory = $true)][object]$Name,
  [string]$Label = 'Environment variable'
) {
  if ($Name -isnot [string] -or
      [string]::IsNullOrWhiteSpace([string]$Name) -or
      [string]$Name -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
    throw "$Label name is invalid."
  }
  [string]$Name
}

function ConvertTo-Issue13V5EnvironmentMutations(
  [AllowNull()][Collections.IDictionary]$Environment
) {
  if ($null -eq $Environment) { return }
  $seen = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  $names = [Collections.Generic.List[string]]::new()
  foreach ($key in @($Environment.Keys)) {
    $name = Assert-Issue13V5EnvironmentName $key
    if (-not $seen.Add($name)) {
      throw "Environment variable is duplicated case-insensitively: $name"
    }
    $value = $Environment[$key]
    if ($null -ne $value -and $value -isnot [string]) {
      throw "Environment variable value must be a string or null: $name"
    }
    $names.Add($name)
  }
  $orderedNames = [string[]]$names.ToArray()
  [Array]::Sort($orderedNames, [StringComparer]::Ordinal)
  foreach ($name in $orderedNames) {
    $value = $Environment[$name]
    [pscustomobject][ordered]@{
      name = $name
      present = $null -ne $value
      value = if ($null -eq $value) { $null } else { [string]$value }
    }
  }
}

function Get-Issue13V5ProcessEnvironmentState(
  [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Names
) {
  $seen = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  $validated = [Collections.Generic.List[string]]::new()
  foreach ($candidate in @($Names)) {
    $name = Assert-Issue13V5EnvironmentName $candidate
    if (-not $seen.Add($name)) {
      throw "Environment variable is duplicated case-insensitively: $name"
    }
    $validated.Add($name)
  }
  foreach ($name in $validated) {
    $path = 'Env:' + $name
    $present = Test-Path -LiteralPath $path
    $value = [Environment]::GetEnvironmentVariable($name, 'Process')
    if ((-not $present) -and $null -ne $value) {
      throw "Environment absence disagrees with the process block: $name"
    }
    if ($present -and $null -eq $value) {
      throw "Environment presence disagrees with the process block: $name"
    }
    [pscustomobject][ordered]@{
      name = $name
      present = [bool]$present
      value = if ($present) { [string]$value } else { $null }
    }
  }
}

function Set-Issue13V5ProcessEnvironmentState(
  [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$States
) {
  $records = @($States)
  $seen = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  foreach ($state in $records) {
    if ($null -eq $state) {
      throw 'Environment state cannot be null.'
    }
    $null = Assert-Issue13V5ExactPropertyNames $state @(
      'name', 'present', 'value') 'Environment state'
    $name = Assert-Issue13V5EnvironmentName $state.name
    if (-not $seen.Add($name) -or $state.present -isnot [bool] -or
        ([bool]$state.present -and $state.value -isnot [string]) -or
        ((-not [bool]$state.present) -and $null -ne $state.value)) {
      throw "Environment state is invalid or duplicated: $name"
    }
  }
  foreach ($state in $records) {
    $name = [string]$state.name
    $path = 'Env:' + $name
    if ([bool]$state.present) {
      $value = [string]$state.value
      Set-Item -LiteralPath $path -Value $value -ErrorAction Stop
      if (-not (Test-Path -LiteralPath $path) -or
          [Environment]::GetEnvironmentVariable($name, 'Process') -cne
            $value) {
        throw "Failed to set process environment variable: $name"
      }
    } else {
      Remove-Item -LiteralPath ('Env:' + $name) -Force `
        -ErrorAction SilentlyContinue
      if ((Test-Path -LiteralPath $path) -or
          $null -ne [Environment]::GetEnvironmentVariable($name, 'Process')) {
        throw "Failed to remove process environment variable: $name"
      }
    }
  }
}

function Invoke-Issue13V5WithCleanup(
  [Parameter(Mandatory = $true, Position = 0)]
    [Alias('Action')][scriptblock]$issue13V5CleanupAction,
  [Parameter(Position = 1)]
    [Alias('Cleanup')][scriptblock[]]$issue13V5CleanupBlocks = @(),
  [Parameter(Position = 2)]
    [Alias('Label')][string]$issue13V5CleanupLabel = 'V5 operation'
) {
  $issue13V5CleanupResult = @()
  $issue13V5CleanupPrimaryError = $null
  try {
    $issue13V5CleanupResult = @(& $issue13V5CleanupAction)
  } catch {
    $issue13V5CleanupPrimaryError = $_
  }
  $issue13V5CleanupErrors = [Collections.Generic.List[Exception]]::new()
  foreach ($issue13V5CleanupBlock in @($issue13V5CleanupBlocks)) {
    try {
      $null = & $issue13V5CleanupBlock
    } catch {
      $issue13V5CleanupErrors.Add($_.Exception)
    }
  }
  if ($issue13V5CleanupErrors.Count -ne 0) {
    $issue13V5AggregateErrors = [Collections.Generic.List[Exception]]::new()
    if ($null -ne $issue13V5CleanupPrimaryError) {
      $issue13V5AggregateErrors.Add(
        $issue13V5CleanupPrimaryError.Exception)
    }
    foreach ($issue13V5CleanupError in $issue13V5CleanupErrors) {
      $issue13V5AggregateErrors.Add($issue13V5CleanupError)
    }
    throw [AggregateException]::new(
      "$issue13V5CleanupLabel cleanup failed.",
      $issue13V5AggregateErrors.ToArray())
  }
  if ($null -ne $issue13V5CleanupPrimaryError) {
    throw $issue13V5CleanupPrimaryError
  }
  $issue13V5CleanupResult
}

function Test-Issue13V5WithCleanupSelfTest {
  $Action = 'caller-action-sentinel'
  $Cleanup = 'caller-cleanup-sentinel'
  $Label = 'caller-label-sentinel'
  $result = 'caller-result-sentinel'
  $primary = 'caller-primary-sentinel'
  $cleanupFailures = 'caller-cleanup-failures-sentinel'
  $cleanupAction = 'caller-cleanup-action-sentinel'
  $failures = 'caller-failures-sentinel'
  $failure = 'caller-failure-sentinel'
  $issue13V5CleanupSelfTestExpected = [ordered]@{
    Action = $Action
    Cleanup = $Cleanup
    Label = $Label
    result = $result
    primary = $primary
    cleanupFailures = $cleanupFailures
    cleanupAction = $cleanupAction
    failures = $failures
    failure = $failure
  }
  $issue13V5CleanupSelfTestProbe = {
    [pscustomobject][ordered]@{
      Action = [string]$Action
      Cleanup = [string]$Cleanup
      Label = [string]$Label
      result = [string]$result
      primary = [string]$primary
      cleanupFailures = [string]$cleanupFailures
      cleanupAction = [string]$cleanupAction
      failures = [string]$failures
      failure = [string]$failure
    }
  }
  $issue13V5CleanupSelfTestAssertProbe = {
    param(
      [Parameter(Mandatory = $true)][object]$issue13V5CleanupSelfTestObserved,
      [Parameter(Mandatory = $true)][string]$issue13V5CleanupSelfTestPhase
    )
    foreach ($issue13V5CleanupSelfTestName in
        $issue13V5CleanupSelfTestExpected.Keys) {
      if ([string]$issue13V5CleanupSelfTestObserved.
          $issue13V5CleanupSelfTestName -cne
          [string]$issue13V5CleanupSelfTestExpected[
            $issue13V5CleanupSelfTestName]) {
        throw ("WithCleanup shadowed $issue13V5CleanupSelfTestName during " +
          "$issue13V5CleanupSelfTestPhase.")
      }
    }
  }

  $issue13V5CleanupSelfTestFunction =
    ${function:Invoke-Issue13V5WithCleanup}
  if ($null -eq $issue13V5CleanupSelfTestFunction) {
    throw 'WithCleanup function definition is unavailable to its self-test.'
  }
  $issue13V5CleanupSelfTestForbiddenNames = [string[]]@(
    'Action', 'Cleanup', 'Label', 'result', 'primary', 'cleanupFailures',
    'cleanupAction', 'failures', 'failure'
  )
  $issue13V5CleanupSelfTestAst =
    $issue13V5CleanupSelfTestFunction.Ast
  $issue13V5CleanupSelfTestForbiddenVariables = @(
    $issue13V5CleanupSelfTestAst.FindAll({
      param($issue13V5CleanupSelfTestNode)
      $issue13V5CleanupSelfTestNode -is
        [Management.Automation.Language.VariableExpressionAst] -and
        $issue13V5CleanupSelfTestForbiddenNames -ccontains
          $issue13V5CleanupSelfTestNode.VariablePath.UserPath
    }, $true)
  )
  if ($issue13V5CleanupSelfTestForbiddenVariables.Count -ne 0) {
    throw ('WithCleanup retains a dynamically visible callback collision: ' +
      [string]::Join(', ', @($issue13V5CleanupSelfTestForbiddenVariables |
          ForEach-Object { $_.VariablePath.UserPath })))
  }

  $issue13V5CleanupSelfTestNamedState = [pscustomobject]@{
    cleanup_count = 0L
    cleanup_probe = $null
  }
  $issue13V5CleanupSelfTestNamedResult = @(
    Invoke-Issue13V5WithCleanup `
      -Action { & $issue13V5CleanupSelfTestProbe } `
      -Cleanup @({
          $issue13V5CleanupSelfTestNamedState.cleanup_count++
          $issue13V5CleanupSelfTestNamedState.cleanup_probe =
            & $issue13V5CleanupSelfTestProbe
        }) `
      -Label 'named-alias-self-test-label'
  )
  if ($issue13V5CleanupSelfTestNamedResult.Count -ne 1 -or
      $issue13V5CleanupSelfTestNamedState.cleanup_count -ne 1L -or
      $null -eq $issue13V5CleanupSelfTestNamedState.cleanup_probe) {
    throw 'WithCleanup named-alias success result differs.'
  }
  $null = & $issue13V5CleanupSelfTestAssertProbe `
    $issue13V5CleanupSelfTestNamedResult[0] 'named action'
  $null = & $issue13V5CleanupSelfTestAssertProbe `
    $issue13V5CleanupSelfTestNamedState.cleanup_probe 'named cleanup'

  $issue13V5CleanupSelfTestPositionalState = [pscustomobject]@{ count = 0L }
  $issue13V5CleanupSelfTestPositionalResult = @(
    Invoke-Issue13V5WithCleanup `
      { 'positional-success' } `
      @({ $issue13V5CleanupSelfTestPositionalState.count++ }) `
      'positional-self-test-label'
  )
  if ($issue13V5CleanupSelfTestPositionalResult.Count -ne 1 -or
      [string]$issue13V5CleanupSelfTestPositionalResult[0] -cne
        'positional-success' -or
      $issue13V5CleanupSelfTestPositionalState.count -ne 1L) {
    throw 'WithCleanup positional success result differs.'
  }

  $issue13V5CleanupSelfTestPrimaryState = [pscustomobject]@{ count = 0L }
  $issue13V5CleanupSelfTestPrimaryError = $null
  try {
    $null = Invoke-Issue13V5WithCleanup `
      -Action { throw 'with-cleanup-primary-self-test' } `
      -Cleanup @({ $issue13V5CleanupSelfTestPrimaryState.count++ }) `
      -Label 'primary-self-test-label'
  } catch {
    $issue13V5CleanupSelfTestPrimaryError = $_
  }
  if ($null -eq $issue13V5CleanupSelfTestPrimaryError -or
      $issue13V5CleanupSelfTestPrimaryError.Exception -is
        [AggregateException] -or
      $issue13V5CleanupSelfTestPrimaryError.Exception.Message -cne
        'with-cleanup-primary-self-test' -or
      $issue13V5CleanupSelfTestPrimaryState.count -ne 1L) {
    throw 'WithCleanup primary-only failure semantics differ.'
  }

  $issue13V5CleanupSelfTestCleanupOnlyError = $null
  try {
    $null = Invoke-Issue13V5WithCleanup `
      -Action { 'cleanup-only-action-output' } `
      -Cleanup @({ throw 'with-cleanup-cleanup-only-self-test' }) `
      -Label 'cleanup-only-self-test-label'
  } catch {
    $issue13V5CleanupSelfTestCleanupOnlyError = $_.Exception
  }
  if ($issue13V5CleanupSelfTestCleanupOnlyError -isnot [AggregateException] -or
      $issue13V5CleanupSelfTestCleanupOnlyError.InnerExceptions.Count -ne 1 -or
      $issue13V5CleanupSelfTestCleanupOnlyError.InnerExceptions[0].Message -cne
        'with-cleanup-cleanup-only-self-test' -or
      -not $issue13V5CleanupSelfTestCleanupOnlyError.Message.StartsWith(
        'cleanup-only-self-test-label cleanup failed.',
        [StringComparison]::Ordinal)) {
    throw 'WithCleanup cleanup-only failure semantics differ.'
  }

  $issue13V5CleanupSelfTestAggregateState = [pscustomobject]@{ count = 0L }
  $issue13V5CleanupSelfTestAggregateError = $null
  try {
    $null = Invoke-Issue13V5WithCleanup `
      -Action { throw 'with-cleanup-aggregate-primary-self-test' } `
      -Cleanup @(
        {
          $issue13V5CleanupSelfTestAggregateState.count++
          throw 'with-cleanup-aggregate-first-self-test'
        },
        {
          $issue13V5CleanupSelfTestAggregateState.count++
          throw 'with-cleanup-aggregate-second-self-test'
        }
      ) `
      -Label 'aggregate-self-test-label'
  } catch {
    $issue13V5CleanupSelfTestAggregateError = $_.Exception
  }
  if ($issue13V5CleanupSelfTestAggregateError -isnot [AggregateException] -or
      $issue13V5CleanupSelfTestAggregateError.InnerExceptions.Count -ne 3 -or
      $issue13V5CleanupSelfTestAggregateError.InnerExceptions[0].Message -cne
        'with-cleanup-aggregate-primary-self-test' -or
      $issue13V5CleanupSelfTestAggregateError.InnerExceptions[1].Message -cne
        'with-cleanup-aggregate-first-self-test' -or
      $issue13V5CleanupSelfTestAggregateError.InnerExceptions[2].Message -cne
        'with-cleanup-aggregate-second-self-test' -or
      $issue13V5CleanupSelfTestAggregateState.count -ne 2L -or
      -not $issue13V5CleanupSelfTestAggregateError.Message.StartsWith(
        'aggregate-self-test-label cleanup failed.',
        [StringComparison]::Ordinal)) {
    throw 'WithCleanup primary/cleanup aggregation semantics differ.'
  }

  [pscustomobject][ordered]@{
    passed = $true
    public_alias_count = 3L
    binding_mode_count = 2L
    collision_name_count = 9L
    failure_scenario_count = 3L
  }
}
$null = Test-Issue13V5WithCleanupSelfTest

function Enter-Issue13V5ProcessEnvironment(
  [AllowNull()][Collections.IDictionary]$Environment
) {
  $mutations = @(ConvertTo-Issue13V5EnvironmentMutations $Environment)
  $snapshot = @()
  if ($mutations.Count -ne 0) {
    $snapshot = @(Get-Issue13V5ProcessEnvironmentState @(
      $mutations | ForEach-Object { [string]$_.name }))
  }
  $primary = $null
  try {
    if ($mutations.Count -ne 0) {
      Set-Issue13V5ProcessEnvironmentState $mutations
    }
  } catch {
    $primary = $_
  }
  if ($null -ne $primary) {
    $restoreFailures = [Collections.Generic.List[Exception]]::new()
    for ($index = $snapshot.Count - 1; $index -ge 0; $index--) {
      try {
        Set-Issue13V5ProcessEnvironmentState @($snapshot[$index])
      } catch {
        $restoreFailures.Add($_.Exception)
      }
    }
    if ($restoreFailures.Count -ne 0) {
      $failures = [Collections.Generic.List[Exception]]::new()
      $failures.Add($primary.Exception)
      foreach ($failure in $restoreFailures) { $failures.Add($failure) }
      throw [AggregateException]::new(
        'Process environment setup and restoration failed.',
        $failures.ToArray())
    }
    throw $primary
  }
  [pscustomobject][ordered]@{
    mutations = [object[]]$mutations
    snapshot = [object[]]$snapshot
    environment_set = [object[]]@($mutations | Where-Object present |
      ForEach-Object {
        [pscustomobject][ordered]@{
          name = [string]$_.name
          value = [string]$_.value
        }
      })
    environment_cleared = [object[]]@($mutations |
      Where-Object { -not [bool]$_.present } |
      ForEach-Object { [string]$_.name })
  }
}

function Exit-Issue13V5ProcessEnvironment(
  [Parameter(Mandatory = $true)][object]$State
) {
  $null = Assert-Issue13V5ExactPropertyNames $State @(
    'mutations', 'snapshot', 'environment_set', 'environment_cleared'
  ) 'Process environment scope'
  $snapshot = @($State.snapshot)
  $restoreFailures = [Collections.Generic.List[Exception]]::new()
  for ($index = $snapshot.Count - 1; $index -ge 0; $index--) {
    try {
      Set-Issue13V5ProcessEnvironmentState @($snapshot[$index])
    } catch {
      $restoreFailures.Add($_.Exception)
    }
  }
  if ($restoreFailures.Count -eq 1) { throw $restoreFailures[0] }
  if ($restoreFailures.Count -gt 1) {
    throw [AggregateException]::new(
      'Process environment restoration failed.',
      $restoreFailures.ToArray())
  }
}

function Invoke-Issue13V5WithProcessEnvironment(
  [AllowNull()][Collections.IDictionary]$Environment,
  [Parameter(Mandatory = $true)][scriptblock]$Action,
  [string]$Label = 'V5 process environment'
) {
  $state = Enter-Issue13V5ProcessEnvironment $Environment
  Invoke-Issue13V5WithCleanup -Action $Action -Label $Label -Cleanup @(
    { Exit-Issue13V5ProcessEnvironment $state }
  )
}

function Set-Issue13V5ProcessStartInfoEnvironment(
  [Parameter(Mandatory = $true)][Diagnostics.ProcessStartInfo]$ProcessStartInfo,
  [AllowNull()][Collections.IDictionary]$Environment
) {
  if ($ProcessStartInfo.UseShellExecute) {
    throw 'ProcessStartInfo must disable UseShellExecute before environment binding.'
  }
  $mutations = @(ConvertTo-Issue13V5EnvironmentMutations $Environment)
  $environmentSet = [Collections.Generic.List[object]]::new()
  $environmentCleared = [Collections.Generic.List[string]]::new()
  foreach ($mutation in $mutations) {
    $name = [string]$mutation.name
    if ([bool]$mutation.present) {
      $value = [string]$mutation.value
      $ProcessStartInfo.Environment[$name] = $value
      if (-not $ProcessStartInfo.Environment.ContainsKey($name) -or
          [string]$ProcessStartInfo.Environment[$name] -cne $value) {
        throw "Failed to set child-process environment variable: $name"
      }
      $environmentSet.Add([pscustomobject][ordered]@{
          name = $name
          value = $value
        })
    } else {
      $null = $ProcessStartInfo.Environment.Remove($name)
      if ($ProcessStartInfo.Environment.ContainsKey($name)) {
        throw "Failed to clear child-process environment variable: $name"
      }
      $environmentCleared.Add($name)
    }
  }
  [pscustomobject][ordered]@{
    environment_set = [object[]]$environmentSet.ToArray()
    environment_cleared = [object[]]$environmentCleared.ToArray()
  }
}

function Get-Issue13V5RenvLibraryRoot(
  [Parameter(Mandatory = $true)][string]$RLibrary
) {
  if ([string]::IsNullOrWhiteSpace($RLibrary)) {
    throw 'The renv library root requires an R library path.'
  }
  $library = [IO.Path]::GetFullPath($RLibrary).TrimEnd('\', '/')
  if (-not [IO.Directory]::Exists($library)) {
    throw 'The renv library path does not exist.'
  }
  $architecture = [IO.DirectoryInfo]::new($library)
  $version = $architecture.Parent
  $platform = if ($null -eq $version) { $null } else { $version.Parent }
  $root = if ($null -eq $platform) { $null } else { $platform.Parent }
  if ($null -eq $architecture -or $null -eq $version -or
      $null -eq $platform -or $null -eq $root -or
      $architecture.Name -cnotmatch '^[A-Za-z0-9._+-]+$' -or
      $version.Name -cnotmatch '^R-[0-9]+[.][0-9]+$' -or
      $platform.Name -cnotmatch '^[A-Za-z0-9._+-]+$' -or
      $root.Name -cne 'library') {
    throw 'The R library does not have the sealed renv profile layout.'
  }
  $reconstructed = [IO.Path]::GetFullPath([IO.Path]::Combine(
      $root.FullName, $platform.Name, $version.Name, $architecture.Name
    )).TrimEnd('\', '/')
  if (-not [string]::Equals(
      $reconstructed, $library, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The sealed renv library root reconstruction differs.'
  }
  $root.FullName.TrimEnd('\', '/')
}

function New-Issue13V5ClosedREnvironment(
  [Parameter(Mandatory = $true)][string]$RLibrary
) {
  if ([string]::IsNullOrWhiteSpace($RLibrary)) {
    throw 'The closed R environment requires an R library path.'
  }
  $environment = [ordered]@{}
  foreach ($name in $script:Issue13V5OracleClearedREnvironment) {
    $environment[$name] = $null
  }
  $environment['R_LIBS_USER'] = $RLibrary
  $environment['RENV_PATHS_LIBRARY'] =
    Get-Issue13V5RenvLibraryRoot $RLibrary
  $environment['RENV_CONFIG_AUTO_SNAPSHOT'] = 'FALSE'
  $environment['RENV_CONFIG_CACHE_ENABLED'] = 'FALSE'
  $environment['RENV_CONFIG_LOCKING_ENABLED'] = 'FALSE'
  $environment['RENV_CONFIG_SANDBOX_ENABLED'] = 'FALSE'
  $environment['RENV_CONFIG_UPDATES_CHECK'] = 'FALSE'
  $environment['RENV_CONFIG_USER_ENVIRON'] = 'FALSE'
  $environment['RENV_CONFIG_USER_LIBRARY'] = 'FALSE'
  $environment['TZ'] = 'UTC'
  $environment
}

function Test-Issue13V5ProcessEnvironmentSelfTest {
  $suffix = [Guid]::NewGuid().ToString('N').ToUpperInvariant()
  $clearName = 'ISSUE13_V5_CLEAR_' + $suffix
  $emptyName = 'ISSUE13_V5_EMPTY_' + $suffix
  $valueName = 'ISSUE13_V5_VALUE_' + $suffix
  $inheritName = 'ISSUE13_V5_INHERIT_' + $suffix
  $names = @($clearName, $emptyName, $valueName, $inheritName)
  $initial = @(Get-Issue13V5ProcessEnvironmentState $names)
  $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
    'issue13-v5-env-selftest-' + [Guid]::NewGuid().ToString('N'))
  $selfTest = {
    Set-Issue13V5ProcessEnvironmentState @(
      [pscustomobject][ordered]@{
        name = $clearName; present = $true; value = 'before-clear'
      },
      [pscustomobject][ordered]@{
        name = $emptyName; present = $true; value = ''
      },
      [pscustomobject][ordered]@{
        name = $valueName; present = $false; value = $null
      },
      [pscustomobject][ordered]@{
        name = $inheritName; present = $true; value = 'inherited'
      }
    )
    $environment = [ordered]@{}
    $environment[$clearName] = $null
    $environment[$emptyName] = ''
    $environment[$valueName] = 'after-value'
    $result = @(Invoke-Issue13V5WithProcessEnvironment `
      -Environment $environment -Label 'Environment tri-state self-test' `
      -Action {
        $observed = @(Get-Issue13V5ProcessEnvironmentState $names)
        if ([bool]$observed[0].present -or
            -not [bool]$observed[1].present -or
            [string]$observed[1].value -cne '' -or
            -not [bool]$observed[2].present -or
            [string]$observed[2].value -cne 'after-value' -or
            [string]$observed[3].value -cne 'inherited') {
          throw 'Tri-state action environment differs.'
        }
        'tri-state-ok'
      })
    if ($result.Count -ne 1 -or [string]$result[0] -cne 'tri-state-ok') {
      throw 'Tri-state action result differs.'
    }
    $restored = @(Get-Issue13V5ProcessEnvironmentState $names)
    if (-not [bool]$restored[0].present -or
        [string]$restored[0].value -cne 'before-clear' -or
        -not [bool]$restored[1].present -or
        [string]$restored[1].value -cne '' -or
        [bool]$restored[2].present -or
        [string]$restored[3].value -cne 'inherited') {
      throw 'Tri-state success restoration differs.'
    }
    $failureObserved = $false
    try {
      $null = Invoke-Issue13V5WithProcessEnvironment `
        -Environment $environment -Label 'Environment failure self-test' `
        -Action { throw 'intentional-environment-self-test-failure' }
    } catch {
      $failureObserved = $_.Exception.Message -ceq
        'intentional-environment-self-test-failure'
    }
    if (-not $failureObserved) {
      throw 'The intentional environment action failure was not preserved.'
    }
    $restoredAfterFailure = @(Get-Issue13V5ProcessEnvironmentState $names)
    if (-not [bool]$restoredAfterFailure[0].present -or
        [string]$restoredAfterFailure[0].value -cne 'before-clear' -or
        -not [bool]$restoredAfterFailure[1].present -or
        [string]$restoredAfterFailure[1].value -cne '' -or
        [bool]$restoredAfterFailure[2].present -or
        [string]$restoredAfterFailure[3].value -cne 'inherited') {
      throw 'Tri-state failure restoration differs.'
    }
    $cleanupState = [pscustomobject]@{ count = 0L }
    $aggregateObserved = $false
    try {
      $null = Invoke-Issue13V5WithCleanup `
        -Label 'Aggregate cleanup self-test' `
        -Action { throw 'self-test-primary' } `
        -Cleanup @(
          {
            $cleanupState.count++
            throw 'self-test-cleanup-one'
          },
          {
            $cleanupState.count++
            throw 'self-test-cleanup-two'
          }
        )
    } catch {
      $exception = $_.Exception
      $aggregateObserved = $exception -is [AggregateException] -and
        $exception.InnerExceptions.Count -eq 3 -and
        $exception.InnerExceptions[0].Message -ceq 'self-test-primary' -and
        $exception.InnerExceptions[1].Message -ceq 'self-test-cleanup-one' -and
        $exception.InnerExceptions[2].Message -ceq 'self-test-cleanup-two'
    }
    if (-not $aggregateObserved -or $cleanupState.count -ne 2L) {
      throw 'Primary/cleanup aggregation self-test failed.'
    }
    $duplicate = [Collections.Specialized.OrderedDictionary]::new(
      [StringComparer]::Ordinal)
    $duplicate.Add($clearName, 'one')
    $duplicate.Add($clearName.ToLowerInvariant(), 'two')
    try {
      $null = @(ConvertTo-Issue13V5EnvironmentMutations $duplicate)
      throw 'Case-insensitive environment duplicate was accepted.'
    } catch {
      if ($_.Exception.Message -ceq
          'Case-insensitive environment duplicate was accepted.') {
        throw
      }
    }
    $invalid = [ordered]@{}
    $invalid[$valueName] = 7L
    try {
      $null = @(ConvertTo-Issue13V5EnvironmentMutations $invalid)
      throw 'Non-string environment value was accepted.'
    } catch {
      if ($_.Exception.Message -ceq
          'Non-string environment value was accepted.') {
        throw
      }
    }
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.UseShellExecute = $false
    $binding = Set-Issue13V5ProcessStartInfoEnvironment $info $environment
    if ($info.Environment.ContainsKey($clearName) -or
        -not $info.Environment.ContainsKey($emptyName) -or
        [string]$info.Environment[$emptyName] -cne '' -or
        [string]$info.Environment[$valueName] -cne 'after-value' -or
        [string]$info.Environment[$inheritName] -cne 'inherited' -or
        @($binding.environment_set).Count -ne 2 -or
        @($binding.environment_cleared).Count -ne 1) {
      throw 'ProcessStartInfo environment binding differs.'
    }
    $null = [IO.Directory]::CreateDirectory($temporaryRoot)
    $childCommand = @"
if (Test-Path -LiteralPath 'Env:$clearName') { exit 81 }
if (-not (Test-Path -LiteralPath 'Env:$emptyName')) { exit 82 }
if ([Environment]::GetEnvironmentVariable('$emptyName', 'Process') -cne '') { exit 83 }
if ([Environment]::GetEnvironmentVariable('$inheritName', 'Process') -cne 'inherited') { exit 84 }
"@
    $externalEnvironment = [ordered]@{}
    $externalEnvironment[$clearName] = $null
    $externalEnvironment[$emptyName] = ''
    $external = Invoke-Issue13V5PwshExternal `
      ([pscustomobject]@{ control_root = $temporaryRoot }) @(
        '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', $childCommand
      ) 'environment-self-test-child' 30 @(0) $null $externalEnvironment
    $record = Read-Issue13V5Json ([string]$external.record_path)
    $null = Assert-Issue13V5ExactPropertyNames $record @(
      'schema', 'label', 'executable', 'arguments', 'environment_set',
      'environment_cleared', 'working_directory', 'started_at_utc',
      'finished_at_utc', 'timeout_seconds', 'timed_out', 'exit_code',
      'expected_exit_codes', 'stdout_path', 'stdout_sha256', 'stderr_path',
      'stderr_sha256'
    ) 'Environment self-test command record'
    $emptyRecords = @($record.environment_set | Where-Object {
      [string]$_.name -ceq $emptyName -and [string]$_.value -ceq ''
    })
    $gitRecords = @($record.environment_set | Where-Object {
      [string]$_.name -ceq 'ISSUE13_V5_GIT_EXECUTABLE' -and
        [string]$_.value -ceq [string]$script:Issue13V5GitLogicalPath
    })
    if (@($record.environment_set).Count -ne 2 -or
        $emptyRecords.Count -ne 1 -or $gitRecords.Count -ne 1 -or
        @($record.environment_cleared).Count -ne 1 -or
        [string]$record.environment_cleared[0] -cne $clearName) {
      throw 'External command environment record differs.'
    }
  }
  $initialScope = [pscustomobject][ordered]@{
    mutations = [object[]]@()
    snapshot = [object[]]$initial
    environment_set = [object[]]@()
    environment_cleared = [object[]]@()
  }
  $cleanup = @(
    { Exit-Issue13V5ProcessEnvironment $initialScope },
    {
      if (Test-Path -LiteralPath $temporaryRoot -PathType Container) {
        [IO.Directory]::Delete($temporaryRoot, $true)
      }
    }
  )
  $null = Invoke-Issue13V5WithCleanup -Action $selfTest -Cleanup $cleanup `
    -Label 'Environment self-test'
  [pscustomobject][ordered]@{
    passed = $true
    tested_state_count = 4L
    external_command_count = 1L
  }
}

function Assert-Issue13V5OracleEffectBindings([object]$Config) {
  $oracle = $Config.oracle_effect
  $bindingFields = @(
    'schema', 'status', 'passed', 'final_evidence_eligible',
    'required_by_final_gate', 'strict_common_method_count',
    'comparison_execution_count', 'approved_run_inventory_count',
    'recovered_method_count', 'oracle_effect_closed',
    'final_v5_gate_substituted', 'authorized_patch_sha256',
    'authorized_patch_id', 'oracle_smoke', 'proof', 'comparisons',
    'comparison_harness', 'r_library', 'tooling'
  )
  if ($oracle.PSObject.Properties.Name -ccontains 'initial_validation') {
    $bindingFields += 'initial_validation'
  }
  $null = Assert-Issue13V5ExactPropertyNames $oracle $bindingFields `
    'Oracle-effect config binding'
  $null = Assert-Issue13V5ExactPropertyNames $oracle.oracle_smoke @(
    'path', 'sha256', 'final_evidence_eligible'
  ) 'Oracle-effect smoke binding'
  $null = Assert-Issue13V5ExactPropertyNames $oracle.proof @(
    'path', 'sha256', 'schema'
  ) 'Oracle-effect proof binding'
  $null = Assert-Issue13V5ExactPropertyNames $oracle.comparisons.primary @(
    'root', 'inventory'
  ) 'Oracle-effect primary binding'
  $null = Assert-Issue13V5ExactPropertyNames $oracle.comparisons.replay @(
    'root', 'inventory'
  ) 'Oracle-effect replay binding'
  $null = Assert-Issue13V5ExactPropertyNames $oracle.comparison_harness @(
    'expected_candidate_commit', 'manifest_path', 'manifest_sha256',
    'generation', 'final_evidence_eligible', 'reuses_candidate_evidence',
    'source_controller_commit_sha256', 'source_controller', 'source_tooling',
    'output_tooling', 'sealed_output_tooling', 'installed_inventory'
  ) 'Oracle-effect terminal harness binding'
  $null = Assert-Issue13V5SourceToolingShape `
    $oracle.comparison_harness.source_tooling `
    'Oracle-effect source tooling binding'
  $null = Assert-Issue13V5ExactPropertyNames $oracle.r_library @(
    'path', 'environment_variable', 'environment', 'activation',
    'r_version', 'platform',
    'lib_paths', 'required_packages', 'loaded_packages', 'inventory_sha256'
  ) 'Oracle-effect R library binding'
  $null = Assert-Issue13V5ExactPropertyNames $oracle.r_library.environment @(
    'set', 'cleared'
  ) 'Oracle-effect R environment binding'
  $null = Assert-Issue13V5ExactPropertyNames $oracle.r_library.activation @(
    'mode', 'verified', 'renv_version', 'captured_console_line_count',
    'renv_library_root', 'project_inventory_sha256',
    'project_library_absent_before', 'project_library_absent_after',
    'r_library_inventory_before_sha256',
    'r_library_inventory_after_sha256'
  ) 'Oracle-effect isolated renv activation binding'
  foreach ($record in @($oracle.r_library.environment.set)) {
    $null = Assert-Issue13V5ExactPropertyNames $record @(
      'name', 'value'
    ) 'Oracle-effect set R environment record'
  }
  foreach ($package in @($oracle.r_library.loaded_packages)) {
    $null = Assert-Issue13V5ExactPropertyNames $package @(
      'name', 'version', 'path', 'required', 'file_count', 'total_bytes',
      'inventory_sha256'
    ) 'Oracle-effect loaded R package record'
  }
  foreach ($inventoryName in @('output_tooling', 'sealed_output_tooling')) {
    $null = Assert-Issue13V5ExactPropertyNames `
      $oracle.comparison_harness.$inventoryName @(
        'file_count', 'total_bytes', 'inventory_sha256'
      ) "Oracle-effect harness $inventoryName binding"
  }
  $null = Assert-Issue13V5ExactPropertyNames `
    $oracle.comparison_harness.installed_inventory @(
      'root', 'harness_root', 'file_count', 'total_bytes', 'inventory_sha256'
    ) 'Oracle-effect installed harness inventory binding'
  if ([string]$oracle.schema -cne 'wlv-issue13-v5-oracle-effect-binding/2' -or
      [string]$oracle.status -cne 'passed' -or
      -not (Test-Issue13V5ExactBoolean $oracle.passed $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $oracle.final_evidence_eligible $false) -or
      -not (Test-Issue13V5ExactBoolean `
        $oracle.required_by_final_gate $true) -or
      [long]$oracle.strict_common_method_count -ne 5L -or
      [long]$oracle.comparison_execution_count -ne 10L -or
      [long]$oracle.approved_run_inventory_count -ne 17L -or
      [long]$oracle.recovered_method_count -ne 7L -or
      -not (Test-Issue13V5ExactBoolean `
        $oracle.oracle_effect_closed $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $oracle.final_v5_gate_substituted $false) -or
      [string]$oracle.authorized_patch_sha256 -cne
        $script:Issue13V5BaselineOverlaySha256 -or
      [string]$oracle.authorized_patch_id -cne
        $script:Issue13V5BaselineOverlayPatchId) {
    throw 'Oracle-effect config binding is not the required auxiliary 5+7 proof.'
  }
  $proofPath = (Resolve-Path -LiteralPath (
    [string]$oracle.proof.path)).Path
  $oracleSmokePath = (Resolve-Path -LiteralPath (
    [string]$oracle.oracle_smoke.path)).Path
  $primaryRoot = (Resolve-Path -LiteralPath (
    [string]$oracle.comparisons.primary.root)).Path
  $replayRoot = (Resolve-Path -LiteralPath (
    [string]$oracle.comparisons.replay.root)).Path
  $comparisonHarness = (Resolve-Path -LiteralPath (
    [string]$oracle.comparison_harness.manifest_path)).Path
  $rscriptPath = (Resolve-Path -LiteralPath ([string]$Config.rscript)).Path
  $rLibraryPath = (Resolve-Path -LiteralPath (
    [string]$oracle.r_library.path)).Path
  $null = Assert-Issue13V5OracleComparisonIsolation $Config
  if ((Get-Issue13V5Sha256 $proofPath) -cne
        [string]$oracle.proof.sha256 -or
      [string]$oracle.proof.schema -cne
        'wlv-issue13-v5-oracle-effect-proof/2' -or
      (Get-Issue13V5Sha256 $oracleSmokePath) -cne
        [string]$oracle.oracle_smoke.sha256 -or
      -not (Test-Issue13V5ExactBoolean `
        $oracle.oracle_smoke.final_evidence_eligible $false) -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path $comparisonHarness),
        (ConvertTo-Issue13V5Path ([string]$Config.harness_manifest_path)),
        [StringComparison]::OrdinalIgnoreCase) -or
      (Get-Issue13V5Sha256 $comparisonHarness) -cne
        [string]$oracle.comparison_harness.manifest_sha256 -or
      [string]$oracle.comparison_harness.manifest_sha256 -cne
        [string]$Config.harness_manifest_sha256 -or
      [string]$oracle.comparison_harness.expected_candidate_commit -cne
        [string]$Config.candidate_commit -or
      [string]$oracle.comparison_harness.source_controller_commit_sha256 -cne
        [string]$Config.candidate_commit -or
      [string]$oracle.comparison_harness.generation -cne 'v5-terminal' -or
      -not (Test-Issue13V5ExactBoolean `
        $oracle.comparison_harness.final_evidence_eligible $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $oracle.comparison_harness.reuses_candidate_evidence $false) -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path $rscriptPath),
        (ConvertTo-Issue13V5Path ([string]$Config.rscript)),
        [StringComparison]::OrdinalIgnoreCase) -or
      (Get-Issue13V5Sha256 $rscriptPath) -cne
        $script:Issue13V5RscriptSha256 -or
      [int64](Get-Item -LiteralPath $rscriptPath).Length -ne 94720L -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path $rLibraryPath),
        (ConvertTo-Issue13V5Path ([string]$Config.r_library)),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$oracle.r_library.environment_variable -cne 'R_LIBS_USER') {
    throw 'Oracle-effect proof, terminal runtime, or candidate binding changed.'
  }
  $clearedObserved = [string[]]@($oracle.r_library.environment.cleared | Sort-Object)
  $clearedExpected = [string[]]@(
    $script:Issue13V5OracleClearedREnvironment | Sort-Object)
  $requiredObserved = [string[]]@($oracle.r_library.required_packages |
    Sort-Object)
  $requiredExpected = [string[]]@(
    $script:Issue13V5OracleRequiredRPackages | Sort-Object)
  $setRecords = @($oracle.r_library.environment.set)
  $renvLibraryRoot = Get-Issue13V5RenvLibraryRoot $rLibraryPath
  $rLibrarySet = @($setRecords | Where-Object {
    [string]$_.name -ceq 'R_LIBS_USER' -and
    [string]::Equals(
      (ConvertTo-Issue13V5Path ([string]$_.value)),
      (ConvertTo-Issue13V5Path $rLibraryPath),
      [StringComparison]::OrdinalIgnoreCase)
  })
  $renvLibrarySet = @($setRecords | Where-Object {
    [string]$_.name -ceq 'RENV_PATHS_LIBRARY' -and
    [string]::Equals(
      (ConvertTo-Issue13V5Path ([string]$_.value)),
      (ConvertTo-Issue13V5Path $renvLibraryRoot),
      [StringComparison]::OrdinalIgnoreCase)
  })
  $tzSet = @($setRecords | Where-Object {
    [string]$_.name -ceq 'TZ' -and [string]$_.value -ceq 'UTC'
  })
  $sandboxSet = @($setRecords | Where-Object {
    [string]$_.name -ceq 'RENV_CONFIG_SANDBOX_ENABLED' -and
    [string]$_.value -ceq 'FALSE'
  })
  $autoSnapshotSet = @($setRecords | Where-Object {
    [string]$_.name -ceq 'RENV_CONFIG_AUTO_SNAPSHOT' -and
    [string]$_.value -ceq 'FALSE'
  })
  $cacheSet = @($setRecords | Where-Object {
    [string]$_.name -ceq 'RENV_CONFIG_CACHE_ENABLED' -and
    [string]$_.value -ceq 'FALSE'
  })
  $lockingSet = @($setRecords | Where-Object {
    [string]$_.name -ceq 'RENV_CONFIG_LOCKING_ENABLED' -and
    [string]$_.value -ceq 'FALSE'
  })
  $updatesSet = @($setRecords | Where-Object {
    [string]$_.name -ceq 'RENV_CONFIG_UPDATES_CHECK' -and
    [string]$_.value -ceq 'FALSE'
  })
  $userEnvironSet = @($setRecords | Where-Object {
    [string]$_.name -ceq 'RENV_CONFIG_USER_ENVIRON' -and
    [string]$_.value -ceq 'FALSE'
  })
  $userLibrarySet = @($setRecords | Where-Object {
    [string]$_.name -ceq 'RENV_CONFIG_USER_LIBRARY' -and
    [string]$_.value -ceq 'FALSE'
  })
  if ([string]::Join("`n", $clearedObserved) -cne
        [string]::Join("`n", $clearedExpected) -or
      [string]::Join("`n", $requiredObserved) -cne
        [string]::Join("`n", $requiredExpected) -or
      $setRecords.Count -ne 10 -or $rLibrarySet.Count -ne 1 -or
      $renvLibrarySet.Count -ne 1 -or $sandboxSet.Count -ne 1 -or
      $autoSnapshotSet.Count -ne 1 -or $cacheSet.Count -ne 1 -or
      $lockingSet.Count -ne 1 -or $updatesSet.Count -ne 1 -or
      $userEnvironSet.Count -ne 1 -or $userLibrarySet.Count -ne 1 -or
      $tzSet.Count -ne 1 -or
      [string]$oracle.r_library.activation.mode -cne
        'isolated-project-copy' -or
      -not (Test-Issue13V5ExactBoolean `
        $oracle.r_library.activation.verified $true) -or
      [string]$oracle.r_library.activation.renv_version -cne '1.2.4' -or
      [long]$oracle.r_library.activation.captured_console_line_count -lt 0L -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path (
          [string]$oracle.r_library.activation.renv_library_root)),
        (ConvertTo-Issue13V5Path $renvLibraryRoot),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$oracle.r_library.activation.project_inventory_sha256 -cnotmatch
        '^[0-9a-f]{64}$' -or
      -not (Test-Issue13V5ExactBoolean `
        $oracle.r_library.activation.project_library_absent_before $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $oracle.r_library.activation.project_library_absent_after $true) -or
      [string]$oracle.r_library.activation.r_library_inventory_before_sha256 `
        -cnotmatch '^[0-9a-f]{64}$' -or
      [string]$oracle.r_library.activation.r_library_inventory_before_sha256 `
        -cne [string]$oracle.r_library.activation.
          r_library_inventory_after_sha256 -or
      @($oracle.r_library.lib_paths).Count -lt 1 -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$oracle.r_library.lib_paths[0])),
        (ConvertTo-Issue13V5Path $rLibraryPath),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$oracle.r_library.r_version -notmatch '^R version ' -or
      [string]::IsNullOrWhiteSpace([string]$oracle.r_library.platform) -or
      [string]$oracle.r_library.inventory_sha256 -cnotmatch
        '^[0-9a-f]{64}$') {
    throw 'Oracle-effect sanitized R environment/runtime binding changed.'
  }
  $loadedPackages = @($oracle.r_library.loaded_packages)
  if ($loadedPackages.Count -lt 3 -or
      @($loadedPackages.name | Select-Object -Unique).Count -ne
        $loadedPackages.Count) {
    throw 'Oracle-effect loaded R package inventory is incomplete or duplicated.'
  }
  $loadedRequired = [string[]]@($loadedPackages | Where-Object required |
    ForEach-Object name | Sort-Object)
  if ([string]::Join("`n", $loadedRequired) -cne
      [string]::Join("`n", $requiredExpected)) {
    throw 'Oracle-effect required R package inventory changed.'
  }
  foreach ($package in $loadedPackages) {
    $packagePath = (Resolve-Path -LiteralPath ([string]$package.path)).Path
    if ((Test-Issue13V5ExactBoolean $package.required $true) -and
        -not (Test-Issue13V5PathContained $packagePath $rLibraryPath)) {
      throw "Required R package escaped RLibrary: $($package.name)"
    }
    $packageInventory = Get-Issue13V5OraclePackageInventory $packagePath
    foreach ($field in @('file_count', 'total_bytes', 'inventory_sha256')) {
      if ([string]$package.$field -cne [string]$packageInventory.$field) {
        throw "Loaded R package inventory changed: $($package.name)/$field"
      }
    }
  }
  $expectedTools = @(Get-Issue13V5OracleEffectToolRecords)
  $storedTools = @($oracle.tooling)
  if ($storedTools.Count -ne $script:Issue13V5OracleEffectFiles.Count -or
      $expectedTools.Count -ne $storedTools.Count) {
    throw 'Oracle-effect tooling coverage is incomplete.'
  }
  for ($index = 0; $index -lt $expectedTools.Count; $index++) {
    foreach ($field in @('name', 'path', 'size_bytes', 'sha256')) {
      $left = [string]$storedTools[$index].$field
      $right = [string]$expectedTools[$index].$field
      if ($field -ceq 'path') {
        if (-not [string]::Equals(
            (ConvertTo-Issue13V5Path $left),
            (ConvertTo-Issue13V5Path $right),
            [StringComparison]::OrdinalIgnoreCase)) {
          throw "Oracle-effect tooling path changed: $($expectedTools[$index].name)"
        }
      } elseif ($left -cne $right) {
        throw "Oracle-effect tooling changed: $($expectedTools[$index].name)/$field"
      }
    }
  }
  $specTool = @($expectedTools | Where-Object {
      [string]$_.name -ceq 'issue13-v5-oracle-effect-spec.json'
    })
  $schemaTool = @($expectedTools | Where-Object {
      [string]$_.name -ceq 'issue13-v5-oracle-effect-proof.schema.json'
    })
  if ($specTool.Count -ne 1 -or $schemaTool.Count -ne 1) {
    throw 'Oracle-effect spec/schema tooling is ambiguous.'
  }
  $proof = Read-Issue13V5Json $proofPath
  $null = Assert-Issue13V5ExactPropertyNames $proof @(
    'schema', 'status', 'passed', 'final_evidence_eligible', 'purpose',
    'generated_at_utc', 'evidence', 'conclusion'
  ) 'Oracle-effect proof'
  $null = Assert-Issue13V5ExactPropertyNames $proof.evidence @(
    'spec', 'proof_schema', 'oracle', 'terminal_runtime', 'source_evidence',
    'approved_run_immutability', 'comparison_workflow', 'recovered_methods'
  ) 'Oracle-effect evidence'
  $null = Assert-Issue13V5ExactPropertyNames $proof.evidence.terminal_runtime @(
    'comparison_harness', 'rscript', 'r_library', 'runtime_immutability'
  ) 'Oracle-effect terminal runtime evidence'
  $runtimeImmutability = $proof.evidence.terminal_runtime.runtime_immutability
  $null = Assert-Issue13V5ExactPropertyNames $runtimeImmutability @(
    'before', 'after', 'immutable'
  ) 'Oracle-effect R runtime immutability'
  foreach ($snapshot in @($runtimeImmutability.before, $runtimeImmutability.after)) {
    $null = Assert-Issue13V5ExactPropertyNames $snapshot @(
      'rscript', 'r_library'
    ) 'Oracle-effect R runtime snapshot'
    $null = Assert-Issue13V5ExactPropertyNames $snapshot.rscript @(
      'logical_path', 'physical_path', 'item_id', 'link_count', 'size_bytes',
      'sha256'
    ) 'Oracle-effect Rscript runtime snapshot'
  }
  if (-not (Test-Issue13V5ExactBoolean $runtimeImmutability.immutable $true) -or
      ($runtimeImmutability.before | ConvertTo-Json -Depth 30 -Compress) -cne
        ($runtimeImmutability.after | ConvertTo-Json -Depth 30 -Compress)) {
    throw 'Oracle-effect R runtime before/after inventory is not immutable.'
  }
  $currentRscriptItem = Get-Issue13V5PhysicalItemIdentity `
    $rscriptPath 'Oracle-effect Rscript executable'
  $currentRscriptRecord = [pscustomobject][ordered]@{
    logical_path = $rscriptPath
    physical_path = [string]$currentRscriptItem.physical_path
    item_id = [string]$currentRscriptItem.item_id
    link_count = [long]$currentRscriptItem.link_count
    size_bytes = [long](Get-Item -LiteralPath $rscriptPath).Length
    sha256 = Get-Issue13V5Sha256 $rscriptPath
  }
  $configuredRuntimeSnapshot = [pscustomobject][ordered]@{
    rscript = $currentRscriptRecord
    r_library = $oracle.r_library
  }
  if (($runtimeImmutability.after | ConvertTo-Json -Depth 30 -Compress) -cne
      ($configuredRuntimeSnapshot | ConvertTo-Json -Depth 30 -Compress)) {
    throw 'Oracle-effect config differs from the attested R runtime snapshot.'
  }
  $expectedController = Get-Issue13V5ControllerIdentity `
    ([string]$Config.repository_root) ([string]$Config.candidate_commit)
  $null = Assert-Issue13V5ControllerIdentity `
    $oracle.comparison_harness.source_controller $expectedController `
    'Oracle-effect config source controller'
  $null = Assert-Issue13V5ControllerIdentity `
    $proof.evidence.terminal_runtime.comparison_harness.source_controller `
    $expectedController 'Oracle-effect proof source controller'
  $harnessManifest = Read-Issue13V5Json $comparisonHarness
  $null = Assert-Issue13V5ExactPropertyNames $harnessManifest.source_controller @(
    'commit_sha256', 'file_count', 'records'
  ) 'Terminal harness manifest source controller'
  $proofHarness = $proof.evidence.terminal_runtime.comparison_harness
  $null = Assert-Issue13V5ExactPropertyNames $proofHarness @(
    'expected_candidate_commit', 'manifest_path', 'manifest_sha256',
    'generation', 'final_evidence_eligible', 'reuses_candidate_evidence',
    'source_controller_commit_sha256', 'source_controller', 'source_tooling',
    'output_tooling', 'sealed_output_tooling', 'installed_inventory', 'tools'
  ) 'Oracle-effect proof comparison harness'
  $null = Assert-Issue13V5SourceToolingShape $harnessManifest.source_tooling `
    'Terminal harness manifest source tooling'
  $null = Assert-Issue13V5SourceToolingShape $proofHarness.source_tooling `
    'Oracle-effect proof source tooling'
  $derivedSourceTooling = Get-Issue13V5SourceToolingBinding $Config
  $derivedSourceToolingJson = $derivedSourceTooling |
    ConvertTo-Json -Depth 30 -Compress
  if (($harnessManifest.source_tooling |
        ConvertTo-Json -Depth 30 -Compress) -cne $derivedSourceToolingJson -or
      ($oracle.comparison_harness.source_tooling |
        ConvertTo-Json -Depth 30 -Compress) -cne $derivedSourceToolingJson -or
      ($proofHarness.source_tooling |
        ConvertTo-Json -Depth 30 -Compress) -cne $derivedSourceToolingJson) {
    throw 'Source tooling differs among Git, manifest, config, and proof.'
  }
  if ([string]$harnessManifest.source_controller.commit_sha256 -cne
        [string]$expectedController.commit_sha256 -or
      [int64]$harnessManifest.source_controller.file_count -ne
        [int64]$expectedController.file_count -or
      @($harnessManifest.source_controller.records).Count -ne
        [int64]$expectedController.file_count) {
    throw 'Terminal harness manifest source controller aggregate changed.'
  }
  foreach ($expectedRecord in @($expectedController.records)) {
    $matches = @($harnessManifest.source_controller.records | Where-Object {
      [string]$_.name -ceq [string]$expectedRecord.name
    })
    if ($matches.Count -ne 1) {
      throw "Terminal harness source record is missing or duplicated: $($expectedRecord.name)"
    }
    $null = Assert-Issue13V5ExactPropertyNames $matches[0] @(
      'name', 'relative_path', 'sha256', 'git_blob'
    ) "Terminal harness source record $($expectedRecord.name)"
    foreach ($field in @('name', 'relative_path', 'sha256', 'git_blob')) {
      if ([string]$matches[0].$field -cne [string]$expectedRecord.$field) {
        throw "Terminal harness source record differs: $($expectedRecord.name)/$field"
      }
    }
  }
  $null = Assert-Issue13V5ExactPropertyNames $proof.conclusion @(
    'authorized_patch_authenticated', 'terminal_harness_authenticated',
    'strict_common_method_count', 'strict_common_primary_and_replay_passed',
    'approved_run_count', 'approved_runs_immutable', 'recovered_method_count',
    'recovered_methods_passed',
    'recovered_coordinate_and_diagnostic_contracts_passed',
    'oracle_effect_closed', 'final_v5_gate_substituted'
  ) 'Oracle-effect conclusion'
  if ([string]$proof.schema -cne
        'wlv-issue13-v5-oracle-effect-proof/2' -or
      [string]$proof.status -cne 'passed' -or
      -not (Test-Issue13V5ExactBoolean $proof.passed $true) -or
      -not (Test-Issue13V5ExactBoolean $proof.final_evidence_eligible $false) -or
      [string]$proof.purpose -cne
        'closed-authorized-oracle-effect-cc2-to-e2f' -or
      -not (Test-Issue13V5ExactBoolean $proof.conclusion.authorized_patch_authenticated $true) -or
      -not (Test-Issue13V5ExactBoolean $proof.conclusion.terminal_harness_authenticated $true) -or
      [long]$proof.conclusion.strict_common_method_count -ne 5L -or
      -not (Test-Issue13V5ExactBoolean $proof.conclusion.strict_common_primary_and_replay_passed $true) -or
      [long]$proof.conclusion.approved_run_count -ne 17L -or
      -not (Test-Issue13V5ExactBoolean $proof.conclusion.approved_runs_immutable $true) -or
      [long]$proof.conclusion.recovered_method_count -ne 7L -or
      -not (Test-Issue13V5ExactBoolean $proof.conclusion.recovered_methods_passed $true) -or
      -not (Test-Issue13V5ExactBoolean $proof.conclusion.recovered_coordinate_and_diagnostic_contracts_passed $true) -or
      -not (Test-Issue13V5ExactBoolean $proof.conclusion.oracle_effect_closed $true) -or
      -not (Test-Issue13V5ExactBoolean $proof.conclusion.final_v5_gate_substituted $false)) {
    throw 'Oracle-effect proof envelope or conclusion changed.'
  }
  if (-not [string]::Equals(
      (ConvertTo-Issue13V5Path (
        [string]$proof.evidence.source_evidence.strict_smoke_summary_path)),
      (ConvertTo-Issue13V5Path (
        [string]$Config.strict_baseline_smoke.path)),
      [StringComparison]::OrdinalIgnoreCase) -or
      [string]$proof.evidence.source_evidence.strict_smoke_summary_sha256 `
        -cne [string]$Config.strict_baseline_smoke.sha256 -or
      -not [string]::Equals(
      (ConvertTo-Issue13V5Path (
        [string]$proof.evidence.source_evidence.oracle_smoke_summary_path)),
      (ConvertTo-Issue13V5Path $oracleSmokePath),
      [StringComparison]::OrdinalIgnoreCase) -or
      [string]$proof.evidence.source_evidence.oracle_smoke_summary_sha256 `
        -cne [string]$oracle.oracle_smoke.sha256) {
    throw 'Oracle-effect proof is not bound to both authenticated smoke summaries.'
  }
  if (-not [string]::Equals(
      (ConvertTo-Issue13V5Path ([string]$proof.evidence.spec.path)),
      (ConvertTo-Issue13V5Path ([string]$specTool[0].path)),
      [StringComparison]::OrdinalIgnoreCase) -or
      [string]$proof.evidence.spec.sha256 -cne [string]$specTool[0].sha256 -or
      [string]$proof.evidence.spec.schema -cne
        'wlv-issue13-v5-oracle-effect-spec/2' -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$proof.evidence.proof_schema.path)),
        (ConvertTo-Issue13V5Path ([string]$schemaTool[0].path)),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$proof.evidence.proof_schema.sha256 -cne
        [string]$schemaTool[0].sha256 -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$proof.evidence.oracle.patch_path)),
        (ConvertTo-Issue13V5Path ([string]$Config.baseline_overlay.path)),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$proof.evidence.oracle.patch_sha256 -cne
        [string]$Config.baseline_overlay.sha256 -or
      [string]$proof.evidence.oracle.base_commit -cne
        [string]$Config.baseline_commit -or
      [string]$proof.evidence.oracle.runtime_commit -cne
        [string]$Config.baseline_runtime_commit) {
    throw 'Oracle-effect spec, schema, or authorized oracle binding changed.'
  }
  $workflow = $proof.evidence.comparison_workflow
  $null = Assert-Issue13V5ExactPropertyNames $workflow @(
    'primary_root', 'replay_root', 'generator_created_both_roots', 'methods',
    'commands', 'comparisons'
  ) 'Oracle-effect comparison workflow'
  $commonMethods = @('wiodr13', 'wiodr16', 'wiodr16v09', 'zerodep_1', 'zerodep_2')
  foreach ($commandRecord in @($workflow.commands)) {
    $null = Assert-Issue13V5ExactPropertyNames $commandRecord @(
      'phase', 'method', 'executable', 'arguments', 'working_directory',
      'r_library_environment', 'environment_set', 'environment_cleared',
      'output_directory', 'command_sha256', 'exit_code'
    ) 'Oracle-effect comparison command'
    foreach ($environmentRecord in @($commandRecord.environment_set)) {
      $null = Assert-Issue13V5ExactPropertyNames $environmentRecord @(
        'name', 'value'
      ) 'Oracle-effect command set-environment record'
    }
  }
  $expectedEnvironmentSetJson = $oracle.r_library.environment.set |
    ConvertTo-Json -Depth 5 -Compress
  $expectedClearedEnvironment = [string]::Join(
    "`n", @($oracle.r_library.environment.cleared))
  if (-not [string]::Equals(
      (ConvertTo-Issue13V5Path ([string]$workflow.primary_root)),
      (ConvertTo-Issue13V5Path $primaryRoot),
      [StringComparison]::OrdinalIgnoreCase) -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$workflow.replay_root)),
        (ConvertTo-Issue13V5Path $replayRoot),
        [StringComparison]::OrdinalIgnoreCase) -or
      -not (Test-Issue13V5ExactBoolean $workflow.generator_created_both_roots $true) -or
      [string]::Join("`n", @($workflow.methods)) -cne
        [string]::Join("`n", $commonMethods) -or
      @($workflow.commands).Count -ne 10 -or
      @($workflow.commands | Where-Object {
        @($_.arguments).Count -ne 9 -or
        [string]$_.arguments[0] -cne '--vanilla' -or
        -not [string]::Equals(
          (ConvertTo-Issue13V5Path ([string]$_.executable)),
          (ConvertTo-Issue13V5Path $rscriptPath),
          [StringComparison]::OrdinalIgnoreCase) -or
        -not [string]::Equals(
          (ConvertTo-Issue13V5Path ([string]$_.working_directory)),
          (ConvertTo-Issue13V5Path (
            (Join-Path (Split-Path -Parent $comparisonHarness) `
              'issue13-evidence-harness'))),
          [StringComparison]::OrdinalIgnoreCase) -or
        [string]$_.r_library_environment.name -cne 'R_LIBS_USER' -or
        -not [string]::Equals(
          (ConvertTo-Issue13V5Path (
            [string]$_.r_library_environment.value)),
          (ConvertTo-Issue13V5Path $rLibraryPath),
          [StringComparison]::OrdinalIgnoreCase) -or
        ($_.environment_set | ConvertTo-Json -Depth 5 -Compress) -cne
          $expectedEnvironmentSetJson -or
        [string]::Join("`n", @($_.environment_cleared)) -cne
          $expectedClearedEnvironment
      }).Count -ne 0 -or
      @($workflow.comparisons).Count -ne 5 -or
      @($workflow.comparisons | Where-Object {
        [string]$_.comparison_mode -cne 'strict' -or
        @($_.files).Count -ne 4 -or
        @($_.files | Where-Object {
          -not (Test-Issue13V5ExactBoolean $_.normalized_identical $true)
        }).Count `
          -ne 0
      }).Count -ne 0 -or
      @($proof.evidence.approved_run_immutability).Count -ne 17 -or
      @($proof.evidence.approved_run_immutability | Where-Object {
        -not (Test-Issue13V5ExactBoolean $_.immutable $true)
      }).Count -ne 0 -or
      @($proof.evidence.recovered_methods).Count -ne 7) {
    throw 'Oracle-effect primary/replay, 10-execution, 17-run, or 5+7 binding changed.'
  }
  $primaryInventory = Get-Issue13V5TreeInventory $primaryRoot
  $replayInventory = Get-Issue13V5TreeInventory $replayRoot
  $null = Assert-Issue13V5InventoryBinding $oracle.comparisons.primary.inventory `
    $primaryInventory 'Oracle-effect primary comparison'
  $null = Assert-Issue13V5InventoryBinding $oracle.comparisons.replay.inventory `
    $replayInventory 'Oracle-effect replay comparison'
  $null = Assert-Issue13V5ExactPropertyNames $oracle.comparisons @(
    'primary', 'replay', 'inventory'
  ) 'Oracle-effect comparison pair binding'
  $null = Assert-Issue13V5ExactPropertyNames $oracle.comparisons.inventory @(
    'schema', 'primary_inventory_sha256', 'replay_inventory_sha256',
    'inventory_sha256'
  ) 'Oracle-effect comparison pair inventory'
  $pairInventoryPayload = [string]::Join("`n", @(
    'wlv-issue13-v5-oracle-effect-comparison-pair-inventory/1',
    'primary|' + (ConvertTo-Issue13V5Path $primaryRoot) + '|' +
      [string]$primaryInventory.inventory_sha256,
    'replay|' + (ConvertTo-Issue13V5Path $replayRoot) + '|' +
      [string]$replayInventory.inventory_sha256
  ))
  if ([string]$oracle.comparisons.inventory.schema -cne
        'wlv-issue13-v5-oracle-effect-comparison-pair-inventory/1' -or
      [string]$oracle.comparisons.inventory.primary_inventory_sha256 -cne
        [string]$primaryInventory.inventory_sha256 -or
      [string]$oracle.comparisons.inventory.replay_inventory_sha256 -cne
        [string]$replayInventory.inventory_sha256 -or
      [string]$oracle.comparisons.inventory.inventory_sha256 -cne
        (Get-Issue13V5TextSha256 $pairInventoryPayload)) {
    throw 'Oracle-effect combined primary/replay inventory changed.'
  }
  $harnessInventory = Get-Issue13V5HarnessInventory (
    Split-Path -Parent $comparisonHarness)
  if ([int64]$harnessInventory.file_count -ne
        $script:Issue13V5HarnessFileCount -or
      [int64]$harnessInventory.total_bytes -ne
        $script:Issue13V5HarnessTotalBytes -or
      [string]$harnessInventory.inventory_sha256 -cne
        $script:Issue13V5HarnessInventorySha256) {
    throw 'Oracle-effect harness differs from the external terminal inventory pin.'
  }
  $proofHarness = $proof.evidence.terminal_runtime.comparison_harness
  foreach ($field in @('file_count', 'total_bytes', 'inventory_sha256')) {
    if ([string]$oracle.comparison_harness.output_tooling.$field -cne
          [string]$harnessInventory.$field -or
        [string]$oracle.comparison_harness.sealed_output_tooling.$field -cne
          [string]$harnessInventory.$field -or
        [string]$oracle.comparison_harness.installed_inventory.$field -cne
          [string]$harnessInventory.$field -or
        [string]$proofHarness.output_tooling.$field -cne
          [string]$harnessInventory.$field -or
        [string]$proofHarness.sealed_output_tooling.$field -cne
          [string]$harnessInventory.$field -or
        [string]$proofHarness.installed_inventory.$field -cne
          [string]$harnessInventory.$field) {
      throw "Oracle-effect terminal harness inventory changed: $field"
    }
  }
  $proofRLibraryJson = $proof.evidence.terminal_runtime.r_library |
    ConvertTo-Json -Depth 20 -Compress
  $configRLibraryJson = $oracle.r_library |
    ConvertTo-Json -Depth 20 -Compress
  if ([string]$proofHarness.expected_candidate_commit -cne
        [string]$Config.candidate_commit -or
      [string]$proofHarness.source_controller_commit_sha256 -cne
        [string]$Config.candidate_commit -or
      [string]$proofHarness.generation -cne 'v5-terminal' -or
      -not (Test-Issue13V5ExactBoolean $proofHarness.final_evidence_eligible $true) -or
      -not (Test-Issue13V5ExactBoolean $proofHarness.reuses_candidate_evidence $false) -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$proofHarness.manifest_path)),
        (ConvertTo-Issue13V5Path $comparisonHarness),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$proofHarness.manifest_sha256 -cne
        [string]$oracle.comparison_harness.manifest_sha256 -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path (
          [string]$oracle.comparison_harness.installed_inventory.root)),
        (ConvertTo-Issue13V5Path (Split-Path -Parent $comparisonHarness)),
        [StringComparison]::OrdinalIgnoreCase) -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path (
          [string]$oracle.comparison_harness.installed_inventory.harness_root)),
        (ConvertTo-Issue13V5Path (
          (Join-Path (Split-Path -Parent $comparisonHarness) `
            'issue13-evidence-harness'))),
        [StringComparison]::OrdinalIgnoreCase) -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path (
          [string]$proofHarness.installed_inventory.root)),
        (ConvertTo-Issue13V5Path (Split-Path -Parent $comparisonHarness)),
        [StringComparison]::OrdinalIgnoreCase) -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path (
          [string]$proofHarness.installed_inventory.harness_root)),
        (ConvertTo-Issue13V5Path (
          (Join-Path (Split-Path -Parent $comparisonHarness) `
            'issue13-evidence-harness'))),
        [StringComparison]::OrdinalIgnoreCase) -or
      @($proofHarness.installed_inventory.records).Count -ne
        [long]$harnessInventory.file_count -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path (
          [string]$proof.evidence.terminal_runtime.rscript.logical_path)),
        (ConvertTo-Issue13V5Path $rscriptPath),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$proof.evidence.terminal_runtime.rscript.sha256 -cne
        $script:Issue13V5RscriptSha256 -or
      [int64]$proof.evidence.terminal_runtime.rscript.size_bytes -ne
        94720L -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path (
          [string]$proof.evidence.terminal_runtime.r_library.path)),
        (ConvertTo-Issue13V5Path $rLibraryPath),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$proof.evidence.terminal_runtime.r_library.environment_variable `
        -cne 'R_LIBS_USER' -or
      $proofRLibraryJson -cne $configRLibraryJson) {
    throw 'Oracle-effect terminal harness/R runtime proof binding changed.'
  }
  [pscustomobject][ordered]@{
    proof = $proof
    proof_path = $proofPath
    primary_root = $primaryRoot
    primary_inventory = $primaryInventory
    replay_root = $replayRoot
    replay_inventory = $replayInventory
    harness_inventory = $harnessInventory
    source_controller = $expectedController
    r_runtime = $oracle.r_library
    tooling = $expectedTools
  }
}

function Invoke-Issue13V5OracleEffectValidation([object]$Config) {
  $bindings = Assert-Issue13V5OracleEffectBindings $Config
  $oracle = $Config.oracle_effect
  $validator = @($bindings.tooling | Where-Object {
    [string]$_.name -ceq 'issue13-v5-oracle-effect-validate.ps1'
  })
  $spec = @($bindings.tooling | Where-Object {
    [string]$_.name -ceq 'issue13-v5-oracle-effect-spec.json'
  })
  $schema = @($bindings.tooling | Where-Object {
    [string]$_.name -ceq 'issue13-v5-oracle-effect-proof.schema.json'
  })
  if ($validator.Count -ne 1 -or $spec.Count -ne 1 -or $schema.Count -ne 1) {
    throw 'Oracle-effect validator/spec/schema tooling is ambiguous.'
  }
  $arguments = @(
    '-NoLogo', '-NoProfile', '-File', [string]$validator[0].path,
    '-RepositoryRoot', [string]$Config.repository_root,
    '-ExpectedCandidateCommit', [string]$Config.candidate_commit,
    '-SpecPath', [string]$spec[0].path,
    '-SchemaPath', [string]$schema[0].path,
    '-StrictSmokeSummary', [string]$Config.strict_baseline_smoke.path,
    '-OracleSmokeSummary', [string]$oracle.oracle_smoke.path,
    '-OraclePatch', [string]$Config.baseline_overlay.path,
    '-ComparisonHarnessManifest',
      [string]$Config.harness_manifest_path,
    '-Rscript', [string]$Config.rscript,
    '-RLibrary', [string]$Config.r_library,
    '-ComparisonRoot', [string]$oracle.comparisons.primary.root,
    '-ReplayRoot', [string]$oracle.comparisons.replay.root,
    '-ProofPath', [string]$oracle.proof.path
  )
  $validationExecution = Invoke-Issue13V5PwshTransient `
    -Arguments $arguments `
    -Label 'oracle-effect-validation' `
    -TimeoutSeconds 1800 `
    -ExpectedExitCodes @(0) `
    -WorkingDirectory ([string]$Config.repository_root) `
    -RscriptPath ([string]$Config.rscript)
  $outputText = [string]$validationExecution.stdout
  $commandRecord = $validationExecution.command_record
  try {
    $result = $outputText | ConvertFrom-Json -DateKind String
  } catch {
    throw "Oracle-effect validator returned invalid JSON: $($_.Exception.Message)"
  }
  $null = Assert-Issue13V5ExactPropertyNames $result @(
    'schema', 'status', 'passed', 'proof_path', 'proof_sha256',
    'strict_common_comparison_count', 'comparison_execution_count',
    'approved_run_inventory_count', 'recovered_method_count',
    'source_controller_inventory_sha256', 'r_runtime_inventory_sha256',
    'oracle_effect_closed', 'final_v5_gate_substituted'
  ) 'Oracle-effect validator result'
  if ([string]$result.schema -cne
        'wlv-issue13-v5-oracle-effect-validation/2' -or
      [string]$result.status -cne 'passed' -or
      -not (Test-Issue13V5ExactBoolean $result.passed $true) -or
      (Get-Issue13V5Sha256 ([string]$result.proof_path)) -cne
        [string]$result.proof_sha256 -or
      [string]$result.proof_sha256 -cne [string]$oracle.proof.sha256 -or
      [long]$result.strict_common_comparison_count -ne 5L -or
      [long]$result.comparison_execution_count -ne 10L -or
      [long]$result.approved_run_inventory_count -ne 17L -or
      [long]$result.recovered_method_count -ne 7L -or
      [string]$result.source_controller_inventory_sha256 -cne
        [string]$oracle.comparison_harness.source_controller.inventory_sha256 -or
      [string]$result.r_runtime_inventory_sha256 -cne
        [string]$oracle.r_library.inventory_sha256 -or
      -not (Test-Issue13V5ExactBoolean $result.oracle_effect_closed $true) -or
      -not (Test-Issue13V5ExactBoolean $result.final_v5_gate_substituted $false)) {
    throw 'Oracle-effect validator returned a forged or incomplete result.'
  }
  $after = Assert-Issue13V5OracleEffectBindings $Config
  [pscustomobject][ordered]@{
    schema = 'wlv-issue13-v5-oracle-effect-validation-record/2'
    status = 'passed'
    passed = $true
    final_evidence_eligible = $false
    required_by_final_gate = $true
    strict_common_comparison_count = 5L
    comparison_execution_count = 10L
    approved_run_inventory_count = 17L
    recovered_method_count = 7L
    source_controller_inventory_sha256 =
      [string]$result.source_controller_inventory_sha256
    r_runtime_inventory_sha256 = [string]$result.r_runtime_inventory_sha256
    oracle_effect_closed = $true
    final_v5_gate_substituted = $false
    proof_sha256 = [string]$result.proof_sha256
    primary_comparison_inventory_sha256 =
      [string]$after.primary_inventory.inventory_sha256
    replay_comparison_inventory_sha256 =
      [string]$after.replay_inventory.inventory_sha256
    comparison_harness_manifest_sha256 =
      [string]$oracle.comparison_harness.manifest_sha256
    comparison_harness_inventory_sha256 =
      [string]$after.harness_inventory.inventory_sha256
    expected_candidate_commit = [string]$Config.candidate_commit
    rscript_sha256 = [string]$Config.strict_baseline_smoke.rscript_sha256
    r_library_path = [string]$oracle.r_library.path
    authorized_patch_sha256 = $script:Issue13V5BaselineOverlaySha256
    authorized_patch_id = $script:Issue13V5BaselineOverlayPatchId
    command = [pscustomobject][ordered]@{
      executable = [string]$commandRecord.executable
      arguments = [object[]]$commandRecord.arguments
      working_directory = [string]$commandRecord.working_directory
      exit_code = [long]$commandRecord.exit_code
      stdout_sha256 = Get-Issue13V5TextSha256 $outputText
    }
  }
}

function New-Issue13V5OracleEffectControlRecord(
  [object]$Config,
  [string]$ConfigSha256,
  [object]$Validation
) {
  [pscustomobject][ordered]@{
    schema = 'wlv-issue13-v5-oracle-effect-control/2'
    status = 'passed'
    passed = $true
    final_evidence_eligible = $false
    required_by_final_gate = $true
    config_sha256 = $ConfigSha256
    baseline_commit = [string]$Config.baseline_commit
    baseline_runtime_commit = [string]$Config.baseline_runtime_commit
    candidate_commit = [string]$Config.candidate_commit
    proof = $Config.oracle_effect.proof
    oracle_smoke = $Config.oracle_effect.oracle_smoke
    comparisons = $Config.oracle_effect.comparisons
    comparison_harness = $Config.oracle_effect.comparison_harness
    r_library = $Config.oracle_effect.r_library
    authorized_patch_sha256 = [string]$Config.baseline_overlay.sha256
    authorized_patch_id = [string]$Config.baseline_overlay.patch_id
    validation = $Validation
  }
}

function Assert-Issue13V5OracleEffectControlRecord(
  [object]$Config,
  [object]$State,
  [object]$FreshValidation = $null
) {
  $null = Assert-Issue13V5OracleEffectBindings $Config
  $expectedPath = ConvertTo-Issue13V5Path (
    Join-Path ([string]$Config.control_root) 'oracle-effect-validation.json')
  $null = Assert-Issue13V5ExactPropertyNames $State.oracle_effect @(
    'status', 'control_record_path', 'control_record_sha256', 'proof_sha256',
    'comparison_inventory_sha256', 'strict_common_method_count',
    'recovered_method_count', 'final_evidence_eligible', 'required_by_final_gate'
  ) 'Oracle-effect state binding'
  if ([string]$State.oracle_effect.status -cne 'authenticated' -or
      [string]$State.oracle_effect.control_record_sha256 -cnotmatch
        '^[0-9a-f]{64}$' -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path (
          [string]$State.oracle_effect.control_record_path)),
        $expectedPath, [StringComparison]::OrdinalIgnoreCase) -or
      -not (Test-Path -LiteralPath $expectedPath -PathType Leaf) -or
      (Get-Issue13V5Sha256 $expectedPath) -cne
        [string]$State.oracle_effect.control_record_sha256 -or
      [string]$State.oracle_effect.proof_sha256 -cne
        [string]$Config.oracle_effect.proof.sha256 -or
      [string]$State.oracle_effect.comparison_inventory_sha256 -cne
        [string]$Config.oracle_effect.comparisons.inventory.inventory_sha256 -or
      [long]$State.oracle_effect.strict_common_method_count -ne 5L -or
      [long]$State.oracle_effect.recovered_method_count -ne 7L -or
      -not (Test-Issue13V5ExactBoolean $State.oracle_effect.final_evidence_eligible $false) -or
      -not (Test-Issue13V5ExactBoolean $State.oracle_effect.required_by_final_gate $true)) {
    throw 'Oracle-effect state/control binding is missing or changed.'
  }
  $record = Read-Issue13V5Json $expectedPath
  $null = Assert-Issue13V5ExactPropertyNames $record @(
    'schema', 'status', 'passed', 'final_evidence_eligible',
    'required_by_final_gate', 'config_sha256', 'baseline_commit',
    'baseline_runtime_commit', 'candidate_commit', 'proof', 'oracle_smoke',
    'comparisons', 'comparison_harness', 'r_library',
    'authorized_patch_sha256', 'authorized_patch_id', 'validation'
  ) 'Oracle-effect control record'
  $null = Assert-Issue13V5ExactPropertyNames $record.validation @(
    'schema', 'status', 'passed', 'final_evidence_eligible',
    'required_by_final_gate', 'strict_common_comparison_count',
    'comparison_execution_count', 'approved_run_inventory_count',
    'recovered_method_count', 'source_controller_inventory_sha256',
    'r_runtime_inventory_sha256', 'oracle_effect_closed',
    'final_v5_gate_substituted', 'proof_sha256',
    'primary_comparison_inventory_sha256',
    'replay_comparison_inventory_sha256',
    'comparison_harness_manifest_sha256',
    'comparison_harness_inventory_sha256', 'expected_candidate_commit',
    'rscript_sha256', 'r_library_path', 'authorized_patch_sha256',
    'authorized_patch_id', 'command'
  ) 'Oracle-effect validation record'
  $null = Assert-Issue13V5ExactPropertyNames $record.validation.command @(
    'executable', 'arguments', 'working_directory', 'exit_code',
    'stdout_sha256'
  ) 'Oracle-effect validation command'
  if ([string]$record.schema -cne
        'wlv-issue13-v5-oracle-effect-control/2' -or
      [string]$record.status -cne 'passed' -or
      -not (Test-Issue13V5ExactBoolean $record.passed $true) -or
      -not (Test-Issue13V5ExactBoolean $record.final_evidence_eligible $false) -or
      -not (Test-Issue13V5ExactBoolean $record.required_by_final_gate $true) -or
      [string]$record.config_sha256 -cne [string]$State.config_sha256 -or
      [string]$record.baseline_commit -cne
        [string]$Config.baseline_commit -or
      [string]$record.baseline_runtime_commit -cne
        [string]$Config.baseline_runtime_commit -or
      [string]$record.candidate_commit -cne
        [string]$Config.candidate_commit -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$record.proof.path)),
        (ConvertTo-Issue13V5Path ([string]$Config.oracle_effect.proof.path)),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$record.proof.sha256 -cne
        [string]$Config.oracle_effect.proof.sha256 -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$record.oracle_smoke.path)),
        (ConvertTo-Issue13V5Path (
          [string]$Config.oracle_effect.oracle_smoke.path)),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$record.oracle_smoke.sha256 -cne
        [string]$Config.oracle_effect.oracle_smoke.sha256 -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path (
          [string]$record.comparisons.primary.root)),
        (ConvertTo-Issue13V5Path (
          [string]$Config.oracle_effect.comparisons.primary.root)),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$record.comparisons.primary.inventory.inventory_sha256 -cne
        [string]$Config.oracle_effect.comparisons.primary.inventory.
          inventory_sha256 -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path (
          [string]$record.comparisons.replay.root)),
        (ConvertTo-Issue13V5Path (
          [string]$Config.oracle_effect.comparisons.replay.root)),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$record.comparisons.replay.inventory.inventory_sha256 -cne
        [string]$Config.oracle_effect.comparisons.replay.inventory.
          inventory_sha256 -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path (
          [string]$record.comparison_harness.manifest_path)),
        (ConvertTo-Issue13V5Path ([string]$Config.harness_manifest_path)),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$record.comparison_harness.manifest_sha256 -cne
        [string]$Config.harness_manifest_sha256 -or
      [string]$record.comparison_harness.expected_candidate_commit -cne
        [string]$Config.candidate_commit -or
      ($record.comparison_harness | ConvertTo-Json -Depth 30 -Compress) -cne
        ($Config.oracle_effect.comparison_harness |
          ConvertTo-Json -Depth 30 -Compress) -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$record.r_library.path)),
        (ConvertTo-Issue13V5Path ([string]$Config.r_library)),
        [StringComparison]::OrdinalIgnoreCase) -or
      ($record.r_library | ConvertTo-Json -Depth 30 -Compress) -cne
        ($Config.oracle_effect.r_library | ConvertTo-Json -Depth 30 -Compress) -or
      [string]$record.authorized_patch_sha256 -cne
        $script:Issue13V5BaselineOverlaySha256 -or
      [string]$record.authorized_patch_id -cne
        $script:Issue13V5BaselineOverlayPatchId -or
      [string]$record.validation.schema -cne
        'wlv-issue13-v5-oracle-effect-validation-record/2' -or
      [string]$record.validation.status -cne 'passed' -or
      -not (Test-Issue13V5ExactBoolean $record.validation.passed $true) -or
      -not (Test-Issue13V5ExactBoolean $record.validation.final_evidence_eligible $false) -or
      -not (Test-Issue13V5ExactBoolean $record.validation.required_by_final_gate $true) -or
      [long]$record.validation.strict_common_comparison_count -ne 5L -or
      [long]$record.validation.comparison_execution_count -ne 10L -or
      [long]$record.validation.approved_run_inventory_count -ne 17L -or
      [long]$record.validation.recovered_method_count -ne 7L -or
      [string]$record.validation.source_controller_inventory_sha256 -cne
        [string]$Config.oracle_effect.comparison_harness.source_controller.
          inventory_sha256 -or
      [string]$record.validation.r_runtime_inventory_sha256 -cne
        [string]$Config.oracle_effect.r_library.inventory_sha256 -or
      -not (Test-Issue13V5ExactBoolean $record.validation.oracle_effect_closed $true) -or
      -not (Test-Issue13V5ExactBoolean $record.validation.final_v5_gate_substituted $false) -or
      [string]$record.validation.proof_sha256 -cne
        [string]$Config.oracle_effect.proof.sha256 -or
      [string]$record.validation.primary_comparison_inventory_sha256 -cne
        [string]$Config.oracle_effect.comparisons.primary.inventory.
          inventory_sha256 -or
      [string]$record.validation.replay_comparison_inventory_sha256 -cne
        [string]$Config.oracle_effect.comparisons.replay.inventory.
          inventory_sha256 -or
      [string]$record.validation.comparison_harness_manifest_sha256 -cne
        [string]$Config.oracle_effect.comparison_harness.manifest_sha256 -or
      [string]$record.validation.comparison_harness_inventory_sha256 -cne
        [string]$Config.oracle_effect.comparison_harness.installed_inventory.
          inventory_sha256 -or
      [string]$record.validation.expected_candidate_commit -cne
        [string]$Config.candidate_commit -or
      [string]$record.validation.rscript_sha256 -cne
        [string]$Config.strict_baseline_smoke.rscript_sha256 -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$record.validation.r_library_path)),
        (ConvertTo-Issue13V5Path ([string]$Config.r_library)),
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$record.validation.authorized_patch_sha256 -cne
        $script:Issue13V5BaselineOverlaySha256 -or
      [string]$record.validation.authorized_patch_id -cne
        $script:Issue13V5BaselineOverlayPatchId -or
      [long]$record.validation.command.exit_code -ne 0L -or
      [string]$record.validation.command.stdout_sha256 -cnotmatch
        '^[0-9a-f]{64}$') {
    throw 'Oracle-effect control record is forged or incomplete.'
  }
  if ($null -ne $FreshValidation) {
    foreach ($field in @(
        'schema', 'status', 'passed', 'final_evidence_eligible',
        'required_by_final_gate', 'strict_common_comparison_count',
        'comparison_execution_count', 'approved_run_inventory_count',
        'recovered_method_count', 'source_controller_inventory_sha256',
        'r_runtime_inventory_sha256', 'oracle_effect_closed',
        'final_v5_gate_substituted', 'proof_sha256',
        'primary_comparison_inventory_sha256',
        'replay_comparison_inventory_sha256',
        'comparison_harness_manifest_sha256',
        'comparison_harness_inventory_sha256', 'expected_candidate_commit',
        'rscript_sha256', 'r_library_path', 'authorized_patch_sha256',
        'authorized_patch_id')) {
      if ([string]$record.validation.$field -cne
          [string]$FreshValidation.$field) {
        throw "Oracle-effect closing validation changed: $field"
      }
    }
    foreach ($field in @(
        'executable', 'working_directory', 'exit_code', 'stdout_sha256')) {
      if ([string]$record.validation.command.$field -cne
          [string]$FreshValidation.command.$field) {
        throw "Oracle-effect closing command changed: $field"
      }
    }
    if ([string]::Join("`n", @($record.validation.command.arguments)) -cne
        [string]::Join("`n", @($FreshValidation.command.arguments))) {
      throw 'Oracle-effect closing command arguments changed.'
    }
  }
  $record
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
      $blob = (Invoke-Issue13V5SealedGit `
        -C ([string]$Config.repository_root) rev-parse `
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

function Assert-Issue13V5PhysicalCopy(
  [string]$SourceRoot,
  [string]$DestinationRoot,
  [object]$Inventory
) {
  $sourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path.TrimEnd('\')
  $destinationRoot = (Resolve-Path -LiteralPath $DestinationRoot).Path.
    TrimEnd('\')
  $null = ConvertTo-Issue13V5PhysicalPath `
    $sourceRoot 'Physical-copy source root'
  $null = ConvertTo-Issue13V5PhysicalPath `
    $destinationRoot 'Physical-copy destination root'
  Assert-Issue13V5NoReparse $sourceRoot
  Assert-Issue13V5NoReparse $destinationRoot
  Assert-Issue13V5PathsDisjoint `
    $sourceRoot $destinationRoot 'Physical-copy roots'
  $records = @($Inventory.records)
  if ($records.Count -ne [long]$Inventory.file_count -or
      $records.Count -eq 0) {
    throw 'Physical-copy inventory has invalid file coverage.'
  }
  $seen = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal)
  foreach ($record in $records) {
    $relative = [string]$record.relative_path
    if ([string]::IsNullOrWhiteSpace($relative) -or
        [IO.Path]::IsPathRooted($relative) -or
        $relative -match '(^|[/\\])[.][.]($|[/\\])' -or
        -not $seen.Add($relative)) {
      throw "Physical-copy inventory path is invalid: $relative"
    }
    $source = Join-Path $sourceRoot $relative.Replace('/', '\')
    $destination = Join-Path $destinationRoot $relative.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or
        -not (Test-Path -LiteralPath $destination -PathType Leaf)) {
      throw "Physical-copy file is missing: $relative"
    }
    $sourceIdentity = Get-Issue13V5PhysicalItemIdentity `
      $source "Physical-copy source file $relative"
    $destinationIdentity = Get-Issue13V5PhysicalItemIdentity `
      $destination "Physical-copy destination file $relative"
    if ($sourceIdentity.item_id -ceq $destinationIdentity.item_id) {
      throw "Source and destination share a physical file: $relative"
    }
    if ($destinationIdentity.link_count -ne 1L) {
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

function Invoke-Issue13V5GitRaw(
  [string]$Repository,
  [string[]]$Arguments,
  [int]$TimeoutSeconds = 120
) {
  if ($TimeoutSeconds -le 0 -or $TimeoutSeconds -gt 2147483) {
    throw 'Git timeout must be between 1 and 2147483 seconds.'
  }
  $lease = Enter-Issue13V5GitExecutableLease
  $binding = $lease.binding
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = [string]$binding.logical_path
  $start.WorkingDirectory = $Repository
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  foreach ($argument in @($Arguments)) {
    $start.ArgumentList.Add([string]$argument)
  }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $start
  $stdout = [IO.MemoryStream]::new()
  $stderr = [IO.MemoryStream]::new()
  $stdoutTask = $null
  $stderrTask = $null
  $outputTasks = [Collections.Generic.List[Threading.Tasks.Task]]::new()
  $processStarted = $false
  $primary = $null
  $result = $null
  try {
    if (-not $process.Start()) {
      throw 'Cannot start sealed Git for V5 source authentication.'
    }
    $processStarted = $true
    $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
    $outputTasks.Add($stdoutTask)
    $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderr)
    $outputTasks.Add($stderrTask)
    $timeoutMilliseconds = [int]([int64]$TimeoutSeconds * 1000L)
    if (-not $process.WaitForExit($timeoutMilliseconds)) {
      throw "Sealed Git exceeded its $TimeoutSeconds-second timeout."
    }
    if (-not [Threading.Tasks.Task]::WaitAll(
        [Threading.Tasks.Task[]]$outputTasks.ToArray(), 30000)) {
      throw 'Sealed Git output streams did not close within 30 seconds.'
    }
    $stderrBytes = [byte[]]$stderr.ToArray()
    $stderrText = if ($stderrBytes.Length -eq 0) { '' } else {
      [Text.UTF8Encoding]::new($false, $true).GetString($stderrBytes)
    }
    if ($process.ExitCode -ne 0) {
      throw "Git source authentication failed ($($process.ExitCode)): $stderrText"
    }
    $result = [pscustomobject][ordered]@{
      stdout = [byte[]]$stdout.ToArray()
      stderr = $stderrText
    }
  } catch {
    $primary = $_
  }
  $cleanupFailures = [Collections.Generic.List[Exception]]::new()
  if ($processStarted) {
    try {
      Stop-Issue13V5ExternalProcess $process
    } catch {
      $cleanupFailures.Add($_.Exception)
    }
  }
  if ($outputTasks.Count -ne 0) {
    try {
      if (-not [Threading.Tasks.Task]::WaitAll(
          [Threading.Tasks.Task[]]$outputTasks.ToArray(), 30000)) {
        throw 'Sealed Git output tasks remained active after bounded cleanup.'
      }
    } catch {
      $cleanupFailures.Add($_.Exception)
    }
  }
  try {
    $null = Assert-Issue13V5GitExecutableBinding $binding
  } catch {
    $cleanupFailures.Add($_.Exception)
  }
  try {
    $lease.handle.Dispose()
  } catch {
    $cleanupFailures.Add($_.Exception)
  }
  try {
    $stdout.Dispose()
  } catch {
    $cleanupFailures.Add($_.Exception)
  }
  try {
    $stderr.Dispose()
  } catch {
    $cleanupFailures.Add($_.Exception)
  }
  try {
    $process.Dispose()
  } catch {
    $cleanupFailures.Add($_.Exception)
  }
  if ($cleanupFailures.Count -ne 0) {
    $failures = [Collections.Generic.List[Exception]]::new()
    if ($null -ne $primary) { $failures.Add($primary.Exception) }
    foreach ($failure in $cleanupFailures) { $failures.Add($failure) }
    throw [AggregateException]::new(
      'Sealed Git lifecycle cleanup failed.', $failures.ToArray())
  }
  if ($null -ne $primary) { throw $primary }
  $result
}

function Get-Issue13V5GitLine(
  [string]$Repository,
  [string[]]$Arguments,
  [string]$Label
) {
  $raw = Invoke-Issue13V5GitRaw $Repository $Arguments
  $value = [Text.UTF8Encoding]::new($false, $true).GetString(
    [byte[]]$raw.stdout).TrimEnd("`r", "`n")
  if ([string]::IsNullOrWhiteSpace($value) -or
      $value.Contains("`r") -or $value.Contains("`n")) {
    throw "$Label did not produce exactly one nonempty line."
  }
  $value
}

function ConvertFrom-Issue13V5GitTreeBytes(
  [byte[]]$Bytes,
  [string]$Label
) {
  if ($Bytes.Length -eq 0 -or $Bytes[$Bytes.Length - 1] -ne 0) {
    throw "$Label is not a nonempty NUL-terminated Git listing."
  }
  $utf8Strict = [Text.UTF8Encoding]::new($false, $true)
  $records = [Collections.Generic.List[object]]::new()
  $start = 0
  for ($index = 0; $index -lt $Bytes.Length; $index++) {
    if ($Bytes[$index] -ne 0) { continue }
    if ($index -eq $start) { throw "$Label contains an empty record." }
    $segment = [byte[]]::new($index - $start)
    [Array]::Copy($Bytes, $start, $segment, 0, $segment.Length)
    $text = $utf8Strict.GetString($segment)
    if ($text -cnotmatch
        '^([0-7]{6}) (blob|tree) ([0-9a-f]{40})\t([^\x00]+)$') {
      throw "$Label contains a malformed Git tree record."
    }
    $records.Add([pscustomobject][ordered]@{
        mode = [string]$Matches[1]
        type = [string]$Matches[2]
        object = [string]$Matches[3]
        path = [string]$Matches[4]
      })
    $start = $index + 1
  }
  [object[]]$records.ToArray()
}

function Get-Issue13V5BytesSha256([byte[]]$Bytes) {
  [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($Bytes)
  ).ToLowerInvariant()
}

function Assert-Issue13V5SourceToolingShape(
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
  foreach ($tree in @($Tooling.trees)) {
    $null = Assert-Issue13V5ExactPropertyNames $tree @(
      'relative_path', 'repository_path', 'mode', 'type', 'tree'
    ) "$Label tree"
  }
  foreach ($record in @($Tooling.records)) {
    $null = Assert-Issue13V5ExactPropertyNames $record @(
      'relative_path', 'repository_path', 'size_bytes', 'sha256', 'mode',
      'type', 'blob'
    ) "$Label file"
  }
  $true
}

function Get-Issue13V5SourceToolingBinding(
  [object]$Config
) {
  $repository = (Resolve-Path -LiteralPath (
      [string]$Config.repository_root)).Path.TrimEnd('\')
  $commit = [string]$Config.candidate_commit
  if ($commit -cnotmatch '^[0-9a-f]{40}$') {
    throw 'V5 source tooling requires a lowercase candidate commit.'
  }
  $root = (Resolve-Path -LiteralPath (
      Join-Path $repository (
        $script:Issue13V5SourceToolingRelativeRoot.Replace('/', '\')))).Path
  $null = Assert-Issue13V5NoReparseAncestors $root `
    'Canonical V5 source tooling'
  Assert-Issue13V5NoReparse $root
  $expectedRoot = Join-Path $repository (
    $script:Issue13V5SourceToolingRelativeRoot.Replace('/', '\'))
  if (-not [string]::Equals(
      (ConvertTo-Issue13V5Path $root),
      (ConvertTo-Issue13V5Path $expectedRoot),
      [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Canonical V5 source tooling is outside its repository root.'
  }
  $head = Get-Issue13V5GitLine $repository @('rev-parse', 'HEAD') `
    'Candidate repository HEAD'
  if ($head -cne $commit) {
    throw 'Canonical V5 source tooling is not evaluated at CandidateCommit.'
  }
  $status = Invoke-Issue13V5GitRaw $repository @(
    'status', '--porcelain=v1', '-z', '--untracked-files=all', '--',
    $script:Issue13V5SourceToolingRelativeRoot)
  if ($status.stdout -isnot [byte[]] -or $status.stdout.Length -ne 0) {
    throw 'Canonical V5 source tooling is not completely clean.'
  }
  $directories = @(Get-ChildItem -LiteralPath $root -Directory -Recurse -Force)
  $directoryPaths = [string[]]@($directories | ForEach-Object {
      $_.FullName.Substring($root.Length + 1).Replace('\', '/')
    })
  [Array]::Sort($directoryPaths, [StringComparer]::Ordinal)
  if ($directoryPaths.Count -ne 1 -or
      $directoryPaths[0] -cne 'issue13-evidence-harness') {
    throw 'Canonical V5 source tooling directory topology changed.'
  }
  $localFiles = @(Get-ChildItem -LiteralPath $root -File -Recurse -Force)
  $localPaths = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal)
  foreach ($file in $localFiles) {
    $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
    if (-not $localPaths.Add($relative)) {
      throw "Canonical V5 source tooling path is duplicated: $relative"
    }
  }
  if ($localFiles.Count -ne 37 -or
      $localPaths.Count -ne $script:Issue13V5SourceToolingFiles.Count -or
      @($script:Issue13V5SourceToolingFiles | Where-Object {
          -not $localPaths.Contains([string]$_)
        }).Count -ne 0) {
    throw 'Canonical V5 source tooling file topology changed.'
  }
  $pathPayload = [Text.Encoding]::UTF8.GetBytes(
    [string]::Join("`n", $script:Issue13V5SourceToolingFiles))
  if ((Get-Issue13V5BytesSha256 $pathPayload) -cne
      $script:Issue13V5SourceToolingPathListSha256) {
    throw 'Canonical V5 source-tooling path-list constant changed.'
  }

  $rootListing = @(ConvertFrom-Issue13V5GitTreeBytes (
      (Invoke-Issue13V5GitRaw $repository @(
          'ls-tree', '-z', $commit, '--',
          $script:Issue13V5SourceToolingRelativeRoot)).stdout) `
      'Canonical source root tree')
  if ($rootListing.Count -ne 1 -or
      $rootListing[0].path -cne $script:Issue13V5SourceToolingRelativeRoot -or
      $rootListing[0].mode -cne '040000' -or
      $rootListing[0].type -cne 'tree') {
    throw 'CandidateCommit lacks the canonical source-tooling root tree.'
  }
  $rootEntries = @(ConvertFrom-Issue13V5GitTreeBytes (
      (Invoke-Issue13V5GitRaw $repository @(
          'ls-tree', '-z',
          ($commit + ':' + $script:Issue13V5SourceToolingRelativeRoot))).stdout) `
      'Canonical source top-level tree')
  $harnessEntry = @($rootEntries | Where-Object {
      $_.path -ceq 'issue13-evidence-harness'
    })
  if ($harnessEntry.Count -ne 1 -or
      $harnessEntry[0].mode -cne '040000' -or
      $harnessEntry[0].type -cne 'tree') {
    throw 'CandidateCommit lacks the canonical source harness tree.'
  }
  $harnessEntries = @(ConvertFrom-Issue13V5GitTreeBytes (
      (Invoke-Issue13V5GitRaw $repository @(
          'ls-tree', '-z', ($commit + ':' +
            $script:Issue13V5SourceToolingRelativeRoot +
            '/issue13-evidence-harness'))).stdout) `
      'Canonical source harness tree')
  $gitFiles = [Collections.Generic.Dictionary[string, object]]::new(
    [StringComparer]::Ordinal)
  foreach ($entry in $rootEntries) {
    if ($entry.type -ceq 'tree') { continue }
    $gitFiles.Add([string]$entry.path, $entry)
  }
  foreach ($entry in $harnessEntries) {
    if ($entry.type -cne 'blob') {
      throw 'Canonical source harness contains a nested Git tree.'
    }
    $gitFiles.Add('issue13-evidence-harness/' + [string]$entry.path, $entry)
  }
  if ($rootEntries.Count -ne 6 -or $harnessEntries.Count -ne 32 -or
      $gitFiles.Count -ne 37 -or
      @($script:Issue13V5SourceToolingFiles | Where-Object {
          -not $gitFiles.ContainsKey([string]$_)
        }).Count -ne 0) {
    throw 'CandidateCommit source-tooling topology changed.'
  }
  foreach ($treeObject in @(
      [string]$rootListing[0].object,
      [string]$harnessEntry[0].object)) {
    if ((Get-Issue13V5GitLine $repository @(
          'cat-file', '-t', $treeObject) 'Source-tooling tree type') -cne
        'tree') {
      throw 'A source-tooling tree object is not a Git tree.'
    }
  }

  $records = [Collections.Generic.List[object]]::new()
  foreach ($relative in $script:Issue13V5SourceToolingFiles) {
    $entry = $gitFiles[[string]$relative]
    if ($null -eq $entry -or $entry.mode -cne '100644' -or
        $entry.type -cne 'blob') {
      throw "Canonical source Git mode changed: $relative"
    }
    $repositoryPath = $script:Issue13V5SourceToolingRelativeRoot + '/' +
      [string]$relative
    $path = Join-Path $root ([string]$relative).Replace('/', '\')
    $localBytes = [IO.File]::ReadAllBytes($path)
    $blobBytes = [byte[]](Invoke-Issue13V5GitRaw $repository @(
        'cat-file', 'blob', ($commit + ':' + $repositoryPath))).stdout
    if (-not [Collections.StructuralComparisons]::StructuralEqualityComparer.
        Equals($localBytes, $blobBytes)) {
      throw "Canonical source bytes differ from CandidateCommit: $relative"
    }
    $localBlob = Get-Issue13V5GitLine $repository @(
      'hash-object', '--no-filters', '--', $repositoryPath) `
      "Canonical source hash-object $relative"
    if ($localBlob -cne [string]$entry.object) {
      throw "Canonical source blob differs from CandidateCommit: $relative"
    }
    $records.Add([pscustomobject][ordered]@{
        relative_path = [string]$relative
        repository_path = $repositoryPath
        size_bytes = [long]$localBytes.LongLength
        sha256 = Get-Issue13V5BytesSha256 $localBytes
        mode = [string]$entry.mode
        type = [string]$entry.type
        blob = [string]$entry.object
      })
  }
  $inventoryLines = @($records | ForEach-Object {
      [string]$_.relative_path + '|' + [string]$_.size_bytes + '|' +
        [string]$_.sha256
    })
  $result = [pscustomobject][ordered]@{
    candidate_commit = $commit
    repository_relative_root = $script:Issue13V5SourceToolingRelativeRoot
    root = $root
    physical_root = ConvertTo-Issue13V5PhysicalPath $root `
      'Canonical V5 source tooling'
    file_count = [long]$records.Count
    directory_count = 1L
    total_bytes = [long](($records | Measure-Object size_bytes -Sum).Sum)
    path_list_sha256 = $script:Issue13V5SourceToolingPathListSha256
    inventory_sha256 = Get-Issue13V5TextSha256 (
      [string]::Join("`n", $inventoryLines))
    trees = [object[]]@(
      [pscustomobject][ordered]@{
        relative_path = '.'
        repository_path = $script:Issue13V5SourceToolingRelativeRoot
        mode = [string]$rootListing[0].mode
        type = [string]$rootListing[0].type
        tree = [string]$rootListing[0].object
      },
      [pscustomobject][ordered]@{
        relative_path = 'issue13-evidence-harness'
        repository_path = $script:Issue13V5SourceToolingRelativeRoot +
          '/issue13-evidence-harness'
        mode = [string]$harnessEntry[0].mode
        type = [string]$harnessEntry[0].type
        tree = [string]$harnessEntry[0].object
      }
    )
    records = [object[]]$records.ToArray()
  }
  $null = Assert-Issue13V5SourceToolingShape $result `
    'Derived source tooling'
  $result
}

function Assert-Issue13V5HarnessBinding([object]$Config) {
  $sourceToolingBefore = Get-Issue13V5SourceToolingBinding $Config
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
  $null = Assert-Issue13V5SourceToolingShape $manifest.source_tooling `
    'Harness-manifest source tooling'
  if ([string]$manifest.schema -cne
        'wlv-issue13-v5-harness-materialization/1' -or
      [string]$manifest.generation -cne 'v5-terminal' -or
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
      -not (Test-Issue13V5ExactBoolean `
        $manifest.strict_negative_evidence_required $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $manifest.final_evidence_eligible $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $manifest.reuses_candidate_evidence $false) -or
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
  if (($manifest.source_tooling | ConvertTo-Json -Depth 30 -Compress) -cne
      ($sourceToolingBefore | ConvertTo-Json -Depth 30 -Compress)) {
    throw 'Harness manifest source tooling differs from Git-derived source.'
  }
  $controllerPins = @(Get-Issue13V5CoordinatorPins $Config)
  $controllerCount = [long]$script:Issue13V5ControllerFiles.Count
  if ([string]$manifest.source_controller.commit_sha256 -cne
        [string]$Config.candidate_commit -or
      [long]$manifest.source_controller.file_count -ne $controllerCount -or
      @($manifest.source_controller.records).Count -ne $controllerCount -or
      $controllerPins.Count -ne $controllerCount) {
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
  $sourceToolingAfter = Get-Issue13V5SourceToolingBinding $Config
  if (($sourceToolingAfter | ConvertTo-Json -Depth 30 -Compress) -cne
      ($sourceToolingBefore | ConvertTo-Json -Depth 30 -Compress)) {
    throw 'Git-derived V5 source tooling changed during authentication.'
  }
  [pscustomobject][ordered]@{
    manifest = $manifest
    inventory = $inventory
    source_tooling = $sourceToolingBefore
  }
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
    $currentBlob = (Invoke-Issue13V5SealedGit `
      -C $repository hash-object -- $path 2>$null).Trim()
    $committedBlob = (Invoke-Issue13V5SealedGit -C $repository rev-parse `
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
  $summarySha256 = Get-Issue13V5Sha256 $summaryPath
  if (-not [string]::IsNullOrWhiteSpace($ExpectedSummarySha256) -and
      $summarySha256 -cne $ExpectedSummarySha256) {
    throw "Baseline smoke summary seal changed: $summaryPath"
  }
  $summary = Read-Issue13V5Json $summaryPath
  $failedMethods = [string[]]@($ExpectedFailedMethods)
  $strictFailedMethods = [string[]]@(
    'alternative_1', 'alternative_2', 'norow_w13', 'ochoa_1', 'ochoa_2',
    'petrovic', 'wiodr13v09')
  $isHistoricalStrict =
    $summarySha256 -ceq $script:Issue13V5StrictSmokeSha256 -and
    $ExpectedSummarySha256 -ceq $script:Issue13V5StrictSmokeSha256 -and
    $ExpectedPurpose -ceq 'strict-cc2-executability-preflight' -and
    $ExpectedRuntimeCommit -ceq $script:Issue13V5BaselineCommit -and
    $ExpectedHarnessManifestSha256 -ceq
      $script:Issue13V5StrictSmokeHarnessSha256 -and
    (-not $ExpectedPassed) -and
    [string]::Join("`n", $failedMethods) -ceq
      [string]::Join("`n", $strictFailedMethods)
  $isCompatibility = $ExpectedPurpose -ceq
    'compatibility-oracle-executability-preflight'
  $baseSummaryProperties = @(
    'schema', 'status', 'passed', 'final_evidence_eligible', 'purpose',
    'baseline_commit', 'started_at_utc', 'finished_at_utc',
    'source_inventory_sha256', 'harness_manifest_path',
    'harness_manifest_sha256', 'method_count', 'passed_count', 'failed_count',
    'records', 'disposition')
  $rscriptSummaryProperties = @(
    'rscript_path', 'rscript_physical_path', 'rscript_item_id',
    'rscript_link_count', 'rscript_sha256')
  $expectedSummaryProperties = @($baseSummaryProperties)
  if ($isCompatibility) {
    $expectedSummaryProperties += @(
      'baseline_base_commit', 'baseline_runtime_commit',
      'environment_removed')
  }
  if (-not $isHistoricalStrict) {
    $expectedSummaryProperties += $rscriptSummaryProperties
  }
  $null = Assert-Issue13V5ExactPropertyNames $summary `
    $expectedSummaryProperties 'Baseline smoke summary'
  foreach ($record in @($summary.records)) {
    $null = Assert-Issue13V5ExactPropertyNames $record @(
      'method', 'scenario_id', 'status', 'detail', 'project_root',
      'evidence_directory', 'scenario_result_sha256',
      'process_metrics_sha256', 'elapsed_seconds', 'peak_rss_bytes',
      'started_at_utc', 'finished_at_utc'
    ) 'Baseline smoke record'
  }
  $null = Assert-Issue13V5ExactPropertyNames `
    $Config.strict_baseline_smoke @(
      'path', 'sha256', 'passed_count', 'failed_count',
      'final_evidence_eligible', 'rscript_path', 'rscript_physical_path',
      'rscript_item_id', 'rscript_link_count', 'rscript_sha256'
    ) 'Strict baseline-smoke config binding'
  $configuredRscript = (Resolve-Path -LiteralPath (
    [string]$Config.rscript)).Path
  $null = Assert-Issue13V5NoReparseAncestors `
    $configuredRscript 'Baseline smoke Rscript executable'
  $configuredRscriptIdentity = Get-Issue13V5PhysicalItemIdentity `
    $configuredRscript 'Baseline smoke Rscript executable'
  $configuredRscriptSha256 = Get-Issue13V5Sha256 $configuredRscript
  if ([IO.Path]::GetFileName($configuredRscript) -cne 'Rscript.exe' -or
      [uint64]$configuredRscriptIdentity.link_count -ne 1UL -or
      [long](Get-Item -LiteralPath $configuredRscript).Length -ne 94720L -or
      $configuredRscriptSha256 -cne $script:Issue13V5RscriptSha256 -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path (
          [string]$Config.strict_baseline_smoke.rscript_path)),
        (ConvertTo-Issue13V5Path $configuredRscript),
        [StringComparison]::OrdinalIgnoreCase) -or
      -not [string]::Equals(
        [string]$Config.strict_baseline_smoke.rscript_physical_path,
        [string]$configuredRscriptIdentity.physical_path,
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$Config.strict_baseline_smoke.rscript_item_id -cne
        [string]$configuredRscriptIdentity.item_id -or
      [long]$Config.strict_baseline_smoke.rscript_link_count -ne 1L -or
      [string]$Config.strict_baseline_smoke.rscript_sha256 -cne
        $configuredRscriptSha256) {
    throw 'Baseline smoke Rscript binding is stale, aliased, or forged.'
  }
  if (-not $isHistoricalStrict -and (
      -not ($summary.rscript_path -is [string]) -or
      -not ($summary.rscript_physical_path -is [string]) -or
      -not ($summary.rscript_item_id -is [string]) -or
      -not ($summary.rscript_link_count -is [long]) -or
      -not ($summary.rscript_sha256 -is [string]) -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$summary.rscript_path)),
        (ConvertTo-Issue13V5Path $configuredRscript),
        [StringComparison]::OrdinalIgnoreCase) -or
      -not [string]::Equals(
        [string]$summary.rscript_physical_path,
        [string]$configuredRscriptIdentity.physical_path,
        [StringComparison]::OrdinalIgnoreCase) -or
      [string]$summary.rscript_item_id -cne
        [string]$configuredRscriptIdentity.item_id -or
      [long]$summary.rscript_link_count -ne 1L -or
      [string]$summary.rscript_sha256 -cne $configuredRscriptSha256)) {
    throw 'Modern baseline smoke omits its exact Rscript identity.'
  }
  $expectedPassedCount = 12L - [long]$failedMethods.Count
  $expectedStatus = if ($ExpectedPassed) { 'passed' } else { 'failed' }
  $expectedTree = (Invoke-Issue13V5SealedGit `
    -C ([string]$Config.repository_root) rev-parse `
    ($ExpectedRuntimeCommit + '^{tree}') 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or $expectedTree -cnotmatch '^[0-9a-f]{40}$') {
    throw "Cannot authenticate smoke runtime tree: $ExpectedRuntimeCommit"
  }
  $baseProperty = $summary.PSObject.Properties['baseline_base_commit']
  $runtimeProperty = $summary.PSObject.Properties['baseline_runtime_commit']
  $removedEnvironmentProperty =
    $summary.PSObject.Properties['environment_removed']
  if ([string]$summary.schema -cne 'wlv-issue13-v5-baseline-smoke/1' -or
      -not (Test-Issue13V5ExactBoolean `
        $summary.final_evidence_eligible $false) -or
      [string]$summary.purpose -cne $ExpectedPurpose -or
      [string]$summary.baseline_commit -cne $script:Issue13V5BaselineCommit -or
      [string]$summary.status -cne $expectedStatus -or
      -not (Test-Issue13V5ExactBoolean `
        $summary.passed $ExpectedPassed) -or
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
  $strictAttemptsBefore = $null
  $strictWorktreesBefore = $null
  $strictHarnessBefore = $null
  $getStrictHarnessBinding = {
    $manifestPath = (Resolve-Path -LiteralPath (
        [string]$summary.harness_manifest_path)).Path
    $runtimeRoot = (Resolve-Path -LiteralPath (
        Split-Path -Parent $manifestPath)).Path
    $null = Assert-Issue13V5NoReparseAncestors $runtimeRoot `
      'Strict historical smoke harness'
    Assert-Issue13V5NoReparse $runtimeRoot
    $manifestDocument = Read-Issue13V5Json $manifestPath
    $null = Assert-Issue13V5ExactPropertyNames $manifestDocument @(
      'schema', 'generation', 'status', 'materialized_at_utc',
      'baseline_commit', 'final_evidence_eligible',
      'reuses_candidate_evidence', 'source_tooling', 'output_tooling',
      'overlays'
    ) 'Strict historical smoke harness manifest'
    $null = Assert-Issue13V5ExactPropertyNames `
      $manifestDocument.source_tooling @(
        'root', 'file_count', 'total_bytes', 'inventory_sha256'
      ) 'Strict historical source-tooling manifest binding'
    $null = Assert-Issue13V5ExactPropertyNames `
      $manifestDocument.output_tooling @(
        'file_count', 'total_bytes', 'inventory_sha256'
      ) 'Strict historical output-tooling manifest binding'
    if ((Get-Issue13V5Sha256 $manifestPath) -cne
          $script:Issue13V5StrictSmokeHarnessSha256 -or
        [string]$manifestDocument.schema -cne
          'wlv-issue13-v5-harness-materialization/1' -or
        [string]$manifestDocument.generation -cne 'v5' -or
        [string]$manifestDocument.status -cne 'materialized' -or
        [string]$manifestDocument.baseline_commit -cne
          $script:Issue13V5BaselineCommit -or
        -not (Test-Issue13V5ExactBoolean `
          $manifestDocument.final_evidence_eligible $true) -or
        -not (Test-Issue13V5ExactBoolean `
          $manifestDocument.reuses_candidate_evidence $false) -or
        [string]::Join("`n", @($manifestDocument.overlays)) -cne
          "strict-baseline-cc2`nauthenticated-candidate-runtime-sidecar" -or
        [long]$manifestDocument.source_tooling.file_count -ne 37L -or
        [long]$manifestDocument.source_tooling.total_bytes -ne 581093L -or
        [string]$manifestDocument.source_tooling.inventory_sha256 -cne
          'f42c94666cd10606176e8fe0f3f2afe9975b58c5b0b914343a267f62724d34f1' -or
        -not [string]::Equals(
          (ConvertTo-Issue13V5Path (
            [string]$manifestDocument.source_tooling.root)),
          (ConvertTo-Issue13V5Path (Join-Path (
              [string]$Config.repository_root) `
            'run_logs\issue13-evidence-runtime-v4')),
          [StringComparison]::OrdinalIgnoreCase) -or
        [long]$manifestDocument.output_tooling.file_count -ne 39L -or
        [long]$manifestDocument.output_tooling.total_bytes -ne 586873L -or
        [string]$manifestDocument.output_tooling.inventory_sha256 -cne
          '7ba02db2ad97cd59bc93405057d5cc127fbefaac0e4e72331c13a10e5f8d495b') {
      throw 'Strict historical harness manifest changed.'
    }
    $rootDirectories = @(Get-ChildItem -LiteralPath $runtimeRoot `
      -Directory -Force)
    $nestedDirectories = @(Get-ChildItem -LiteralPath (
        Join-Path $runtimeRoot 'issue13-evidence-harness') `
      -Directory -Recurse -Force)
    if ($rootDirectories.Count -ne 1 -or
        $rootDirectories[0].Name -cne 'issue13-evidence-harness' -or
        $nestedDirectories.Count -ne 0) {
      throw 'Strict historical harness topology changed.'
    }
    $files = @(Get-ChildItem -LiteralPath $runtimeRoot -File `
      -Recurse -Force | Where-Object {
        -not [string]::Equals($_.FullName, $manifestPath,
          [StringComparison]::OrdinalIgnoreCase)
      })
    $records = @($files | ForEach-Object {
        [pscustomobject][ordered]@{
          relative_path = $_.FullName.Substring($runtimeRoot.Length + 1).
            Replace('\', '/')
          size_bytes = [long]$_.Length
          sha256 = Get-Issue13V5Sha256 $_.FullName
        }
      } | Sort-Object relative_path)
    $pathLines = [string[]]@($records | ForEach-Object relative_path)
    $inventoryLines = [string[]]@($records | ForEach-Object {
        [string]$_.relative_path + '|' + [string]$_.size_bytes + '|' +
          [string]$_.sha256
      })
    $totalBytes = [long](($records | Measure-Object size_bytes -Sum).Sum)
    $pathListSha256 = Get-Issue13V5TextSha256 (
      [string]::Join("`n", $pathLines))
    $inventorySha256 = Get-Issue13V5TextSha256 (
      [string]::Join("`n", $inventoryLines))
    if ($records.Count -ne 39 -or $totalBytes -ne 586873L -or
        $pathListSha256 -cne
          'd6fe55884678c1300f661bd4b1ff1f42694af9d49dabd739fad7630ebfd2b416' -or
        $inventorySha256 -cne
          '7ba02db2ad97cd59bc93405057d5cc127fbefaac0e4e72331c13a10e5f8d495b') {
      throw 'Strict historical harness physical inventory changed.'
    }
    [pscustomobject][ordered]@{
      runtime_root = $runtimeRoot
      physical_runtime_root = ConvertTo-Issue13V5PhysicalPath $runtimeRoot `
        'Strict historical smoke harness'
      manifest_path = $manifestPath
      physical_manifest_path = ConvertTo-Issue13V5PhysicalPath $manifestPath `
        'Strict historical smoke harness manifest'
      manifest_sha256 = Get-Issue13V5Sha256 $manifestPath
      file_count = 39L
      directory_count = 1L
      total_bytes = $totalBytes
      path_list_sha256 = $pathListSha256
      inventory_sha256 = $inventorySha256
      records = [object[]]$records
    }
  }
  $getStrictWorktreeBinding = {
    param([string]$Root)
    $worktreeRoot = (Resolve-Path -LiteralPath (
        Join-Path $Root 'worktrees')).Path
    $null = Assert-Issue13V5NoReparseAncestors $worktreeRoot `
      'Strict historical smoke worktrees'
    Assert-Issue13V5NoReparse $worktreeRoot
    $topFiles = @(Get-ChildItem -LiteralPath $worktreeRoot -File -Force)
    $directories = @(Get-ChildItem -LiteralPath $worktreeRoot `
      -Directory -Force)
    $names = [string[]]@($directories | ForEach-Object Name)
    [Array]::Sort($names, [StringComparer]::Ordinal)
    $expectedNames = [string[]]@($script:Issue13V5Methods)
    [Array]::Sort($expectedNames, [StringComparer]::Ordinal)
    if ($topFiles.Count -ne 0 -or $directories.Count -ne 12 -or
        [string]::Join("`n", $names) -cne
          [string]::Join("`n", $expectedNames)) {
      throw 'Strict historical smoke worktree topology changed.'
    }
    $bindings = [Collections.Generic.List[object]]::new()
    foreach ($methodName in $script:Issue13V5Methods) {
      $worktree = (Resolve-Path -LiteralPath (
          Join-Path $worktreeRoot $methodName)).Path
      $headValue = Get-Issue13V5GitLine $worktree @('rev-parse', 'HEAD') `
        "Strict smoke worktree HEAD $methodName"
      $treeValue = Get-Issue13V5GitLine $worktree @(
        'rev-parse', 'HEAD^{tree}') "Strict smoke worktree tree $methodName"
      $statusValue = Invoke-Issue13V5GitRaw $worktree @(
        'status', '--porcelain=v1', '-z', '--untracked-files=all')
      if ($statusValue.stdout.Length -ne 0 -or
          $headValue -cne $script:Issue13V5BaselineCommit -or
          $treeValue -cne $script:Issue13V5StrictWorktreeTree) {
        throw "Strict historical smoke worktree changed: $methodName"
      }
      $bindings.Add([pscustomobject][ordered]@{
          method = $methodName
          path = $worktree
          head = $headValue
          tree = $treeValue
          status_sha256 = Get-Issue13V5BytesSha256 (
            [byte[]]$statusValue.stdout)
        })
    }
    [object[]]$bindings.ToArray()
  }
  if ($isHistoricalStrict) {
    $strictHarnessBefore = & $getStrictHarnessBinding
    $attemptsRoot = (Resolve-Path -LiteralPath (
        Join-Path $smokeRoot 'attempts')).Path
    $strictAttemptsBefore = Get-Issue13V5TreeInventory $attemptsRoot
    $attemptPaths = [string[]]@(
      $strictAttemptsBefore.records | ForEach-Object {
        [string]$_.relative_path
      })
    [Array]::Sort($attemptPaths, [StringComparer]::Ordinal)
    $attemptPathListSha256 = Get-Issue13V5TextSha256 (
      [string]::Join("`n", $attemptPaths))
    if ([long]$strictAttemptsBefore.file_count -ne 120L -or
        [long]$strictAttemptsBefore.directory_count -ne 60L -or
        [long]$strictAttemptsBefore.total_bytes -ne 2255912L -or
        [string]$strictAttemptsBefore.inventory_sha256 -cne
          $script:Issue13V5StrictAttemptsInventorySha256 -or
        [string]$strictAttemptsBefore.directory_list_sha256 -cne
          $script:Issue13V5StrictAttemptsDirectoryListSha256 -or
        $attemptPathListSha256 -cne
          $script:Issue13V5StrictAttemptsPathListSha256) {
      throw 'Strict historical smoke attempts archive changed.'
    }
    $strictWorktreesBefore = @(& $getStrictWorktreeBinding $smokeRoot)
  }
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
    $head = Get-Issue13V5GitLine $expectedProject @('rev-parse', 'HEAD') `
      "Baseline smoke worktree HEAD $method"
    $tree = Get-Issue13V5GitLine $expectedProject @(
      'rev-parse', 'HEAD^{tree}') "Baseline smoke worktree tree $method"
    $tracked = Invoke-Issue13V5GitRaw $expectedProject @(
      'status', '--porcelain=v1', '-z', '--untracked-files=all')
    if ($head -cne $ExpectedRuntimeCommit -or
        $tree -cne $expectedTree -or $tracked.stdout.Length -ne 0) {
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
    $null = Assert-Issue13V5ExactPropertyNames $result @(
      'schema', 'scenario_id', 'status', 'passed', 'kind', 'project_root',
      'expected_commit', 'observed_commit', 'started_at', 'finished_at',
      'elapsed_seconds', 'request', 'execution_checkpoint', 'outputs', 'seed',
      'publication_before', 'publication_after', 'source_before',
      'source_after', 'error'
    ) "Baseline smoke scenario result $method"
    $null = Assert-Issue13V5ExactPropertyNames $result.request @(
      'method', 'methods', 'channel', 'workers', 'allow_experimental',
      'at_stage', 'sea_vars', 'euklems_years', 'fail_at', 'paper',
      'expected_failure', 'expected_error_pattern', 'fault'
    ) "Baseline smoke scenario request $method"
    $null = Assert-Issue13V5ExactPropertyNames $metrics @(
      'schema', 'scenario_id', 'status', 'passed', 'executable', 'arguments',
      'working_directory', 'root_pid', 'exit_code', 'expected_exit_codes',
      'exit_code_matched', 'timed_out', 'timeout_seconds', 'started_at_utc',
      'finished_at_utc', 'elapsed_seconds', 'sample_interval_ms', 'samples',
      'peak_rss_bytes', 'peak_private_bytes', 'cumulative_cpu_seconds_peak',
      'max_concurrent_processes', 'expected_worker_processes',
      'max_concurrent_worker_processes', 'worker_count_matched',
      'cluster_closed', 'lingering_pids', 'observed_processes', 'stdout_path',
      'stderr_path', 'stdout_sha256', 'stderr_sha256', 'samples_path',
      'samples_sha256', 'process_spec_path', 'process_spec_sha256'
    ) "Baseline smoke process metrics $method"
    if ($isHistoricalStrict) {
      $attemptRoot = ConvertTo-Issue13V5Path (
        Join-Path (Join-Path $smokeRoot 'attempts') $method)
      $attemptInventory = Get-Issue13V5TreeInventory $attemptRoot
      $expectedAttemptFiles = [string[]]@(
        'bundle/bundle.json', 'bundle/process-spec.json',
        'bundle/scenario-spec.json',
        ('evidence/scenarios/' + $scenarioId.Replace('/', '__') +
          '/process-metrics.json'),
        ('evidence/scenarios/' + $scenarioId.Replace('/', '__') +
          '/process-samples.csv'),
        ('evidence/scenarios/' + $scenarioId.Replace('/', '__') +
          '/scenario-result.json'),
        ('evidence/scenarios/' + $scenarioId.Replace('/', '__') +
          '/stderr.log'),
        ('evidence/scenarios/' + $scenarioId.Replace('/', '__') +
          '/stdout.log'),
        'execution-checkpoint.json', 'execution-checkpoint.started.json')
      $observedAttemptFiles = [string[]]@(
        $attemptInventory.records | ForEach-Object {
          [string]$_.relative_path
        })
      [Array]::Sort($expectedAttemptFiles, [StringComparer]::Ordinal)
      [Array]::Sort($observedAttemptFiles, [StringComparer]::Ordinal)
      if ([long]$attemptInventory.file_count -ne 10L -or
          [long]$attemptInventory.directory_count -ne 4L -or
          [string]::Join("`n", $observedAttemptFiles) -cne
            [string]::Join("`n", $expectedAttemptFiles)) {
        throw "Strict smoke attempt topology changed: $method"
      }
      $bundleRoot = Join-Path $attemptRoot 'bundle'
      $processSpecPath = Join-Path $bundleRoot 'process-spec.json'
      $scenarioSpecPath = Join-Path $bundleRoot 'scenario-spec.json'
      $bundlePath = Join-Path $bundleRoot 'bundle.json'
      $checkpointPath = Join-Path $attemptRoot 'execution-checkpoint.json'
      $startedPath = Join-Path $attemptRoot `
        'execution-checkpoint.started.json'
      $processDocument = Read-Issue13V5Json $processSpecPath
      $scenarioDocument = Read-Issue13V5Json $scenarioSpecPath
      $bundleDocument = Read-Issue13V5Json $bundlePath
      $checkpointDocument = Read-Issue13V5Json $checkpointPath
      $startedDocument = Read-Issue13V5Json $startedPath
      $null = Assert-Issue13V5ExactPropertyNames $processDocument @(
        'schema', 'scenario_id', 'executable', 'arguments',
        'working_directory', 'environment', 'expected_exit_codes',
        'timeout_seconds', 'sample_interval_ms', 'shutdown_grace_seconds',
        'expected_worker_processes'
      ) "Strict smoke process spec $method"
      $null = Assert-Issue13V5ExactPropertyNames `
        $processDocument.environment @('R_LIBS_USER') `
        "Strict smoke process environment $method"
      $null = Assert-Issue13V5ExactPropertyNames $scenarioDocument @(
        'schema', 'scenario_id', 'project_root', 'expected_commit', 'kind',
        'method', 'channel', 'checkpoint_path', 'workers',
        'allow_experimental'
      ) "Strict smoke scenario spec $method"
      $null = Assert-Issue13V5ExactPropertyNames $bundleDocument @(
        'schema', 'scenario_id', 'process_spec', 'scenario_evidence',
        'runtime_commit', 'r_library', 'channel'
      ) "Strict smoke bundle $method"
      $null = Assert-Issue13V5ExactPropertyNames $checkpointDocument @(
        'schema', 'status', 'scenario_id', 'project_root', 'expected_commit',
        'scenario_spec_path', 'scenario_spec_sha256', 'request',
        'started_marker_path', 'started_marker_sha256', 'started_at',
        'finished_at', 'elapsed_seconds', 'publication_before',
        'publication_after', 'source_before', 'source_after', 'outputs',
        'error'
      ) "Strict smoke checkpoint $method"
      $null = Assert-Issue13V5ExactPropertyNames $startedDocument @(
        'schema', 'status', 'scenario_id', 'project_root', 'expected_commit',
        'scenario_spec_path', 'scenario_spec_sha256', 'request', 'started_at',
        'publication_before', 'source_before'
      ) "Strict smoke started marker $method"
      $null = Assert-Issue13V5ExactPropertyNames $result.execution_checkpoint @(
        'scenario_spec_path', 'scenario_spec_sha256', 'started_marker_path',
        'started_marker_sha256', 'checkpoint_path', 'checkpoint_sha256'
      ) "Strict smoke result checkpoint binding $method"
      $expectedChannel = 'issue13-v5-smoke-b-' + $method.Replace('_', '-')
      $historicalHarness = Join-Path (Split-Path -Parent (
          [string]$summary.harness_manifest_path)) `
        'issue13-evidence-harness\issue13-scenario.R'
      $expectedArguments = [string[]]@(
        '--vanilla', (ConvertTo-Issue13V5Path $historicalHarness),
        (ConvertTo-Issue13V5Path $scenarioSpecPath),
        (ConvertTo-Issue13V5Path $expectedEvidence))
      $processArguments = [string[]]@(
        for ($argumentIndex = 0;
            $argumentIndex -lt @($processDocument.arguments).Count;
            $argumentIndex++) {
          if ($argumentIndex -eq 0) {
            [string]$processDocument.arguments[$argumentIndex]
          } else {
            ConvertTo-Issue13V5Path (
              [string]$processDocument.arguments[$argumentIndex])
          }
        })
      $metricsArguments = [string[]]@(
        for ($argumentIndex = 0;
            $argumentIndex -lt @($metrics.arguments).Count;
            $argumentIndex++) {
          if ($argumentIndex -eq 0) {
            [string]$metrics.arguments[$argumentIndex]
          } else {
            ConvertTo-Issue13V5Path ([string]$metrics.arguments[$argumentIndex])
          }
        })
      $normalizedExpectedArguments = [string[]]@(
        $expectedArguments | ForEach-Object {
          if ($_ -ceq '--vanilla') { $_ } else {
            ConvertTo-Issue13V5Path $_
          }
        })
      if ([string]$processDocument.schema -cne
            'wlv-issue13-process-spec/1' -or
          [string]$scenarioDocument.schema -cne
            'wlv-issue13-scenario/1' -or
          [string]$bundleDocument.schema -cne
            'wlv-issue13-calculate-bundle/1' -or
          [string]$checkpointDocument.schema -cne
            'wlv-issue13-execution-checkpoint/2' -or
          [string]$startedDocument.schema -cne
            'wlv-issue13-execution-started/1' -or
          [string]$processDocument.scenario_id -cne $scenarioId -or
          [string]$scenarioDocument.scenario_id -cne $scenarioId -or
          [string]$bundleDocument.scenario_id -cne $scenarioId -or
          [string]$checkpointDocument.scenario_id -cne $scenarioId -or
          [string]$startedDocument.scenario_id -cne $scenarioId -or
          [string]::Join("`n", $processArguments) -cne
            [string]::Join("`n", $normalizedExpectedArguments) -or
          [string]::Join("`n", $metricsArguments) -cne
            [string]::Join("`n", $normalizedExpectedArguments) -or
          -not [string]::Equals(
            (ConvertTo-Issue13V5Path ([string]$processDocument.executable)),
            (ConvertTo-Issue13V5Path $configuredRscript),
            [StringComparison]::OrdinalIgnoreCase) -or
          -not [string]::Equals(
            (ConvertTo-Issue13V5Path ([string]$metrics.executable)),
            (ConvertTo-Issue13V5Path $configuredRscript),
            [StringComparison]::OrdinalIgnoreCase) -or
          -not [string]::Equals(
            (ConvertTo-Issue13V5Path ([string]$processDocument.working_directory)),
            $expectedProject, [StringComparison]::OrdinalIgnoreCase) -or
          -not [string]::Equals(
            (ConvertTo-Issue13V5Path ([string]$metrics.working_directory)),
            $expectedProject, [StringComparison]::OrdinalIgnoreCase) -or
          -not [string]::Equals(
            (ConvertTo-Issue13V5Path ([string]$scenarioDocument.project_root)),
            $expectedProject, [StringComparison]::OrdinalIgnoreCase) -or
          -not [string]::Equals(
            (ConvertTo-Issue13V5Path ([string]$checkpointDocument.project_root)),
            $expectedProject, [StringComparison]::OrdinalIgnoreCase) -or
          -not [string]::Equals(
            (ConvertTo-Issue13V5Path ([string]$startedDocument.project_root)),
            $expectedProject, [StringComparison]::OrdinalIgnoreCase) -or
          -not [string]::Equals(
            (ConvertTo-Issue13V5Path ([string]$result.project_root)),
            $expectedProject, [StringComparison]::OrdinalIgnoreCase) -or
          -not [string]::Equals(
            (ConvertTo-Issue13V5Path (
              [string]$processDocument.environment.R_LIBS_USER)),
            (ConvertTo-Issue13V5Path ([string]$Config.r_library)),
            [StringComparison]::OrdinalIgnoreCase) -or
          -not [string]::Equals(
            (ConvertTo-Issue13V5Path ([string]$bundleDocument.r_library)),
            (ConvertTo-Issue13V5Path ([string]$Config.r_library)),
            [StringComparison]::OrdinalIgnoreCase) -or
          [string]$scenarioDocument.expected_commit -cne
            $ExpectedRuntimeCommit -or
          [string]$checkpointDocument.expected_commit -cne
            $ExpectedRuntimeCommit -or
          [string]$startedDocument.expected_commit -cne
            $ExpectedRuntimeCommit -or
          [string]$scenarioDocument.kind -cne 'calculate' -or
          [string]$scenarioDocument.method -cne $method -or
          [string]$scenarioDocument.channel -cne $expectedChannel -or
          [long]$scenarioDocument.workers -ne 1L -or
          -not (Test-Issue13V5ExactBoolean `
            $scenarioDocument.allow_experimental $true) -or
          [string]$bundleDocument.runtime_commit -cne
            $ExpectedRuntimeCommit -or
          [string]$bundleDocument.channel -cne $expectedChannel -or
          [string]$checkpointDocument.status -cne 'finished' -or
          [string]$startedDocument.status -cne 'started') {
        throw "Strict smoke bundle/process contract changed: $method"
      }
      foreach ($pathBinding in @(
          @($bundleDocument.process_spec, $processSpecPath),
          @($bundleDocument.scenario_evidence, $expectedEvidence),
          @($scenarioDocument.checkpoint_path, $checkpointPath),
          @($checkpointDocument.scenario_spec_path, $scenarioSpecPath),
          @($startedDocument.scenario_spec_path, $scenarioSpecPath),
          @($checkpointDocument.started_marker_path, $startedPath),
          @($result.execution_checkpoint.scenario_spec_path,
            $scenarioSpecPath),
          @($result.execution_checkpoint.started_marker_path, $startedPath),
          @($result.execution_checkpoint.checkpoint_path, $checkpointPath)
        )) {
        if ($null -eq $pathBinding[0] -or -not [string]::Equals(
            (ConvertTo-Issue13V5Path ([string]$pathBinding[0])),
            (ConvertTo-Issue13V5Path ([string]$pathBinding[1])),
            [StringComparison]::OrdinalIgnoreCase)) {
          throw "Strict smoke path binding changed: $method"
        }
      }
      $scenarioSpecSha = Get-Issue13V5Sha256 $scenarioSpecPath
      $startedSha = Get-Issue13V5Sha256 $startedPath
      $checkpointSha = Get-Issue13V5Sha256 $checkpointPath
      $checkpointRequestJson = $checkpointDocument.request |
        ConvertTo-Json -Depth 30 -Compress
      if ($checkpointRequestJson -cne
          ($startedDocument.request | ConvertTo-Json -Depth 30 -Compress)) {
        throw "Strict smoke checkpoint requests differ: $method"
      }
      foreach ($requestDocument in @(
          $result.request, $checkpointDocument.request,
          $startedDocument.request)) {
        if ([string]$requestDocument.method -cne $method -or
            [string]::Join("`n", @($requestDocument.methods)) -cne $method -or
            [string]$requestDocument.channel -cne $expectedChannel -or
            [long]$requestDocument.workers -ne 1L -or
            -not (Test-Issue13V5ExactBoolean `
              $requestDocument.allow_experimental $true) -or
            $null -ne $requestDocument.at_stage -or
            $null -ne $requestDocument.sea_vars -or
            $null -ne $requestDocument.euklems_years -or
            @($requestDocument.fail_at).Count -ne 0 -or
            $null -ne $requestDocument.paper -or
            -not (Test-Issue13V5ExactBoolean `
              $requestDocument.expected_failure $false) -or
            $null -ne $requestDocument.expected_error_pattern -or
            $null -ne $requestDocument.fault) {
          throw "Strict smoke request contract changed: $method"
        }
      }
      foreach ($checkpointRequest in @(
          $checkpointDocument.request, $startedDocument.request)) {
        if (-not [string]::Equals(
              (ConvertTo-Issue13V5Path (
                [string]$checkpointRequest.scenario_spec_path)),
              (ConvertTo-Issue13V5Path $scenarioSpecPath),
              [StringComparison]::OrdinalIgnoreCase) -or
            [string]$checkpointRequest.scenario_spec_sha256 -cne
              $scenarioSpecSha -or
            [string]$checkpointRequest.kind -cne 'calculate' -or
            $null -ne $checkpointRequest.seed) {
          throw "Strict smoke checkpoint request binding changed: $method"
        }
      }
      if (($result.outputs | ConvertTo-Json -Depth 30 -Compress) -cne
            ($checkpointDocument.outputs |
              ConvertTo-Json -Depth 30 -Compress) -or
          ($result.error | ConvertTo-Json -Depth 30 -Compress) -cne
            ($checkpointDocument.error |
              ConvertTo-Json -Depth 30 -Compress) -or
          ($result.publication_before |
              ConvertTo-Json -Depth 30 -Compress) -cne
            ($checkpointDocument.publication_before |
              ConvertTo-Json -Depth 30 -Compress) -or
          ($result.publication_before |
              ConvertTo-Json -Depth 30 -Compress) -cne
            ($startedDocument.publication_before |
              ConvertTo-Json -Depth 30 -Compress) -or
          ($result.publication_after |
              ConvertTo-Json -Depth 30 -Compress) -cne
            ($checkpointDocument.publication_after |
              ConvertTo-Json -Depth 30 -Compress) -or
          ($result.source_before | ConvertTo-Json -Depth 30 -Compress) -cne
            ($checkpointDocument.source_before |
              ConvertTo-Json -Depth 30 -Compress) -or
          ($result.source_before | ConvertTo-Json -Depth 30 -Compress) -cne
            ($startedDocument.source_before |
              ConvertTo-Json -Depth 30 -Compress) -or
          ($result.source_after | ConvertTo-Json -Depth 30 -Compress) -cne
            ($checkpointDocument.source_after |
              ConvertTo-Json -Depth 30 -Compress)) {
        throw "Strict smoke checkpoint/result snapshots differ: $method"
      }
      if ([string]$checkpointDocument.scenario_spec_sha256 -cne
            $scenarioSpecSha -or
          [string]$startedDocument.scenario_spec_sha256 -cne
            $scenarioSpecSha -or
          [string]$checkpointDocument.started_marker_sha256 -cne
            $startedSha -or
          [string]$result.execution_checkpoint.scenario_spec_sha256 -cne
            $scenarioSpecSha -or
          [string]$result.execution_checkpoint.started_marker_sha256 -cne
            $startedSha -or
          [string]$result.execution_checkpoint.checkpoint_sha256 -cne
            $checkpointSha -or
          @($processDocument.expected_exit_codes).Count -ne 1 -or
          [long]$processDocument.expected_exit_codes[0] -ne 0L -or
          [long]$processDocument.expected_worker_processes -ne 0L -or
          [long]$metrics.exit_code -ne $(if ($shouldPass) { 0L } else { 1L }) -or
          -not (Test-Issue13V5ExactBoolean `
            $metrics.exit_code_matched $shouldPass) -or
          -not (Test-Issue13V5ExactBoolean $metrics.timed_out $false) -or
          [string]$result.request.channel -cne $expectedChannel -or
          [string]::Join("`n", @($result.request.methods)) -cne $method -or
          -not (Test-Issue13V5ExactBoolean `
            $result.request.allow_experimental $true) -or
          -not (Test-Issue13V5ExactBoolean `
            $result.request.expected_failure $false) -or
          @($result.request.fail_at).Count -ne 0) {
        throw "Strict smoke checkpoint/status binding changed: $method"
      }
    }
    if ([string]$result.schema -cne 'wlv-issue13-scenario-result/1' -or
        [string]$result.scenario_id -cne $scenarioId -or
        [string]$result.status -cne $recordStatus -or
        -not (Test-Issue13V5ExactBoolean $result.passed $shouldPass) -or
        [string]$result.kind -cne 'calculate' -or
        [string]$result.expected_commit -cne $ExpectedRuntimeCommit -or
        [string]$result.observed_commit -cne $ExpectedRuntimeCommit -or
        [string]$result.request.method -cne $method -or
        [long]$result.request.workers -ne 1L -or
        [string]$metrics.schema -cne 'wlv-issue13-process-metrics/2' -or
        [string]$metrics.scenario_id -cne $scenarioId -or
        [string]$metrics.status -cne $recordStatus -or
        -not (Test-Issue13V5ExactBoolean $metrics.passed $shouldPass) -or
        -not (Test-Issue13V5ExactBoolean $metrics.cluster_closed $true) -or
        -not (Test-Issue13V5ExactBoolean `
          $metrics.worker_count_matched $true) -or
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
  if ($isHistoricalStrict) {
    $strictHarnessAfter = & $getStrictHarnessBinding
    $strictAttemptsAfter = Get-Issue13V5TreeInventory (
      Join-Path $smokeRoot 'attempts')
    $strictWorktreesAfter = @(& $getStrictWorktreeBinding $smokeRoot)
    if (($strictHarnessAfter | ConvertTo-Json -Depth 20 -Compress) -cne
          ($strictHarnessBefore | ConvertTo-Json -Depth 20 -Compress) -or
        ($strictAttemptsAfter | ConvertTo-Json -Depth 20 -Compress) -cne
          ($strictAttemptsBefore | ConvertTo-Json -Depth 20 -Compress) -or
        ($strictWorktreesAfter | ConvertTo-Json -Depth 10 -Compress) -cne
          ($strictWorktreesBefore | ConvertTo-Json -Depth 10 -Compress)) {
      throw 'Strict historical smoke archive changed during validation.'
    }
  }
  $null = Assert-Issue13V5NoReparseAncestors `
    $configuredRscript 'Baseline smoke Rscript executable'
  $currentRscriptIdentity = Get-Issue13V5PhysicalItemIdentity `
    $configuredRscript 'Baseline smoke Rscript executable'
  if ([uint64]$currentRscriptIdentity.link_count -ne 1UL -or
      [string]$currentRscriptIdentity.item_id -cne
        [string]$configuredRscriptIdentity.item_id -or
      -not [string]::Equals(
        [string]$currentRscriptIdentity.physical_path,
        [string]$configuredRscriptIdentity.physical_path,
        [StringComparison]::OrdinalIgnoreCase) -or
      (Get-Issue13V5Sha256 $configuredRscript) -cne
        $script:Issue13V5RscriptSha256 -or
      [long](Get-Item -LiteralPath $configuredRscript).Length -ne 94720L) {
    throw 'Baseline smoke Rscript binding changed during validation.'
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
  $configuredPaths = @(Get-Issue13V5ConfiguredPaths $config)
  $legacyPaths = @($configuredPaths | Where-Object {
    Test-Issue13V5LegacyPath $_
  })
  if ($legacyPaths.Count -ne 0) {
    throw 'V5 config contains a forbidden V4/V4R2 path.'
  }
  $null = ConvertTo-Issue13V5PhysicalPath $path 'V5 config file'
  foreach ($configuredPath in $configuredPaths) {
    $null = ConvertTo-Issue13V5PhysicalPath $configuredPath 'V5 configured path'
    Assert-Issue13V5NoReparseAncestors $configuredPath 'V5 configured path'
  }
  if ([string]$config.schema -cne 'wlv-issue13-native-gate-config/3' -or
      [string]$config.generation -cne 'v5' -or
      -not (Test-Issue13V5ExactBoolean `
        $config.final_evidence_eligible $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.reuse_policy.v4_evidence_allowed $false) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.reuse_policy.candidate_evidence_reuse_allowed $false) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.reuse_policy.imported_scenario_evidence_allowed $false) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.reuse_policy.fresh_roots_required $true) -or
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
  $preparationProfile = $config.comparison.preparation_equivalence_profile
  $null = Assert-Issue13V5ExactPropertyNames $preparationProfile @(
    'schema', 'path', 'sha256', 'sources', 'artifacts', 'profile_count',
    'all_rows_fields_and_order_exact', 'architecture_projection',
    'source_unit_contract_bridge'
  ) 'Exhaustive preparation equivalence binding'
  $preparationProfilePath = ConvertTo-Issue13V5Path (
    [string]$preparationProfile.path)
  $expectedPreparationProfilePath = ConvertTo-Issue13V5Path (Join-Path `
    ([string]$config.harness_root) `
    'issue13-v5-preparation-equivalence.json')
  if (-not [string]::Equals($preparationProfilePath,
        $expectedPreparationProfilePath,
        [StringComparison]::OrdinalIgnoreCase) -or
      -not (Test-Path -LiteralPath $preparationProfilePath -PathType Leaf) -or
      [string]$preparationProfile.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      (Get-Issue13V5Sha256 $preparationProfilePath) -cne
        [string]$preparationProfile.sha256 -or
      [string]$preparationProfile.schema -cne
        'wlv-issue13-preparation-equivalence/1' -or
      [string]::Join("`n", @($preparationProfile.sources)) -cne
        "wiodr13`nwiodr16" -or
      [string]::Join("`n", @($preparationProfile.artifacts)) -cne
        "_unit_contract.csv`n_source_manifest.csv" -or
      [long]$preparationProfile.profile_count -ne 2L -or
      -not (Test-Issue13V5ExactBoolean `
        $preparationProfile.all_rows_fields_and_order_exact $true) -or
      @($preparationProfile.architecture_projection).Count -ne 0 -or
      [string]$preparationProfile.source_unit_contract_bridge -cne
        'exhaustive-source-unit-contract-bridge') {
    throw 'The exhaustive preparation-equivalence binding changed.'
  }
  $preparationProfileDocument = Read-Issue13V5Json $preparationProfilePath
  if ([string]$preparationProfileDocument.schema -cne
        'wlv-issue13-preparation-equivalence/1' -or
      [string]::Join("`n", @($preparationProfileDocument.sources)) -cne
        "wiodr13`nwiodr16" -or
      [string]::Join("`n", @($preparationProfileDocument.artifacts)) -cne
        "_unit_contract.csv`n_source_manifest.csv" -or
      @($preparationProfileDocument.profiles).Count -ne 2) {
    throw 'The exhaustive preparation-equivalence document changed.'
  }
  if ([string]$config.comparison.numerical_tolerance -cne
        'contract-only-no-new-tolerance' -or
      -not (Test-Issue13V5ExactBoolean `
        $config.comparison.compare_dimensions $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.comparison.compare_dimnames $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.comparison.compare_finite_values $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.comparison.distinguish_na_nan_posinf_neginf $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.comparison.compare_semantic_states $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.comparison.compare_metadata_and_contracts $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.comparison.compare_method_matrices $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.comparison.compare_diagnostics_as_duplicate_preserving_multisets `
        $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.comparison.compare_unselected_cells $true) -or
      [string]::Join("`n", @($config.comparison.ignore_only)) -cne
        "timestamps`npaths`nrun_id`nresult_id`n" +
          'provenance-dependent-container-bytes' -or
      [string]::Join("`n", @($config.comparison.candidate_only_artifacts)) `
        -cne "_nonfinite_resolution_diagnostics.csv`n_runtime_resources.rds") {
    throw 'V5 scientific comparison policy changed.'
  }
  if ([double]$config.performance.candidate_time_ratio_maximum -ne 1.2 -or
      [double]$config.performance.candidate_rss_baseline_ratio_allowance `
        -ne 0.1 -or
      [long]$config.performance.candidate_rss_minimum_allowance_bytes -ne
        536870912L -or
      [string]::Join("`n", @($config.performance.workers2_methods)) -cne
        "wiodr13`nwiodr16" -or
      -not (Test-Issue13V5ExactBoolean `
        $config.performance.require_cluster_closed $true) -or
      [string]::Join("`n", @($config.preparation.sources)) -cne
        "wiodr13`nwiodr16`neuklems" -or
      -not (Test-Issue13V5ExactBoolean `
        $config.preparation.same_official_cache_inventory $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.preparation.bitwise_arrays $true) -or
      -not (Test-Issue13V5ExactBoolean `
        $config.preparation.require_atomic_promotion $true) -or
      [string]::Join("`n", @($config.paper0.methods)) -cne
        "ochoa_1`nochoa_2" -or
      [string]::Join("`n", @($config.paper0.unsupported_papers)) -cne
        "3`n4" -or
      -not (Test-Issue13V5ExactBoolean `
        $config.paper0.workbook_semantic_comparison $true)) {
    throw 'V5 performance, preparation, or paper policy changed.'
  }
  if ([string]$config.report.required_path -cne
        'docs/validation/issue-13.md' -or
      [string]::Join("`n", @($config.report.required_fields)) -cne
        "baseline_commit`nbaseline_base_commit`nbaseline_runtime_commit`n" +
          "strict_baseline_smoke`ncompatibility_baseline_smoke`n" +
          "baseline_overlay_patch`noracle_effect_proof`n" +
          "candidate_commit`nsource_ids`ncommands`n" +
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
  foreach ($root in $roots) {
    Assert-Issue13V5PathsDisjoint $path $root 'V5 config/output-root isolation'
  }
  $oracleComparisonRoots = @(
    (ConvertTo-Issue13V5Path (
      [string]$config.oracle_effect.comparisons.primary.root)),
    (ConvertTo-Issue13V5Path (
      [string]$config.oracle_effect.comparisons.replay.root))
  )
  foreach ($oracleComparisonRoot in $oracleComparisonRoots) {
    Assert-Issue13V5PathsDisjoint $path $oracleComparisonRoot 'V5 config/oracle-comparison isolation'
  }
  for ($left = 0; $left -lt $roots.Count; $left++) {
    for ($right = $left + 1; $right -lt $roots.Count; $right++) {
      Assert-Issue13V5PathsDisjoint $roots[$left] $roots[$right] 'Worktree/evidence/control isolation'
    }
  }
  $immutableRoots = @(
      (ConvertTo-Issue13V5Path ([string]$config.repository_root))
      (ConvertTo-Issue13V5Path ([string]$config.source_origin))
      (ConvertTo-Issue13V5Path ([string]$config.candidate_source_origin))
      (ConvertTo-Issue13V5Path ([string]$config.harness_runtime_root))
      (ConvertTo-Issue13V5Path ([string]$config.r_library))
      (ConvertTo-Issue13V5Path ([string]$config.rscript))
      (ConvertTo-Issue13V5Path (
        [string]$config.oracle_effect.comparisons.primary.root))
      (ConvertTo-Issue13V5Path (
        [string]$config.oracle_effect.comparisons.replay.root))
  )
  $null = Assert-Issue13V5ConfigPathIsolation $path $immutableRoots
  foreach ($immutable in $immutableRoots) {
    foreach ($root in $roots) {
      Assert-Issue13V5PathsDisjoint $root $immutable 'V5 output/immutable-root isolation'
    }
  }
  if (@($config.allowed_r_processes).Count -ne 1 -or
      [long]$config.allowed_r_processes[0].pid -ne 30272L -or
      [string]$config.allowed_r_processes[0].command_line_sha256 -cne
        $script:Issue13V5AllowedRCommandSha256) {
    throw 'V5 config does not preserve the sole allowed persistent R PID.'
  }
  $null = Assert-Issue13V5ExactPropertyNames `
    $config.strict_baseline_smoke @(
      'path', 'sha256', 'passed_count', 'failed_count',
      'final_evidence_eligible', 'rscript_path', 'rscript_physical_path',
      'rscript_item_id', 'rscript_link_count', 'rscript_sha256'
    ) 'Strict baseline-smoke config'
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
      -not (Test-Issue13V5ExactBoolean `
        $config.strict_baseline_smoke.final_evidence_eligible $false) -or
      [long]$config.compatibility_baseline_smoke.passed_count -ne 12 -or
      [long]$config.compatibility_baseline_smoke.failed_count -ne 0 -or
      -not (Test-Issue13V5ExactBoolean `
        $config.compatibility_baseline_smoke.final_evidence_eligible $false) -or
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
  $oracleEffectValidation = Invoke-Issue13V5OracleEffectValidation $config
  $initialOracleValidation = $config.oracle_effect.initial_validation
  foreach ($field in @(
      'schema', 'status', 'passed', 'final_evidence_eligible',
      'required_by_final_gate', 'strict_common_comparison_count',
      'comparison_execution_count', 'approved_run_inventory_count',
      'recovered_method_count', 'source_controller_inventory_sha256',
      'r_runtime_inventory_sha256', 'oracle_effect_closed',
      'final_v5_gate_substituted', 'proof_sha256',
      'primary_comparison_inventory_sha256',
      'replay_comparison_inventory_sha256',
      'comparison_harness_manifest_sha256',
      'comparison_harness_inventory_sha256', 'expected_candidate_commit',
      'rscript_sha256', 'r_library_path', 'authorized_patch_sha256',
      'authorized_patch_id')) {
    if ([string]$initialOracleValidation.$field -cne
        [string]$oracleEffectValidation.$field) {
      throw "Initial oracle-effect validation is stale or forged: $field"
    }
  }
  if ([string]::Join("`n", @(
        $initialOracleValidation.command.arguments)) -cne
      [string]::Join("`n", @($oracleEffectValidation.command.arguments)) -or
      [string]$initialOracleValidation.command.executable -cne
        [string]$oracleEffectValidation.command.executable -or
      [string]$initialOracleValidation.command.working_directory -cne
        [string]$oracleEffectValidation.command.working_directory -or
      [long]$initialOracleValidation.command.exit_code -ne 0L -or
      [string]$initialOracleValidation.command.stdout_sha256 -cne
        [string]$oracleEffectValidation.command.stdout_sha256) {
    throw 'Initial oracle-effect validation command is stale or forged.'
  }
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
      -not (Test-Issue13V5ExactBoolean `
        $index.profiles[0].run_dirty $false) -or
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
  $headExists = Invoke-Issue13V5SealedGit `
    -C ([string]$config.repository_root) cat-file -e `
    ([string]$config.candidate_commit + '^{commit}') 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw 'Candidate commit is unavailable in the configured repository.'
  }
  $null = $headExists
  $runtimeExists = Invoke-Issue13V5SealedGit `
    -C ([string]$config.repository_root) cat-file -e `
    ([string]$config.baseline_runtime_commit + '^{commit}') 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw 'Compatibility runtime commit is unavailable.'
  }
  $null = $runtimeExists
  $runtimeParent = (Invoke-Issue13V5SealedGit `
    -C ([string]$config.repository_root) rev-parse `
    ([string]$config.baseline_runtime_commit + '^') 2>$null).Trim()
  $runtimeTree = (Invoke-Issue13V5SealedGit `
    -C ([string]$config.repository_root) rev-parse `
    ([string]$config.baseline_runtime_commit + '^{tree}') 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or
      $runtimeParent -cne $script:Issue13V5BaselineCommit -or
      $runtimeTree -cne $script:Issue13V5BaselineRuntimeTree) {
    throw 'Compatibility runtime is not a direct child of cc2.'
  }
  $ancestor = Invoke-Issue13V5SealedGit `
    -C ([string]$config.repository_root) merge-base `
    --is-ancestor $script:Issue13V5BaselineCommit `
    ([string]$config.candidate_commit) 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw 'Candidate is not a descendant of the strict cc2 baseline.'
  }
  $null = $ancestor
  $oracleAncestor = Invoke-Issue13V5SealedGit `
    -C ([string]$config.repository_root) merge-base `
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
    oracle_effect_validation = $oracleEffectValidation
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
  $head = (Invoke-Issue13V5SealedGit `
    -C $resolved rev-parse HEAD 2>$null).Trim()
  $tree = (Invoke-Issue13V5SealedGit `
    -C $resolved rev-parse 'HEAD^{tree}' 2>$null).Trim()
  $status = @(Invoke-Issue13V5SealedGit `
    -C $resolved status '--porcelain=v1' `
    '--untracked-files=all' 2>$null)
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

function Stop-Issue13V5ExternalProcess(
  [Parameter(Mandatory = $true)][Diagnostics.Process]$Process,
  [int]$GraceMilliseconds = 30000
) {
  if ($GraceMilliseconds -le 0) {
    throw 'External-process cleanup grace must be positive.'
  }
  $failures = [Collections.Generic.List[Exception]]::new()
  try {
    if (-not $Process.HasExited) { $Process.Kill($true) }
  } catch {
    $failures.Add($_.Exception)
  }
  try {
    if (-not $Process.HasExited) {
      $Process.Kill($true)
      if (-not $Process.WaitForExit($GraceMilliseconds)) {
        throw 'External process tree did not terminate within the cleanup grace.'
      }
    }
  } catch {
    $failures.Add($_.Exception)
  }
  try {
    if (-not $Process.HasExited) {
      throw 'External process remains active after bounded cleanup.'
    }
  } catch {
    $failures.Add($_.Exception)
  }
  if ($failures.Count -eq 1) { throw $failures[0] }
  if ($failures.Count -gt 1) {
    throw [AggregateException]::new(
      'External-process tree cleanup failed.', $failures.ToArray())
  }
}

function Invoke-Issue13V5RscriptBounded(
  [Parameter(Mandatory = $true)][string]$RscriptPath,
  [string[]]$Arguments = @(),
  [Parameter(Mandatory = $true)][string]$Label,
  [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
  [AllowNull()][int[]]$ExpectedExitCodes = @(0),
  [AllowNull()][string]$WorkingDirectory = $null,
  [AllowNull()][Collections.IDictionary]$Environment = $null
) {
  if ([string]::IsNullOrWhiteSpace($Label)) {
    throw 'Bounded Rscript label cannot be empty.'
  }
  if ($TimeoutSeconds -le 0 -or $TimeoutSeconds -gt 2147483) {
    throw 'Bounded Rscript timeout must be between 1 and 2147483 seconds.'
  }
  $validateExitCode = $null -ne $ExpectedExitCodes
  if ($validateExitCode -and @($ExpectedExitCodes).Count -eq 0) {
    throw 'Bounded Rscript expected exit codes cannot be empty.'
  }
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
  $start.StandardOutputEncoding = $strictUtf8
  $start.StandardErrorEncoding = $strictUtf8
  $environmentBinding = Set-Issue13V5ProcessStartInfoEnvironment `
    $start $Environment
  if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
    $resolvedWorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory)
    if (-not [IO.Directory]::Exists($resolvedWorkingDirectory)) {
      throw "Bounded Rscript working directory is unavailable: $resolvedWorkingDirectory"
    }
    Assert-Issue13V5NoReparseAncestors `
      $resolvedWorkingDirectory 'bounded Rscript working directory'
    $start.WorkingDirectory = $resolvedWorkingDirectory
  }
  foreach ($argument in @($Arguments)) {
    $start.ArgumentList.Add([string]$argument)
  }
  $start.FileName = [IO.Path]::GetFullPath($RscriptPath)
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $start
  $lease = $null
  $binding = $null
  $processStarted = $false
  $stdoutTask = $null
  $stderrTask = $null
  $stdoutBuffer = $null
  $stderrBuffer = $null
  $primary = $null
  $timedOut = $false
  $stdoutText = ''
  $stderrText = ''
  $exitCode = $null
  try {
    $lease = Enter-Issue13V5RscriptExecutableLease $RscriptPath
    $binding = $lease.binding
    $start.FileName = [string]$binding.logical_path
    if (-not $process.Start()) {
      throw "Could not start bounded Rscript: $Label"
    }
    $processStarted = $true
    $outputLimitBytes = 8L * 1024L * 1024L
    $stdoutBuffer = [IO.MemoryStream]::new()
    $stderrBuffer = [IO.MemoryStream]::new()
    $stdoutTask = $script:Issue13V5BoundedStreamCaptureType::CopyAsync(
      $process.StandardOutput.BaseStream, $stdoutBuffer, $outputLimitBytes)
    $stderrTask = $script:Issue13V5BoundedStreamCaptureType::CopyAsync(
      $process.StandardError.BaseStream, $stderrBuffer, $outputLimitBytes)
    $timeoutMilliseconds = [int]([int64]$TimeoutSeconds * 1000L)
    $waitStopwatch = [Diagnostics.Stopwatch]::StartNew()
    while (-not $process.HasExited) {
      if ($stdoutTask.IsFaulted) {
        $null = $stdoutTask.GetAwaiter().GetResult()
      }
      if ($stderrTask.IsFaulted) {
        $null = $stderrTask.GetAwaiter().GetResult()
      }
      $remainingMilliseconds =
        [int64]$timeoutMilliseconds - $waitStopwatch.ElapsedMilliseconds
      if ($remainingMilliseconds -le 0) {
        $timedOut = $true
        break
      }
      $waitSlice = [int][Math]::Min(250L, $remainingMilliseconds)
      $null = $process.WaitForExit($waitSlice)
    }
    $waitStopwatch.Stop()
    if ($timedOut) {
      Stop-Issue13V5ExternalProcess $process
    }
    $outputTasks = [Threading.Tasks.Task[]]@($stdoutTask, $stderrTask)
    if (-not [Threading.Tasks.Task]::WaitAll($outputTasks, 30000)) {
      throw 'Bounded Rscript output streams did not close within 30 seconds.'
    }
    $null = $stdoutTask.GetAwaiter().GetResult()
    $null = $stderrTask.GetAwaiter().GetResult()
    $stdoutText = $strictUtf8.GetString($stdoutBuffer.ToArray())
    $stderrText = $strictUtf8.GetString($stderrBuffer.ToArray())
    $exitCode = if ($timedOut) { -999 } else { [int]$process.ExitCode }
  } catch {
    $primary = $_
  }
  $cleanupFailures = [Collections.Generic.List[Exception]]::new()
  if ($processStarted) {
    try {
      Stop-Issue13V5ExternalProcess $process
    } catch {
      $cleanupFailures.Add($_.Exception)
    }
  }
  foreach ($task in @($stdoutTask, $stderrTask)) {
    if ($null -eq $task) { continue }
    try {
      if (-not $task.IsCompleted -and -not $task.Wait(30000)) {
        throw 'A bounded Rscript output task remained active after cleanup.'
      }
    } catch {
      $cleanupFailures.Add($_.Exception)
    }
    if ($task.IsCompleted) {
      try { $task.Dispose() } catch { $cleanupFailures.Add($_.Exception) }
    }
  }
  foreach ($buffer in @($stdoutBuffer, $stderrBuffer)) {
    if ($null -eq $buffer) { continue }
    try { $buffer.Dispose() } catch { $cleanupFailures.Add($_.Exception) }
  }
  try {
    $process.Dispose()
  } catch {
    $cleanupFailures.Add($_.Exception)
  }
  if ($null -ne $lease) {
    try {
      Exit-Issue13V5RscriptExecutableLease $lease
    } catch {
      $cleanupFailures.Add($_.Exception)
    }
  }
  if ($cleanupFailures.Count -ne 0) {
    $failures = [Collections.Generic.List[Exception]]::new()
    if ($null -ne $primary) { $failures.Add($primary.Exception) }
    foreach ($failure in $cleanupFailures) { $failures.Add($failure) }
    throw [AggregateException]::new(
      "Bounded Rscript lifecycle cleanup failed: $Label",
      $failures.ToArray())
  }
  if ($null -ne $primary) { throw $primary }
  if ($timedOut -and $validateExitCode) {
    throw [TimeoutException]::new(
      "Bounded Rscript exceeded its $TimeoutSeconds-second timeout: $Label")
  }
  if ($validateExitCode -and $exitCode -notin $ExpectedExitCodes) {
    throw "Bounded Rscript failed: $Label (exit=$exitCode)"
  }
  $stdoutLines = [string[]]@()
  if (-not [string]::IsNullOrEmpty($stdoutText)) {
    $stdoutLineValues = [regex]::Split($stdoutText, "\r?\n")
    $stdoutLineCount = $stdoutLineValues.Count
    if ($stdoutLineCount -gt 0 -and
        $stdoutLineValues[$stdoutLineCount - 1] -ceq '') {
      $stdoutLineCount--
    }
    if ($stdoutLineCount -gt 0) {
      $stdoutLines = [string[]]@(
        $stdoutLineValues[0..($stdoutLineCount - 1)])
    }
  }
  $stderrLines = [string[]]@()
  if (-not [string]::IsNullOrEmpty($stderrText)) {
    $stderrLineValues = [regex]::Split($stderrText, "\r?\n")
    $stderrLineCount = $stderrLineValues.Count
    if ($stderrLineCount -gt 0 -and
        $stderrLineValues[$stderrLineCount - 1] -ceq '') {
      $stderrLineCount--
    }
    if ($stderrLineCount -gt 0) {
      $stderrLines = [string[]]@(
        $stderrLineValues[0..($stderrLineCount - 1)])
    }
  }
  [pscustomobject][ordered]@{
    exit_code = [int]$exitCode
    stdout = $stdoutText
    stderr = $stderrText
    stdout_lines = $stdoutLines
    stderr_lines = $stderrLines
    combined_lines = [string[]]@($stdoutLines + $stderrLines)
    timed_out = [bool]$timedOut
    timeout_seconds = [int]$TimeoutSeconds
    environment_set = [object[]]$environmentBinding.environment_set
    environment_cleared = [string[]]$environmentBinding.environment_cleared
  }
}

function Invoke-Issue13V5External(
  [object]$Config,
  [string]$Executable,
  [string[]]$Arguments,
  [string]$Label,
  [int]$TimeoutSeconds,
  [int[]]$ExpectedExitCodes = @(0),
  [string]$WorkingDirectory = $null,
  [AllowNull()][Collections.IDictionary]$Environment = $null
) {
  if ($TimeoutSeconds -le 0 -or $TimeoutSeconds -gt 2147483) {
    throw 'External command timeout must be between 1 and 2147483 seconds.'
  }
  if (@($ExpectedExitCodes).Count -eq 0) {
    throw 'External command expected exit codes cannot be empty.'
  }
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
  $environmentBinding = Set-Issue13V5ProcessStartInfoEnvironment `
    $info $Environment
  if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
    $info.WorkingDirectory = $WorkingDirectory
  }
  foreach ($argument in $Arguments) {
    $info.ArgumentList.Add([string]$argument)
  }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $info
  $processStarted = $false
  $primary = $null
  try {
    if (-not $process.Start()) {
      throw "Could not start command: $Label"
    }
    $processStarted = $true
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timeoutMilliseconds = [int]([int64]$TimeoutSeconds * 1000L)
    $timedOut = -not $process.WaitForExit($timeoutMilliseconds)
    if ($timedOut) {
      Stop-Issue13V5ExternalProcess $process
    }
    $outputTasks = [Threading.Tasks.Task[]]@($stdoutTask, $stderrTask)
    if (-not [Threading.Tasks.Task]::WaitAll($outputTasks, 30000)) {
      throw 'External command output streams did not close within 30 seconds.'
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
      environment_set = [object[]]$environmentBinding.environment_set
      environment_cleared = [object[]]$environmentBinding.environment_cleared
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
  } catch {
    $primary = $_
  }
  $cleanupFailures = [Collections.Generic.List[Exception]]::new()
  if ($processStarted) {
    try {
      Stop-Issue13V5ExternalProcess $process
    } catch {
      $cleanupFailures.Add($_.Exception)
    }
  }
  try {
    $process.Dispose()
  } catch {
    $cleanupFailures.Add($_.Exception)
  }
  if ($cleanupFailures.Count -ne 0) {
    $failures = [Collections.Generic.List[Exception]]::new()
    if ($null -ne $primary) { $failures.Add($primary.Exception) }
    foreach ($failure in $cleanupFailures) { $failures.Add($failure) }
    throw [AggregateException]::new(
      "External command lifecycle cleanup failed: $Label",
      $failures.ToArray())
  }
  if ($null -ne $primary) { throw $primary }
  if ($timedOut -or $exitCode -notin $ExpectedExitCodes) {
    throw "Command failed: $Label (exit=$exitCode, record=$recordPath)"
  }
  [pscustomobject]@{
    exit_code = $exitCode
    stdout = $stdoutText
    stderr = $stderrText
    record_path = $recordPath
    command_record = [pscustomobject]$record
  }
}

function Invoke-Issue13V5GitExternal(
  [object]$Config,
  [string[]]$Arguments,
  [string]$Label,
  [int]$TimeoutSeconds,
  [int[]]$ExpectedExitCodes = @(0),
  [string]$WorkingDirectory = $null
) {
  $lease = Enter-Issue13V5GitExecutableLease
  $binding = $lease.binding
  $execution = [pscustomobject]@{ result = $null }
  $action = {
    $execution.result = Invoke-Issue13V5External $Config `
      ([string]$binding.logical_path) $Arguments $Label $TimeoutSeconds `
      $ExpectedExitCodes $WorkingDirectory
  }
  $cleanup = {
    Exit-Issue13V5GitExecutableLease $lease
  }
  Invoke-Issue13V5WithCleanup $action $cleanup `
    "Sealed Git command lifecycle failed: $Label"
  $execution.result
}

function Invoke-Issue13V5PwshExternal(
  [object]$Config,
  [string[]]$Arguments,
  [string]$Label,
  [int]$TimeoutSeconds,
  [int[]]$ExpectedExitCodes = @(0),
  [string]$WorkingDirectory = $null,
  [AllowNull()][Collections.IDictionary]$Environment = $null
) {
  $effectiveEnvironment = [ordered]@{}
  if ($null -ne $Environment) {
    foreach ($key in @($Environment.Keys)) {
      $name = [string]$key
      if ([string]::Equals(
          $name, 'ISSUE13_V5_GIT_EXECUTABLE',
          [StringComparison]::OrdinalIgnoreCase) -or
          [string]::Equals(
          $name, 'ISSUE13_V5_RSCRIPT_EXECUTABLE',
          [StringComparison]::OrdinalIgnoreCase)) {
        throw "Reserved V5 executable environment variable: $name"
      }
      $effectiveEnvironment[$name] = $Environment[$key]
    }
  }
  $pwshLease = $null
  $gitLease = $null
  $rscriptLease = $null
  $acquisitionFailure = $null
  try {
    $pwshLease = Enter-Issue13V5PwshExecutableLease
    $gitLease = Enter-Issue13V5GitExecutableLease
    if ($Config.PSObject.Properties.Name -ccontains 'rscript') {
      $rscriptLease = Enter-Issue13V5RscriptExecutableLease `
        ([string]$Config.rscript)
    }
    $effectiveEnvironment['ISSUE13_V5_GIT_EXECUTABLE'] =
      [string]$gitLease.binding.logical_path
    if ($null -ne $rscriptLease) {
      $effectiveEnvironment['ISSUE13_V5_RSCRIPT_EXECUTABLE'] =
        [string]$rscriptLease.binding.logical_path
    }
  } catch {
    $acquisitionFailure = $_
  }
  if ($null -ne $acquisitionFailure) {
    $cleanupFailures = [Collections.Generic.List[Exception]]::new()
    foreach ($cleanupAction in [scriptblock[]]@(
        { if ($null -ne $rscriptLease) {
            Exit-Issue13V5RscriptExecutableLease $rscriptLease } },
        { if ($null -ne $gitLease) {
            Exit-Issue13V5GitExecutableLease $gitLease } },
        { if ($null -ne $pwshLease) {
            Exit-Issue13V5PwshExecutableLease $pwshLease } })) {
      try { $null = & $cleanupAction } catch {
        $cleanupFailures.Add($_.Exception)
      }
    }
    if ($cleanupFailures.Count -ne 0) {
      $failures = [Collections.Generic.List[Exception]]::new()
      $failures.Add($acquisitionFailure.Exception)
      foreach ($failure in $cleanupFailures) { $failures.Add($failure) }
      throw [AggregateException]::new(
        'Sealed pwsh authority acquisition rollback failed.',
        $failures.ToArray())
    }
    throw $acquisitionFailure
  }
  $execution = [pscustomobject]@{ result = $null }
  $action = {
    $execution.result = Invoke-Issue13V5External $Config `
      ([string]$pwshLease.binding.logical_path) $Arguments $Label `
      $TimeoutSeconds $ExpectedExitCodes $WorkingDirectory `
      $effectiveEnvironment
  }
  Invoke-Issue13V5WithCleanup $action @(
      { if ($null -ne $rscriptLease) {
          Exit-Issue13V5RscriptExecutableLease $rscriptLease } },
      { Exit-Issue13V5GitExecutableLease $gitLease },
      { Exit-Issue13V5PwshExecutableLease $pwshLease }
    ) `
    "Sealed pwsh command lifecycle failed: $Label"
  $execution.result
}

function Invoke-Issue13V5PwshTransient(
  [string[]]$Arguments,
  [string]$Label,
  [int]$TimeoutSeconds,
  [int[]]$ExpectedExitCodes = @(0),
  [string]$WorkingDirectory = $null,
  [AllowNull()][Collections.IDictionary]$Environment = $null,
  [AllowNull()][string]$RscriptPath = $null
) {
  $temporaryBase = [IO.Path]::GetFullPath(
    [IO.Path]::GetTempPath()).TrimEnd('\')
  if (-not [IO.Directory]::Exists($temporaryBase)) {
    throw 'The canonical transient pwsh parent does not exist.'
  }
  Assert-Issue13V5NoReparseAncestors `
    $temporaryBase 'transient pwsh parent'
  $temporaryBaseIdentity = Get-Issue13V5PhysicalItemIdentity `
    $temporaryBase 'transient pwsh parent'
  $temporaryLeaf = 'issue13-v5-pwsh-' + [Guid]::NewGuid().ToString('N')
  if ($temporaryLeaf -cnotmatch '^issue13-v5-pwsh-[0-9a-f]{32}$') {
    throw 'The transient pwsh leaf is not canonical.'
  }
  $temporaryRoot = [IO.Path]::GetFullPath(
    [IO.Path]::Combine($temporaryBase, $temporaryLeaf))
  if (-not [string]::Equals(
      [IO.Directory]::GetParent($temporaryRoot).FullName.TrimEnd('\'),
      $temporaryBase, [StringComparison]::OrdinalIgnoreCase) -or
      [IO.Directory]::Exists($temporaryRoot) -or
      [IO.File]::Exists($temporaryRoot)) {
    throw 'The transient pwsh root is not a fresh direct child.'
  }
  $expectedTemporaryPhysical =
    ([string]$temporaryBaseIdentity.physical_path).TrimEnd('\') +
      '\' + $temporaryLeaf
  $temporaryState = [pscustomobject]@{ root_identity = $null }
  $execution = [pscustomobject]@{
    result = $null
    command_record = $null
  }
  $action = {
    $null = [IO.Directory]::CreateDirectory($temporaryRoot)
    Assert-Issue13V5NoReparseAncestors `
      $temporaryRoot 'transient pwsh root'
    $temporaryState.root_identity = Get-Issue13V5PhysicalItemIdentity `
      $temporaryRoot 'transient pwsh root'
    if (-not [string]::Equals(
        [string]$temporaryState.root_identity.physical_path,
        $expectedTemporaryPhysical,
        [StringComparison]::OrdinalIgnoreCase)) {
      throw 'The transient pwsh root escaped its canonical parent.'
    }
    $temporaryConfig = if ([string]::IsNullOrWhiteSpace($RscriptPath)) {
      [pscustomobject]@{ control_root = $temporaryRoot }
    } else {
      [pscustomobject]@{
        control_root = $temporaryRoot
        rscript = $RscriptPath
      }
    }
    $execution.result = Invoke-Issue13V5PwshExternal $temporaryConfig `
      $Arguments $Label $TimeoutSeconds $ExpectedExitCodes `
      $WorkingDirectory $Environment
    $execution.command_record = $execution.result.command_record
  }
  $cleanup = {
    if (-not [IO.Directory]::Exists($temporaryRoot)) {
      if ($null -ne $temporaryState.root_identity) {
        throw 'The transient pwsh root disappeared before cleanup.'
      }
      return
    }
    Assert-Issue13V5NoReparseAncestors `
      $temporaryBase 'transient pwsh parent cleanup'
    $currentBaseIdentity = Get-Issue13V5PhysicalItemIdentity `
      $temporaryBase 'transient pwsh parent cleanup'
    $pendingDirectories =
      [Collections.Generic.Stack[IO.DirectoryInfo]]::new()
    $rootDirectory = [IO.DirectoryInfo]::new($temporaryRoot)
    if (($rootDirectory.Attributes -band
        [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw 'The transient pwsh root became a reparse point.'
    }
    $pendingDirectories.Push($rootDirectory)
    while ($pendingDirectories.Count -ne 0) {
      $directory = $pendingDirectories.Pop()
      foreach ($item in $directory.EnumerateFileSystemInfos()) {
        $attributes = $item.Attributes
        if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
          throw "The transient pwsh tree contains a reparse point: $($item.FullName)"
        }
        if (($attributes -band [IO.FileAttributes]::Directory) -ne 0) {
          $pendingDirectories.Push([IO.DirectoryInfo]$item)
        }
      }
    }
    $currentRootIdentity = Get-Issue13V5PhysicalItemIdentity `
      $temporaryRoot 'transient pwsh root cleanup'
    if ([string]$currentBaseIdentity.item_id -cne
          [string]$temporaryBaseIdentity.item_id -or
        -not [string]::Equals(
          [string]$currentBaseIdentity.physical_path,
          [string]$temporaryBaseIdentity.physical_path,
          [StringComparison]::OrdinalIgnoreCase) -or
        ($null -ne $temporaryState.root_identity -and
          [string]$currentRootIdentity.item_id -cne
            [string]$temporaryState.root_identity.item_id) -or
        -not [string]::Equals(
          [string]$currentRootIdentity.physical_path,
          $expectedTemporaryPhysical,
          [StringComparison]::OrdinalIgnoreCase)) {
      throw 'The transient pwsh root authority changed before cleanup.'
    }
    [IO.Directory]::Delete($temporaryRoot, $true)
    if ([IO.Directory]::Exists($temporaryRoot) -or
        [IO.File]::Exists($temporaryRoot)) {
      throw 'The transient pwsh root survived cleanup.'
    }
  }
  Invoke-Issue13V5WithCleanup $action $cleanup `
    "Transient sealed pwsh lifecycle failed: $Label"
  [pscustomobject][ordered]@{
    exit_code = [int]$execution.result.exit_code
    stdout = [string]$execution.result.stdout
    stderr = [string]$execution.result.stderr
    command_record = $execution.command_record
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
  $rscriptLease = Enter-Issue13V5RscriptExecutableLease `
    ([string]$Config.rscript)
  $execution = [pscustomobject]@{ result = $null }
  $action = {
    $environment = New-Issue13V5ClosedREnvironment `
      ([string]$Config.r_library)
    $execution.result = Invoke-Issue13V5External `
      $Config ([string]$rscriptLease.binding.logical_path) `
      $Arguments $Label $TimeoutSeconds $ExpectedExitCodes `
      ([string]$Config.repository_root) $environment
  }
  $null = Invoke-Issue13V5WithCleanup `
    -Action $action `
    -Cleanup @(
      { $null = Assert-Issue13V5NoConcurrentR $Config },
      { $null = Assert-Issue13V5HarnessBinding $Config },
      { Exit-Issue13V5RscriptExecutableLease $rscriptLease }
    ) `
    -Label $Label
  $execution.result
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
  $execution = [pscustomobject]@{ result = $null }
  $action = {
    $environment = New-Issue13V5ClosedREnvironment `
      ([string]$Config.r_library)
    $execution.result = Invoke-Issue13V5PwshExternal `
      $Config $Arguments $Label `
      $TimeoutSeconds @(0) ([string]$Config.repository_root) `
      $environment
  }
  $null = Invoke-Issue13V5WithCleanup `
    -Action $action `
    -Cleanup @(
      { $null = Assert-Issue13V5NoConcurrentR $Config },
      { $null = Assert-Issue13V5HarnessBinding $Config }
    ) `
    -Label $Label
  $execution.result
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
  $null = Assert-Issue13V5OracleEffectControlRecord $Config $state
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
  $null = Assert-Issue13V5OracleEffectControlRecord $Config $State
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

function Assert-Issue13V5ScenarioStateHashes(
  [string]$Directory,
  [string]$ExpectedResultSha256,
  [string]$ExpectedMetricsSha256,
  [string]$Label
) {
  $root = (Resolve-Path -LiteralPath $Directory).Path
  $resultPath = Join-Path $root 'scenario-result.json'
  $metricsPath = Join-Path $root 'process-metrics.json'
  if ($ExpectedResultSha256 -cnotmatch '^[0-9a-f]{64}$' -or
      $ExpectedMetricsSha256 -cnotmatch '^[0-9a-f]{64}$' -or
      (Get-Issue13V5Sha256 $resultPath) -cne $ExpectedResultSha256 -or
      (Get-Issue13V5Sha256 $metricsPath) -cne $ExpectedMetricsSha256) {
    throw "Scenario state hash changed: $Label"
  }
  $metrics = Read-Issue13V5Json $metricsPath
  $expectedSamples = ConvertTo-Issue13V5Path (
    Join-Path $root 'process-samples.csv')
  $recordedSamplesName = [IO.Path]::GetFileName(
    ([string]$metrics.samples_path).Replace('/', '\'))
  if ($recordedSamplesName -cne 'process-samples.csv' -or
      [string]$metrics.samples_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      (Get-Issue13V5Sha256 $expectedSamples) -cne
        [string]$metrics.samples_sha256) {
    throw "Scenario samples are not anchored by the state-bound metrics: $Label"
  }
  foreach ($binding in @(
      @($metrics.stdout_path, $metrics.stdout_sha256, 'stdout'),
      @($metrics.stderr_path, $metrics.stderr_sha256, 'stderr'),
      @($metrics.process_spec_path, $metrics.process_spec_sha256,
        'process spec')
    )) {
    if ([string]$binding[1] -cnotmatch '^[0-9a-f]{64}$' -or
        (Get-Issue13V5Sha256 ([string]$binding[0])) -cne
          [string]$binding[1]) {
      throw "Scenario $($binding[2]) changed: $Label"
    }
  }
  if ((Get-Issue13V5Sha256 $resultPath) -cne $ExpectedResultSha256 -or
      (Get-Issue13V5Sha256 $metricsPath) -cne $ExpectedMetricsSha256 -or
      (Get-Issue13V5Sha256 $expectedSamples) -cne
        [string]$metrics.samples_sha256) {
    throw "Scenario evidence changed during authentication: $Label"
  }
  $true
}

function Assert-Issue13V5PhaseEvidenceState(
  [object]$Config,
  [object]$Phase,
  [switch]$RequireCompletedComparison
) {
  foreach ($arm in @('baseline', 'candidate')) {
    $status = [string]$Phase.($arm + '_status')
    $directory = [string]$Phase.($arm + '_evidence')
    $resultSha = [string]$Phase.($arm + '_result_sha256')
    $metricsSha = [string]$Phase.($arm + '_metrics_sha256')
    if ($status -cne 'executed') {
      throw "Phase arm is not state-bound as executed: $($Phase.phase)/$arm"
    }
    $expectedDirectory = ConvertTo-Issue13V5Path (
      Get-Issue13V5ScenarioDirectory $Config "$arm/$($Phase.phase)")
    if (-not [string]::Equals(
        (ConvertTo-Issue13V5Path $directory), $expectedDirectory,
        [StringComparison]::OrdinalIgnoreCase)) {
      throw "Phase evidence directory changed: $($Phase.phase)/$arm"
    }
    $null = Assert-Issue13V5ScenarioStateHashes $directory $resultSha `
      $metricsSha "$($Phase.phase)/$arm"
  }
  if (-not $RequireCompletedComparison) { return $true }
  if ([string]$Phase.comparison_status -cne 'completed') {
    throw "Phase comparison is not complete: $($Phase.phase)"
  }
  $records = @($Phase.comparisons)
  $expectedCount = if ([string]$Phase.kind -ceq 'prepare') {
    3
  } elseif ([string]$Phase.kind -ceq 'recalculate' -or
      ([string]$Phase.kind -ceq 'calculate' -and
        [long]$Phase.workers -eq 2L)) {
    3
  } else { 1 }
  if ($records.Count -ne $expectedCount -or
      @($records.id | Sort-Object -Unique).Count -ne $expectedCount) {
    throw "Phase comparison coverage changed: $($Phase.phase)"
  }
  foreach ($record in $records) {
    $expectedDirectory = ConvertTo-Issue13V5Path (
      Get-Issue13V5ComparisonDirectory $Config ([string]$record.id))
    if (-not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$record.directory)),
        $expectedDirectory, [StringComparison]::OrdinalIgnoreCase) -or
        [string]$record.comparison_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        (Get-Issue13V5Sha256 (
          Join-Path $expectedDirectory 'comparison.json')) -cne
          [string]$record.comparison_sha256) {
      throw "Phase comparison changed: $($record.id)"
    }
  }
  $expectedPairPath = ConvertTo-Issue13V5Path (
    Join-Path (Join-Path ([string]$Config.control_root) 'pair-results') `
      ('p' + ([long]$Phase.ordinal).ToString('000') + '.json'))
  if (-not [string]::Equals(
      (ConvertTo-Issue13V5Path ([string]$Phase.pair_result_path)),
      $expectedPairPath, [StringComparison]::OrdinalIgnoreCase) -or
      [string]$Phase.pair_result_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      (Get-Issue13V5Sha256 $expectedPairPath) -cne
        [string]$Phase.pair_result_sha256) {
    throw "Phase pair-result changed: $($Phase.phase)"
  }
  $pair = Read-Issue13V5Json $expectedPairPath
  if ([string]$pair.schema -cne 'wlv-issue13-v5-pair/1' -or
      [string]$pair.status -cne 'passed' -or
      [long]$pair.ordinal -ne [long]$Phase.ordinal -or
      [string]$pair.phase -cne [string]$Phase.phase -or
      @($pair.comparisons).Count -ne $records.Count) {
    throw "Phase pair-result envelope changed: $($Phase.phase)"
  }
  for ($index = 0; $index -lt $records.Count; $index++) {
    if ([string]$pair.comparisons[$index].id -cne
          [string]$records[$index].id -or
        [string]$pair.comparisons[$index].comparison_sha256 -cne
          [string]$records[$index].comparison_sha256) {
      throw "Phase pair-result comparison binding changed: $($Phase.phase)"
    }
  }
  $true
}

function Assert-Issue13V5PrepFaultEvidenceState(
  [object]$Config,
  [object]$State,
  [switch]$BeforeAggregate
) {
  $workflow = $State.prep_fault
  if ([string]$workflow.plan_status -cne 'built') {
    throw 'Preparation/fault plan is not state-bound.'
  }
  foreach ($binding in @(
      @($workflow.plan_path, $workflow.plan_sha256,
        (Join-Path ([string]$Config.control_root) 'prep-fault-plan\plan.json'),
        'plan'),
      @($workflow.plan_audit_path, $workflow.plan_audit_sha256,
        (Join-Path ([string]$Config.control_root) `
          'prep-fault-plan\plan-audit.json'), 'plan audit'),
      @($workflow.preparation_comparison_path,
        $workflow.preparation_comparison_sha256,
        (Join-Path ([string]$Config.control_root) `
          'preparation-comparison\issue13-preparation-comparison.json'),
        'preparation comparison'),
      @($workflow.import_report_path, $workflow.import_report_sha256,
        (Join-Path ([string]$Config.control_root) `
          'fault-inputs\fault-input-import.json'), 'fault import'),
      @($workflow.seed_plan_path, $workflow.seed_plan_sha256,
        (Join-Path ([string]$Config.control_root) `
          'fault-seeds\seed-plan.json'), 'fault seed plan')
    )) {
    $expectedPath = ConvertTo-Issue13V5Path ([string]$binding[2])
    if (-not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$binding[0])), $expectedPath,
        [StringComparison]::OrdinalIgnoreCase) -or
        [string]$binding[1] -cnotmatch '^[0-9a-f]{64}$' -or
        (Get-Issue13V5Sha256 $expectedPath) -cne [string]$binding[1]) {
      throw "Preparation/fault evidence changed: $($binding[3])"
    }
  }
  $plan = Read-Issue13V5Json ([string]$workflow.plan_path)
  $audit = Read-Issue13V5Json ([string]$workflow.plan_audit_path)
  if ([string]$audit.plan_sha256 -cne [string]$workflow.plan_sha256 -or
      @($plan.records).Count -ne 12) {
    throw 'Preparation/fault plan audit binding changed.'
  }
  foreach ($record in @($plan.records)) {
    foreach ($specBinding in @(
        @($record.scenario_spec_path, $record.scenario_spec_sha256,
          'scenario spec'),
        @($record.process_spec_path, $record.process_spec_sha256,
          'process spec')
      )) {
      if ([string]$specBinding[1] -cnotmatch '^[0-9a-f]{64}$' -or
          (Get-Issue13V5Sha256 ([string]$specBinding[0])) -cne
            [string]$specBinding[1]) {
        throw "Preparation/fault $($specBinding[2]) changed: $($record.scenario_id)"
      }
    }
  }
  $seeds = @($workflow.seed_evidence)
  if ([string]$workflow.seeds_status -cne 'executed' -or
      $seeds.Count -ne 10 -or
      @($seeds.scenario_id | Sort-Object -Unique).Count -ne 10) {
    throw 'Preparation/fault seed evidence coverage changed.'
  }
  foreach ($seed in $seeds) {
    $current = Get-Issue13V5TreeInventory ([string]$seed.root)
    $null = Assert-Issue13V5InventoryBinding $seed.inventory $current `
      "Fault seed $($seed.scenario_id)"
  }
  $faults = @($workflow.faults)
  if ($faults.Count -ne 10 -or
      @($faults | Where-Object status -cne 'executed').Count -ne 0) {
    throw 'Preparation/fault scenario state coverage changed.'
  }
  foreach ($fault in $faults) {
    $expectedDirectory = ConvertTo-Issue13V5Path (
      Get-Issue13V5ScenarioDirectory $Config ([string]$fault.scenario_id))
    if (-not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$fault.evidence)),
        $expectedDirectory, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Fault evidence path changed: $($fault.fault_id)"
    }
    $null = Assert-Issue13V5ScenarioStateHashes $expectedDirectory `
      ([string]$fault.result_sha256) ([string]$fault.metrics_sha256) `
      ([string]$fault.scenario_id)
  }
  if ($BeforeAggregate) {
    if ([string]$workflow.aggregate_status -cne 'planned' -or
        $null -ne $workflow.aggregate_path -or
        $null -ne $workflow.aggregate_sha256) {
      throw 'Preparation/fault aggregate state is not pristine.'
    }
    return $true
  }
  $aggregatePath = ConvertTo-Issue13V5Path (
    Join-Path ([string]$Config.control_root) `
      'prep-fault-aggregate\prep-fault-aggregate.json')
  if ([string]$workflow.aggregate_status -cne 'passed' -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$workflow.aggregate_path)),
        $aggregatePath, [StringComparison]::OrdinalIgnoreCase) -or
      [string]$workflow.aggregate_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
      (Get-Issue13V5Sha256 $aggregatePath) -cne
        [string]$workflow.aggregate_sha256) {
    throw 'Preparation/fault aggregate changed.'
  }
  $true
}

function Assert-Issue13V5CompletedEvidenceState(
  [object]$Config,
  [object]$State
) {
  if (@($State.phases).Count -ne 76) {
    throw 'Completed evidence state does not contain exactly 76 phases.'
  }
  foreach ($phase in @($State.phases)) {
    $null = Assert-Issue13V5PhaseEvidenceState $Config $phase `
      -RequireCompletedComparison
  }
  $null = Assert-Issue13V5PrepFaultEvidenceState $Config $State
  $true
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
      [string]$Config.baseline_overlay.patch_id,
      [string]$Config.oracle_effect.proof.sha256,
      [string]$Config.oracle_effect.oracle_smoke.sha256,
      [string]$Config.oracle_effect.comparisons.inventory.inventory_sha256,
      [string]$Config.oracle_effect.comparisons.primary.inventory.
        inventory_sha256,
      [string]$Config.oracle_effect.comparisons.replay.inventory.
        inventory_sha256,
      [string]$Config.oracle_effect.comparison_harness.manifest_sha256,
      [string]$State.oracle_effect.control_record_sha256
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
  $oracleEffectValidation = Invoke-Issue13V5OracleEffectValidation $Config
  $null = Assert-Issue13V5OracleEffectControlRecord $Config $State `
    $oracleEffectValidation
  $null = Assert-Issue13V5CompletedEvidenceState $Config $State
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
      -not (Test-Issue13V5ExactBoolean $result.passed $true) -or
      [string]$result.status -cne 'passed' -or
      [string]$result.observed_commit -cne $Commit -or
      [string]$metrics.schema -cne 'wlv-issue13-process-metrics/2' -or
      [string]$metrics.scenario_id -cne $ScenarioId -or
      -not (Test-Issue13V5ExactBoolean $metrics.passed $true) -or
      -not (Test-Issue13V5ExactBoolean $metrics.cluster_closed $true) -or
      @($metrics.lingering_pids).Count -ne 0 -or
      [long]$metrics.expected_worker_processes -ne $ExpectedWorkers -or
      [long]$metrics.max_concurrent_worker_processes -ne $ExpectedWorkers -or
      -not (Test-Issue13V5ExactBoolean `
        $metrics.worker_count_matched $true)) {
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
