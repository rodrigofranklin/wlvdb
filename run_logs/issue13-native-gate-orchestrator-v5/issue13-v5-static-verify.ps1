param(
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')]
  [string]$CandidateCommit,
  [string]$HarnessRuntimeRoot =
    'D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5',
  [string]$RepositoryRoot = 'D:\Trabalho\Code\wlvdb'
)

$issue13AliasCollisionPreflight = {
  param([Parameter(Mandatory = $true)][string]$StaticPath)
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

  if ([string]::IsNullOrWhiteSpace($StaticPath)) {
    throw 'Static verifier path is unavailable during command preflight.'
  }
  $staticFull = [IO.Path]::GetFullPath($StaticPath)
  if (-not [IO.File]::Exists($staticFull)) {
    throw 'Static verifier source is absent during command preflight.'
  }
  $controllerRoot = [IO.Path]::GetDirectoryName($staticFull)
  $repositoryRoot = [IO.Path]::GetDirectoryName(
    [IO.Path]::GetDirectoryName($controllerRoot))
  if ([string]::IsNullOrWhiteSpace($repositoryRoot) -or
      -not [IO.Directory]::Exists($repositoryRoot)) {
    throw 'Repository root is unavailable during command preflight.'
  }
  $entrypointRelativePaths = [string[]]@(
    'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-attest-delivery.ps1',
    'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-baseline-smoke.ps1',
    'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-capture-clean-bridge-evidence.ps1',
    'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-capture-clean-stage5-evidence.ps1',
    'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-coordinator-lib.ps1',
    'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-coordinator.ps1',
    'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-materialize-harness.ps1',
    'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-new-config.ps1',
    'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-oracle-effect-generate.ps1',
    'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-oracle-effect-lib.ps1',
    'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-oracle-effect-validate.ps1',
    'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-render-report.ps1',
    'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-monitor-selftest.ps1',
    'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-monitor.ps1',
    'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-run-fault-seed-record.ps1',
    'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-run-fault-seeds.ps1',
    'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-run-plan.ps1',
    'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-run-prep-fault-record.ps1',
    'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-run-recalc-bundle.ps1'
  )
  if ($entrypointRelativePaths.Count -ne 19) {
    throw 'Command-preflight entrypoint allowlist is not exact.'
  }
  $sourcePaths = [Collections.Generic.List[string]]::new()
  $sourcePaths.Add($staticFull)
  $seenSourcePaths = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  $null = $seenSourcePaths.Add($staticFull)
  foreach ($entrypointRelativePath in $entrypointRelativePaths) {
    $sourcePath = [IO.Path]::GetFullPath(
      [IO.Path]::Combine(
        $repositoryRoot,
        $entrypointRelativePath.Replace('/',
          [IO.Path]::DirectorySeparatorChar)))
    if (-not $sourcePath.StartsWith(
          $repositoryRoot + [IO.Path]::DirectorySeparatorChar,
          [StringComparison]::OrdinalIgnoreCase) -or
        -not $seenSourcePaths.Add($sourcePath)) {
      throw ('Command-preflight entrypoint escaped or duplicated: ' +
        $entrypointRelativePath)
    }
    if (-not [IO.File]::Exists($sourcePath)) {
      throw "Command-preflight source is absent: $entrypointRelativePath"
    }
    $sourcePaths.Add($sourcePath)
  }
  $commandAsts = [Collections.Generic.List[object]]::new()
  $utf8 = [Text.UTF8Encoding]::new($false, $true)
  foreach ($sourcePath in $sourcePaths) {
    $sourceBytes = [IO.File]::ReadAllBytes($sourcePath)
    $sourceText = $utf8.GetString($sourceBytes)
    $tokens = [Management.Automation.Language.Token[]]@()
    $parseErrors = [Management.Automation.Language.ParseError[]]@()
    $sourceAst = [Management.Automation.Language.Parser]::ParseInput(
      $sourceText, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -ne 0 -or $null -eq $sourceAst) {
      throw ('Command-preflight parser rejected ' +
        [IO.Path]::GetFileName($sourcePath) + '.')
    }
    foreach ($commandAst in $sourceAst.FindAll(
        [Func[Management.Automation.Language.Ast, bool]]{
          param($node)
          $node -is [Management.Automation.Language.CommandAst]
        }, $true)) {
      $commandAsts.Add($commandAst)
    }
  }
  $names = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  $collisions = [Collections.Generic.List[string]]::new()
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
  if (-not $names.Contains('Assert-Issue13V5HarnessBinding') -or
      -not $names.Contains('Resolve-Path') -or
      -not $names.Contains('Set-StrictMode')) {
    throw 'Command preflight did not discover its critical surface.'
  }
  [pscustomobject][ordered]@{
    source_count = [int]$sourcePaths.Count
    entrypoint_count = [int]$entrypointRelativePaths.Count
    command_name_count = [int]$names.Count
    mutable_command_type_count = 3
    resolved_cmdlet_count = [int]$resolvedTrustedCmdlets.Count
    trusted_cmdlet_assembly_count = [int]$trustedCmdletAssemblies.Count
    trusted_runtime_file_count = [int]$trustedRuntimeFiles.Count
    runtime_file_lease_count = [int]$runtimeFileLeases.Count
    resolve_path_protected = [bool]$names.Contains('Resolve-Path')
    set_strict_mode_protected = [bool]$names.Contains('Set-StrictMode')
  }}
$issue13AliasCollisionPreflightResult =
  $issue13AliasCollisionPreflight.InvokeReturnAsIs(
    [object[]]@([string]$PSCommandPath))
if ($null -eq $issue13AliasCollisionPreflightResult -or
    [int]$issue13AliasCollisionPreflightResult.source_count -ne 20 -or
    [int]$issue13AliasCollisionPreflightResult.entrypoint_count -ne 19 -or
    [int]$issue13AliasCollisionPreflightResult.command_name_count -le 0 -or
    [int]$issue13AliasCollisionPreflightResult.mutable_command_type_count -ne
      3 -or
    [int]$issue13AliasCollisionPreflightResult.resolved_cmdlet_count -ne 44 -or
    [int]$issue13AliasCollisionPreflightResult.trusted_cmdlet_assembly_count -ne
      4 -or
    [int]$issue13AliasCollisionPreflightResult.trusted_runtime_file_count -ne
      11 -or
    [int]$issue13AliasCollisionPreflightResult.runtime_file_lease_count -ne
      11 -or
    -not [bool]$issue13AliasCollisionPreflightResult.resolve_path_protected -or
    -not [bool](
      $issue13AliasCollisionPreflightResult.set_strict_mode_protected)) {
  throw 'Alias-collision preflight returned an invalid result.'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$bootstrapSourceSha256 = @{
  'issue13-v5-attest-delivery.ps1' =
    '2E1A9D527AB98C3EFCF296DB56E59FCE34461C9A7A0A979044EC70E2B54B981D'
  'issue13-v5-baseline-smoke.ps1' =
    '0F040EB03F3A7AEEFAACF6B0437C5C12D11A3803C9C163B5134D22D928CF3DF6'
  'issue13-v5-capture-clean-bridge-evidence.ps1' =
    'A78F5C6535ADFF09F4248F1EA192F0058DCF4B129A0295E1C04357BC1747B6E6'
  'issue13-v5-capture-clean-stage5-evidence.ps1' =
    'EDCFCE9759F8B73E2368A36ABA309FA3D330C91C417249D49B69A4194768BFF8'
  'issue13-v5-coordinator-lib.ps1' =
    'A99CDED9165CCAC9A93A1AF640FB0DC850C26A815A1C694294E7B5DC5A8F47A5'
  'issue13-v5-coordinator.ps1' =
    '57A284A2600AAC37B5879BA44EB6B4AB1953AB00590D4EA6720524195E0EBF28'
  'issue13-v5-materialize-harness.ps1' =
    '8CBD99EA71B7C21DAB3CAF66E0BB79729C91557982AA9A9B93DD0AF90EB309C7'
  'issue13-v5-new-config.ps1' =
    '221ED165A1EE746A296C881C9E104612FB5E0A97803C68490F544F6ADED68AEF'
  'issue13-v5-oracle-effect-generate.ps1' =
    '6C1E26154794A253974B7E51C5D15B054AE2D31E09736BF19B624F56EA3C30F9'
  'issue13-v5-oracle-effect-lib.ps1' =
    '6CCA4757A9754D5DC778200EE37901D232A45A94021E36200BAA53334CEA5290'
  'issue13-v5-oracle-effect-validate.ps1' =
    '11912422CEB54A45A791E49E11688F974AB45A4CC0F2FB89145D90176AAB0140'
  'issue13-v5-render-report.ps1' =
    'F7B11D7CD0AF8F867467AED19D220E135C6F69D6416413C81FC2AFDCD842153B'
}
$bootstrapSourceTexts = @{}
$bootstrapSourceAsts = @{}
$bootstrapSourceFileSha256 = @{}
$bootstrapEncoding = [Text.UTF8Encoding]::new($false, $true)
foreach ($bootstrapName in @($bootstrapSourceSha256.Keys | Sort-Object)) {
  $bootstrapPath = Join-Path $root $bootstrapName
  $bootstrapBytes = [IO.File]::ReadAllBytes($bootstrapPath)
  $bootstrapHash = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($bootstrapBytes))
  if ($bootstrapHash -cne [string]$bootstrapSourceSha256[$bootstrapName]) {
    throw "Static bootstrap source is not byte-authenticated: $bootstrapName"
  }
  $bootstrapSourceTexts[$bootstrapName] =
    $bootstrapEncoding.GetString($bootstrapBytes)
  $bootstrapTokens = $null
  $bootstrapErrors = $null
  $bootstrapSourceAsts[$bootstrapName] =
    [Management.Automation.Language.Parser]::ParseInput(
      $bootstrapSourceTexts[$bootstrapName],
      [ref]$bootstrapTokens, [ref]$bootstrapErrors)
  if ($bootstrapErrors.Count -ne 0) {
    throw "Static bootstrap parser rejected: $bootstrapName"
  }
  $bootstrapSourceFileSha256[$bootstrapName] = $bootstrapHash
}
$bootstrapStaticName = 'issue13-v5-static-verify.ps1'
$bootstrapStaticPath = Join-Path $root $bootstrapStaticName
$bootstrapStaticBytes = [IO.File]::ReadAllBytes($bootstrapStaticPath)
$bootstrapStaticText = $bootstrapEncoding.GetString($bootstrapStaticBytes)
$bootstrapStaticAst = $MyInvocation.MyCommand.ScriptBlock.Ast
if ($null -eq $bootstrapStaticAst -or
    $bootstrapStaticText -cne $bootstrapStaticAst.Extent.Text) {
  throw 'Executing static verifier differs from its on-disk source.'
}
$aliasPreflightStatements = @($bootstrapStaticAst.EndBlock.Statements)
if ($aliasPreflightStatements.Count -lt 4 -or
    $aliasPreflightStatements[0] -isnot
      [Management.Automation.Language.AssignmentStatementAst] -or
    $aliasPreflightStatements[0].Left -isnot
      [Management.Automation.Language.VariableExpressionAst] -or
    $aliasPreflightStatements[0].Left.VariablePath.UserPath -cne
      'issue13AliasCollisionPreflight' -or
    $aliasPreflightStatements[0].Right -isnot
      [Management.Automation.Language.CommandExpressionAst] -or
    $aliasPreflightStatements[0].Right.Expression -isnot
      [Management.Automation.Language.ScriptBlockExpressionAst] -or
    $aliasPreflightStatements[1] -isnot
      [Management.Automation.Language.AssignmentStatementAst] -or
    $aliasPreflightStatements[1].Left -isnot
      [Management.Automation.Language.VariableExpressionAst] -or
    $aliasPreflightStatements[1].Left.VariablePath.UserPath -cne
      'issue13AliasCollisionPreflightResult' -or
    $aliasPreflightStatements[1].Right -isnot
      [Management.Automation.Language.CommandExpressionAst] -or
    $aliasPreflightStatements[1].Right.Expression -isnot
      [Management.Automation.Language.InvokeMemberExpressionAst] -or
    $aliasPreflightStatements[1].Right.Expression.Member.Value -cne
      'InvokeReturnAsIs' -or
    $aliasPreflightStatements[2] -isnot
      [Management.Automation.Language.IfStatementAst] -or
    $aliasPreflightStatements[3] -isnot
      [Management.Automation.Language.PipelineAst] -or
    $aliasPreflightStatements[3].PipelineElements.Count -ne 1 -or
    $aliasPreflightStatements[3].PipelineElements[0] -isnot
      [Management.Automation.Language.CommandAst] -or
    $aliasPreflightStatements[3].PipelineElements[0].GetCommandName() -cne
      'Set-StrictMode') {
  throw 'Alias-collision preflight is not the first executable logic.'
}
$aliasPreflightBodyCommands = @(
  $aliasPreflightStatements[0].Right.Expression.ScriptBlock.FindAll(
    {
      param($node)
      $node -is [Management.Automation.Language.CommandAst]
    }, $true))
$aliasPreflightValidationCommands = @(
  $aliasPreflightStatements[1].FindAll(
    {
      param($node)
      $node -is [Management.Automation.Language.CommandAst]
    }, $true)) + @(
  $aliasPreflightStatements[2].FindAll(
    {
      param($node)
      $node -is [Management.Automation.Language.CommandAst]
    }, $true))
$aliasPreflightFirstCommand =
  $aliasPreflightStatements[3].PipelineElements[0]
$aliasPreflightEarlierCommands =
  [Collections.Generic.List[
    Management.Automation.Language.CommandAst]]::new()
$aliasPreflightAllCommands = $bootstrapStaticAst.FindAll(
  {
    param($node)
    $node -is [Management.Automation.Language.CommandAst]
  }, $true)
foreach ($aliasPreflightCommand in $aliasPreflightAllCommands) {
  if ($aliasPreflightCommand.Extent.StartOffset -lt
      $aliasPreflightFirstCommand.Extent.StartOffset) {
    $aliasPreflightEarlierCommands.Add($aliasPreflightCommand)
  }
}
if ($aliasPreflightBodyCommands.Count -ne 1 -or
    $aliasPreflightValidationCommands.Count -ne 0 -or
    $aliasPreflightEarlierCommands.Count -ne 1 -or
    -not [object]::ReferenceEquals(
      $aliasPreflightBodyCommands[0], $aliasPreflightEarlierCommands[0]) -or
    $aliasPreflightBodyCommands[0].InvocationOperator -ne
      [Management.Automation.Language.TokenKind]::Ampersand -or
    -not [string]::IsNullOrWhiteSpace(
      $aliasPreflightBodyCommands[0].GetCommandName()) -or
    [regex]::Replace(
      $aliasPreflightBodyCommands[0].Extent.Text, '[\s`]', '') -cne
      '&$importModuleCmdlet-Name$manifest-Global-Force-ErrorActionStop') {
  throw 'Alias-collision preflight contains or follows a bare command.'
}
$bootstrapSourceTexts[$bootstrapStaticName] = $bootstrapStaticText
$bootstrapSourceAsts[$bootstrapStaticName] = $bootstrapStaticAst
$bootstrapSourceFileSha256[$bootstrapStaticName] = [Convert]::ToHexString(
  [Security.Cryptography.SHA256]::HashData($bootstrapStaticBytes))
$bootstrapOracleScript = [scriptblock]::Create(
  '$PSScriptRoot = $root' + "`n" +
    $bootstrapSourceTexts['issue13-v5-oracle-effect-lib.ps1'])
. $bootstrapOracleScript
if (-not [string]::Equals(
      [string]$script:Issue13V5CoordinatorRoot, $root,
      [StringComparison]::OrdinalIgnoreCase) -or
    -not [string]::Equals(
      [string]$script:Issue13OracleEffectControllerRoot, $root,
      [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Authenticated static bootstrap resolved an unexpected controller root.'
}
$aliasCollisionMutants = [object[]]@(
  [pscustomobject][ordered]@{
    name = 'alias_resolve_path_case_insensitive'
    entry =
      [Management.Automation.Runspaces.SessionStateAliasEntry]::new(
        'rEsOlVe-PaTh', 'Write-Output',
        'Issue #13 alias-collision mutant')
    expected = 'Alias:rEsOlVe-PaTh'
  },
  [pscustomobject][ordered]@{
    name = 'function_resolve_path_case_insensitive'
    entry =
      [Management.Automation.Runspaces.SessionStateFunctionEntry]::new(
        'ReSoLvE-pAtH', "throw 'FUNCTION_RESOLVE_PATH_MUTANT_EXECUTED'",
        'Issue #13 function-collision mutant')
    expected = 'Function:ReSoLvE-pAtH, Filter:ReSoLvE-pAtH'
  },
  [pscustomobject][ordered]@{
    name = 'function_set_strict_mode_case_insensitive'
    entry =
      [Management.Automation.Runspaces.SessionStateFunctionEntry]::new(
        'sEt-StRiCtMoDe',
        "throw 'FUNCTION_SET_STRICT_MODE_MUTANT_EXECUTED'",
        'Issue #13 first-command collision mutant')
    expected = 'Function:sEt-StRiCtMoDe, Filter:sEt-StRiCtMoDe'
  }
)
$aliasCollisionMutantScript = @'
param(
  [Parameter(Mandatory = $true)][string]$PreflightText,
  [Parameter(Mandatory = $true)][string]$StaticPath
)
$preflight = [scriptblock]::Create($PreflightText)
try {
  $null = $preflight.InvokeReturnAsIs([object[]]@($StaticPath))
  'ALIAS_MUTANT_ACCEPTED'
} catch {
  'ALIAS_MUTANT_REJECTED:' +
    [string]$_.Exception.GetBaseException().Message
}
'@
foreach ($aliasCollisionMutant in $aliasCollisionMutants) {
  $aliasCollisionMutantInitialState =
    [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
  $aliasCollisionMutantInitialState.Commands.Add(
    $aliasCollisionMutant.entry)
  $aliasCollisionMutantRunspace =
    [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace(
      $aliasCollisionMutantInitialState)
  $aliasCollisionMutantPowerShell =
    [Management.Automation.PowerShell]::Create()
  try {
    $aliasCollisionMutantRunspace.Open()
    $aliasCollisionMutantPowerShell.Runspace = $aliasCollisionMutantRunspace
    $null = $aliasCollisionMutantPowerShell.AddScript(
      $aliasCollisionMutantScript)
    $null = $aliasCollisionMutantPowerShell.AddArgument(
      [string]$issue13AliasCollisionPreflight.ToString())
    $null = $aliasCollisionMutantPowerShell.AddArgument(
      [string]$PSCommandPath)
    $aliasCollisionMutantResult = @(
      $aliasCollisionMutantPowerShell.Invoke())
    $expectedAliasCollision =
      'ALIAS_MUTANT_REJECTED:V5 command collision bootstrap rejected ' +
        'inherited commands: ' +
        [string]$aliasCollisionMutant.expected
    if ($aliasCollisionMutantPowerShell.HadErrors -or
        $aliasCollisionMutantResult.Count -ne 1 -or
        [string]$aliasCollisionMutantResult[0] -ceq
          'ALIAS_MUTANT_ACCEPTED' -or
        -not [string]::Equals(
          [string]$aliasCollisionMutantResult[0],
          $expectedAliasCollision,
          [StringComparison]::OrdinalIgnoreCase)) {
      throw ('Alias-collision preflight accepted or mishandled mutant: ' +
        [string]$aliasCollisionMutant.name + '; observed=' +
        [string]::Join(' | ', [string[]]$aliasCollisionMutantResult))
    }
  } finally {
    $aliasCollisionMutantPowerShell.Dispose()
    $aliasCollisionMutantRunspace.Dispose()
  }
}
function Get-Issue13V5BootstrapDeliveryResolverDefinitions(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  @($Ast.FindAll({
    param($node)
    if ($node -isnot
        [Management.Automation.Language.FunctionDefinitionAst]) {
      return $false
    }
    $leaf = @(([string]$node.Name).Split('\'))[-1]
    $leaf = @($leaf.Split(':'))[-1]
    $leaf -ieq 'Resolve-Issue13V5DeliveryOutput'
  }, $true))
}
$bootstrapDeliveryResolverDefinitions = @(
  Get-Issue13V5BootstrapDeliveryResolverDefinitions `
    $bootstrapSourceAsts['issue13-v5-attest-delivery.ps1']
)
if ($bootstrapDeliveryResolverDefinitions.Count -ne 1 -or
    $bootstrapDeliveryResolverDefinitions[0].Name -cne
      'Resolve-Issue13V5DeliveryOutput' -or
    $bootstrapDeliveryResolverDefinitions[0].Parent -isnot
      [Management.Automation.Language.NamedBlockAst] -or
    -not [object]::ReferenceEquals(
      $bootstrapDeliveryResolverDefinitions[0].Parent.Parent,
      $bootstrapSourceAsts['issue13-v5-attest-delivery.ps1'])) {
  throw 'Authenticated delivery resolver definition is missing or nested.'
}
$bootstrapDeliveryResolverScript = [scriptblock]::Create(
  [string]$bootstrapDeliveryResolverDefinitions[0].Extent.Text)
. $bootstrapDeliveryResolverScript
$bootstrapDeliveryMutantTokens = $null
$bootstrapDeliveryMutantErrors = $null
$bootstrapDeliveryMutantAst =
  [Management.Automation.Language.Parser]::ParseInput(
    ('function Resolve-Issue13V5DeliveryOutput {}' + "`n" +
      'function local:rEsOlVe-IsSuE13v5dElIvErYoUtPuT {}'),
    [ref]$bootstrapDeliveryMutantTokens,
    [ref]$bootstrapDeliveryMutantErrors)
if ($bootstrapDeliveryMutantErrors.Count -ne 0 -or
    @(Get-Issue13V5BootstrapDeliveryResolverDefinitions `
      $bootstrapDeliveryMutantAst).Count -ne 2) {
  throw 'Authenticated delivery resolver matcher ignored a scoped/case collision.'
}
foreach ($bootstrapName in @($bootstrapSourceSha256.Keys | Sort-Object)) {
  $bootstrapPath = Join-Path $root $bootstrapName
  $bootstrapHash = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
      [IO.File]::ReadAllBytes($bootstrapPath)))
  if ($bootstrapHash -cne [string]$bootstrapSourceSha256[$bootstrapName]) {
    throw "Static bootstrap source changed while loading: $bootstrapName"
  }
}

$scripts = @(
  'issue13-v5-baseline-smoke.ps1',
  'issue13-v5-materialize-harness.ps1',
  'issue13-v5-new-config.ps1',
  'issue13-v5-coordinator-lib.ps1',
  'issue13-v5-coordinator.ps1',
  'issue13-v5-render-report.ps1',
  'issue13-v5-static-verify.ps1'
)
$oracleEffectFiles = @(
  'issue13-v5-oracle-effect-README.md',
  'issue13-v5-oracle-effect-generate.ps1',
  'issue13-v5-oracle-effect-lib.ps1',
  'issue13-v5-oracle-effect-proof.schema.json',
  'issue13-v5-oracle-effect-spec.json',
  'issue13-v5-oracle-effect-validate.ps1'
)
$expectedControllerFiles = @(
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
$forbiddenAbsoluteEvidenceSeed =
  'issue13-v5-diagnostic-bridge-evidence.csv'
$diagnosticEvidenceControllers = @(
  'issue13-v5-build-diagnostic-bridges.R',
  'issue13-v5-capture-clean-bridge-evidence.ps1',
  'issue13-v5-verify-diagnostic-evidence.R',
  'issue13-v5-build-stage5-profiles.R',
  'issue13-v5-run-stage5-evidence.R',
  'issue13-v5-capture-clean-stage5-evidence.ps1'
)
$diagnosticsOverride = 'issue13-v5-diagnostics-override.R'
$diagnosticBridges = 'issue13-v5-diagnostic-module-bridges.csv'
$stage5Profiles = 'issue13-v5-stage5-multiplicity-profiles.csv'
$preparationEquivalenceFiles = @(
  'issue13-v5-build-preparation-equivalence.R',
  'issue13-v5-preparation-equivalence.R',
  'issue13-v5-preparation-equivalence.json'
)
if ($expectedControllerFiles.Count -ne 34 -or
    @($expectedControllerFiles | Sort-Object -Unique).Count -ne 34 -or
    @($script:Issue13V5ControllerFiles | Sort-Object -Unique).Count -ne 34 -or
    [string]::Join("`n", $script:Issue13V5ControllerFiles) -cne
      [string]::Join("`n", $expectedControllerFiles) -or
    $forbiddenAbsoluteEvidenceSeed -cin $expectedControllerFiles -or
    $forbiddenAbsoluteEvidenceSeed -cin $script:Issue13V5ControllerFiles -or
    @($oracleEffectFiles | Where-Object {
      $_ -cnotin $script:Issue13V5ControllerFiles
    }).Count -ne 0 -or
    @($diagnosticEvidenceControllers | Where-Object {
      $_ -cnotin $script:Issue13V5ControllerFiles
    }).Count -ne 0 -or
    $diagnosticsOverride -cnotin $script:Issue13V5ControllerFiles -or
    $diagnosticBridges -cnotin $script:Issue13V5ControllerFiles -or
    $stage5Profiles -cnotin $script:Issue13V5ControllerFiles -or
    @($preparationEquivalenceFiles | Where-Object {
      $_ -cnotin $script:Issue13V5ControllerFiles
    }).Count -ne 0) {
  throw 'V5 exact 34-file controller inventory changed or adopted absolute evidence.'
}
foreach ($name in $expectedControllerFiles) {
  if (-not $bootstrapSourceFileSha256.ContainsKey($name) -and
      -not (Test-Path -LiteralPath (Join-Path $root $name) -PathType Leaf)) {
    throw "V5 controller source is missing: $name"
  }
}
$legacyGeneration = 'v' + '4'
$legacyPathNeedles = @(
  'issue13-native-gate-orchestrator-' + $legacyGeneration,
  'final-evidence-' + $legacyGeneration,
  'final-control-' + $legacyGeneration
)
$records = [Collections.Generic.List[object]]::new()
foreach ($name in $scripts) {
  $path = Join-Path $root $name
  $tokens = @()
  $errors = @()
  $ast = $bootstrapSourceAsts[$name]
  if ($errors.Count -ne 0) {
    throw "PowerShell parser rejected $name`: $($errors[0].Message)"
  }
  $commands = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst]
  }, $true))
  $dangerous = @($commands | Where-Object {
    $commandName = [string]$_.GetCommandName()
    $leaf = @($commandName.Split('\'))[-1]
    $leaf = @($leaf.Split(':'))[-1]
    $isForbiddenLeaf = $leaf -iin @(
      'Invoke-Expression', 'iex',
      'Remove-Item', 'ri', 'rm', 'del', 'erase', 'rd', 'rmdir',
      'Stop-Process', 'spps', 'kill',
      'Start-Job', 'sajb', 'Start-ThreadJob'
    )
    if (-not $isForbiddenLeaf) {
      return $false
    }
    if ($leaf -ine 'Remove-Item') {
      return $true
    }
    $owner = $_.Parent
    while ($null -ne $owner -and $owner -isnot
        [Management.Automation.Language.FunctionDefinitionAst]) {
      $owner = $owner.Parent
    }
    $isTopLevelOwner = $null -ne $owner -and
      $owner.Parent -is [Management.Automation.Language.NamedBlockAst] -and
      [object]::ReferenceEquals($owner.Parent.Parent, $ast)
    if (-not $isTopLevelOwner) {
      return $true
    }
    $signature = [string]::Join('|', @($_.CommandElements | ForEach-Object {
          $_.Extent.Text
        }))
    $isCentralEnvironmentRemove = $name -ceq
        'issue13-v5-coordinator-lib.ps1' -and
      $owner.Name -ceq 'Set-Issue13V5ProcessEnvironmentState' -and
      $signature -ceq
        "Remove-Item|-LiteralPath|('Env:' + `$name)|-Force|-ErrorAction|SilentlyContinue"
    $isOracleEnvironmentRemove = $name -ceq
        'issue13-v5-oracle-effect-lib.ps1' -and
      $owner.Name -ceq
        'Set-Issue13OracleEffectProcessEnvironmentState' -and
      $signature -ceq
        "Remove-Item|-LiteralPath|('Env:' + `$name)|-ErrorAction|Stop"
    -not ($isCentralEnvironmentRemove -or $isOracleEnvironmentRemove)
  })
  if ($dangerous.Count -ne 0) {
    throw "Forbidden coordinator command appears in $name."
  }
  $text = [string]$bootstrapSourceTexts[$name]
  $legacyMatches = @($legacyPathNeedles | Where-Object {
    $text.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0
  })
  if ($legacyMatches.Count -ne 0) {
    throw "Coordinator depends on a legacy V4 path: $name"
  }
  $records.Add([ordered]@{
    name = $name
    sha256 = [string]$bootstrapSourceFileSha256[$name]
    command_ast_count = [long]$commands.Count
  })
}

foreach ($name in $oracleEffectFiles) {
  $path = Join-Path $root $name
  $sourceIsCached = $bootstrapSourceFileSha256.ContainsKey($name)
  $sourceExists = $sourceIsCached -or
    (Test-Path -LiteralPath $path -PathType Leaf)
  $sourceSha256 = if ($sourceIsCached) {
    ([string]$bootstrapSourceFileSha256[$name]).ToLowerInvariant()
  } else {
    Get-Issue13V5Sha256 $path
  }
  if (-not $sourceExists -or
      $name -cnotin $script:Issue13V5ControllerFiles -or
      $sourceSha256 -cnotmatch '^[0-9a-f]{64}$') {
    throw "Oracle-effect controller source is missing or unpinned: $name"
  }
  $oracleCommandCount = 0L
  if ([IO.Path]::GetExtension($name) -ceq '.ps1') {
    $tokens = @()
    $errors = @()
    $oracleAst = $bootstrapSourceAsts[$name]
    if ($errors.Count -ne 0) {
      throw "PowerShell parser rejected oracle-effect source $name`: $($errors[0].Message)"
    }
    $oracleCommandCount = [long]@($oracleAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst]
    }, $true)).Count
  }
  $records.Add([ordered]@{
    name = $name
    sha256 = $sourceSha256
    command_ast_count = $oracleCommandCount
  })
}
$diagnosticsOverridePath = Join-Path $root $diagnosticsOverride
$diagnosticsOverrideText = [IO.File]::ReadAllText(
  $diagnosticsOverridePath, [Text.UTF8Encoding]::new($false, $true))
if ($diagnosticsOverride -cnotin $script:Issue13V5ControllerFiles -or
    (Get-Issue13V5Sha256 $diagnosticsOverridePath) -cnotmatch
      '^[0-9a-f]{64}$' -or
    -not $diagnosticsOverrideText.Contains(
      'wlv13_cross_engine_validate_nonfinite <- function') -or
    -not $diagnosticsOverrideText.Contains(
      'wlv13_cross_engine_compare_anomalies <- function') -or
    -not $diagnosticsOverrideText.Contains('wlv13_v5d_selftest <- function') -or
    -not $diagnosticsOverrideText.Contains(
      'wlv13_v5d_compare_source_unit_contract <- function') -or
    -not $diagnosticsOverrideText.Contains(
      'wlv13_v5d_read_stage5_profiles <- function')) {
  throw 'V5 diagnostic override is missing, unpinned or structurally incomplete.'
}
$records.Add([ordered]@{
  name = $diagnosticsOverride
  sha256 = Get-Issue13V5Sha256 $diagnosticsOverridePath
  command_ast_count = 0L
})

$diagnosticControllerText = @{}
foreach ($name in $diagnosticEvidenceControllers) {
  $path = Join-Path $root $name
  $sourceIsCached = $bootstrapSourceFileSha256.ContainsKey($name)
  $sourceExists = $sourceIsCached -or
    (Test-Path -LiteralPath $path -PathType Leaf)
  $sourceSha256 = if ($sourceIsCached) {
    ([string]$bootstrapSourceFileSha256[$name]).ToLowerInvariant()
  } else {
    Get-Issue13V5Sha256 $path
  }
  if (-not $sourceExists -or
      $sourceSha256 -cnotmatch '^[0-9a-f]{64}$') {
    throw "Diagnostic evidence controller is missing or unpinned: $name"
  }
  $textValue = if ($bootstrapSourceTexts.ContainsKey($name)) {
    [string]$bootstrapSourceTexts[$name]
  } else {
    [IO.File]::ReadAllText(
      $path, [Text.UTF8Encoding]::new($false, $true))
  }
  if ($textValue.Contains([char]0xfffd)) {
    throw "Diagnostic evidence controller is not strict UTF-8: $name"
  }
  $diagnosticControllerText[$name] = $textValue
  $commandCount = 0L
  if ([IO.Path]::GetExtension($name) -ceq '.ps1') {
    $tokens = @()
    $errors = @()
    $diagnosticAst = $bootstrapSourceAsts[$name]
    if ($errors.Count -ne 0) {
      throw "PowerShell parser rejected diagnostic controller $name`: $($errors[0].Message)"
    }
    $commandCount = [long]@($diagnosticAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst]
    }, $true)).Count
  }
  $records.Add([ordered]@{
    name = $name
    sha256 = $sourceSha256
    command_ast_count = $commandCount
  })
}
foreach ($required in @(
    'wlv13_v5d_generate_bridge_manifest <- function',
    'wlv13_v5d_scientific_profile_from_commit <- function',
    'wlv13_v5d_historical_profile_binding_selftest <- function',
    'identical(profile_selftest$assertions, 26L)'
  )) {
  if (-not $diagnosticControllerText[
      'issue13-v5-build-diagnostic-bridges.R'].Contains($required)) {
    throw "Diagnostic bridge builder lacks authenticated freeze: $required"
  }
}
foreach ($required in @(
    'schema=issue13-v5-clean-bridge-capture/2',
    'tool_records=$($toolRecordsBefore.Count)',
    'harness_inventory_sha256=$harnessInventoryBefore',
    'harness_runtime_inventory_before_sha256=$harnessRuntimeInventoryBefore',
    'harness_runtime_inventory_after_sha256=$harnessRuntimeInventoryAfter',
    'rscript_sha256=$rscriptSha256',
    'fsutil_sha256=$fsutilSha256',
    '([Environment]::SystemDirectory)',
    'r_library_path=$($script:rLibrary.Replace',
    'r_library_inventory_before_sha256=$rLibraryInventoryBefore',
    'r_library_inventory_after_sha256=$rLibraryInventoryAfter',
    'Invoke-SealedRscript',
    'New-Issue13V5ClosedREnvironment',
    'Invoke-Issue13V5RscriptBounded',
    'Invoke-SealedRscript $arguments 18000 $baselineRoot',
    'Invoke-SealedRscript $verifyArguments 600 $baselineRoot',
    'metadata_equivalence = Resolve-PhysicalExistingFile',
    'source_wiodr13_inventory_before_sha256=',
    'source_wiodr16_inventory_after_sha256=',
    'Copy-Issue13V5PhysicalDirectorySnapshot',
    'source_data_origin_physical_path=',
    'source_data_snapshot_physical_path=',
    'source_data_independence_after_sha256=',
    'source_data_origin_inventory_before_sha256=',
    'source_data_origin_inventory_after_sha256=',
    'source_data_snapshot_inventory_before_sha256=',
    'source_data_snapshot_inventory_after_sha256=',
    '"--vanilla"',
    'Write-Output "captured_runs=7"'
  )) {
  if (-not $diagnosticControllerText[
      'issue13-v5-capture-clean-bridge-evidence.ps1'].Contains($required)) {
    throw "Clean diagnostic bridge capturer lacks tooling seal: $required"
  }
}
foreach ($required in @(
    'wlv13_v5d_bridge_authenticate_run(',
    '"evidence_record",',
    'issue13-v5-build-diagnostic-bridges.R'
  )) {
  if (-not $diagnosticControllerText[
      'issue13-v5-verify-diagnostic-evidence.R'].Contains($required)) {
    throw "Diagnostic evidence verifier lacks run authentication: $required"
  }
}
foreach ($required in @(
    'wlv13_v5d_validate_stage5_capture <- function',
    'wlv13_v5d_stage5_capture_mutation_selftest <- function',
    'wlv13_v5d_live_validation_structure_selftest <- function',
    'identical(capture_assertions, 46L)',
    'identical(live_structure_assertions, 7L)',
    'requested_verify_live <- verify_live',
    'lockBinding("requested_verify_live", environment())',
    'd7fc0ba48bed304cf3975f2189ee975b14c16522443b28379d26329ea661b97a',
    'lockBinding("official_source_inventory_sha256", environment())',
    'stats::setNames(c(1L, 1L, 6L, 1L, 1L, 6L)',
    'live_structure_assertions=%d',
    'wlv13_v5d_physical_snapshot_attest <- function',
    'external_inventories, verify_live = TRUE',
    'utils::readRegistry(',
    'Bridge capture fsutil is not independently authenticated.',
    'coherent fsutil executable',
    'harness_runtime_inventory_before_sha256',
    'harness_runtime_inventory_after_sha256',
    'r_library_inventory_before_sha256',
    'r_library_inventory_after_sha256',
    'length(stage_header) + 10L + 6L + 6L + 12L + 36L + 36L'
  )) {
  if (-not $diagnosticControllerText[
      'issue13-v5-build-stage5-profiles.R'].Contains($required)) {
    throw "Stage-five profile builder lacks exact capture freeze: $required"
  }
}
foreach ($required in @(
    'capture_role = "stage5-parent-alias"',
    'The stage-five capture parent is not a calculate run.'
  )) {
  if (-not $diagnosticControllerText[
      'issue13-v5-run-stage5-evidence.R'].Contains($required)) {
    throw "Stage-five native launcher lacks parent binding: $required"
  }
}
foreach ($required in @(
    'schema=issue13-v5-clean-stage5-capture/2',
    '$stageRows.Count -ne 36',
    '$seedRecords.Count -ne 36',
    '$targetRecords.Count -ne 36',
    'recipe_records=$($recipeRecords.Count)',
    '$recipeRecordsBefore = @(',
    '$recipeRecordsAfter = @(',
    'Stage-five capture recipes changed during execution.',
    'harness_inventory_sha256=$harnessInventoryBefore',
    'harness_runtime_inventory_before_sha256=$harnessRuntimeInventoryBefore',
    'harness_runtime_inventory_after_sha256=$harnessRuntimeInventoryAfter',
    'rscript_sha256=$rscriptSha256',
    'fsutil_sha256=$fsutilSha256',
    '([Environment]::SystemDirectory)',
    'r_library_path=$($script:rLibrary.Replace',
    'r_library_inventory_before_sha256=$rLibraryInventoryBefore',
    'r_library_inventory_after_sha256=$rLibraryInventoryAfter',
    'Copy-Issue13V5PhysicalDirectorySnapshot',
    'source_snapshot_records=$($sourceSnapshotRecords.Count)',
    'source_data_origin_inventory_before_sha256=',
    'source_data_origin_inventory_after_sha256=',
    'bridge_source_data_snapshot_inventory_before_sha256=',
    'bridge_source_data_snapshot_inventory_after_sha256=',
    'source_data_origin_physical_path=',
    'bridge_source_data_snapshot_physical_path=',
    'bridge_source_data_independence_after_sha256=',
    'Invoke-SealedRscript',
    'New-Issue13V5ClosedREnvironment',
    'Invoke-Issue13V5RscriptBounded',
    'Invoke-SealedRscript $arguments 600 $ProjectRoot',
    'Invoke-SealedRscript $runArguments 18000 $worktree',
    'metadata_equivalence = Resolve-PhysicalExistingFile',
    'Write-Output "baseline_recalculations=36"'
  )) {
  if (-not $diagnosticControllerText[
      'issue13-v5-capture-clean-stage5-evidence.ps1'].Contains($required)) {
    throw "Clean stage-five capturer lacks exhaustive tooling seal: $required"
  }
}

function Get-Issue13V5PowerShellCommandLeaf(
  [AllowNull()][string]$Name
) {
  if ([string]::IsNullOrWhiteSpace($Name)) { return '' }
  $leaf = $Name
  $separator = $leaf.LastIndexOf('\')
  if ($separator -ge 0) { $leaf = $leaf.Substring($separator + 1) }
  $scope = $leaf.LastIndexOf(':')
  if ($scope -ge 0) { $leaf = $leaf.Substring($scope + 1) }
  $leaf
}
function Test-Issue13V5TypeExpression(
  [Management.Automation.Language.Ast]$Expression,
  [string]$ExpectedFullName
) {
  if ($Expression -isnot
      [Management.Automation.Language.TypeExpressionAst]) {
    return $false
  }
  $resolved = $Expression.TypeName.GetReflectionType()
  if ($null -ne $resolved) {
    return $resolved.FullName -ieq $ExpectedFullName
  }
  $Expression.TypeName.FullName -ieq $ExpectedFullName
}
function Test-Issue13V5TypeConstraint(
  [Management.Automation.Language.TypeConstraintAst]$Constraint,
  [string]$ExpectedFullName
) {
  $resolved = $Constraint.TypeName.GetReflectionType()
  if ($null -ne $resolved) {
    return $resolved.FullName -ieq $ExpectedFullName
  }
  $Constraint.TypeName.FullName -ieq $ExpectedFullName
}
function Test-Issue13V5CanonicalCriticalCommands(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string[]]$CriticalNames
) {
  $criticalAliases = @{
    'gcm' = 'Get-Command'
    'mi' = 'Move-Item'
    'move' = 'Move-Item'
    'mv' = 'Move-Item'
    'cat' = 'Get-Content'
    'gc' = 'Get-Content'
    'type' = 'Get-Content'
  }
  $providerWrites = @($Ast.FindAll({
    param($node)
    $target = if ($node -is
        [Management.Automation.Language.AssignmentStatementAst]) {
      $node.Left
    } elseif ($node -is [Management.Automation.Language.UnaryExpressionAst] -and
        $node.TokenKind -in @(
          [Management.Automation.Language.TokenKind]::PlusPlus,
          [Management.Automation.Language.TokenKind]::MinusMinus,
          [Management.Automation.Language.TokenKind]::PostfixPlusPlus,
          [Management.Automation.Language.TokenKind]::PostfixMinusMinus)) {
      $node.Child
    } elseif ($node -is
        [Management.Automation.Language.ForEachStatementAst]) {
      $node.Variable
    } elseif ($node -is
        [Management.Automation.Language.ConvertExpressionAst] -and
        $node.Type.TypeName.FullName -ieq 'ref') {
      $node.Child
    } else {
      $null
    }
    $directProviderWrite = $null -ne $target -and
      $target -is [Management.Automation.Language.VariableExpressionAst] -and
      $target.VariablePath.UserPath -imatch '^(?:function|alias):'
    $nestedProviderWrite = $null -ne $target -and @($target.FindAll({
        param($variable)
        $variable -is
          [Management.Automation.Language.VariableExpressionAst] -and
          $variable.VariablePath.UserPath -imatch '^(?:function|alias):'
      }, $true)).Count -ne 0
    if ($directProviderWrite -or $nestedProviderWrite) {
      return $true
    }
    $node -is [Management.Automation.Language.FileRedirectionAst] -and
      $node.Location -is
        [Management.Automation.Language.StringConstantExpressionAst] -and
      $node.Location.Value -imatch '^(?:function|alias):'
  }, $true))
  $aliasCommands = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -iin @(
        'Set-Alias', 'sal', 'New-Alias', 'nal',
        'Import-Alias', 'ipal', 'Remove-Alias', 'ral'
      )
  }, $true))
  $providerMutationCommands = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -iin @(
        'Set-Item', 'si', 'New-Item', 'ni',
        'Copy-Item', 'cpi', 'cp', 'copy',
        'Rename-Item', 'rni', 'ren',
        'Clear-Item', 'cli', 'Remove-Item', 'ri', 'rm', 'del', 'erase',
        'rd', 'rmdir', 'Set-Content', 'sc', 'Clear-Content', 'clc',
        'Out-File'
      ) -and
      $node.Extent.Text -imatch '(?:function|alias)\s*:'
  }, $true))
  if ($providerWrites.Count -ne 0 -or $aliasCommands.Count -ne 0 -or
      $providerMutationCommands.Count -ne 0) {
    return $false
  }
  $collisions = @($Ast.FindAll({
    param($node)
    if ($node -is [Management.Automation.Language.CommandAst]) {
      $leaf = Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())
      $semanticLeaf = if ($criticalAliases.ContainsKey($leaf)) {
        [string]$criticalAliases[$leaf]
      } else {
        $leaf
      }
      return $CriticalNames -icontains $semanticLeaf
    }
    if ($node -is [Management.Automation.Language.FunctionDefinitionAst]) {
      $leaf = Get-Issue13V5PowerShellCommandLeaf $node.Name
      $semanticLeaf = if ($criticalAliases.ContainsKey($leaf)) {
        [string]$criticalAliases[$leaf]
      } else {
        $leaf
      }
      return $CriticalNames -icontains $semanticLeaf
    }
    $false
  }, $true))
  foreach ($node in $collisions) {
    $raw = if ($node -is [Management.Automation.Language.CommandAst]) {
      [string]$node.GetCommandName()
    } else {
      [string]$node.Name
    }
    $leaf = Get-Issue13V5PowerShellCommandLeaf $raw
    $semanticLeaf = if ($criticalAliases.ContainsKey($leaf)) {
      [string]$criticalAliases[$leaf]
    } else {
      $leaf
    }
    $expected = @($CriticalNames | Where-Object { $_ -ieq $semanticLeaf })
    if ($expected.Count -ne 1 -or $raw -cne $expected[0]) {
      return $false
    }
    if ($node -is [Management.Automation.Language.CommandAst] -and
        ($node.InvocationOperator -ne
          [Management.Automation.Language.TokenKind]::Unknown -or
          $node.CommandElements.Count -lt 1 -or
          $node.CommandElements[0].Extent.Text -cne $expected[0])) {
      return $false
    }
  }
  $true
}
function Test-Issue13V5ForbiddenVariableMutationCommand(
  [Management.Automation.Language.CommandAst]$Command
) {
  $leaf = Get-Issue13V5PowerShellCommandLeaf ($Command.GetCommandName())
  if ($leaf -iin @(
    'Set-Variable', 'sv', 'set',
    'New-Variable', 'nv',
    'Clear-Variable', 'clv',
    'Remove-Variable', 'rv',
    'Set-Alias', 'sal', 'New-Alias', 'nal',
    'Import-Alias', 'ipal', 'Remove-Alias', 'ral'
  )) { return $true }
  $parameters = @($Command.CommandElements | Where-Object {
    $_ -is [Management.Automation.Language.CommandParameterAst]
  } | ForEach-Object { $_.ParameterName })
  $commonVariableParameters = @(
    'OutVariable',
    'PipelineVariable',
    'ErrorVariable',
    'WarningVariable',
    'InformationVariable'
  )
  if (@($parameters | Where-Object {
      $parameter = $_
      $parameter -iin @('ov', 'pv', 'ev', 'wv', 'iv') -or
        @($commonVariableParameters | Where-Object {
          $parameter.Length -gt 0 -and
            $_.StartsWith(
              $parameter, [StringComparison]::OrdinalIgnoreCase)
        }).Count -ne 0
    }).Count -ne 0 -or
      ($leaf -iin @('Tee-Object', 'tee') -and
        @($parameters | Where-Object {
          $_.Length -gt 0 -and
            'Variable'.StartsWith(
              $_, [StringComparison]::OrdinalIgnoreCase)
        }).Count -ne 0)) {
    return $true
  }
  if ($leaf -iin @(
      'Set-Item', 'si', 'New-Item', 'ni',
      'Copy-Item', 'cpi', 'cp', 'copy',
      'Rename-Item', 'rni', 'ren',
      'Set-Content', 'sc',
      'Clear-Item', 'cli', 'Clear-Content', 'clc',
      'Remove-Item', 'ri', 'rm', 'del', 'erase', 'rd', 'rmdir',
      'Out-File') -and
      $Command.Extent.Text -imatch '(?:variable|function|alias)\s*:') {
    return $true
  }
  $false
}
function Test-Issue13V5ForbiddenProtectedScopeCommand(
  [Management.Automation.Language.CommandAst]$Command,
  [string[]]$AllowedMutationSignatures = @()
) {
  $signature = [string]::Join('|', @($Command.CommandElements |
      ForEach-Object { $_.Extent.Text }))
  if ($AllowedMutationSignatures -ccontains $signature) {
    return $false
  }
  if (Test-Issue13V5ForbiddenVariableMutationCommand $Command) {
    return $true
  }
  $splats = @($Command.FindAll({
    param($node)
    $node -is [Management.Automation.Language.VariableExpressionAst] -and
      $node.Splatted
  }, $true))
  if ($splats.Count -ne 0) { return $true }
  if ($Command.InvocationOperator -ne
      [Management.Automation.Language.TokenKind]::Unknown) {
    return $AllowedMutationSignatures -cnotcontains $signature
  }
  $name = [string]$Command.GetCommandName()
  if ([string]::IsNullOrWhiteSpace($name)) {
    return $AllowedMutationSignatures -cnotcontains $signature
  }
  $leaf = Get-Issue13V5PowerShellCommandLeaf $name
  if ($leaf -iin @('Invoke-Expression', 'iex', 'Invoke-Command', 'icm')) {
    return $true
  }
  if ($leaf -iin @(
      'Set-Item', 'si', 'New-Item', 'ni',
      'Copy-Item', 'cpi', 'cp', 'copy',
      'Rename-Item', 'rni', 'ren',
      'Clear-Item', 'cli', 'Remove-Item', 'ri', 'rm', 'del', 'erase',
      'rd', 'rmdir', 'Set-Content', 'sc', 'Clear-Content', 'clc',
      'Out-File')) {
    return $AllowedMutationSignatures -cnotcontains $signature
  }
  $false
}
function Test-Issue13V5ForbiddenProtectedScopeRedirection(
  [Management.Automation.Language.Ast]$Ast,
  [string[]]$AllowedSignatures = @()
) {
  @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FileRedirectionAst] -and
      $AllowedSignatures -cnotcontains $node.Extent.Text
  }, $true)).Count -ne 0
}
function Get-Issue13V5UnscopedVariableName(
  [Management.Automation.Language.VariableExpressionAst]$Variable
) {
  $name = [string]$Variable.VariablePath.UserPath
  $separator = $name.IndexOf(':')
  if ($separator -ge 0 -and $name.Substring(0, $separator) -iin @(
      'script', 'local', 'private', 'global', 'variable')) {
    $name = $name.Substring($separator + 1)
  }
  '$' + $name
}
function Test-Issue13V5ForbiddenSessionStateMutation(
  [Management.Automation.Language.Ast]$Ast,
  [Management.Automation.Language.Ast[]]$AllowedRootAsts = @()
) {
  $forbiddenReferences = @($Ast.FindAll({
    param($node)
    ($node -is [Management.Automation.Language.VariableExpressionAst] -and
      (Get-Issue13V5UnscopedVariableName $node) -iin @(
        '$ExecutionContext', '$PSDefaultParameterValues'
      )) -or
      ($node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -iin @(
          'Get-Variable', 'gv'
        )) -or
      ($node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        ($node.Extent.Text -imatch 'PSVariable' -or
          @($node.FindAll({
            param($variable)
            $variable -is
              [Management.Automation.Language.VariableExpressionAst] -and
              (Get-Issue13V5UnscopedVariableName $variable) -iin @(
                '$ExecutionContext', '$PSDefaultParameterValues'
              )
          }, $true)).Count -ne 0 -or
          ($node.Static -and
            (Test-Issue13V5TypeExpression $node.Expression `
              'System.Management.Automation.ScriptBlock'))))
  }, $true))
  foreach ($reference in $forbiddenReferences) {
    $allowed = $false
    foreach ($allowedRoot in $AllowedRootAsts) {
      if ($null -ne $allowedRoot -and
          $reference.Extent.StartOffset -ge
            $allowedRoot.Extent.StartOffset -and
          $reference.Extent.EndOffset -le $allowedRoot.Extent.EndOffset) {
        $allowed = $true
        break
      }
    }
    if (-not $allowed) { return $true }
  }
  $false
}
function Get-Issue13V5AstSurfaceDigest(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [ValidateSet('command', 'redirection')][string]$Kind
) {
  $nodes = @(if ($Kind -ieq 'command') {
    $Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst]
    }, $true) | Sort-Object { $_.Extent.StartOffset }
  } else {
    $Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.FileRedirectionAst]
    }, $true) | Sort-Object { $_.Extent.StartOffset }
  })
  $records = @()
  foreach ($node in $nodes) {
    $owner = '<script>'
    $current = $node.Parent
    while ($null -ne $current -and
        -not [object]::ReferenceEquals($current, $Ast)) {
      if ($current -is
          [Management.Automation.Language.FunctionDefinitionAst]) {
        $owner = [string]$current.Name
        break
      }
      $current = $current.Parent
    }
    $types = @()
    $current = $node
    while ($null -ne $current -and
        -not [object]::ReferenceEquals($current, $Ast)) {
      $types += $current.GetType().Name
      $current = $current.Parent
    }
    if ($null -eq $current) {
      throw 'AST surface node does not belong to the supplied root.'
    }
    $chain = [string]::Join('>', [string[]]$types)
    $fields = if ($Kind -ieq 'command') {
      @(
        'C',
        $owner,
        $node.InvocationOperator.ToString(),
        [string]$node.GetCommandName(),
        [string]::Join('|', @($node.CommandElements | ForEach-Object {
          $_.Extent.Text
        })),
        $chain
      )
    } else {
      @('R', $owner, $node.Extent.Text, $chain)
    }
    $record = ''
    foreach ($field in $fields) {
      $value = [string]$field
      $record += ([string]$value.Length) + ':' + $value
    }
    $records += $record
  }
  $payload = [string]::Join("`n", [string[]]$records)
  $encoding = [Text.UTF8Encoding]::new($false, $true)
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = $algorithm.ComputeHash($encoding.GetBytes($payload))
  } finally {
    $algorithm.Dispose()
  }
  [pscustomobject]@{
    count = [int]$nodes.Count
    sha256 = [Convert]::ToHexString($hash)
  }
}
function Test-Issue13V5AstSurface(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [Collections.IDictionary]$Expected
) {
  $commands = Get-Issue13V5AstSurfaceDigest $Ast 'command'
  $redirections = Get-Issue13V5AstSurfaceDigest $Ast 'redirection'
  $commands.count -eq [int]$Expected.command_count -and
    $commands.sha256 -ceq [string]$Expected.command_sha256 -and
    $redirections.count -eq [int]$Expected.redirection_count -and
    $redirections.sha256 -ceq [string]$Expected.redirection_sha256
}
function Test-Issue13V5CommandCollisionGuardFirst(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string]$CanonicalGuardText
) {
  if ($null -eq $Ast -or
      [string]::IsNullOrWhiteSpace($CanonicalGuardText)) {
    return $false
  }
  $statements = @($Ast.EndBlock.Statements)
  if ($statements.Count -lt 2 -or
      $statements[0] -isnot
        [Management.Automation.Language.AssignmentStatementAst] -or
      $statements[0].Left -isnot
        [Management.Automation.Language.VariableExpressionAst] -or
      $statements[0].Left.VariablePath.UserPath -cne
        'issue13V5CommandCollisionGuard' -or
      $statements[0].Right -isnot
        [Management.Automation.Language.CommandExpressionAst] -or
      $statements[0].Right.Expression -isnot
        [Management.Automation.Language.ScriptBlockExpressionAst] -or
      $statements[0].Right.Expression.ScriptBlock.Extent.Text -cne
        $CanonicalGuardText -or
      $statements[1] -isnot [Management.Automation.Language.PipelineAst] -or
      $statements[1].PipelineElements.Count -ne 1 -or
      $statements[1].PipelineElements[0] -isnot
        [Management.Automation.Language.CommandAst]) {
    return $false
  }
  $guardInvocation = $statements[1].PipelineElements[0]
  if ($guardInvocation.InvocationOperator -ne
        [Management.Automation.Language.TokenKind]::Ampersand -or
      -not [string]::IsNullOrWhiteSpace($guardInvocation.GetCommandName()) -or
      $guardInvocation.CommandElements.Count -ne 2 -or
      $guardInvocation.CommandElements[0] -isnot
        [Management.Automation.Language.VariableExpressionAst] -or
      $guardInvocation.CommandElements[0].VariablePath.UserPath -cne
        'issue13V5CommandCollisionGuard' -or
      $guardInvocation.CommandElements[1].Extent.Text -cne
        '$MyInvocation.MyCommand.ScriptBlock.Ast') {
    return $false
  }
  $guardCommands = @(
    $statements[0].Right.Expression.ScriptBlock.FindAll(
      {
        param($node)
        $node -is [Management.Automation.Language.CommandAst]
      }, $true))
  $guardCommandChainTypes = @()
  if ($guardCommands.Count -eq 1) {
    $guardCommandChainNode = $guardCommands[0]
    while ($null -ne $guardCommandChainNode -and
        -not [object]::ReferenceEquals($guardCommandChainNode, $Ast)) {
      $guardCommandChainTypes += $guardCommandChainNode.GetType().Name
      $guardCommandChainNode = $guardCommandChainNode.Parent
    }
  }
  $guardCommandChain =
    [string]::Join('>', [string[]]$guardCommandChainTypes)
  $guardAssignments = @($Ast.FindAll(
      {
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
          $node.Left -is
            [Management.Automation.Language.VariableExpressionAst] -and
          $node.Left.VariablePath.UserPath -ieq
            'issue13V5CommandCollisionGuard'
      }, $true))
  $guardInvocations = @($Ast.FindAll(
      {
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
          $node.CommandElements.Count -ge 1 -and
          $node.CommandElements[0] -is
            [Management.Automation.Language.VariableExpressionAst] -and
          $node.CommandElements[0].VariablePath.UserPath -ieq
            'issue13V5CommandCollisionGuard'
      }, $true))
  $earlierCommands = [Collections.Generic.List[
    Management.Automation.Language.CommandAst]]::new()
  foreach ($commandAst in $Ast.FindAll(
      {
        param($node)
        $node -is [Management.Automation.Language.CommandAst]
      }, $true)) {
    if ($commandAst.Extent.StartOffset -lt
        $guardInvocation.Extent.StartOffset) {
      $earlierCommands.Add($commandAst)
    }
  }
  $guardCommands.Count -eq 1 -and
    $guardCommands[0].InvocationOperator -eq
      [Management.Automation.Language.TokenKind]::Ampersand -and
    [string]::IsNullOrWhiteSpace($guardCommands[0].GetCommandName()) -and
    $guardCommands[0].CommandElements.Count -eq 7 -and
    [regex]::Replace($guardCommands[0].Extent.Text, '[\s`]', '') -ceq
      '&$importModuleCmdlet-Name$manifest-Global-Force-ErrorActionStop' -and
    $guardCommandChain -ceq
      ('CommandAst>PipelineAst>AssignmentStatementAst>StatementBlockAst>' +
        'ForEachStatementAst>NamedBlockAst>ScriptBlockAst>' +
        'ScriptBlockExpressionAst>CommandExpressionAst>' +
        'AssignmentStatementAst>NamedBlockAst') -and
    $guardAssignments.Count -eq 1 -and
    [object]::ReferenceEquals($guardAssignments[0], $statements[0]) -and
    $guardInvocations.Count -eq 1 -and
    [object]::ReferenceEquals($guardInvocations[0], $guardInvocation) -and
    $earlierCommands.Count -eq 1 -and
    [object]::ReferenceEquals($earlierCommands[0], $guardCommands[0])
}
function Test-Issue13V5BootstrapRuntimeLeaseRetention(
  [Management.Automation.Language.ScriptBlockAst]$Guard
) {
  if ($null -eq $Guard) { return $false }
  $runtimeAssignments = @($Guard.FindAll({
      param($node)
      $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is
          [Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.UserPath -ieq 'runtimeFileLeases'
    }, $true))
  $getDataAssignments = @($Guard.FindAll({
      param($node)
      $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is
          [Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.UserPath -ieq 'leaseSets' -and
        [regex]::Replace($node.Right.Extent.Text, '[\s`]', '') -ceq
          ("[AppDomain]::CurrentDomain.GetData(" +
            "'wlv.issue13.v5.powershell.runtime.leases')")
    }, $true))
  $leaseSetAssignments = @($Guard.FindAll({
      param($node)
      $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is
          [Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.UserPath -ieq 'leaseSets'
    }, $true))
  $newListAssignments = @($Guard.FindAll({
      param($node)
      $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is
          [Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.UserPath -ieq 'leaseSets' -and
        [regex]::Replace($node.Right.Extent.Text, '[\s`]', '') -ceq
          '[Collections.Generic.List[object]]::new()'
    }, $true))
  $countChecks = @($Guard.FindAll({
      param($node)
      $node -is [Management.Automation.Language.IfStatementAst] -and
        $node.Clauses.Count -eq 1 -and $null -eq $node.ElseClause -and
        [regex]::Replace(
          $node.Clauses[0].Item1.Extent.Text, '[\s`()]', '') -ceq
          '$runtimeFileLeases.Count-ne11'
    }, $true))
  $runtimeMembers = @($Guard.FindAll({
      param($node)
      $node -is
        [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Expression.Extent.Text -ceq '$runtimeFileLeases'
    }, $true))
  $leaseSetMembers = @($Guard.FindAll({
      param($node)
      $node -is
        [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Expression.Extent.Text -ceq '$leaseSets'
    }, $true))
  $setDataCalls = @($Guard.FindAll({
      param($node)
      $node -is
        [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Member.Extent.Text -ceq 'SetData' -and
        [regex]::Replace($node.Expression.Extent.Text, '[\s`]', '') -ceq
          '[AppDomain]::CurrentDomain'
    }, $true))
  if ($runtimeAssignments.Count -ne 1 -or
      [regex]::Replace(
        $runtimeAssignments[0].Right.Extent.Text, '[\s`]', '') -cne
        '[Collections.Generic.List[IO.FileStream]]::new()' -or
      $getDataAssignments.Count -ne 1 -or
      $leaseSetAssignments.Count -ne 2 -or
      $newListAssignments.Count -ne 1 -or $countChecks.Count -ne 1 -or
      $runtimeMembers.Count -ne 2 -or $leaseSetMembers.Count -ne 1 -or
      $setDataCalls.Count -ne 1) {
    return $false
  }
  $runtimeMemberSignatures = [Collections.Generic.List[string]]::new()
  foreach ($member in $runtimeMembers) {
    $runtimeMemberSignatures.Add(
      [regex]::Replace($member.Extent.Text, '[\s`]', ''))
  }
  if ([string]::Join("`n", $runtimeMemberSignatures.ToArray()) -cne
      [string]::Join("`n", @(
        '$runtimeFileLeases.Add($stream)',
        '$runtimeFileLeases.Clear()'
      )) -or
      [regex]::Replace(
        $leaseSetMembers[0].Extent.Text, '[\s`]', '') -cne
        '$leaseSets.Add($runtimeFileLeases)' -or
      [regex]::Replace($setDataCalls[0].Extent.Text, '[\s`]', '') -cne
        ("[AppDomain]::CurrentDomain.SetData(" +
          "'wlv.issue13.v5.powershell.runtime.leases',`$leaseSets)")) {
    return $false
  }
  $nodes = [ordered]@{
    runtime_assignment = $runtimeAssignments[0]
    runtime_add = $runtimeMembers[0]
    runtime_clear = $runtimeMembers[1]
    count_check = $countChecks[0]
    get_data = $getDataAssignments[0]
    new_list = $newListAssignments[0]
    lease_set_add = $leaseSetMembers[0]
    set_data = $setDataCalls[0]
  }
  $chains = @{}
  foreach ($name in $nodes.Keys) {
    $types = [Collections.Generic.List[string]]::new()
    $current = $nodes[$name]
    while ($null -ne $current -and
        -not [object]::ReferenceEquals($current, $Guard)) {
      $types.Add($current.GetType().Name)
      $current = $current.Parent
    }
    if ($null -eq $current) { return $false }
    $chains[$name] = [string]::Join('>', $types.ToArray())
  }
  $chains.runtime_assignment -ceq 'AssignmentStatementAst>NamedBlockAst' -and
    $chains.runtime_add -ceq
      ('InvokeMemberExpressionAst>CommandExpressionAst>PipelineAst>' +
        'StatementBlockAst>TryStatementAst>StatementBlockAst>' +
        'ForEachStatementAst>StatementBlockAst>TryStatementAst>' +
        'NamedBlockAst') -and
    $chains.runtime_clear -ceq
      ('InvokeMemberExpressionAst>CommandExpressionAst>PipelineAst>' +
        'StatementBlockAst>IfStatementAst>NamedBlockAst') -and
    $chains.count_check -ceq 'IfStatementAst>NamedBlockAst' -and
    $chains.get_data -ceq 'AssignmentStatementAst>NamedBlockAst' -and
    $chains.new_list -ceq
      'AssignmentStatementAst>StatementBlockAst>IfStatementAst>NamedBlockAst' -and
    $chains.lease_set_add -ceq
      'InvokeMemberExpressionAst>CommandExpressionAst>PipelineAst>NamedBlockAst' -and
    $chains.set_data -ceq
      'InvokeMemberExpressionAst>CommandExpressionAst>PipelineAst>NamedBlockAst' -and
    $newListAssignments[0].Parent.Parent -is
      [Management.Automation.Language.IfStatementAst] -and
    $newListAssignments[0].Parent.Parent.Clauses.Count -eq 1 -and
    $null -eq $newListAssignments[0].Parent.Parent.ElseClause -and
    [regex]::Replace(
      $newListAssignments[0].Parent.Parent.Clauses[0].Item1.Extent.Text,
      '[\s`()]', '') -ceq
      '$leaseSets-isnot[Collections.Generic.List[object]]' -and
    $runtimeAssignments[0].Extent.EndOffset -lt
      $runtimeMembers[0].Extent.StartOffset -and
    $runtimeMembers[0].Extent.EndOffset -lt $countChecks[0].Extent.StartOffset -and
    $countChecks[0].Extent.EndOffset -lt
      $getDataAssignments[0].Extent.StartOffset -and
    $getDataAssignments[0].Extent.EndOffset -lt
      $newListAssignments[0].Extent.StartOffset -and
    $newListAssignments[0].Extent.EndOffset -lt
      $leaseSetMembers[0].Extent.StartOffset -and
    $leaseSetMembers[0].Extent.EndOffset -lt
      $setDataCalls[0].Extent.StartOffset
}
function Get-Issue13V5ControllerSourceSha256(
  [string]$Text,
  [string]$FileName
) {
  $canonical = $Text
  if ($FileName -ceq 'issue13-v5-static-verify.ps1') {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput(
      $Text, [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) {
      throw 'Cannot canonicalize the static verifier source digest.'
    }
    $assignments = @($ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is
          [Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.UserPath -ieq
          'issue13ExpectedControllerSourceSha256'
    }, $true))
    if ($assignments.Count -ne 1 -or
        $assignments[0].Left.Extent.Text -cne
          '$issue13ExpectedControllerSourceSha256') {
      throw 'Static verifier source-digest map is not singular.'
    }
    $tables = @($assignments[0].Right.FindAll({
      param($node)
      $node -is [Management.Automation.Language.HashtableAst]
    }, $true))
    if ($tables.Count -ne 1) {
      throw 'Static verifier source-digest hashtable is not singular.'
    }
    $selfPairs = @($tables[0].KeyValuePairs | Where-Object {
      $_.Item1 -is
        [Management.Automation.Language.StringConstantExpressionAst] -and
        $_.Item1.Value -ceq 'issue13-v5-static-verify.ps1'
    })
    if ($selfPairs.Count -ne 1) {
      throw 'Static verifier self-digest entry is not singular.'
    }
    $valuePipeline = $selfPairs[0].Item2
    $pipelineElements = @($valuePipeline.PipelineElements)
    if ($valuePipeline -isnot [Management.Automation.Language.PipelineAst] -or
        $pipelineElements.Count -ne 1 -or
        $pipelineElements[0] -isnot
          [Management.Automation.Language.CommandExpressionAst] -or
        $pipelineElements[0].Expression -isnot
          [Management.Automation.Language.StringConstantExpressionAst]) {
      throw 'Static verifier self digest must be one literal string.'
    }
    $valueLiteral = $pipelineElements[0].Expression
    if ($valueLiteral.StringConstantType -ne
          [Management.Automation.Language.StringConstantType]::SingleQuoted -or
        $valueLiteral.Value -cnotmatch '^[0-9A-F]{64}$' -or
        $valuePipeline.Extent.StartOffset -ne
          $pipelineElements[0].Extent.StartOffset -or
        $valuePipeline.Extent.EndOffset -ne
          $pipelineElements[0].Extent.EndOffset -or
        $pipelineElements[0].Extent.StartOffset -ne
          $valueLiteral.Extent.StartOffset -or
        $pipelineElements[0].Extent.EndOffset -ne
          $valueLiteral.Extent.EndOffset -or
        $valueLiteral.Extent.Text -cne ("'" + $valueLiteral.Value + "'")) {
      throw 'Static verifier self digest is not a canonical SHA-256 literal.'
    }
    $valueExtent = $valueLiteral.Extent
    $canonical = $Text.Remove(
      $valueExtent.StartOffset,
      $valueExtent.EndOffset - $valueExtent.StartOffset).Insert(
        $valueExtent.StartOffset, "'<SELF-SHA256>'")
  }
  $encoding = [Text.UTF8Encoding]::new($false, $true)
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = $algorithm.ComputeHash($encoding.GetBytes($canonical))
  } finally {
    $algorithm.Dispose()
  }
  [Convert]::ToHexString($hash)
}

$issue13CriticalPowerShellNames = @(
  'Copy-Issue13V5PhysicalDirectorySnapshot',
  'Get-Issue13V5PhysicalSnapshotProof',
  'Get-Issue13V5PhysicalItemIdentity',
  'Enter-Issue13V5GitExecutableLease',
  'Get-Issue13V5GitExecutableBinding',
  'Assert-Issue13V5GitExecutableBinding',
  'Exit-Issue13V5GitExecutableLease',
  'Enter-Issue13V5PwshExecutableLease',
  'Get-Issue13V5PwshExecutableBinding',
  'Assert-Issue13V5PwshExecutableBinding',
  'Exit-Issue13V5PwshExecutableLease',
  'Assert-Issue13V5CurrentPwshHost',
  'Enter-Issue13V5RscriptExecutableLease',
  'Get-Issue13V5RscriptExecutableBinding',
  'Assert-Issue13V5RscriptExecutableBinding',
  'Exit-Issue13V5RscriptExecutableLease',
  'Invoke-Issue13V5SealedGit',
  'Get-Issue13V5TreeInventory',
  'Set-Issue13V5ScriptConstant',
  'Assert-Issue13V5OfficialSourceDataInventory',
  'Assert-Issue13V5BaselineSmokeRscriptSeal',
  'Get-Issue13V5BaselineSmokeSha256',
  'Get-Issue13V5BaselineSmokeTextSha256',
  'Assert-Issue13V5BaselineSmokeSourceInventory',
  'Assert-Issue13V5BaselineSmokeNoConcurrentR',
  'Write-Issue13V5BaselineSmokeJson',
  'Invoke-Issue13V5DeliveryGit',
  'Invoke-Issue13V5DeliveryAttestation',
  'Resolve-Issue13V5DeliveryOutput',
  'ConvertTo-Issue13V5PhysicalPath',
  'Test-Issue13V5PathContained',
  'Assert-Issue13V5PathsDisjoint',
  'Assert-Issue13V5NoReparseAncestors',
  'Assert-Issue13V5MaterializerNoReparseAncestors',
  'Assert-Issue13V5AliasFreeLocalPath',
  'ConvertTo-Issue13V5CanonicalPath',
  'Get-Issue13V5MaterializerSha256',
  'Get-Issue13V5MaterializerBytesSha256',
  'Get-Issue13V5MaterializerGitLine',
  'ConvertFrom-Issue13V5MaterializerGitTreeBytes',
  'Get-Issue13V5NewConfigSha256',
  'Assert-Issue13V5Config',
  'Assert-Issue13V5ConfigPathIsolation',
  'Assert-Issue13V5OracleComparisonIsolation',
  'Assert-Issue13V5FreshRoot',
  'Assert-Issue13OracleEffectProofPathIsolation',
  'Assert-Issue13OracleEffectComparisonIsolation',
  'Assert-Issue13OracleEffectPathsDisjoint',
  'ConvertTo-Issue13OracleEffectPhysicalPath',
  'Write-Issue13OracleEffectJsonOnce',
  'Write-Issue13V5Json',
  'Assert-Issue13V5PhysicalCopy',
  'Assert-Issue13V5HarnessBinding',
  'Assert-Issue13V5BaselineSmokeEvidence',
  'Assert-Issue13V5EnvironmentName',
  'ConvertTo-Issue13V5EnvironmentMutations',
  'Get-Issue13V5ProcessEnvironmentState',
  'Set-Issue13V5ProcessEnvironmentState',
  'Invoke-Issue13V5WithCleanup',
  'Enter-Issue13V5ProcessEnvironment',
  'Exit-Issue13V5ProcessEnvironment',
  'Invoke-Issue13V5WithProcessEnvironment',
  'Set-Issue13V5ProcessStartInfoEnvironment',
  'New-Issue13V5ClosedREnvironment',
  'Test-Issue13V5ProcessEnvironmentSelfTest',
  'Stop-Issue13V5ExternalProcess',
  'Invoke-Issue13V5RscriptBounded',
  'Invoke-Issue13V5External',
  'Invoke-Issue13V5GitRaw',
  'Invoke-Issue13V5GitExternal',
  'Invoke-Issue13V5PwshExternal',
  'Invoke-Issue13V5PwshTransient',
  'Invoke-Issue13V5R',
  'Invoke-Issue13V5Pwsh',
  'Invoke-Issue13V5GitBytes',
  'Get-Issue13V5TrackedSourceTooling',
  'Resolve-Issue13OracleEffectFile',
  'Read-Issue13OracleEffectJson',
  'Invoke-Issue13OracleEffectGit',
  'Invoke-Issue13OracleEffectGitBytes',
  'Get-Issue13OracleEffectExpectedSourceTooling',
  'Get-Issue13OracleEffectRscriptIdentity',
  'Get-Issue13OracleEffectProcessEnvironmentState',
  'Set-Issue13OracleEffectProcessEnvironmentState',
  'Enter-Issue13OracleEffectSanitizedREnvironment',
  'Exit-Issue13OracleEffectSanitizedREnvironment',
  'Test-Issue13OracleEffectNegativeSelfTests',
  'Test-Issue13OracleEffectSpec',
  'Assert-Issue13OracleEffectHarnessManifestEnvelope',
  'Test-Issue13OracleEffectHarnessManifest',
  'Get-Issue13OracleEffectInputContext',
  'Get-Issue13OracleEffectEvidence',
  'Add-Type',
  'Add-Member',
  'Get-Command',
  'Move-Item',
  'Get-Content'
)
$issue13CriticalDefinitionOwners = @{
  'issue13-v5-attest-delivery.ps1' = @(
    'Invoke-Issue13V5DeliveryGit',
    'Resolve-Issue13V5DeliveryOutput',
    'Invoke-Issue13V5DeliveryAttestation'
  )
  'issue13-v5-baseline-smoke.ps1' = @(
    'Assert-Issue13V5BaselineSmokeRscriptSeal',
    'Get-Issue13V5BaselineSmokeSha256',
    'Get-Issue13V5BaselineSmokeTextSha256',
    'Assert-Issue13V5BaselineSmokeSourceInventory',
    'Assert-Issue13V5BaselineSmokeNoConcurrentR',
    'Write-Issue13V5BaselineSmokeJson'
  )
  'issue13-v5-coordinator-lib.ps1' = @(
    'Set-Issue13V5ScriptConstant',
    'ConvertTo-Issue13V5PhysicalPath',
    'Test-Issue13V5PathContained',
    'Assert-Issue13V5PathsDisjoint',
    'Assert-Issue13V5ConfigPathIsolation',
    'Assert-Issue13V5NoReparseAncestors',
    'Get-Issue13V5PhysicalItemIdentity',
    'Enter-Issue13V5GitExecutableLease',
    'Get-Issue13V5GitExecutableBinding',
    'Assert-Issue13V5GitExecutableBinding',
    'Exit-Issue13V5GitExecutableLease',
    'Enter-Issue13V5PwshExecutableLease',
    'Get-Issue13V5PwshExecutableBinding',
    'Assert-Issue13V5PwshExecutableBinding',
    'Exit-Issue13V5PwshExecutableLease',
    'Assert-Issue13V5CurrentPwshHost',
    'Enter-Issue13V5RscriptExecutableLease',
    'Get-Issue13V5RscriptExecutableBinding',
    'Assert-Issue13V5RscriptExecutableBinding',
    'Exit-Issue13V5RscriptExecutableLease',
    'Invoke-Issue13V5SealedGit',
    'Get-Issue13V5PhysicalSnapshotProof',
    'Copy-Issue13V5PhysicalDirectorySnapshot',
    'Write-Issue13V5Json',
    'Get-Issue13V5TreeInventory',
    'Assert-Issue13V5OfficialSourceDataInventory',
    'Assert-Issue13V5OracleComparisonIsolation',
    'Assert-Issue13V5EnvironmentName',
    'ConvertTo-Issue13V5EnvironmentMutations',
    'Get-Issue13V5ProcessEnvironmentState',
    'Set-Issue13V5ProcessEnvironmentState',
    'Invoke-Issue13V5WithCleanup',
    'Enter-Issue13V5ProcessEnvironment',
    'Exit-Issue13V5ProcessEnvironment',
    'Invoke-Issue13V5WithProcessEnvironment',
    'Set-Issue13V5ProcessStartInfoEnvironment',
    'New-Issue13V5ClosedREnvironment',
    'Test-Issue13V5ProcessEnvironmentSelfTest',
    'Assert-Issue13V5PhysicalCopy',
    'Invoke-Issue13V5GitRaw',
    'Assert-Issue13V5HarnessBinding',
    'Assert-Issue13V5BaselineSmokeEvidence',
    'Assert-Issue13V5Config',
    'Stop-Issue13V5ExternalProcess',
    'Invoke-Issue13V5RscriptBounded',
    'Invoke-Issue13V5External',
    'Invoke-Issue13V5GitExternal',
    'Invoke-Issue13V5PwshExternal',
    'Invoke-Issue13V5PwshTransient',
    'Invoke-Issue13V5R',
    'Invoke-Issue13V5Pwsh'
  )
  'issue13-v5-materialize-harness.ps1' = @(
    'Assert-Issue13V5AliasFreeLocalPath',
    'ConvertTo-Issue13V5CanonicalPath',
    'Assert-Issue13V5MaterializerNoReparseAncestors',
    'Get-Issue13V5MaterializerSha256',
    'Get-Issue13V5MaterializerBytesSha256',
    'Invoke-Issue13V5GitBytes',
    'Get-Issue13V5MaterializerGitLine',
    'ConvertFrom-Issue13V5MaterializerGitTreeBytes',
    'Get-Issue13V5TrackedSourceTooling'
  )
  'issue13-v5-new-config.ps1' = @(
    'Assert-Issue13V5FreshRoot',
    'Get-Issue13V5NewConfigSha256'
  )
  'issue13-v5-oracle-effect-lib.ps1' = @(
    'Resolve-Issue13OracleEffectFile',
    'ConvertTo-Issue13OracleEffectPhysicalPath',
    'Get-Issue13OracleEffectRscriptIdentity',
    'Assert-Issue13OracleEffectPathsDisjoint',
    'Assert-Issue13OracleEffectProofPathIsolation',
    'Read-Issue13OracleEffectJson',
    'Invoke-Issue13OracleEffectGit',
    'Invoke-Issue13OracleEffectGitBytes',
    'Get-Issue13OracleEffectExpectedSourceTooling',
    'Get-Issue13OracleEffectProcessEnvironmentState',
    'Set-Issue13OracleEffectProcessEnvironmentState',
    'Enter-Issue13OracleEffectSanitizedREnvironment',
    'Exit-Issue13OracleEffectSanitizedREnvironment',
    'Test-Issue13OracleEffectNegativeSelfTests',
    'Test-Issue13OracleEffectSpec',
    'Assert-Issue13OracleEffectHarnessManifestEnvelope',
    'Test-Issue13OracleEffectHarnessManifest',
    'Get-Issue13OracleEffectInputContext',
    'Assert-Issue13OracleEffectComparisonIsolation',
    'Get-Issue13OracleEffectEvidence',
    'Write-Issue13OracleEffectJsonOnce'
  )
}
$issue13ExpectedAstSurfaces = @{
  'issue13-v5-attest-delivery.ps1' = @{
    command_count = 77
    command_sha256 = 'EA83D37EDD2823F647F15A2BEBD4C48551DC634AC93472F59CAE71A21600B600'
    redirection_count = 1
    redirection_sha256 = '2637588ECE5D0693F068560BB7ADDA69DBE15A91B08B1853C82B7A2B046ECFD0'
  }
  'issue13-v5-baseline-smoke.ps1' = @{
    command_count = 171
    command_sha256 = '3E630B55C45D19309A066EA5E989B0A22073D35719BC22CE5B3BAB43FBA01E3A'
    redirection_count = 4
    redirection_sha256 = '3ADEEFA5B4469B07E9149CD294980C3F82241C9EE64016075D92540C0A44D3CA'
  }
  'issue13-v5-capture-clean-bridge-evidence.ps1' = @{
    command_count = 148
    command_sha256 = '9E119DDC1B69636CA3BDD9D2897F3D274D39C10D2AD4152EEFEF93A9BE6A63E3'
    redirection_count = 0
    redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-v5-capture-clean-stage5-evidence.ps1' = @{
    command_count = 246
    command_sha256 = '8E5FB54184961B8BFCF6C50AF53E92B94DE123FB6E6E31939375F36C045AED2B'
    redirection_count = 0
    redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-v5-coordinator-lib.ps1' = @{
    command_count = 1169
    command_sha256 = 'ACC2BDE3A990CC90ECECB2F7F3FFFB93C291BAA0F0B912D3C844A344978D6900'
    redirection_count = 16
    redirection_sha256 = 'A27C1F1A1A78A655A820FF3FB0CF52CDB0B3A4DF14EE3A8B21EADCFCD395E8EE'
  }
  'issue13-v5-coordinator.ps1' = @{
    command_count = 418
    command_sha256 = '849D03AB9615B8D2E95A6FBF13D9B44CC3D3B0218EB19C22FD4680761CB9520E'
    redirection_count = 2
    redirection_sha256 = '085831E9BDB8C3100B84B1D27450520F0DCA253440E9644501B931C9273D75D7'
  }
  'issue13-v5-materialize-harness.ps1' = @{
    command_count = 253
    command_sha256 = '591C255AC8391AF3C3D407AA1EC5C3C55C4856BE212C92EDCEFD36EBD3CFA40F'
    redirection_count = 4
    redirection_sha256 = '5FE6646416132F2444D3AC9C63EBDF8DCEAE6E18DC5242C675574BC026FF9352'
  }
  'issue13-v5-new-config.ps1' = @{
    command_count = 161
    command_sha256 = 'CE9E21B28841EF1E4222BF74823A812D29FC055493374AC51AB6B54FB5A29685'
    redirection_count = 3
    redirection_sha256 = 'F5308A7B6632030C8FB84F968127215DAEBCBFF41DA11F9D9F9E7D902B8D4F47'
  }
  'issue13-v5-oracle-effect-generate.ps1' = @{
    command_count = 50
    command_sha256 = '876696BF59F09F8A73947FAADED8C2FD6D8A412418A453FC6EFE1C6DFF89BF2B'
    redirection_count = 0
    redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-v5-oracle-effect-lib.ps1' = @{
    command_count = 889
    command_sha256 = '6B70A7CE2938CA3A54CFE0291A8297D1FB62C51BF383C5F0B86FDA3598D725EA'
    redirection_count = 0
    redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-v5-oracle-effect-validate.ps1' = @{
    command_count = 21
    command_sha256 = '5ED874370190D9050DD638FB5A4D1E2EEADD80E21DCFFDB8CCF0D52632B0A9B5'
    redirection_count = 0
    redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-v5-render-report.ps1' = @{
    command_count = 297
    command_sha256 = 'F5E15E521804842E0B2F570862A4322D072267594F1F0FFF859B853FFCBE0D1E'
    redirection_count = 9
    redirection_sha256 = '7F4027149DBBCCC5E186586FA06D6058EF6E3821AC51098E7521EBC767D5FE2D'
  }
  'issue13-v5-static-verify.ps1' = @{
    command_count = 732
    command_sha256 = 'B297CEAF051F95ACF17D679037BC537B66EF90E0161299321ADA50589ABEDBFD'
    redirection_count = 0
    redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
}
$issue13ExpectedControllerSourceSha256 = @{
  'issue13-v5-attest-delivery.ps1' = '2E1A9D527AB98C3EFCF296DB56E59FCE34461C9A7A0A979044EC70E2B54B981D'
  'issue13-v5-baseline-smoke.ps1' = '0F040EB03F3A7AEEFAACF6B0437C5C12D11A3803C9C163B5134D22D928CF3DF6'
  'issue13-v5-capture-clean-bridge-evidence.ps1' = 'A78F5C6535ADFF09F4248F1EA192F0058DCF4B129A0295E1C04357BC1747B6E6'
  'issue13-v5-capture-clean-stage5-evidence.ps1' = 'EDCFCE9759F8B73E2368A36ABA309FA3D330C91C417249D49B69A4194768BFF8'
  'issue13-v5-coordinator-lib.ps1' = 'A99CDED9165CCAC9A93A1AF640FB0DC850C26A815A1C694294E7B5DC5A8F47A5'
  'issue13-v5-coordinator.ps1' = '57A284A2600AAC37B5879BA44EB6B4AB1953AB00590D4EA6720524195E0EBF28'
  'issue13-v5-materialize-harness.ps1' = '8CBD99EA71B7C21DAB3CAF66E0BB79729C91557982AA9A9B93DD0AF90EB309C7'
  'issue13-v5-new-config.ps1' = '221ED165A1EE746A296C881C9E104612FB5E0A97803C68490F544F6ADED68AEF'
  'issue13-v5-oracle-effect-generate.ps1' = '6C1E26154794A253974B7E51C5D15B054AE2D31E09736BF19B624F56EA3C30F9'
  'issue13-v5-oracle-effect-lib.ps1' = '6CCA4757A9754D5DC778200EE37901D232A45A94021E36200BAA53334CEA5290'
  'issue13-v5-oracle-effect-validate.ps1' = '11912422CEB54A45A791E49E11688F974AB45A4CC0F2FB89145D90176AAB0140'
  'issue13-v5-render-report.ps1' = 'F7B11D7CD0AF8F867467AED19D220E135C6F69D6416413C81FC2AFDCD842153B'
    'issue13-v5-static-verify.ps1' = 'D11E77E23963704D110D30293C25F769046E6B01721466AF3158C01178F4A580'
}
$issue13ExpectedDotSourceSignatures = @{
  'issue13-v5-attest-delivery.ps1' = @(
    "([IO.Path]::Combine(`$PSScriptRoot, 'issue13-v5-coordinator-lib.ps1'))"
  )
  'issue13-v5-baseline-smoke.ps1' = @(
    "([IO.Path]::Combine(`$PSScriptRoot, 'issue13-v5-coordinator-lib.ps1'))"
  )
  'issue13-v5-capture-clean-bridge-evidence.ps1' = @(
    "([IO.Path]::Combine(`$PSScriptRoot, 'issue13-v5-coordinator-lib.ps1'))"
  )
  'issue13-v5-capture-clean-stage5-evidence.ps1' = @(
    "([IO.Path]::Combine(`$PSScriptRoot, 'issue13-v5-coordinator-lib.ps1'))"
  )
  'issue13-v5-coordinator.ps1' = @(
    "([IO.Path]::Combine(`$PSScriptRoot, 'issue13-v5-coordinator-lib.ps1'))"
  )
  'issue13-v5-materialize-harness.ps1' = @(
    "([IO.Path]::Combine(`$PSScriptRoot, 'issue13-v5-coordinator-lib.ps1'))"
  )
  'issue13-v5-new-config.ps1' = @(
    "([IO.Path]::Combine(`$PSScriptRoot, 'issue13-v5-coordinator-lib.ps1'))"
  )
  'issue13-v5-oracle-effect-generate.ps1' = @(
    "([IO.Path]::Combine(`$PSScriptRoot, 'issue13-v5-oracle-effect-lib.ps1'))"
  )
  'issue13-v5-oracle-effect-lib.ps1' = @(
    "([IO.Path]::Combine(`$PSScriptRoot, 'issue13-v5-coordinator-lib.ps1'))"
  )
  'issue13-v5-oracle-effect-validate.ps1' = @(
    "([IO.Path]::Combine(`$PSScriptRoot, 'issue13-v5-oracle-effect-lib.ps1'))"
  )
  'issue13-v5-render-report.ps1' = @(
    "([IO.Path]::Combine(`$PSScriptRoot, 'issue13-v5-coordinator-lib.ps1'))"
  )
  'issue13-v5-static-verify.ps1' = @(
    '$bootstrapOracleScript',
    '$bootstrapDeliveryResolverScript'
  )
}
function Test-Issue13V5CriticalDefinitionOwnership(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string[]]$ExpectedNames
) {
  $actual = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      $issue13CriticalPowerShellNames -icontains
        (Get-Issue13V5PowerShellCommandLeaf $node.Name)
  }, $true) | ForEach-Object { $_.Name })
  [string]::Join("`n", [string[]]@($actual)) -ceq
    [string]::Join("`n", [string[]]@($ExpectedNames))
}
function Test-Issue13V5ImportedFunctionNamespaceIsolation(
  [Management.Automation.Language.ScriptBlockAst]$ImportedAst,
  [Management.Automation.Language.ScriptBlockAst]$ConsumerAst
) {
  $importedNames = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  foreach ($definition in @($ImportedAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst]
      }, $true))) {
    $null = $importedNames.Add(
      (Get-Issue13V5PowerShellCommandLeaf $definition.Name))
  }
  $collisions = @($ConsumerAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        $importedNames.Contains(
          (Get-Issue13V5PowerShellCommandLeaf $node.Name))
    }, $true))
  $importedNames.Count -ne 0 -and $collisions.Count -eq 0
}
function Test-Issue13V5BootstrapImports(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string[]]$ExpectedDotSourceSignatures
) {
  $imports = @($Ast.FindAll({
    param($node)
    ($node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -iin @(
        'Import-Module', 'ipmo', 'Import-PSSession', 'ipsn'
      )) -or
      ($node -is [Management.Automation.Language.UsingStatementAst] -and
        $node.UsingStatementKind.ToString() -iin @('Module', 'Assembly'))
  }, $true))
  $dotSources = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      $node.InvocationOperator -eq
        [Management.Automation.Language.TokenKind]::Dot
  }, $true))
  $actual = @($dotSources | ForEach-Object {
    [string]::Join('|', @($_.CommandElements | ForEach-Object {
      $_.Extent.Text
    }))
  })
  $requirements = $Ast.ScriptRequirements
  $requirementsClean = $null -eq $requirements -or
    (@($requirements.RequiredModules).Count -eq 0 -and
      @($requirements.RequiredAssemblies).Count -eq 0)
  @($imports).Count -eq 0 -and
    $requirementsClean -and
    [string]::Join("`n", [string[]]@($actual)) -ceq
      [string]::Join("`n", [string[]]@($ExpectedDotSourceSignatures))
}
$issue13ControllerPowerShellAsts = @{}
$issue13ControllerPowerShellTexts = @{}
$issue13ControllerPowerShellFileSha256 = @{}
foreach ($controllerPowerShellName in @($expectedControllerFiles |
    Where-Object { $_ -like '*.ps1' })) {
  $criticalTokens = $null
  $criticalErrors = @()
  $criticalPath = Join-Path $root $controllerPowerShellName
  $criticalText = [string]$bootstrapSourceTexts[$controllerPowerShellName]
  $criticalFileSha256 =
    [string]$bootstrapSourceFileSha256[$controllerPowerShellName]
  $criticalAst = $bootstrapSourceAsts[$controllerPowerShellName]
  $issue13ControllerPowerShellAsts[$controllerPowerShellName] = $criticalAst
  $issue13ControllerPowerShellTexts[$controllerPowerShellName] = $criticalText
  $issue13ControllerPowerShellFileSha256[$controllerPowerShellName] =
    $criticalFileSha256
  $expectedDefinitions = if (
      $issue13CriticalDefinitionOwners.ContainsKey($controllerPowerShellName)) {
    @($issue13CriticalDefinitionOwners[$controllerPowerShellName])
  } else {
    @()
  }
  $expectedDotSources = if (
      $issue13ExpectedDotSourceSignatures.ContainsKey(
        $controllerPowerShellName)) {
    @($issue13ExpectedDotSourceSignatures[$controllerPowerShellName])
  } else {
    @()
  }
  if ($criticalErrors.Count -ne 0 -or
      -not $issue13ExpectedControllerSourceSha256.ContainsKey(
        $controllerPowerShellName) -or
      (Get-Issue13V5ControllerSourceSha256 `
        $criticalText $controllerPowerShellName) -cne
        [string]$issue13ExpectedControllerSourceSha256[
          $controllerPowerShellName] -or
      -not $issue13ExpectedAstSurfaces.ContainsKey(
        $controllerPowerShellName) -or
      -not (Test-Issue13V5AstSurface $criticalAst `
        $issue13ExpectedAstSurfaces[$controllerPowerShellName]) -or
      -not (Test-Issue13V5CanonicalCriticalCommands `
        $criticalAst $issue13CriticalPowerShellNames) -or
      -not (Test-Issue13V5CriticalDefinitionOwnership `
        $criticalAst $expectedDefinitions) -or
      -not (Test-Issue13V5BootstrapImports `
        $criticalAst $expectedDotSources)) {
    throw "Critical command is qualified, case-variant, or dynamic: $controllerPowerShellName"
  }
  $criticalBytesAfter = [IO.File]::ReadAllBytes($criticalPath)
  $criticalHashAfter = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($criticalBytesAfter))
  if ($criticalHashAfter -cne $criticalFileSha256) {
    throw "Controller source changed while authenticating: $controllerPowerShellName"
  }
}

$coordinatorNamespaceAst = $issue13ControllerPowerShellAsts[
  'issue13-v5-coordinator-lib.ps1']
$coordinatorImportSignature =
  "([IO.Path]::Combine(`$PSScriptRoot, 'issue13-v5-coordinator-lib.ps1'))"
$coordinatorNamespaceConsumers = @(
  $issue13ExpectedDotSourceSignatures.Keys | Where-Object {
    $issue13ControllerPowerShellAsts.ContainsKey($_) -and
      @($issue13ExpectedDotSourceSignatures[$_]) -ccontains
        $coordinatorImportSignature
  })
if ($coordinatorNamespaceConsumers.Count -ne 9 -or
    @($coordinatorNamespaceConsumers | Where-Object {
      -not (Test-Issue13V5ImportedFunctionNamespaceIsolation `
        $coordinatorNamespaceAst $issue13ControllerPowerShellAsts[$_])
    }).Count -ne 0) {
  throw 'A coordinator consumer shadows an imported function definition.'
}
$namespaceValidTokens = $null
$namespaceValidErrors = $null
$namespaceValidAst = [Management.Automation.Language.Parser]::ParseInput(
  'function Invoke-Issue13V5NamespaceUnique {}',
  [ref]$namespaceValidTokens, [ref]$namespaceValidErrors)
$namespaceMutantTokens = $null
$namespaceMutantErrors = $null
$namespaceMutantAst = [Management.Automation.Language.Parser]::ParseInput(
  'function get-issue13v5sha256 {}',
  [ref]$namespaceMutantTokens, [ref]$namespaceMutantErrors)
if ($namespaceValidErrors.Count -ne 0 -or
    $namespaceMutantErrors.Count -ne 0 -or
    -not (Test-Issue13V5ImportedFunctionNamespaceIsolation `
      $coordinatorNamespaceAst $namespaceValidAst) -or
    (Test-Issue13V5ImportedFunctionNamespaceIsolation `
      $coordinatorNamespaceAst $namespaceMutantAst)) {
  throw 'Imported-function namespace isolation accepted a shadow mutant.'
}

# These variable-write helpers are needed by the Commit E checks below.  Keep
# their definitions ahead of every executable use so the verifier remains
# single-pass under a fresh PowerShell process.
function Get-Issue13V5AssignmentBaseVariableName(
  [Management.Automation.Language.Ast]$Left
) {
  $current = $Left
  while ($null -ne $current) {
    if ($current -is
        [Management.Automation.Language.VariableExpressionAst]) {
      $name = [string]$current.VariablePath.UserPath
      $scope = $name.IndexOf(':')
      if ($scope -ge 0 -and $name.Substring(0, $scope) -iin @(
          'script', 'local', 'private', 'global', 'variable')) {
        $name = $name.Substring($scope + 1)
      }
      return '$' + $name
    }
    if ($current -is [Management.Automation.Language.MemberExpressionAst]) {
      $current = $current.Expression
      continue
    }
    if ($current -is [Management.Automation.Language.IndexExpressionAst]) {
      $current = $current.Target
      continue
    }
    if ($current -is [Management.Automation.Language.ConvertExpressionAst] -or
        $current -is
          [Management.Automation.Language.AttributedExpressionAst]) {
      $current = $current.Child
      continue
    }
    if ($current -is [Management.Automation.Language.ParenExpressionAst] -and
        $current.Pipeline.PipelineElements.Count -eq 1 -and
        $current.Pipeline.PipelineElements[0] -is
          [Management.Automation.Language.CommandExpressionAst]) {
      $current = $current.Pipeline.PipelineElements[0].Expression
      continue
    }
    $variables = @($current.FindAll({
      param($node)
      $node -is [Management.Automation.Language.VariableExpressionAst]
    }, $true))
    if ($variables.Count -eq 1) {
      $current = $variables[0]
      continue
    }
    return ''
  }
  ''
}
function Get-Issue13V5VariableWriteBaseName(
  [Management.Automation.Language.Ast]$Node
) {
  if ($Node -is
      [Management.Automation.Language.AssignmentStatementAst]) {
    return Get-Issue13V5AssignmentBaseVariableName $Node.Left
  }
  if ($Node -is [Management.Automation.Language.UnaryExpressionAst] -and
      $Node.TokenKind -in @(
        [Management.Automation.Language.TokenKind]::PlusPlus,
        [Management.Automation.Language.TokenKind]::MinusMinus,
        [Management.Automation.Language.TokenKind]::PostfixPlusPlus,
        [Management.Automation.Language.TokenKind]::PostfixMinusMinus)) {
    return Get-Issue13V5AssignmentBaseVariableName $Node.Child
  }
  if ($Node -is [Management.Automation.Language.ForEachStatementAst]) {
    return Get-Issue13V5AssignmentBaseVariableName $Node.Variable
  }
  if ($Node -is [Management.Automation.Language.ConvertExpressionAst] -and
      $Node.Type.TypeName.FullName -ieq 'ref') {
    return Get-Issue13V5AssignmentBaseVariableName $Node.Child
  }
  if ($Node -is [Management.Automation.Language.FileRedirectionAst] -and
      $Node.Location -is
        [Management.Automation.Language.StringConstantExpressionAst] -and
      $Node.Location.Value -imatch '^variable:') {
    $name = $Node.Location.Value.Substring('variable:'.Length).
      TrimStart([char]'\', [char]'/')
    return '$' + $name
  }
  ''
}
function Get-Issue13V5VariableWriteAsts(
  [Management.Automation.Language.Ast]$Ast,
  [string]$VariableName
) {
  @($Ast.FindAll({
    param($node)
    if ((Get-Issue13V5VariableWriteBaseName $node) -ieq $VariableName) {
      return $true
    }
    $target = if ($node -is
        [Management.Automation.Language.AssignmentStatementAst]) {
      $node.Left
    } elseif ($node -is [Management.Automation.Language.UnaryExpressionAst] -and
        $node.TokenKind -in @(
          [Management.Automation.Language.TokenKind]::PlusPlus,
          [Management.Automation.Language.TokenKind]::MinusMinus,
          [Management.Automation.Language.TokenKind]::PostfixPlusPlus,
          [Management.Automation.Language.TokenKind]::PostfixMinusMinus)) {
      $node.Child
    } elseif ($node -is
        [Management.Automation.Language.ForEachStatementAst]) {
      $node.Variable
    } elseif ($node -is
        [Management.Automation.Language.ConvertExpressionAst] -and
        $node.Type.TypeName.FullName -ieq 'ref') {
      $node.Child
    } else {
      $null
    }
    if ($null -eq $target) { return $false }
    @($target.FindAll({
      param($variable)
      $variable -is
        [Management.Automation.Language.VariableExpressionAst] -and
        (Get-Issue13V5AssignmentBaseVariableName $variable) -ieq
          $VariableName
    }, $true)).Count -ne 0
  }, $true))
}

# Commit E: authenticate the explicit process-environment contract, the
# candidate-commit source tooling, and the historical/oracle proof boundary.
function Get-Issue13V5StaticTopLevelFunctions(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string]$Name
) {
  @($Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq $Name -and
        $node.Parent -is [Management.Automation.Language.NamedBlockAst] -and
        [object]::ReferenceEquals($node.Parent.Parent, $Ast)
    }, $true))
}
function Test-Issue13V5StaticExactProperties(
  [object]$Value,
  [string[]]$Expected
) {
  if ($null -eq $Value) { return $false }
  [string]::Join("`n", @($Value.PSObject.Properties.Name)) -ceq
    [string]::Join("`n", $Expected)
}
function Get-Issue13V5StaticHashtableKeys(
  [Management.Automation.Language.HashtableAst]$Hashtable
) {
  [string[]]@($Hashtable.KeyValuePairs | ForEach-Object {
      if ($_.Item1 -isnot
          [Management.Automation.Language.StringConstantExpressionAst]) {
        return '<dynamic>'
      }
      [string]$_.Item1.Value
    })
}
function Test-Issue13V5StaticEnvironmentSetter(
  [Management.Automation.Language.FunctionDefinitionAst]$Definition,
  [string]$ExpectedName
) {
  if ($null -eq $Definition -or $Definition.Name -cne $ExpectedName) {
    return $false
  }
  $text = [string]$Definition.Extent.Text
  $removeCalls = @($Definition.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Remove-Item'
    }, $true))
  $setItemCalls = @($Definition.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Set-Item'
    }, $true))
  $setEnvironmentCalls = @($Definition.FindAll({
      param($node)
      $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Member.Extent.Text -ieq 'SetEnvironmentVariable'
    }, $true))
  $nullSetEnvironmentArguments = @($setEnvironmentCalls | Where-Object {
      @($_.Arguments | Where-Object {
          $_ -is [Management.Automation.Language.ConstantExpressionAst] -and
            $null -eq $_.Value
        }).Count -ne 0
    })
  $nullSetItems = @($setItemCalls | Where-Object {
      [regex]::IsMatch($_.Extent.Text, '(?i)-Value\s+\$null(?:\s|$)')
    })
  $isOracleSetter = $ExpectedName -ceq
    'Set-Issue13OracleEffectProcessEnvironmentState'
  $seenOffset = if ($isOracleSetter) {
    $text.IndexOf('Assert-Issue13OracleEffectExactProperties $State',
      [StringComparison]::Ordinal)
  } else {
    $text.IndexOf('$seen.Add($name)', [StringComparison]::Ordinal)
  }
  if (-not $isOracleSetter -and $seenOffset -lt 0) {
    $seenOffset = $text.IndexOf(
      '$seen.Add([string]$state.name)', [StringComparison]::Ordinal)
  }
  $firstMutationOffset = @(
    @($removeCalls + $setItemCalls) | ForEach-Object {
      $_.Extent.StartOffset - $Definition.Extent.StartOffset
    }
    @($setEnvironmentCalls) | ForEach-Object {
      $_.Extent.StartOffset - $Definition.Extent.StartOffset
    }
  ) | Measure-Object -Minimum
  $hasStateContract = $text.Contains("'name', 'present', 'value'") -and
    (($text.IndexOf('$state.present -isnot [bool]',
          [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
      ($text.IndexOf('$state.present -is [bool]',
          [StringComparison]::OrdinalIgnoreCase) -ge 0)) -and
    (($text.IndexOf('$state.value -isnot [string]',
          [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
      ($text.IndexOf('$state.value -is [string]',
          [StringComparison]::OrdinalIgnoreCase) -ge 0)) -and
    (($text.IndexOf('$null -ne $state.value',
          [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
      ($text.IndexOf('$null -eq $state.value',
          [StringComparison]::OrdinalIgnoreCase) -ge 0))
  $valueTypeCheck = [regex]::Match($text,
    '(?i)\$state\.value\s+-is(?:not)?\s+\[string\]')
  $valueCast = [regex]::Match($text, '(?i)\[string\]\$state\.value')
  $removeSignature = if ($removeCalls.Count -eq 1) {
    [string]::Join('|', @($removeCalls[0].CommandElements |
        ForEach-Object { $_.Extent.Text }))
  } else { '' }
  $removeExact = $removeSignature -cin @(
    "Remove-Item|-LiteralPath|('Env:' + `$name)|-Force|-ErrorAction|SilentlyContinue",
    "Remove-Item|-LiteralPath|('Env:' + `$name)|-Force|-ErrorAction|Stop",
    "Remove-Item|-LiteralPath|('Env:' + `$name)|-ErrorAction|Stop"
  )
  $removeVerified = if ($isOracleSetter) {
    $text.Contains('Get-Issue13OracleEffectProcessEnvironmentState')
  } else {
    $text.Contains('Test-Path -LiteralPath $path') -and
      $text.Contains('GetEnvironmentVariable')
  }
  $duplicateContract = if ($isOracleSetter) {
    $text.Contains('Assert-Issue13OracleEffectProcessEnvironmentName')
  } else {
    $text.Contains('OrdinalIgnoreCase')
  }
  $seenOffset -ge 0 -and $firstMutationOffset.Count -ge 1 -and
    $seenOffset -lt [long]$firstMutationOffset.Minimum -and
    $duplicateContract -and $hasStateContract -and
    $valueTypeCheck.Success -and $valueCast.Success -and
    $valueTypeCheck.Index -lt $valueCast.Index -and
    $removeCalls.Count -eq 1 -and $removeExact -and $removeVerified -and
    $nullSetEnvironmentArguments.Count -eq 0 -and $nullSetItems.Count -eq 0 -and
    -not $text.Contains('IsNullOrEmpty')
}

$commitECriticalOwners = [ordered]@{
  'Assert-Issue13V5EnvironmentName' = 'issue13-v5-coordinator-lib.ps1'
  'ConvertTo-Issue13V5EnvironmentMutations' = 'issue13-v5-coordinator-lib.ps1'
  'Get-Issue13V5ProcessEnvironmentState' = 'issue13-v5-coordinator-lib.ps1'
  'Set-Issue13V5ProcessEnvironmentState' = 'issue13-v5-coordinator-lib.ps1'
  'Invoke-Issue13V5WithCleanup' = 'issue13-v5-coordinator-lib.ps1'
  'Enter-Issue13V5ProcessEnvironment' = 'issue13-v5-coordinator-lib.ps1'
  'Exit-Issue13V5ProcessEnvironment' = 'issue13-v5-coordinator-lib.ps1'
  'Invoke-Issue13V5WithProcessEnvironment' = 'issue13-v5-coordinator-lib.ps1'
  'Set-Issue13V5ProcessStartInfoEnvironment' = 'issue13-v5-coordinator-lib.ps1'
  'New-Issue13V5ClosedREnvironment' = 'issue13-v5-coordinator-lib.ps1'
  'Test-Issue13V5ProcessEnvironmentSelfTest' = 'issue13-v5-coordinator-lib.ps1'
  'Stop-Issue13V5ExternalProcess' = 'issue13-v5-coordinator-lib.ps1'
  'Invoke-Issue13V5RscriptBounded' = 'issue13-v5-coordinator-lib.ps1'
  'Assert-Issue13V5HarnessBinding' = 'issue13-v5-coordinator-lib.ps1'
  'Assert-Issue13V5BaselineSmokeEvidence' = 'issue13-v5-coordinator-lib.ps1'
  'Invoke-Issue13V5External' = 'issue13-v5-coordinator-lib.ps1'
  'Invoke-Issue13V5R' = 'issue13-v5-coordinator-lib.ps1'
  'Invoke-Issue13V5Pwsh' = 'issue13-v5-coordinator-lib.ps1'
  'Invoke-Issue13V5GitBytes' = 'issue13-v5-materialize-harness.ps1'
  'Get-Issue13V5TrackedSourceTooling' = 'issue13-v5-materialize-harness.ps1'
  'Invoke-Issue13OracleEffectGitBytes' = 'issue13-v5-oracle-effect-lib.ps1'
  'Get-Issue13OracleEffectExpectedSourceTooling' =
    'issue13-v5-oracle-effect-lib.ps1'
  'Get-Issue13OracleEffectRscriptIdentity' =
    'issue13-v5-oracle-effect-lib.ps1'
  'Get-Issue13OracleEffectProcessEnvironmentState' =
    'issue13-v5-oracle-effect-lib.ps1'
  'Set-Issue13OracleEffectProcessEnvironmentState' =
    'issue13-v5-oracle-effect-lib.ps1'
  'Enter-Issue13OracleEffectSanitizedREnvironment' =
    'issue13-v5-oracle-effect-lib.ps1'
  'Exit-Issue13OracleEffectSanitizedREnvironment' =
    'issue13-v5-oracle-effect-lib.ps1'
  'Test-Issue13OracleEffectNegativeSelfTests' =
    'issue13-v5-oracle-effect-lib.ps1'
  'Test-Issue13OracleEffectSpec' = 'issue13-v5-oracle-effect-lib.ps1'
  'Assert-Issue13OracleEffectHarnessManifestEnvelope' =
    'issue13-v5-oracle-effect-lib.ps1'
  'Test-Issue13OracleEffectHarnessManifest' =
    'issue13-v5-oracle-effect-lib.ps1'
  'Get-Issue13OracleEffectInputContext' = 'issue13-v5-oracle-effect-lib.ps1'
  'Get-Issue13OracleEffectEvidence' = 'issue13-v5-oracle-effect-lib.ps1'
}
foreach ($criticalName in $commitECriticalOwners.Keys) {
  $matches = @()
  foreach ($fileName in $issue13ControllerPowerShellAsts.Keys) {
    $matches += @(Get-Issue13V5StaticTopLevelFunctions `
        $issue13ControllerPowerShellAsts[$fileName] $criticalName |
        ForEach-Object {
          [pscustomobject]@{ file = $fileName; definition = $_ }
        })
  }
  if ($matches.Count -ne 1 -or $matches[0].definition.Name -cne $criticalName -or
      [string]$matches[0].file -cne [string]$commitECriticalOwners[$criticalName]) {
    throw "Commit E helper ownership is missing, nested, or ambiguous: $criticalName"
  }
}

$centralAst = $issue13ControllerPowerShellAsts[
  'issue13-v5-coordinator-lib.ps1']
$centralText = $issue13ControllerPowerShellTexts[
  'issue13-v5-coordinator-lib.ps1']
$materializerAst = $issue13ControllerPowerShellAsts[
  'issue13-v5-materialize-harness.ps1']
$materializerText = $issue13ControllerPowerShellTexts[
  'issue13-v5-materialize-harness.ps1']
$newConfigText = $issue13ControllerPowerShellTexts[
  'issue13-v5-new-config.ps1']
$oracleLibraryText = $issue13ControllerPowerShellTexts[
  'issue13-v5-oracle-effect-lib.ps1']
function Test-Issue13V5StaticAddTypeAuthority(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string]$TypeName,
  [string]$PreexistingVariable,
  [string]$TypesVariable,
  [string]$TypeVariable,
  [string]$LoadedVariable,
  [string]$MethodsVariable,
  [string]$AssembliesBeforeVariable,
  [string]$NonTypesVariable,
  [string]$ReturnedAssembliesVariable,
  [string]$AssemblyWasPreexistingVariable,
  [string]$CapturedVariable,
  [string]$CapturedValueExpression,
  [string]$ExpectedUseMembers,
  [long]$ExpectedReturnedCount,
  [string]$ExpectedReturnedNames,
  [string]$ExpectedMethods,
  [string]$PreloadedMessage,
  [string]$CompilationMessage
) {
  $writes = @{}
  foreach ($variableName in [string[]]@(
      $PreexistingVariable, $TypesVariable, $TypeVariable,
      $LoadedVariable, $MethodsVariable, $AssembliesBeforeVariable,
      $NonTypesVariable, $ReturnedAssembliesVariable,
      $AssemblyWasPreexistingVariable)) {
    $writes[$variableName] = @($Ast.FindAll({
        param($node)
        $node -is
          [Management.Automation.Language.AssignmentStatementAst] -and
          $node.Left -is
            [Management.Automation.Language.VariableExpressionAst] -and
          $node.Left.VariablePath.UserPath -ceq $variableName
      }, $true))
    if ($writes[$variableName].Count -ne 1) { return $false }
  }
  $preexistingAssignment = $writes[$PreexistingVariable][0]
  $typesAssignment = $writes[$TypesVariable][0]
  $typeAssignment = $writes[$TypeVariable][0]
  $loadedAssignment = $writes[$LoadedVariable][0]
  $methodsAssignment = $writes[$MethodsVariable][0]
  $assembliesBeforeAssignment = $writes[$AssembliesBeforeVariable][0]
  $nonTypesAssignment = $writes[$NonTypesVariable][0]
  $returnedAssembliesAssignment = $writes[$ReturnedAssembliesVariable][0]
  $assemblyWasPreexistingAssignment =
    $writes[$AssemblyWasPreexistingVariable][0]
  $precheckNormalized = [regex]::Replace(
    [string]$preexistingAssignment.Extent.Text, '[\s`]', '')
  $loadedNormalized = [regex]::Replace(
    [string]$loadedAssignment.Extent.Text, '[\s`]', '')
  $expectedPreexisting =
    ('$' + $PreexistingVariable + '=[type[]]@(' +
      '[AppDomain]::CurrentDomain.GetAssemblies()|ForEach-Object{' +
      '$_.GetType(''' + $TypeName + ''',$false,$true)}|' +
      'Where-Object{$null-ne$_})')
  $expectedLoaded =
    ('$' + $LoadedVariable + '=[type[]]@(' +
      '[AppDomain]::CurrentDomain.GetAssemblies()|ForEach-Object{' +
      '$_.GetType(''' + $TypeName + ''',$false,$true)}|' +
      'Where-Object{$null-ne$_})')
  if ($precheckNormalized -cne $expectedPreexisting -or
      $loadedNormalized -cne $expectedLoaded) {
    return $false
  }
  if ([regex]::Replace(
        [string]$assembliesBeforeAssignment.Extent.Text, '[\s`]', '') -cne
      ('$' + $AssembliesBeforeVariable +
        '=[Reflection.Assembly[]]@(' +
        '[AppDomain]::CurrentDomain.GetAssemblies())') -or
      -not [regex]::Replace(
        [string]$nonTypesAssignment.Extent.Text, '[\s`]', '').Contains(
          ('$' + $TypesVariable +
            '|Where-Object{$_-isnot[type]}')) -or
      -not [regex]::Replace(
        [string]$returnedAssembliesAssignment.Extent.Text,
        '[\s`]', '').Contains(
          ('$' + $TypesVariable +
            '|ForEach-Object{$_.Assembly}|Select-Object-Unique')) -or
      -not [regex]::Replace(
        [string]$assemblyWasPreexistingAssignment.Extent.Text,
        '[\s`]', '').Contains(
          ('$' + $AssembliesBeforeVariable +
            '|Where-Object{[object]::ReferenceEquals($_,$' +
            $ReturnedAssembliesVariable + '[0])}'))) {
    return $false
  }
  $normalizedPreloadedMessage = [regex]::Replace(
    $PreloadedMessage, '[\s`]', '')
  $precheckIfs = @($Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.IfStatementAst] -and
        [regex]::Replace(
          [string]$node.Extent.Text, '[\s`]', '') -ceq
          ('if($' + $PreexistingVariable + '.Count-ne0){throw''' +
            $normalizedPreloadedMessage + '''}')
    }, $true))
  $validationIfs = @($Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.IfStatementAst] -and
        [object]::ReferenceEquals(
          $node.Parent, $typesAssignment.Parent) -and
        [string]$node.Extent.Text -cmatch
          [regex]::Escape("throw '$CompilationMessage'")
    }, $true))
  $addTypeCalls = @($typesAssignment.Right.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -ceq 'Add-Type'
    }, $true))
  if ($precheckIfs.Count -ne 1 -or $validationIfs.Count -ne 1 -or
      $addTypeCalls.Count -ne 1) {
    return $false
  }
  $addTypeCall = $addTypeCalls[0]
  $parameters = @($addTypeCall.CommandElements | Where-Object {
      $_ -is [Management.Automation.Language.CommandParameterAst]
    })
  if ($addTypeCall.InvocationOperator -ne
        [Management.Automation.Language.TokenKind]::Unknown -or
      $addTypeCall.CommandElements.Count -ne 6 -or
      [string]::Join(',', [string[]]@(
        $parameters | ForEach-Object { $_.ParameterName })) -cne
        'PassThru,ErrorAction,TypeDefinition' -or
      $addTypeCall.CommandElements[3].Extent.Text -cne 'Stop') {
    return $false
  }
  $typeNormalized = [regex]::Replace(
    [string]$typeAssignment.Extent.Text, '[\s`]', '')
  if ($typeNormalized -cne
      ('$' + $TypeVariable + '=''' + $TypeName + '''-as[type]')) {
    return $false
  }
  $validation = $validationIfs[0]
  $validationNormalized = [regex]::Replace(
    [string]$validation.Extent.Text, '[\s`]', '')
  $referenceEqualsCalls = @($validation.FindAll({
      param($node)
      $node -is
        [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Static -and
        $node.Expression -is
          [Management.Automation.Language.TypeExpressionAst] -and
        $node.Expression.TypeName.FullName -ceq 'object' -and
        $node.Member.Extent.Text -ceq 'ReferenceEquals'
    }, $true))
  $captureCommands = @($Ast.FindAll({
      param($node)
      if ($node -isnot [Management.Automation.Language.CommandAst]) {
        return $false
      }
      $normalized = [regex]::Replace(
        [string]$node.Extent.Text, '[\s`]', '')
      $normalized -ceq
        ('Set-Issue13V5ScriptConstant' + $CapturedVariable +
          $CapturedValueExpression) -or
        $normalized -ceq
          ('New-Variable-Name' + $CapturedVariable +
            '-ScopeScript-OptionConstant-Value' +
            $CapturedValueExpression)
    }, $true))
  $capturedUses = @($Ast.FindAll({
      param($node)
      $node -is
        [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Static -and
        $node.Expression -is
          [Management.Automation.Language.VariableExpressionAst] -and
        $node.Expression.VariablePath.UserPath -ceq
          ('script:' + $CapturedVariable)
    }, $true))
  $nominalTypeUses = @($Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.TypeExpressionAst] -and
        $node.TypeName.FullName -ceq $TypeName
    }, $true))
  $capturedUseMembers = [string]::Join(',', [string[]]@(
      $capturedUses | ForEach-Object { $_.Member.Extent.Text }))
  $expectedMethodsNormalized = [regex]::Replace(
    $ExpectedMethods, '[\s`]', '')
  $methodsAssignmentNormalized = [regex]::Replace(
    [string]$methodsAssignment.Extent.Text, '[\s`]', '')
  $returnedNameChecks = [Collections.Generic.List[bool]]::new()
  foreach ($expectedReturnedName in [string[]]($ExpectedReturnedNames -split
      '\|')) {
    $returnedNameChecks.Add(
      $validationNormalized.Contains($expectedReturnedName))
  }
  $sameContainer =
    [object]::ReferenceEquals(
      $preexistingAssignment.Parent, $precheckIfs[0].Parent) -and
    [object]::ReferenceEquals(
      $preexistingAssignment.Parent, $typesAssignment.Parent) -and
    [object]::ReferenceEquals(
      $preexistingAssignment.Parent, $typeAssignment.Parent) -and
    [object]::ReferenceEquals(
      $preexistingAssignment.Parent, $loadedAssignment.Parent) -and
    [object]::ReferenceEquals(
      $preexistingAssignment.Parent, $methodsAssignment.Parent) -and
    [object]::ReferenceEquals(
      $preexistingAssignment.Parent, $assembliesBeforeAssignment.Parent) -and
    [object]::ReferenceEquals(
      $preexistingAssignment.Parent, $nonTypesAssignment.Parent) -and
    [object]::ReferenceEquals(
      $preexistingAssignment.Parent, $returnedAssembliesAssignment.Parent) -and
    [object]::ReferenceEquals(
      $preexistingAssignment.Parent,
      $assemblyWasPreexistingAssignment.Parent) -and
    [object]::ReferenceEquals(
      $preexistingAssignment.Parent, $validation.Parent)
  $sameContainer -and
    $assembliesBeforeAssignment.Extent.StartOffset -lt
      $preexistingAssignment.Extent.StartOffset -and
    $preexistingAssignment.Extent.StartOffset -lt
      $precheckIfs[0].Extent.StartOffset -and
    $precheckIfs[0].Extent.StartOffset -lt $typesAssignment.Extent.StartOffset -and
    $typesAssignment.Extent.StartOffset -lt $typeAssignment.Extent.StartOffset -and
    $typeAssignment.Extent.StartOffset -lt $loadedAssignment.Extent.StartOffset -and
    $loadedAssignment.Extent.StartOffset -lt
      $methodsAssignment.Extent.StartOffset -and
    $methodsAssignment.Extent.StartOffset -lt $validation.Extent.StartOffset -and
    $captureCommands.Count -eq 1 -and
    $captureCommands[0].Extent.StartOffset -gt $validation.Extent.StartOffset -and
    $capturedUseMembers -ceq $ExpectedUseMembers -and
    $nominalTypeUses.Count -eq 0 -and
    $methodsAssignmentNormalized.Contains(
      '|ForEach-Object{$_.ToString()}|Sort-Object)') -and
    $referenceEqualsCalls.Count -eq 2 -and
    $validationNormalized.Contains(
      ('$' + $TypesVariable + '.Count-ne' + $ExpectedReturnedCount)) -and
    $validationNormalized.Contains(
      ('$' + $NonTypesVariable + '.Count-ne0')) -and
    $validationNormalized.Contains(
      ('$' + $ReturnedAssembliesVariable + '.Count-ne1')) -and
    $validationNormalized.Contains(
      ('$' + $AssemblyWasPreexistingVariable + '.Count-ne0')) -and
    $validationNormalized.Contains(
      ('$' + $LoadedVariable + '.Count-ne1')) -and
    $validationNormalized.Contains(
      ("[string]::Join('|',`$$MethodsVariable)-cne'" +
        $expectedMethodsNormalized + "'")) -and
    -not $returnedNameChecks.Contains($false) -and
    [regex]::Replace(
      [string]$typesAssignment.Right.Extent.Text, '[\s`]', '').StartsWith(
        '[object[]]@(Add-Type-PassThru-ErrorActionStop-TypeDefinition')
}
$addTypeAuthoritySpecs = [object[]]@(
  [pscustomobject]@{
    file = 'issue13-v5-coordinator-lib.ps1'
    type_name = 'Issue13V5.CoordinatorNativePath'
    preexisting = 'preexistingCoordinatorNativePathTypes'
    types = 'coordinatorNativePathTypes'
    type = 'coordinatorNativePathType'
    loaded = 'loadedCoordinatorNativePathTypes'
    methods = 'coordinatorNativePathMethods'
    assemblies_before = 'coordinatorNativePathAssembliesBefore'
    non_types = 'coordinatorNativePathNonTypes'
    returned_assemblies = 'coordinatorNativePathReturnedAssemblies'
    assembly_was_preexisting =
      'coordinatorNativePathAssemblyWasPreexisting'
    captured = 'Issue13V5CoordinatorNativePathType'
    captured_value = '$coordinatorNativePathTargetTypes[0]'
    use_members = 'DriveTarget,Resolve,Identity'
    returned_count = 3L
    returned_names =
      ('Issue13V5.CoordinatorNativePath|' +
        'Issue13V5.CoordinatorNativePath+ByHandleFileInformation|' +
        'Issue13V5.CoordinatorNativePath+FileIdInformation')
    expected_methods =
      ('System.String DriveTarget(System.String)|' +
        'System.String Identity(System.String)|' +
        'System.String Resolve(System.String)')
    preloaded_message = 'The coordinator native path type was preloaded.'
    compilation_message =
      'The coordinator native path type compilation was not singular.'
  },
  [pscustomobject]@{
    file = 'issue13-v5-coordinator-lib.ps1'
    type_name = 'Issue13V5.BoundedStreamCapture'
    preexisting = 'preexistingBoundedStreamCaptureTypes'
    types = 'boundedStreamCaptureTypes'
    type = 'boundedStreamCaptureType'
    loaded = 'loadedBoundedStreamCaptureTypes'
    methods = 'boundedStreamCaptureMethods'
    assemblies_before = 'boundedStreamCaptureAssembliesBefore'
    non_types = 'boundedStreamCaptureNonTypes'
    returned_assemblies = 'boundedStreamCaptureReturnedAssemblies'
    assembly_was_preexisting =
      'boundedStreamCaptureAssemblyWasPreexisting'
    captured = 'Issue13V5BoundedStreamCaptureType'
    captured_value = '$boundedStreamCaptureTypes[0]'
    use_members = 'CopyAsync,CopyAsync'
    returned_count = 1L
    returned_names = 'Issue13V5.BoundedStreamCapture'
    expected_methods =
      ('System.Threading.Tasks.Task`1[System.Int64] ' +
        'CopyAsync(System.IO.Stream, System.IO.Stream, Int64)')
    preloaded_message = 'The bounded stream capture type was preloaded.'
    compilation_message =
      'The bounded stream capture type compilation was not singular.'
  },
  [pscustomobject]@{
    file = 'issue13-v5-baseline-smoke.ps1'
    type_name = 'Issue13V5.BaselineSmokeNativePath'
    preexisting = 'preexistingBaselineSmokeNativePathTypes'
    types = 'baselineSmokeNativePathTypes'
    type = 'baselineSmokeNativePathType'
    loaded = 'loadedBaselineSmokeNativePathTypes'
    methods = 'baselineSmokeNativePathMethods'
    assemblies_before = 'baselineSmokeNativePathAssembliesBefore'
    non_types = 'baselineSmokeNativePathNonTypes'
    returned_assemblies = 'baselineSmokeNativePathReturnedAssemblies'
    assembly_was_preexisting =
      'baselineSmokeNativePathAssemblyWasPreexisting'
    captured = 'Issue13V5BaselineSmokeNativePathType'
    captured_value = '$baselineSmokeNativePathTypes[0]'
    use_members = 'DriveTarget,Resolve'
    returned_count = 1L
    returned_names = 'Issue13V5.BaselineSmokeNativePath'
    expected_methods =
      ('System.String DriveTarget(System.String)|' +
        'System.String Resolve(System.String)')
    preloaded_message = 'The baseline smoke native path type was preloaded.'
    compilation_message =
      'The baseline smoke native path type compilation was not singular.'
  },
  [pscustomobject]@{
    file = 'issue13-v5-materialize-harness.ps1'
    type_name = 'Issue13V5.NativePath'
    preexisting = 'preexistingMaterializerNativePathTypes'
    types = 'materializerNativePathTypes'
    type = 'materializerNativePathType'
    loaded = 'loadedMaterializerNativePathTypes'
    methods = 'materializerNativePathMethods'
    assemblies_before = 'materializerNativePathAssembliesBefore'
    non_types = 'materializerNativePathNonTypes'
    returned_assemblies = 'materializerNativePathReturnedAssemblies'
    assembly_was_preexisting =
      'materializerNativePathAssemblyWasPreexisting'
    captured = 'Issue13V5MaterializerNativePathType'
    captured_value = '$materializerNativePathTypes[0]'
    use_members = 'DriveTarget,Resolve'
    returned_count = 1L
    returned_names = 'Issue13V5.NativePath'
    expected_methods =
      ('System.String DriveTarget(System.String)|' +
        'System.String Resolve(System.String)')
    preloaded_message = 'The materializer native path type was preloaded.'
    compilation_message =
      'The materializer native path type compilation was not singular.'
  },
  [pscustomobject]@{
    file = 'issue13-v5-oracle-effect-lib.ps1'
    type_name = 'Issue13V5.OracleEffectNativePath'
    preexisting = 'preexistingOracleEffectNativePathTypes'
    types = 'oracleEffectNativePathTypes'
    type = 'oracleEffectNativePathType'
    loaded = 'loadedOracleEffectNativePathTypes'
    methods = 'oracleEffectNativePathMethods'
    assemblies_before = 'oracleEffectNativePathAssembliesBefore'
    non_types = 'oracleEffectNativePathNonTypes'
    returned_assemblies = 'oracleEffectNativePathReturnedAssemblies'
    assembly_was_preexisting =
      'oracleEffectNativePathAssemblyWasPreexisting'
    captured = 'Issue13OracleEffectNativePathType'
    captured_value = '$oracleEffectNativePathTargetTypes[0]'
    use_members = 'DriveTarget,Resolve,Identity'
    returned_count = 3L
    returned_names =
      ('Issue13V5.OracleEffectNativePath|' +
        'Issue13V5.OracleEffectNativePath+ByHandleFileInformation|' +
        'Issue13V5.OracleEffectNativePath+FileIdInformation')
    expected_methods =
      ('System.String DriveTarget(System.String)|' +
        'System.String Identity(System.String)|' +
        'System.String Resolve(System.String)')
    preloaded_message = 'The oracle-effect native path type was preloaded.'
    compilation_message =
      'The oracle-effect native path type compilation was not singular.'
  },
  [pscustomobject]@{
    file = 'issue13-v5-static-verify.ps1'
    type_name = 'Issue13V5.NativePath'
    preexisting = 'preexistingStaticMaterializerNativePathTypes'
    types = 'staticMaterializerNativePathTypes'
    type = 'staticMaterializerNativePathType'
    loaded = 'loadedStaticMaterializerNativePathTypes'
    methods = 'staticMaterializerNativePathMethods'
    assemblies_before = 'staticMaterializerNativePathAssembliesBefore'
    non_types = 'staticMaterializerNativePathNonTypes'
    returned_assemblies = 'staticMaterializerNativePathReturnedAssemblies'
    assembly_was_preexisting =
      'staticMaterializerNativePathAssemblyWasPreexisting'
    captured = 'Issue13V5StaticMaterializerNativePathType'
    captured_value = '$staticMaterializerNativePathTypes[0]'
    use_members = 'DriveTarget'
    returned_count = 1L
    returned_names = 'Issue13V5.NativePath'
    expected_methods =
      ('System.String DriveTarget(System.String)|' +
        'System.String Resolve(System.String)')
    preloaded_message =
      'The static verifier materializer native path type was preloaded.'
    compilation_message =
      'The static materializer native path type was not singular.'
  })
foreach ($addTypeAuthoritySpec in $addTypeAuthoritySpecs) {
  $addTypeAuthorityAst = if (
      [string]$addTypeAuthoritySpec.file -ceq
        'issue13-v5-static-verify.ps1') {
    $bootstrapStaticAst
  } else {
    $issue13ControllerPowerShellAsts[[string]$addTypeAuthoritySpec.file]
  }
  if (-not (Test-Issue13V5StaticAddTypeAuthority `
      $addTypeAuthorityAst `
      ([string]$addTypeAuthoritySpec.type_name) `
      ([string]$addTypeAuthoritySpec.preexisting) `
      ([string]$addTypeAuthoritySpec.types) `
      ([string]$addTypeAuthoritySpec.type) `
      ([string]$addTypeAuthoritySpec.loaded) `
      ([string]$addTypeAuthoritySpec.methods) `
      ([string]$addTypeAuthoritySpec.assemblies_before) `
      ([string]$addTypeAuthoritySpec.non_types) `
      ([string]$addTypeAuthoritySpec.returned_assemblies) `
      ([string]$addTypeAuthoritySpec.assembly_was_preexisting) `
      ([string]$addTypeAuthoritySpec.captured) `
      ([string]$addTypeAuthoritySpec.captured_value) `
      ([string]$addTypeAuthoritySpec.use_members) `
      ([long]$addTypeAuthoritySpec.returned_count) `
      ([string]$addTypeAuthoritySpec.returned_names) `
      ([string]$addTypeAuthoritySpec.expected_methods) `
      ([string]$addTypeAuthoritySpec.preloaded_message) `
      ([string]$addTypeAuthoritySpec.compilation_message))) {
    throw ('Add-Type authority is not fail-closed: ' +
      [string]$addTypeAuthoritySpec.type_name)
  }
  $addTypeAuthorityText = [string]$addTypeAuthorityAst.Extent.Text
  $addTypeAuthorityMutants = [string[]]@(
    $addTypeAuthorityText.Replace(
      ('$' + [string]$addTypeAuthoritySpec.preexisting + '.Count -ne 0'),
      ('$' + [string]$addTypeAuthoritySpec.preexisting + '.Count -eq 0')),
    $addTypeAuthorityText.Replace('-PassThru', '-WhatIf'),
    $addTypeAuthorityText.Replace('-ErrorAction Stop', '-ErrorAction Continue'),
    $addTypeAuthorityText.Replace(
      "GetType('$([string]$addTypeAuthoritySpec.type_name)', `$false, `$true)",
      "GetType('$([string]$addTypeAuthoritySpec.type_name)', `$false, `$false)"),
    $addTypeAuthorityText.Replace(
      '| Where-Object { $null -ne $_ })', ')'),
    $addTypeAuthorityText.Replace(
      '[object]::ReferenceEquals(', '[object]::Equals('),
    $addTypeAuthorityText.Replace(
      ('$' + [string]$addTypeAuthoritySpec.loaded + '.Count -ne 1'),
      ('$' + [string]$addTypeAuthoritySpec.loaded + '.Count -lt 2')),
    $addTypeAuthorityText.Replace(
      '.ToString()', '.Name'),
    $addTypeAuthorityText.Replace(
      '-isnot [type]', '-is [type]'),
    $addTypeAuthorityText.Replace(
      'Select-Object -Unique', 'Select-Object'),
    $addTypeAuthorityText.Replace(
      ('$script:' + [string]$addTypeAuthoritySpec.captured),
      ('[' + [string]$addTypeAuthoritySpec.type_name + ']')),
    $addTypeAuthorityText.Replace(
      ('$' + [string]$addTypeAuthoritySpec.types + '.Count -ne ' +
        [long]$addTypeAuthoritySpec.returned_count),
      ('$' + [string]$addTypeAuthoritySpec.types + '.Count -lt ' +
        ([long]$addTypeAuthoritySpec.returned_count + 1L))))
  foreach ($addTypeAuthorityMutant in $addTypeAuthorityMutants) {
    $addTypeAuthorityMutantTokens = $null
    $addTypeAuthorityMutantErrors = $null
    $addTypeAuthorityMutantAst =
      [Management.Automation.Language.Parser]::ParseInput(
        $addTypeAuthorityMutant, [ref]$addTypeAuthorityMutantTokens,
        [ref]$addTypeAuthorityMutantErrors)
    if ($addTypeAuthorityMutant -ceq $addTypeAuthorityText -or
        $addTypeAuthorityMutantErrors.Count -ne 0 -or
        (Test-Issue13V5StaticAddTypeAuthority `
          $addTypeAuthorityMutantAst `
          ([string]$addTypeAuthoritySpec.type_name) `
          ([string]$addTypeAuthoritySpec.preexisting) `
          ([string]$addTypeAuthoritySpec.types) `
          ([string]$addTypeAuthoritySpec.type) `
          ([string]$addTypeAuthoritySpec.loaded) `
          ([string]$addTypeAuthoritySpec.methods) `
          ([string]$addTypeAuthoritySpec.assemblies_before) `
          ([string]$addTypeAuthoritySpec.non_types) `
          ([string]$addTypeAuthoritySpec.returned_assemblies) `
          ([string]$addTypeAuthoritySpec.assembly_was_preexisting) `
          ([string]$addTypeAuthoritySpec.captured) `
          ([string]$addTypeAuthoritySpec.captured_value) `
          ([string]$addTypeAuthoritySpec.use_members) `
          ([long]$addTypeAuthoritySpec.returned_count) `
          ([string]$addTypeAuthoritySpec.returned_names) `
          ([string]$addTypeAuthoritySpec.expected_methods) `
          ([string]$addTypeAuthoritySpec.preloaded_message) `
          ([string]$addTypeAuthoritySpec.compilation_message))) {
      throw 'Add-Type authority verifier accepted a preload/identity mutant.'
    }
  }
}
$boundedTypeSpoofScript = @'
$null = Add-Type -ErrorAction Stop -TypeDefinition 'using System.IO; using System.Threading.Tasks; namespace issue13v5 { public static class boundedstreamcapture { public static Task<long> CopyAsync(Stream source, Stream destination, long maximumBytes) { return Task.FromResult(0L); } } }'
$libraryPath = [Environment]::GetEnvironmentVariable(
  'ISSUE13_V5_SPOOF_LIBRARY_PATH')
try {
  . $libraryPath
  'TYPE_SPOOF_ACCEPTED'
} catch {
  'TYPE_SPOOF_REJECTED:' +
    [string]$_.Exception.GetBaseException().Message
}
'@
$boundedTypeSpoofEncoded = [Convert]::ToBase64String(
  [Text.Encoding]::Unicode.GetBytes($boundedTypeSpoofScript))
$boundedTypeSpoofExecution = Invoke-Issue13V5PwshTransient `
  -Arguments @(
    '-NoLogo', '-NoProfile', '-NonInteractive',
    '-EncodedCommand', $boundedTypeSpoofEncoded) `
  -Label 'bounded-stream-type-preload-selftest' `
  -TimeoutSeconds 120 `
  -ExpectedExitCodes @(0) `
  -WorkingDirectory $RepositoryRoot `
  -Environment ([ordered]@{
      ISSUE13_V5_SPOOF_LIBRARY_PATH =
        (Join-Path $root 'issue13-v5-coordinator-lib.ps1')
    })
$expectedBoundedTypeSpoofOutput =
  'TYPE_SPOOF_REJECTED:The bounded stream capture type was preloaded.'
if ([int]$boundedTypeSpoofExecution.exit_code -ne 0 -or
    [string]$boundedTypeSpoofExecution.stdout.Trim() -cne
      $expectedBoundedTypeSpoofOutput -or
    -not [string]::IsNullOrWhiteSpace(
      [string]$boundedTypeSpoofExecution.stderr)) {
  throw 'A preloaded bounded stream type was not rejected dynamically.'
}
$preexistingOutputLimitRProcesses = [object[]]@(
  Get-Process -Name R, Rgui, Rscript, Rterm -ErrorAction SilentlyContinue)
if ($preexistingOutputLimitRProcesses.Count -ne 0) {
  throw 'The output-limit self-test requires no preexisting R process.'
}
$outputLimitRejected = $false
$outputLimitMessage = ''
try {
  $null = Invoke-Issue13V5RscriptBounded `
    -RscriptPath ([string]$script:Issue13V5RscriptLogicalPath) `
    -Arguments @(
      '--vanilla', '-e', 'cat(strrep("A", 9437184L))') `
    -Label 'bounded-stream-output-limit-selftest' `
    -TimeoutSeconds 120 `
    -ExpectedExitCodes @(0) `
    -WorkingDirectory $RepositoryRoot `
    -Environment (New-Issue13V5ClosedREnvironment `
      'D:\Trabalho\Code\wlvdb\renv\library\windows\R-4.6\x86_64-w64-mingw32')
} catch {
  $outputLimitMessage =
    [string]$_.Exception.GetBaseException().Message
  $outputLimitRejected = $outputLimitMessage.Contains(
    'Bounded process output exceeded its byte limit.')
}
$remainingOutputLimitRProcesses = [object[]]@(
  Get-Process -Name R, Rgui, Rscript, Rterm -ErrorAction SilentlyContinue)
if (-not $outputLimitRejected -or
    $remainingOutputLimitRProcesses.Count -ne 0) {
  throw ('The real output-limit self-test did not fail closed: ' +
    $outputLimitMessage)
}
$oracleSpec = Read-Issue13V5Json (
  Join-Path $root 'issue13-v5-oracle-effect-spec.json')
$oracleSchema = Read-Issue13V5Json (
  Join-Path $root 'issue13-v5-oracle-effect-proof.schema.json')
$oracleSchemaSha256 = Get-Issue13V5Sha256 (
  Join-Path $root 'issue13-v5-oracle-effect-proof.schema.json')
$centralSetter = @(Get-Issue13V5StaticTopLevelFunctions $centralAst `
    'Set-Issue13V5ProcessEnvironmentState')
$centralGetter = @(Get-Issue13V5StaticTopLevelFunctions $centralAst `
    'Get-Issue13V5ProcessEnvironmentState')[0]
$oracleAst = $issue13ControllerPowerShellAsts[
  'issue13-v5-oracle-effect-lib.ps1']
$oracleSetter = @(Get-Issue13V5StaticTopLevelFunctions $oracleAst `
    'Set-Issue13OracleEffectProcessEnvironmentState')
if ($centralSetter.Count -ne 1 -or $oracleSetter.Count -ne 1 -or
    -not (Test-Issue13V5StaticEnvironmentSetter $centralSetter[0] `
      'Set-Issue13V5ProcessEnvironmentState') -or
    -not (Test-Issue13V5StaticEnvironmentSetter $oracleSetter[0] `
      'Set-Issue13OracleEffectProcessEnvironmentState')) {
  throw 'Commit E process-environment setters are not fail-closed tri-state setters.'
}
if ($oracleSetter[0].Extent.Text.Contains('Issue13V5') -or
    $oracleSetter[0].Extent.Text.Contains('Set-Issue13V5')) {
  throw 'Oracle process environment setter depends on the coordinator helper.'
}
$oracleGetter = @(Get-Issue13V5StaticTopLevelFunctions $oracleAst `
    'Get-Issue13OracleEffectProcessEnvironmentState')[0]
if (-not $centralGetter.Extent.Text.Contains('Test-Path -LiteralPath $path') -or
    -not $centralGetter.Extent.Text.Contains('GetEnvironmentVariable') -or
    -not $oracleGetter.Extent.Text.Contains('GetEnvironmentVariables') -or
    -not $oracleGetter.Extent.Text.Contains('.GetEnumerator()') -or
    -not $oracleGetter.Extent.Text.Contains('$matches.Count -eq 1')) {
  throw 'Environment presence is inferred from a null-collapsing getter.'
}

$expectedCommandRecordProperties = [string[]]@(
  'schema', 'label', 'executable', 'arguments', 'environment_set',
  'environment_cleared', 'working_directory', 'started_at_utc',
  'finished_at_utc', 'timeout_seconds', 'timed_out', 'exit_code',
  'expected_exit_codes', 'stdout_path', 'stdout_sha256', 'stderr_path',
  'stderr_sha256')
$externalDefinition = @(Get-Issue13V5StaticTopLevelFunctions $centralAst `
    'Invoke-Issue13V5External')[0]
$externalRecordTables = @($externalDefinition.FindAll({
    param($node)
    if ($node -isnot [Management.Automation.Language.HashtableAst]) {
      return $false
    }
    $keys = Get-Issue13V5StaticHashtableKeys $node
    $keys.Count -eq 17 -and $keys[0] -ceq 'schema' -and
      $keys[-1] -ceq 'stderr_sha256'
  }, $true))
if ($externalRecordTables.Count -ne 1 -or
    [string]::Join("`n", (Get-Issue13V5StaticHashtableKeys `
      $externalRecordTables[0])) -cne
      [string]::Join("`n", $expectedCommandRecordProperties) -or
    $externalDefinition.Extent.Text.Contains('environment_removed =') -or
    $externalDefinition.Extent.Text.Contains('environment = [object[]]')) {
  throw 'External command record is not the exact 17-field Commit E shape.'
}
function Test-Issue13V5StaticCentralEnvironmentContract(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $requiredNames = [string[]]@(
    'ConvertTo-Issue13V5EnvironmentMutations',
    'Enter-Issue13V5ProcessEnvironment',
    'Invoke-Issue13V5WithCleanup',
    'Invoke-Issue13V5WithProcessEnvironment',
    'Set-Issue13V5ProcessStartInfoEnvironment',
    'New-Issue13V5ClosedREnvironment',
    'Invoke-Issue13V5External')
  $definitions = @{}
  foreach ($name in $requiredNames) {
    $matches = @(Get-Issue13V5StaticTopLevelFunctions $Ast $name)
    if ($matches.Count -ne 1 -or $matches[0].Name -cne $name) {
      return $false
    }
    $definitions[$name] = $matches[0]
  }
  $convertText = [string]$definitions[
    'ConvertTo-Issue13V5EnvironmentMutations'].Extent.Text
  $enterText = [string]$definitions[
    'Enter-Issue13V5ProcessEnvironment'].Extent.Text
  $cleanupText = [string]$definitions[
    'Invoke-Issue13V5WithCleanup'].Extent.Text
  $scopeText = [string]$definitions[
    'Invoke-Issue13V5WithProcessEnvironment'].Extent.Text
  $startInfoText = [string]$definitions[
    'Set-Issue13V5ProcessStartInfoEnvironment'].Extent.Text
  $closedText = [string]$definitions[
    'New-Issue13V5ClosedREnvironment'].Extent.Text
  $external = $definitions['Invoke-Issue13V5External']
  $externalText = [string]$external.Extent.Text
  $recordTables = @($external.FindAll({
      param($node)
      if ($node -isnot [Management.Automation.Language.HashtableAst]) {
        return $false
      }
      $keys = Get-Issue13V5StaticHashtableKeys $node
      [string]::Join("`n", $keys) -ceq
        [string]::Join("`n", $expectedCommandRecordProperties)
    }, $true))
  $bindingOffset = $externalText.IndexOf(
    'Set-Issue13V5ProcessStartInfoEnvironment',
    [StringComparison]::Ordinal)
  $startOffset = $externalText.IndexOf('$process.Start()',
    [StringComparison]::Ordinal)
  $snapshotOffset = $enterText.IndexOf(
    '$snapshot = @(Get-Issue13V5ProcessEnvironmentState',
    [StringComparison]::Ordinal)
  $mutationOffset = $enterText.IndexOf(
    'Set-Issue13V5ProcessEnvironmentState $mutations',
    [StringComparison]::Ordinal)
  $convertText.Contains('if ($null -eq $Environment) { return }') -and
    $convertText.Contains('[StringComparer]::OrdinalIgnoreCase') -and
    $convertText.Contains('-not $seen.Add($name)') -and
    $convertText.Contains(
      '$null -ne $value -and $value -isnot [string]') -and
    $convertText.Contains('present = $null -ne $value') -and
    $convertText.Contains(
      'value = if ($null -eq $value) { $null } else { [string]$value }') -and
    -not $convertText.Contains('IsNullOrEmpty') -and
    $snapshotOffset -ge 0 -and $mutationOffset -gt $snapshotOffset -and
    $enterText.Contains(
      'for ($index = $snapshot.Count - 1; $index -ge 0; $index--)') -and
    $enterText.Contains('$failures.Add($primary.Exception)') -and
    $cleanupText.Contains('foreach ($cleanupAction in @($Cleanup))') -and
    $cleanupText.Contains('$failures.Add($primary.Exception)') -and
    $cleanupText.Contains('foreach ($failure in $cleanupFailures)') -and
    $cleanupText.Contains('throw [AggregateException]::new(') -and
    $cleanupText.Contains('if ($null -ne $primary) { throw $primary }') -and
    $scopeText.Contains('Enter-Issue13V5ProcessEnvironment $Environment') -and
    $scopeText.Contains('Invoke-Issue13V5WithCleanup -Action $Action') -and
    $scopeText.Contains('Exit-Issue13V5ProcessEnvironment $state') -and
    $startInfoText.Contains(
      'ConvertTo-Issue13V5EnvironmentMutations $Environment') -and
    $startInfoText.Contains('$ProcessStartInfo.Environment[$name] = $value') -and
    $startInfoText.Contains('$ProcessStartInfo.Environment.Remove($name)') -and
    $startInfoText.Contains(
      'environment_set = [object[]]$environmentSet.ToArray()') -and
    $startInfoText.Contains(
      'environment_cleared = [object[]]$environmentCleared.ToArray()') -and
    $closedText.Contains(
      'foreach ($name in $script:Issue13V5OracleClearedREnvironment)') -and
    $closedText.Contains("`$environment['R_LIBS_USER'] = `$RLibrary") -and
    $closedText.Contains("`$environment['TZ'] = 'UTC'") -and
    $recordTables.Count -eq 1 -and
    -not $externalText.Contains('environment_removed =') -and
    -not $externalText.Contains('environment = [object[]]') -and
    $bindingOffset -ge 0 -and $startOffset -gt $bindingOffset
}
if (-not (Test-Issue13V5StaticCentralEnvironmentContract $centralAst)) {
  throw 'Central absent/null/empty environment contract is not structurally closed.'
}
$centralEnvironmentMutantTexts = @(
  $centralText.Replace(
    'present = $null -ne $value',
    'present = -not [string]::IsNullOrEmpty([string]$value)'),
  $centralText.Replace(
    '[StringComparer]::OrdinalIgnoreCase', '[StringComparer]::Ordinal'),
  $centralText.Replace(
    'for ($index = $snapshot.Count - 1; $index -ge 0; $index--)',
    'for ($index = $snapshot.Count - 1; $index -gt 0; $index--)'),
  $centralText.Replace(
    '$failures.Add($primary.Exception)', '$null = $primary.Exception'),
  $centralText.Replace(
    'environment_set = [object[]]$environmentBinding.environment_set',
    'environment = [object[]]$environmentBinding.environment_set'),
  $centralText.Replace(
    "`$environment['TZ'] = 'UTC'", "`$null = 'UTC'"),
  $centralText.Replace(
    'foreach ($name in $script:Issue13V5OracleClearedREnvironment)',
    'foreach ($name in @())'))
foreach ($centralEnvironmentMutantText in $centralEnvironmentMutantTexts) {
  $centralEnvironmentMutantTokens = $null
  $centralEnvironmentMutantErrors = $null
  $centralEnvironmentMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $centralEnvironmentMutantText,
      [ref]$centralEnvironmentMutantTokens,
      [ref]$centralEnvironmentMutantErrors)
  if ($centralEnvironmentMutantText -ceq $centralText -or
      $centralEnvironmentMutantErrors.Count -ne 0 -or
      (Test-Issue13V5StaticCentralEnvironmentContract `
        $centralEnvironmentMutantAst)) {
    throw 'Central environment verifier accepted a tri-state/cleanup mutant.'
  }
}
function Test-Issue13V5StaticExternalLifecycle(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $stopDefinitions = @(Get-Issue13V5StaticTopLevelFunctions $Ast `
      'Stop-Issue13V5ExternalProcess')
  $externalDefinitions = @(Get-Issue13V5StaticTopLevelFunctions $Ast `
      'Invoke-Issue13V5External')
  if ($stopDefinitions.Count -ne 1 -or $externalDefinitions.Count -ne 1) {
    return $false
  }
  $stop = $stopDefinitions[0]
  $external = $externalDefinitions[0]
  $stopText = [string]$stop.Extent.Text
  $externalText = [string]$external.Extent.Text
  $killCalls = @($stop.FindAll({
      param($node)
      $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Member.Extent.Text -ceq 'Kill'
    }, $true))
  $graceWaits = @($stop.FindAll({
      param($node)
      $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Member.Extent.Text -ceq 'WaitForExit' -and
        $null -ne $node.Arguments -and
        $node.Arguments.Count -eq 1 -and
        $node.Arguments[0].Extent.Text -ceq '$GraceMilliseconds'
    }, $true))
  $externalStopCalls = @($external.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Stop-Issue13V5ExternalProcess'
    }, $true))
  $disposeCalls = @($external.FindAll({
      param($node)
      $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Member.Extent.Text -ceq 'Dispose' -and
        $node.Expression.Extent.Text -ceq '$process'
    }, $true))
  $primaryOffset = $externalText.IndexOf('$primary = $_',
    [StringComparison]::Ordinal)
  $cleanupOffset = $externalText.IndexOf(
    '$cleanupFailures = [Collections.Generic.List[Exception]]::new()',
    [StringComparison]::Ordinal)
  $finalFailureOffset = $externalText.LastIndexOf(
    'if ($null -ne $primary) { throw $primary }',
    [StringComparison]::Ordinal)
  $killCalls.Count -eq 2 -and
    @($killCalls | Where-Object {
        $null -eq $_.Arguments -or $_.Arguments.Count -ne 1 -or
          $_.Arguments[0].Extent.Text -cne '$true'
      }).Count -eq 0 -and
    $graceWaits.Count -eq 1 -and
    $stopText.Contains('if ($GraceMilliseconds -le 0)') -and
    $stopText.Contains('if (-not $Process.HasExited)') -and
    $stopText.Contains('External process remains active after bounded cleanup.') -and
    $stopText.Contains('throw [AggregateException]::new(') -and
    $externalStopCalls.Count -eq 2 -and
    $externalText.Contains(
      '$timedOut = -not $process.WaitForExit($timeoutMilliseconds)') -and
    $externalText.Contains(
      '[Threading.Tasks.Task]::WaitAll($outputTasks, 30000)') -and
    $externalText.Contains('if ($processStarted)') -and
    $disposeCalls.Count -eq 1 -and
    $externalText.Contains('$cleanupFailures.Add($_.Exception)') -and
    $externalText.Contains('$failures.Add($primary.Exception)') -and
    $externalText.Contains(
      'External command lifecycle cleanup failed: $Label') -and
    $primaryOffset -ge 0 -and $cleanupOffset -gt $primaryOffset -and
    $finalFailureOffset -gt $cleanupOffset
}
if (-not (Test-Issue13V5StaticExternalLifecycle $centralAst)) {
  throw 'External process lifecycle is not bounded and failure-preserving.'
}
$externalLifecycleMutantTexts = @(
  $centralText.Replace('$Process.Kill($true)', '$Process.Kill($false)'),
  $centralText.Replace(
    '$Process.WaitForExit($GraceMilliseconds)', '$Process.WaitForExit()'),
  $centralText.Replace('$process.Dispose()', '$null = $process'),
  $centralText.Replace('if ($processStarted) {', 'if ($false) {'),
  $centralText.Replace(
    'External command lifecycle cleanup failed: $Label',
    'External command cleanup failed'))
foreach ($externalLifecycleMutantText in $externalLifecycleMutantTexts) {
  $externalLifecycleMutantTokens = $null
  $externalLifecycleMutantErrors = $null
  $externalLifecycleMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $externalLifecycleMutantText,
      [ref]$externalLifecycleMutantTokens,
      [ref]$externalLifecycleMutantErrors)
  if ($externalLifecycleMutantText -ceq $centralText -or
      $externalLifecycleMutantErrors.Count -ne 0 -or
      (Test-Issue13V5StaticExternalLifecycle $externalLifecycleMutantAst)) {
    throw 'External lifecycle verifier accepted a kill/wait/cleanup mutant.'
  }
}
function Test-Issue13V5StaticBoundedRscriptLifecycle(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $sourceText = [string]$Ast.Extent.Text
  $definitions = @(Get-Issue13V5StaticTopLevelFunctions $Ast `
      'Invoke-Issue13V5RscriptBounded')
  if ($definitions.Count -ne 1) { return $false }
  $definition = $definitions[0]
  $text = [string]$definition.Extent.Text
  $enterCalls = @($definition.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Enter-Issue13V5RscriptExecutableLease'
    }, $true))
  $exitCalls = @($definition.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Exit-Issue13V5RscriptExecutableLease'
    }, $true))
  $stopCalls = @($definition.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Stop-Issue13V5ExternalProcess'
    }, $true))
  $environmentCalls = @($definition.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Set-Issue13V5ProcessStartInfoEnvironment'
    }, $true))
  $waits = @($definition.FindAll({
      param($node)
      $node -is
        [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Member.Extent.Text -ceq 'WaitForExit' -and
        $null -ne $node.Arguments -and $node.Arguments.Count -eq 1 -and
        $node.Arguments[0].Extent.Text -ceq '$waitSlice'
    }, $true))
  $reads = @($definition.FindAll({
      param($node)
      $node -is
        [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Member.Extent.Text -ceq 'ReadToEndAsync'
    }, $true))
  $boundedCaptures = @($definition.FindAll({
      param($node)
      $node -is
        [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Static -and $node.Member.Extent.Text -ceq 'CopyAsync' -and
        $node.Expression -is
          [Management.Automation.Language.VariableExpressionAst] -and
        $node.Expression.VariablePath.UserPath -ceq
          'script:Issue13V5BoundedStreamCaptureType'
    }, $true))
  $captureSignatures = [Collections.Generic.List[string]]::new()
  foreach ($capture in $boundedCaptures) {
    $captureSignatures.Add(
      [regex]::Replace($capture.Extent.Text, '[\s`]', ''))
  }
  $processDisposals = @($definition.FindAll({
      param($node)
      $node -is
        [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Member.Extent.Text -ceq 'Dispose' -and
        $node.Expression.Extent.Text -ceq '$process'
    }, $true))
  $dynamicCalls = @($definition.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        $node.InvocationOperator -eq
          [Management.Automation.Language.TokenKind]::Ampersand
    }, $true))
  if ($enterCalls.Count -ne 1 -or $exitCalls.Count -ne 1 -or
      $stopCalls.Count -ne 2 -or $environmentCalls.Count -ne 1 -or
      $waits.Count -ne 1 -or $reads.Count -ne 0 -or
      $boundedCaptures.Count -ne 2 -or
      [string]::Join("`n", $captureSignatures.ToArray()) -cne
        [string]::Join("`n", @(
          ('$script:Issue13V5BoundedStreamCaptureType::CopyAsync(' +
            '$process.StandardOutput.BaseStream,$stdoutBuffer,' +
            '$outputLimitBytes)'),
          ('$script:Issue13V5BoundedStreamCaptureType::CopyAsync(' +
            '$process.StandardError.BaseStream,$stderrBuffer,' +
            '$outputLimitBytes)')
        )) -or
      $processDisposals.Count -ne 1 -or $dynamicCalls.Count -ne 0) {
    return $false
  }
  $startOffset = $text.IndexOf('$process.Start()',
    [StringComparison]::Ordinal)
  $waitOffset = $text.IndexOf(
    '$process.WaitForExit($waitSlice)',
    [StringComparison]::Ordinal)
  $cleanupOffset = $text.IndexOf(
    '$cleanupFailures = [Collections.Generic.List[Exception]]::new()',
    [StringComparison]::Ordinal)
  $stdoutBufferNullOffset = $text.IndexOf(
    '$stdoutBuffer = $null', [StringComparison]::Ordinal)
  $stderrBufferNullOffset = $text.IndexOf(
    '$stderrBuffer = $null', [StringComparison]::Ordinal)
  $stdoutBufferCreateOffset = $text.IndexOf(
    '$stdoutBuffer = [IO.MemoryStream]::new()',
    [StringComparison]::Ordinal)
  $stderrBufferCreateOffset = $text.IndexOf(
    '$stderrBuffer = [IO.MemoryStream]::new()',
    [StringComparison]::Ordinal)
  $enterCalls[0].Extent.StartOffset -lt $startOffset +
      $definition.Extent.StartOffset -and
    $startOffset -ge 0 -and $waitOffset -gt $startOffset -and
    $stdoutBufferNullOffset -ge 0 -and
    $stderrBufferNullOffset -gt $stdoutBufferNullOffset -and
    $stdoutBufferCreateOffset -gt $startOffset -and
    $stderrBufferCreateOffset -gt $stdoutBufferCreateOffset -and
    $stdoutBufferNullOffset -lt $startOffset -and
    $stderrBufferNullOffset -lt $startOffset -and
    $cleanupOffset -gt $waitOffset -and
    $exitCalls[0].Extent.StartOffset -gt
      $cleanupOffset + $definition.Extent.StartOffset -and
    $text.Contains(
      '[AllowNull()][int[]]$ExpectedExitCodes = @(0)') -and
    $text.Contains(
      '$TimeoutSeconds -le 0 -or $TimeoutSeconds -gt 2147483') -and
    $text.Contains('$start.UseShellExecute = $false') -and
    $text.Contains('$start.CreateNoWindow = $true') -and
    $text.Contains('$start.RedirectStandardOutput = $true') -and
    $text.Contains('$start.RedirectStandardError = $true') -and
    $text.Contains('$start.WorkingDirectory = $resolvedWorkingDirectory') -and
    $text.Contains('Assert-Issue13V5NoReparseAncestors') -and
    $sourceText.Contains('public static async Task<long> CopyAsync(') -and
    $sourceText.Contains('byte[] buffer = new byte[81920]') -and
    $sourceText.Contains('if (total > maximumBytes - read)') -and
    $sourceText.Contains('Bounded process output exceeded its byte limit.') -and
    $sourceText.Contains('source.ReadAsync(') -and
    $sourceText.Contains('destination.WriteAsync(') -and
    $text.Contains('$outputLimitBytes = 8L * 1024L * 1024L') -and
    $text.Contains('$stdoutTask.IsFaulted') -and
    $text.Contains('$stderrTask.IsFaulted') -and
    $text.Contains('$waitStopwatch.ElapsedMilliseconds') -and
    $text.Contains('$strictUtf8.GetString($stdoutBuffer.ToArray())') -and
    $text.Contains('$strictUtf8.GetString($stderrBuffer.ToArray())') -and
    $text.Contains('foreach ($buffer in @($stdoutBuffer, $stderrBuffer))') -and
    $text.Contains('[Threading.Tasks.Task]::WaitAll($outputTasks, 30000)') -and
    $text.Contains('$exitCode = if ($timedOut) { -999 } else') -and
    $text.Contains('if ($timedOut -and $validateExitCode)') -and
    $text.Contains('timed_out = [bool]$timedOut') -and
    $text.Contains('$cleanupFailures.Add($_.Exception)') -and
    $text.Contains('$failures.Add($primary.Exception)') -and
    $text.Contains('Bounded Rscript lifecycle cleanup failed: $Label') -and
    $text.Contains('environment_set = [object[]]$environmentBinding.environment_set') -and
    $text.Contains('environment_cleared = [string[]]$environmentBinding.environment_cleared')
}
if (-not (Test-Issue13V5StaticBoundedRscriptLifecycle $centralAst)) {
  throw 'Auxiliary Rscript lifecycle is not sealed, bounded, and log-preserving.'
}
$boundedRscriptMutantTexts = @(
  $centralText.Replace(
    '$process.WaitForExit($waitSlice)', '$process.WaitForExit()'),
  $centralText.Replace(
    'Stop-Issue13V5ExternalProcess $process', '$null = $process'),
  $centralText.Replace(
    'Exit-Issue13V5RscriptExecutableLease $lease', '$lease.handle.Dispose()'),
  $centralText.Replace(
    '$script:Issue13V5BoundedStreamCaptureType::CopyAsync',
    '$script:Issue13V5BoundedStreamCaptureType::CopyToAsync'),
  $centralText.Replace(
    '$outputLimitBytes = 8L * 1024L * 1024L',
    '$outputLimitBytes = [long]::MaxValue'),
  $centralText.Replace(
    'if (total > maximumBytes - read)', 'if (false)'),
  $centralText.Replace(
    'byte[] buffer = new byte[81920]',
    'byte[] buffer = new byte[int.MaxValue]'),
  $centralText.Replace(
    '$stdoutBuffer = $null', '$null = $null'),
  $centralText.Replace(
    '$stderrBuffer = $null', '$null = $null'),
  $centralText.Replace('$stdoutTask.IsFaulted', '$false'),
  $centralText.Replace(
    'timed_out = [bool]$timedOut', 'timed_out = $false'),
  $centralText.Replace(
    '$exitCode = if ($timedOut) { -999 } else',
    '$exitCode = if ($timedOut) { 0 } else'),
  $centralText.Replace(
    'Set-Issue13V5ProcessStartInfoEnvironment',
    'Set-Issue13V5ProcessStartInfoEnvironment_MUTANT'))
foreach ($boundedRscriptMutantText in $boundedRscriptMutantTexts) {
  $boundedRscriptMutantTokens = $null
  $boundedRscriptMutantErrors = $null
  $boundedRscriptMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $boundedRscriptMutantText,
      [ref]$boundedRscriptMutantTokens,
      [ref]$boundedRscriptMutantErrors)
  if ($boundedRscriptMutantText -ceq $centralText -or
      $boundedRscriptMutantErrors.Count -ne 0 -or
      (Test-Issue13V5StaticBoundedRscriptLifecycle `
        $boundedRscriptMutantAst)) {
    throw 'Bounded Rscript verifier accepted a timeout/cleanup mutant.'
  }
}
$closedNames = [string[]]$script:Issue13V5OracleClearedREnvironment
if ($closedNames.Count -ne 16 -or
    @($closedNames | Sort-Object -Unique).Count -ne 16 -or
    -not $centralText.Contains("`$environment['R_LIBS_USER'] = `$RLibrary") -or
    -not $centralText.Contains("`$environment['TZ'] = 'UTC'")) {
  throw 'The closed R environment is not the exact clear-16 plus set-2 contract.'
}
foreach ($requiredEnvironmentSelftest in @(
    'Environment tri-state self-test',
    'Case-insensitive environment duplicate was accepted.',
    'Non-string environment value was accepted.',
    'Aggregate cleanup self-test',
    'Process environment setup and restoration failed.',
    'environment_set', 'environment_cleared')) {
  if (-not $centralText.Contains($requiredEnvironmentSelftest)) {
    throw "Central environment self-test omits mutant: $requiredEnvironmentSelftest"
  }
}
foreach ($wrapperName in @('Invoke-Issue13V5R', 'Invoke-Issue13V5Pwsh')) {
  $wrapper = @(Get-Issue13V5StaticTopLevelFunctions $centralAst $wrapperName)[0]
  $expectedExternalName = if ($wrapperName -ceq 'Invoke-Issue13V5R') {
    'Invoke-Issue13V5External'
  } else {
    'Invoke-Issue13V5PwshExternal'
  }
  $closedCalls = @($wrapper.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'New-Issue13V5ClosedREnvironment'
    }, $true))
  $externalCalls = @($wrapper.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          $expectedExternalName
    }, $true))
  if ($closedCalls.Count -ne 1 -or $externalCalls.Count -ne 1 -or
      $closedCalls[0].Extent.StartOffset -ge $externalCalls[0].Extent.StartOffset -or
      -not $externalCalls[0].Extent.Text.Contains('$environment') -or
      -not $wrapper.Extent.Text.Contains('Invoke-Issue13V5WithCleanup') -or
      @($wrapper.FindAll({
          param($node)
          $node -is [Management.Automation.Language.CommandAst] -and
            (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
              'Assert-Issue13V5HarnessBinding'
        }, $true)).Count -lt 2 -or
      @($wrapper.FindAll({
          param($node)
          $node -is [Management.Automation.Language.CommandAst] -and
            (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
              'Assert-Issue13V5NoConcurrentR'
        }, $true)).Count -lt 2) {
    throw "R/Pwsh wrapper lacks its closed environment: $wrapperName"
  }
}
foreach ($captureName in @(
    'issue13-v5-capture-clean-bridge-evidence.ps1',
    'issue13-v5-capture-clean-stage5-evidence.ps1')) {
  $captureText = [string]$issue13ControllerPowerShellTexts[$captureName]
  if (-not $captureText.Contains('New-Issue13V5ClosedREnvironment') -or
      -not $captureText.Contains('Invoke-Issue13V5RscriptBounded')) {
    throw "Evidence capture does not delegate process environment: $captureName"
  }
}
foreach ($delegateName in @(
    'issue13-v5-baseline-smoke.ps1',
    'issue13-v5-capture-clean-bridge-evidence.ps1',
      'issue13-v5-capture-clean-stage5-evidence.ps1')) {
  $delegateAst = $issue13ControllerPowerShellAsts[$delegateName]
  $delegateGuardEnd = @($delegateAst.EndBlock.Statements)[1].Extent.EndOffset
  $directEnvironmentMutators = @($delegateAst.FindAll({
      param($node)
      $node.Extent.StartOffset -gt $delegateGuardEnd -and (
      ($node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -iin @(
          'Set-Item', 'Remove-Item') -and
        $node.Extent.Text -imatch "Env:") -or
      ($node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Member.Extent.Text -ieq 'SetEnvironmentVariable'))
    }, $true))
  $requiredDelegate = if ($delegateName -ceq
      'issue13-v5-baseline-smoke.ps1') {
    'Invoke-Issue13V5WithCleanup'
  } else {
    'Invoke-Issue13V5RscriptBounded'
  }
  if ($directEnvironmentMutators.Count -ne 0 -or
      -not ([string]$issue13ControllerPowerShellTexts[$delegateName]).Contains(
        $requiredDelegate)) {
    throw "Environment delegate bypasses central restoration: $delegateName"
  }
}
function Test-Issue13V5StaticBoundedRscriptCallers(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string[]]$ExpectedSignatures
) {
  $directRscriptCalls = @($Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        $node.InvocationOperator -eq
          [Management.Automation.Language.TokenKind]::Ampersand -and
        $node.CommandElements.Count -gt 0 -and
        $node.CommandElements[0].Extent.Text -imatch
          'rscript|lease[.]binding[.]logical_path'
    }, $true))
  $boundedCalls = @($Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Invoke-Issue13V5RscriptBounded'
    }, $true))
  $actualSignatures = [string[]]@($boundedCalls | ForEach-Object {
      [regex]::Replace($_.Extent.Text, '[\s`]', '')
    })
  $directRscriptCalls.Count -eq 0 -and
    [string]::Join("`n", $actualSignatures) -ceq
      [string]::Join("`n", $ExpectedSignatures)
}
$boundedRscriptCallerSignatures = [ordered]@{
  'issue13-v5-baseline-smoke.ps1' = [string[]]@(
    'Invoke-Issue13V5RscriptBounded-RscriptPath$rscriptFull' +
      '-Arguments$builderArguments-Label"Baselinesmokebuilderfor$method"' +
      '-TimeoutSeconds600-ExpectedExitCodes$null' +
      '-WorkingDirectory$project-Environment$builderEnvironment'
  )
  'issue13-v5-capture-clean-bridge-evidence.ps1' = [string[]]@(
    'Invoke-Issue13V5RscriptBounded-RscriptPath$script:rscriptPath' +
      '-Arguments$Arguments-Label"BridgecapturesealedRscript"' +
      '-TimeoutSeconds$TimeoutSeconds-ExpectedExitCodes$null' +
      '-WorkingDirectory$WorkingDirectory-Environment$environment'
  )
  'issue13-v5-capture-clean-stage5-evidence.ps1' = [string[]]@(
    'Invoke-Issue13V5RscriptBounded-RscriptPath$script:rscriptPath' +
      '-Arguments$Arguments-Label"Stage5capturesealedRscript"' +
      '-TimeoutSeconds$TimeoutSeconds-ExpectedExitCodes$null' +
      '-WorkingDirectory$WorkingDirectory-Environment$environment'
  )
  'issue13-v5-oracle-effect-lib.ps1' = [string[]]@(
    ('Invoke-Issue13V5RscriptBounded-RscriptPath$rscriptPath' +
      '-Arguments@(''--vanilla'',''-e'',$expression)' +
      '-Label''Oracle-effectRruntimeprobe''-TimeoutSeconds600' +
      '-ExpectedExitCodes$null' +
      '-WorkingDirectory$script:Issue13OracleEffectControllerRoot' +
      '-Environment$probeEnvironment'),
    ('Invoke-Issue13V5RscriptBounded' +
      '-RscriptPath([string]$command.executable)' +
      '-Arguments$invokeArguments' +
      '-Label"$phasecomparisonfor$($command.method)"' +
      '-TimeoutSeconds14400-ExpectedExitCodes$null' +
      '-WorkingDirectory([string]$command.working_directory)' +
      '-Environment$comparisonEnvironment')
  )
}
foreach ($boundedCallerName in $boundedRscriptCallerSignatures.Keys) {
  $boundedCallerAst = $issue13ControllerPowerShellAsts[$boundedCallerName]
  $expectedSignatures = [string[]]$boundedRscriptCallerSignatures[
    $boundedCallerName]
  if (-not (Test-Issue13V5StaticBoundedRscriptCallers `
      $boundedCallerAst $expectedSignatures)) {
    throw "Rscript caller bypasses bounded execution: $boundedCallerName"
  }
  $boundedCallerText = [string]$issue13ControllerPowerShellTexts[
    $boundedCallerName]
  foreach ($boundedCallerMutantText in @(
      $boundedCallerText.Replace(
        'Invoke-Issue13V5RscriptBounded', '& $script:rscriptPath'),
      $boundedCallerText.Replace(
        '-TimeoutSeconds $TimeoutSeconds', '-TimeoutSeconds 0'),
      $boundedCallerText.Replace('-TimeoutSeconds 600', '-TimeoutSeconds 0'),
      $boundedCallerText.Replace('-TimeoutSeconds 14400', '-TimeoutSeconds 0'),
      $boundedCallerText.Replace(
        '-WorkingDirectory $WorkingDirectory', '-WorkingDirectory $null'),
      $boundedCallerText.Replace(
        '-WorkingDirectory $project', '-WorkingDirectory $null'),
      $boundedCallerText.Replace(
        '-WorkingDirectory $script:Issue13OracleEffectControllerRoot',
        '-WorkingDirectory $null'),
      $boundedCallerText.Replace(
        '-WorkingDirectory ([string]$command.working_directory)',
        '-WorkingDirectory $null'),
      $boundedCallerText.Replace(
        '-Environment $environment', '-Environment $null'),
      $boundedCallerText.Replace(
        '-Environment $builderEnvironment', '-Environment $null'),
      $boundedCallerText.Replace(
        '-Environment $probeEnvironment', '-Environment $null'),
      $boundedCallerText.Replace(
        '-Environment $comparisonEnvironment', '-Environment $null'))) {
    if ($boundedCallerMutantText -ceq $boundedCallerText) { continue }
    $boundedCallerMutantTokens = $null
    $boundedCallerMutantErrors = $null
    $boundedCallerMutantAst =
      [Management.Automation.Language.Parser]::ParseInput(
        $boundedCallerMutantText,
        [ref]$boundedCallerMutantTokens,
        [ref]$boundedCallerMutantErrors)
    $mutantBoundedCalls = @($boundedCallerMutantAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
          (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
            'Invoke-Issue13V5RscriptBounded'
      }, $true))
    $mutantSignatures = [string[]]@($mutantBoundedCalls |
      ForEach-Object { [regex]::Replace($_.Extent.Text, '[\s`]', '') })
    if ([string]::Join("`n", $mutantSignatures) -ceq
        [string]::Join("`n", $expectedSignatures)) {
      continue
    }
    if ($boundedCallerMutantErrors.Count -ne 0 -or
        (Test-Issue13V5StaticBoundedRscriptCallers `
          $boundedCallerMutantAst $expectedSignatures)) {
      throw "Rscript caller verifier accepted a direct/timeout mutant: $boundedCallerName"
    }
  }
}

$sourceRoot = Join-Path $RepositoryRoot `
  'run_logs\issue13-evidence-source-v5'
$sourcePhysicalRoot = (Resolve-Path -LiteralPath $sourceRoot).Path
$expectedSourceSha256 = [ordered]@{
  'issue13-evidence-harness/issue13-aggregate-prep-fault.R' = 'E8E4AA307A8D33E3252EA3A26A5E86832810FB5DC5CC477ACC4D64FA5CEA5EF2'
  'issue13-evidence-harness/issue13-aggregate.R' = '9EE1654CB2AA8C85A96D9834C357A78BAF7C2A4FD5602EF516369972E9B194D5'
  'issue13-evidence-harness/issue13-audit-prep-fault-plan.R' = 'FD7DBCD5CB500B65FE7380C24574DD787117FF54C757B5E95067422C4BE6D0FE'
  'issue13-evidence-harness/issue13-baseline-runtime-index-lib.R' = '6DB06C454CF4E2782CF1C4D214D2F16EB39ADE29F4A78BD42BEF6BFE1B8C7708'
  'issue13-evidence-harness/issue13-build-calculate-bundle.R' = '17D2199EC06B1CEB159618FEB59A571D074FF53E898D5AA87C347715CEFC5AE6'
  'issue13-evidence-harness/issue13-build-fault-seed-specs.R' = '6344B11ACABBD6379CD247FA89AA65E3E1A58529C6D8ED32EAF52EBD33E9E07C'
  'issue13-evidence-harness/issue13-build-paper-bundle.R' = '3C879E87AE6EBB91043E73DF4A145544A933B1A53AD30ABED0B5205F1E283EBF'
  'issue13-evidence-harness/issue13-build-prep-fault-specs.R' = 'A30145EF606B3B9AAA47D814B0A02F6C887F9779C9A1400B9C878E3C54C3BFF0'
  'issue13-evidence-harness/issue13-build-recalc-bundle.R' = '2122BC4D32330938C767215BF5A0496298596ACF1EBD5C3EE8C12977A29EA709'
  'issue13-evidence-harness/issue13-compare-lib.R' = '2AD64460DAFD5FAC9778189D5D312BD733FADA7316D557196ED069FB84888014'
  'issue13-evidence-harness/issue13-compare-results.R' = '32C6AC7B04DEE4EDEB8820110B2DED5C65AD76103D31BB4A17BE179510040E4B'
  'issue13-evidence-harness/issue13-compare.R' = '5B723B5F1E2B230A5E7E0E552CB24F84537A907C1CD0C6C28957D4757B96BF4F'
  'issue13-evidence-harness/issue13-import-baseline-lib.R' = '070D8F792F3864AC4496A03EE2B5B89B62A177B2D0075967E41B9AC0760F7CF0'
  'issue13-evidence-harness/issue13-import-baseline-run.R' = 'A6952D64491C28AEF79381332F2B895B84C6281AE1D54D3440B16994F6FE58B7'
  'issue13-evidence-harness/issue13-import-baseline-selftest.R' = '59AB035D1B8756DA4541045C15E1DFADBA2547D120DC088984D5DC0DB0D26603'
  'issue13-evidence-harness/issue13-import-fault-inputs.R' = '92CA987DEDAF055582A18C295B7409C2F3A623BB4527405E67029275C01CD13A'
  'issue13-evidence-harness/issue13-lib.R' = '742FF5288A7AE5F8713FA8C67754328E7093A9BE11B4A5BA0B10968862BE96EB'
  'issue13-evidence-harness/issue13-matrix.R' = 'D71DD34DC5184F6D12E43CBD24F605ACA53BFF121357600D6283DC1BBC9D87D5'
  'issue13-evidence-harness/issue13-monitor-selftest.ps1' = '8AACA7D4C518962D94396BCD657675240507795293E5AC64DB22265DBF0934FF'
  'issue13-evidence-harness/issue13-monitor.ps1' = '564B940E779C604C8B630EBE91D35ADB86C07B8B2EFFCBD788613B0C8042E00E'
  'issue13-evidence-harness/issue13-run-fault-seed-record.ps1' = '025146B19A9E6A69F0CC54C741938BDC8FE77615C9CA80DB4AB368953E602491'
  'issue13-evidence-harness/issue13-run-fault-seeds.ps1' = 'A0D3CF98052F252CE7919030F8228DAC344FE9E2B74690FF5746958866DA862D'
  'issue13-evidence-harness/issue13-run-plan.ps1' = '925270836D79B5E7399B75730472AF1D3545B565C0A0679D1FC7D38FF29FA1B8'
  'issue13-evidence-harness/issue13-run-prep-fault-record.ps1' = 'FF21D11CE374937A390B6E0AE7FB58B2A089B8F379D2B3D49D8192F1BD9F5D3D'
  'issue13-evidence-harness/issue13-run-recalc-bundle.ps1' = 'E239C81AEF7483857A96AF12BD1C41354A65F8F65DF0619D7DB3511E487C6E53'
  'issue13-evidence-harness/issue13-scenario.R' = 'BD3F79EB018F4126E290C48376AB4B9C2CBB8A2A750D8C785B4739FDF59CB155'
  'issue13-evidence-harness/issue13-seed-channel.R' = '72D33F157E6AF6EF64B42C8CC052E59FA91885287564636F590A9B9F8B940957'
  'issue13-evidence-harness/issue13-seed-runtime-lib.R' = '283C42374E030A78AB77C94F7260E788575D8D3AB7E637511255D203B1AC01E0'
  'issue13-evidence-harness/issue13-seed-runtime-selftest.R' = '3F7186B75427196BB6504A002F090ADFC218AEF5B03BF3FC58F0E9232E81D1A5'
  'issue13-evidence-harness/issue13-selftest.R' = 'C46BF0396531C886D62A09024C05F37FEC958443BAA3617126DE8BD5A385343D'
  'issue13-evidence-harness/issue13-snapshot.R' = '40D91118B5707B3A4824A760C0640C0403C88F5A4F33D597733FE877E43220DA'
  'issue13-evidence-harness/README.md' = '87B33547D33D775C27EF6DC31B06538340FA178A33A3C3E15EAEFCF9A5D6C528'
  'issue13-prep-paper-lib.R' = 'F90F418C0EEE3AF14B2795A8CEB1085F936630E8136A3CD0D38E03BDF85B9B26'
  'issue13-preparation-auth-lib.R' = '36229B64E2581E81175623584B11B33E2DF884D8AF5C8D5BF206F8C28C299A58'
  'issue13-preparation-compare.R' = '20152903D3690811CB387C32E4EB6B47AB549CB76B4EF35D843F04885A0FCE98'
  'issue13-preparation-rule-matrix.json' = '0DB8D883E3DB89D2A8626F9BF387AF32DDD69BF8C8C56F5A3E4DD011CF4ABC44'
  'issue13-runtime-loader-selftest.R' = 'BF64921E6B1F6F7078F8CB59439FA8D855CD739B2CF78FE94D1EB7241A170090'
}
$expectedSourceFiles = [string[]]@($expectedSourceSha256.Keys)
$sourceDirectories = @(Get-ChildItem -LiteralPath $sourcePhysicalRoot `
    -Directory -Recurse -Force)
$sourceFiles = @(Get-ChildItem -LiteralPath $sourcePhysicalRoot `
    -File -Recurse -Force)
if ($expectedSourceFiles.Count -ne 37 -or $sourceFiles.Count -ne 37 -or
    $sourceDirectories.Count -ne 1 -or
    $sourceDirectories[0].Name -cne 'issue13-evidence-harness' -or
    [string]::Join("`n", [string[]]$script:Issue13V5SourceToolingFiles) -cne
      [string]::Join("`n", $expectedSourceFiles) -or
    [string]::Join("`n", [string[]]@(
      $script:Issue13OracleEffectSourceToolingFiles)) -cne
      [string]::Join("`n", $expectedSourceFiles)) {
  throw 'The Commit E source tooling is not the exact 37-file/one-directory root.'
}
$sourcePathPayload = [Text.UTF8Encoding]::new($false, $true).GetBytes(
  [string]::Join("`n", $expectedSourceFiles))
$sourcePathSha256 = [Convert]::ToHexString(
  [Security.Cryptography.SHA256]::HashData($sourcePathPayload)).ToLowerInvariant()
if ($expectedSourceFiles[31] -cne 'issue13-evidence-harness/README.md' -or
    $sourcePathSha256 -cne
      '7bf2e27807e9bc36d3d3766789439d0d9afdd7b2cc5127145ce0e0f6819db00d') {
  throw 'The source-tooling allowlist order changed (README must remain item 32).'
}
$sourceAsts = @{}
foreach ($relativeSource in $expectedSourceFiles) {
  $sourcePath = Join-Path $sourcePhysicalRoot $relativeSource.Replace('/', '\')
  $sourceBytes = [IO.File]::ReadAllBytes($sourcePath)
  $sourceHash = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($sourceBytes))
  if ($sourceHash -cne [string]$expectedSourceSha256[$relativeSource] -or
      ($sourceBytes.Length -ge 3 -and $sourceBytes[0] -eq 0xEF -and
        $sourceBytes[1] -eq 0xBB -and $sourceBytes[2] -eq 0xBF) -or
      $sourceBytes -contains 13) {
    throw "Source-tooling bytes are not UTF-8/LF sealed: $relativeSource"
  }
  $sourceText = $bootstrapEncoding.GetString($sourceBytes)
  if ($sourceText.Contains([char]0xFFFD)) {
    throw "Source-tooling text is not strict UTF-8: $relativeSource"
  }
  if ($relativeSource.EndsWith('.ps1', [StringComparison]::Ordinal)) {
    $sourceTokens = $null
    $sourceErrors = $null
    $sourceAst = [Management.Automation.Language.Parser]::ParseInput(
      $sourceText, [ref]$sourceTokens, [ref]$sourceErrors)
    if ($sourceErrors.Count -ne 0) {
      throw "Source-tooling PowerShell parser rejected: $relativeSource"
    }
    $sourceAsts[$relativeSource] = $sourceAst
  }
}
$guardedEntrypointAsts = [ordered]@{
  'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-attest-delivery.ps1' =
    $issue13ControllerPowerShellAsts['issue13-v5-attest-delivery.ps1']
  'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-baseline-smoke.ps1' =
    $issue13ControllerPowerShellAsts['issue13-v5-baseline-smoke.ps1']
  'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-capture-clean-bridge-evidence.ps1' =
    $issue13ControllerPowerShellAsts[
      'issue13-v5-capture-clean-bridge-evidence.ps1']
  'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-capture-clean-stage5-evidence.ps1' =
    $issue13ControllerPowerShellAsts[
      'issue13-v5-capture-clean-stage5-evidence.ps1']
  'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-coordinator-lib.ps1' =
    $issue13ControllerPowerShellAsts['issue13-v5-coordinator-lib.ps1']
  'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-coordinator.ps1' =
    $issue13ControllerPowerShellAsts['issue13-v5-coordinator.ps1']
  'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-materialize-harness.ps1' =
    $issue13ControllerPowerShellAsts['issue13-v5-materialize-harness.ps1']
  'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-new-config.ps1' =
    $issue13ControllerPowerShellAsts['issue13-v5-new-config.ps1']
  'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-oracle-effect-generate.ps1' =
    $issue13ControllerPowerShellAsts[
      'issue13-v5-oracle-effect-generate.ps1']
  'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-oracle-effect-lib.ps1' =
    $issue13ControllerPowerShellAsts['issue13-v5-oracle-effect-lib.ps1']
  'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-oracle-effect-validate.ps1' =
    $issue13ControllerPowerShellAsts[
      'issue13-v5-oracle-effect-validate.ps1']
  'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-render-report.ps1' =
    $issue13ControllerPowerShellAsts['issue13-v5-render-report.ps1']
  'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-monitor-selftest.ps1' =
    $sourceAsts['issue13-evidence-harness/issue13-monitor-selftest.ps1']
  'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-monitor.ps1' =
    $sourceAsts['issue13-evidence-harness/issue13-monitor.ps1']
  'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-run-fault-seed-record.ps1' =
    $sourceAsts[
      'issue13-evidence-harness/issue13-run-fault-seed-record.ps1']
  'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-run-fault-seeds.ps1' =
    $sourceAsts['issue13-evidence-harness/issue13-run-fault-seeds.ps1']
  'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-run-plan.ps1' =
    $sourceAsts['issue13-evidence-harness/issue13-run-plan.ps1']
  'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-run-prep-fault-record.ps1' =
    $sourceAsts[
      'issue13-evidence-harness/issue13-run-prep-fault-record.ps1']
  'run_logs/issue13-evidence-source-v5/issue13-evidence-harness/issue13-run-recalc-bundle.ps1' =
    $sourceAsts['issue13-evidence-harness/issue13-run-recalc-bundle.ps1']
}
$guardedEntrypointPathPayload = $bootstrapEncoding.GetBytes(
  [string]::Join("`n", [string[]]$guardedEntrypointAsts.Keys))
$guardedEntrypointPathSha256 = [Convert]::ToHexString(
  [Security.Cryptography.SHA256]::HashData(
    $guardedEntrypointPathPayload))
if ($guardedEntrypointAsts.Count -ne 19 -or
    $guardedEntrypointPathSha256 -cne
      '170B353ABB4C7FD84D38FDE4DFB4A14A7E61968B7C4395A31FBDDE596F3D7186') {
  throw 'The reachable PowerShell entrypoint allowlist is not exact.'
}
$canonicalGuardAst = $issue13ControllerPowerShellAsts[
  'issue13-v5-coordinator-lib.ps1']
$canonicalGuardStatements = @($canonicalGuardAst.EndBlock.Statements)
if ($canonicalGuardStatements.Count -lt 2 -or
    $canonicalGuardStatements[0] -isnot
      [Management.Automation.Language.AssignmentStatementAst] -or
    $canonicalGuardStatements[0].Right -isnot
      [Management.Automation.Language.CommandExpressionAst] -or
    $canonicalGuardStatements[0].Right.Expression -isnot
      [Management.Automation.Language.ScriptBlockExpressionAst]) {
  throw 'The canonical command-collision guard is unavailable.'
}
$canonicalGuardText =
  $canonicalGuardStatements[0].Right.Expression.ScriptBlock.Extent.Text
$canonicalGuardBlock =
  $canonicalGuardStatements[0].Right.Expression.ScriptBlock
$canonicalGuardAssignmentText =
  $canonicalGuardStatements[0].Extent.Text
$staticAliasGuardBlock =
  $bootstrapStaticAst.EndBlock.Statements[0].Right.Expression.ScriptBlock
if (-not (Test-Issue13V5BootstrapRuntimeLeaseRetention `
      $canonicalGuardBlock) -or
    -not (Test-Issue13V5BootstrapRuntimeLeaseRetention `
      $staticAliasGuardBlock)) {
  throw 'The PowerShell bootstrap does not retain its authenticated leases.'
}
foreach ($guardNeedle in [string[]]@(
    '[StringComparer]::OrdinalIgnoreCase',
    '$trustedRuntimeFiles.Count -ne 11',
    '$runtimeFileLeases.Count -ne 11',
    '''wlv.issue13.v5.powershell.runtime.leases''',
    '[IO.FileShare]::Read',
    '$global:PSModuleAutoLoadingPreference = ''None''',
    '''PSModulePath'', $moduleRoot',
    '$ExecutionContext.InvokeCommand.GetCommands(',
    '[Management.Automation.CommandTypes]::Cmdlet',
    '[Management.Automation.CommandTypes]::Alias',
    '[Management.Automation.CommandTypes]::Function',
    '[Management.Automation.CommandTypes]::Filter',
    '[Management.Automation.CommandTypes]::Application',
    '[Management.Automation.CommandTypes]::ExternalScript',
    '$importModuleCmdlet -Name $manifest -Global -Force -ErrorAction Stop',
    '''Microsoft.PowerShell.Management\Microsoft.PowerShell.Management.psd1''',
    '''Microsoft.PowerShell.Utility\Microsoft.PowerShell.Utility.psd1''',
    '''CimCmdlets\CimCmdlets.psd1''',
    '$trustedCmdlets.Count -ne 44',
    '$node -is [Management.Automation.Language.CommandAst]',
    '$Ast.FindAll(',
    '$true',
    '$collisions.Count -ne 0')) {
  if (-not $canonicalGuardText.Contains($guardNeedle)) {
    throw "The canonical command-collision guard lacks: $guardNeedle"
  }
}
foreach ($guardedEntrypointPath in $guardedEntrypointAsts.Keys) {
  $guardedEntrypointLeaf = [IO.Path]::GetFileName($guardedEntrypointPath)
  $guardedDotSources = if (
      $issue13ExpectedDotSourceSignatures.ContainsKey(
        $guardedEntrypointLeaf)) {
    [string[]]$issue13ExpectedDotSourceSignatures[$guardedEntrypointLeaf]
  } else {
    [string[]]@()
  }
  $guardedRetentionBlock = $guardedEntrypointAsts[
    $guardedEntrypointPath].EndBlock.Statements[0].Right.Expression.ScriptBlock
  if (-not (Test-Issue13V5CommandCollisionGuardFirst `
      $guardedEntrypointAsts[$guardedEntrypointPath] `
      $canonicalGuardText) -or
      -not (Test-Issue13V5BootstrapRuntimeLeaseRetention `
        $guardedRetentionBlock) -or
      -not (Test-Issue13V5BootstrapImports `
        $guardedEntrypointAsts[$guardedEntrypointPath] `
        $guardedDotSources)) {
    throw "Command-collision guard is absent or late: $guardedEntrypointPath"
  }
}
$canonicalRuntimeMembers = @($canonicalGuardBlock.FindAll({
  param($node)
  $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
    $node.Expression.Extent.Text -ceq '$runtimeFileLeases'
}, $true))
$canonicalLeaseSetMembers = @($canonicalGuardBlock.FindAll({
  param($node)
  $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
    $node.Expression.Extent.Text -ceq '$leaseSets'
}, $true))
$canonicalSetDataCalls = @($canonicalGuardBlock.FindAll({
  param($node)
  $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
    $node.Member.Extent.Text -ceq 'SetData' -and
    [regex]::Replace($node.Expression.Extent.Text, '[\s`]', '') -ceq
      '[AppDomain]::CurrentDomain'
}, $true))
if ($canonicalRuntimeMembers.Count -ne 2 -or
    $canonicalLeaseSetMembers.Count -ne 1 -or
    $canonicalSetDataCalls.Count -ne 1) {
  throw 'Cannot construct bootstrap lease-retention mutants.'
}
$canonicalRuntimeAddText = $canonicalRuntimeMembers[0].Extent.Text
$canonicalLeaseSetAddText = $canonicalLeaseSetMembers[0].Extent.Text
$canonicalSetDataText = $canonicalSetDataCalls[0].Extent.Text
$leaseRetentionMutantTexts = @(
  $canonicalGuardText.Replace(
    $canonicalRuntimeAddText,
    $canonicalRuntimeAddText.Replace('$stream', '$null')),
  $canonicalGuardText.Replace(
    $canonicalLeaseSetAddText,
    $canonicalLeaseSetAddText.Replace('$runtimeFileLeases', '$null')),
  $canonicalGuardText.Replace(
    $canonicalLeaseSetAddText,
    'if ($false) { ' + $canonicalLeaseSetAddText + ' }'),
  $canonicalGuardText.Replace(
    $canonicalLeaseSetAddText,
    $canonicalLeaseSetAddText + "`n  `$leaseSets.Clear()"),
  $canonicalGuardText.Replace(
    $canonicalSetDataText,
    $canonicalSetDataText.Replace('$leaseSets', '$null')),
  $canonicalGuardText.Replace(
    $canonicalSetDataText,
    'if ($false) { ' + $canonicalSetDataText + ' }')
)
foreach ($leaseRetentionMutantText in $leaseRetentionMutantTexts) {
  $leaseRetentionMutantTokens = $null
  $leaseRetentionMutantErrors = $null
  $leaseRetentionMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $leaseRetentionMutantText, [ref]$leaseRetentionMutantTokens,
      [ref]$leaseRetentionMutantErrors)
  if ($leaseRetentionMutantText -ceq $canonicalGuardText -or
      $leaseRetentionMutantErrors.Count -ne 0 -or
      (Test-Issue13V5BootstrapRuntimeLeaseRetention `
        $leaseRetentionMutantAst)) {
    throw 'Bootstrap lease-retention verifier accepted a structural mutant.'
  }
}
$guardInvocationText =
  '& $issue13V5CommandCollisionGuard ' +
    '$MyInvocation.MyCommand.ScriptBlock.Ast'
$guardFirstValidText =
  $canonicalGuardAssignmentText + "`n" +
    $guardInvocationText + "`n" +
    'Set-StrictMode -Version Latest'
$guardFirstLateText =
  $canonicalGuardAssignmentText + "`n" +
    'Set-StrictMode -Version Latest' + "`n" +
    $guardInvocationText
$guardFirstWrongAstText =
  $canonicalGuardAssignmentText + "`n" +
    '& $issue13V5CommandCollisionGuard $null' + "`n" +
    'Set-StrictMode -Version Latest'
$guardFirstDuplicateText =
  $guardFirstValidText + "`n" + $canonicalGuardAssignmentText
$guardFirstCommandBodyText = $guardFirstValidText.Replace(
  'param([Management.Automation.Language.ScriptBlockAst]$Ast)',
  'param([Management.Automation.Language.ScriptBlockAst]$Ast)' + "`n" +
    "Write-Output 'GUARD_BODY_MUTANT'")
$guardFirstMutantTexts = [string[]]@(
  $guardFirstLateText,
  $guardFirstWrongAstText,
  $guardFirstDuplicateText,
  $guardFirstCommandBodyText)
$guardFirstValidTokens = $null
$guardFirstValidErrors = $null
$guardFirstValidAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $guardFirstValidText,
    [ref]$guardFirstValidTokens,
    [ref]$guardFirstValidErrors)
$guardFirstMutantsAccepted = 0
foreach ($guardFirstMutantText in $guardFirstMutantTexts) {
  $guardFirstMutantTokens = $null
  $guardFirstMutantErrors = $null
  $guardFirstMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $guardFirstMutantText,
      [ref]$guardFirstMutantTokens,
      [ref]$guardFirstMutantErrors)
  if ($guardFirstMutantErrors.Count -eq 0 -and
      (Test-Issue13V5CommandCollisionGuardFirst `
        $guardFirstMutantAst $canonicalGuardText)) {
    $guardFirstMutantsAccepted++
  }
}
if ($guardFirstValidErrors.Count -ne 0 -or
    -not (Test-Issue13V5CommandCollisionGuardFirst `
      $guardFirstValidAst $canonicalGuardText) -or
    $guardFirstMutantsAccepted -ne 0) {
  throw 'Command-collision guard-first structural mutants were accepted.'
}
$reachablePowerShellAsts = [ordered]@{
  'run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-static-verify.ps1' =
    $bootstrapStaticAst
}
foreach ($guardedEntrypointPath in $guardedEntrypointAsts.Keys) {
  $reachablePowerShellAsts[$guardedEntrypointPath] =
    $guardedEntrypointAsts[$guardedEntrypointPath]
}
foreach ($reachablePowerShellPath in $reachablePowerShellAsts.Keys) {
  $applicationCommands = @(
    $reachablePowerShellAsts[$reachablePowerShellPath].FindAll(
      {
        param($node)
        if ($node -isnot [Management.Automation.Language.CommandAst]) {
          return $false
        }
        $commandName = [string]$node.GetCommandName()
        if ([string]::IsNullOrWhiteSpace($commandName)) {
          return $false
        }
        $commandLeaf = @($commandName.Split('\'))[-1]
        $commandLeaf = @($commandLeaf.Split(':'))[-1]
        if ($commandLeaf -iin @('git', 'pwsh', 'pwsh.exe',
            'Rscript', 'Rscript.exe')) {
          return $true
        }
        $null -ne $ExecutionContext.InvokeCommand.GetCommand(
          $commandName,
          [Management.Automation.CommandTypes]::Application -bor
            [Management.Automation.CommandTypes]::ExternalScript)
      }, $true))
  $pathLookupCommands = @(
    $reachablePowerShellAsts[$reachablePowerShellPath].FindAll(
      {
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
          [string]$node.GetCommandName() -ieq 'Get-Command'
      }, $true))
  if ($applicationCommands.Count -ne 0 -or
      $pathLookupCommands.Count -ne 0) {
    throw ('Reachable PowerShell uses an unsealed application or PATH ' +
      "lookup: $reachablePowerShellPath")
  }
}
$sourceGitDynamicCount = 0
foreach ($sourceGitPath in [string[]]@(
    'issue13-evidence-harness/issue13-run-fault-seed-record.ps1',
    'issue13-evidence-harness/issue13-run-fault-seeds.ps1')) {
  $sourceGitAst = $sourceAsts[$sourceGitPath]
  $sourceGitText = [string]$sourceGitAst.Extent.Text
  $sourceGitCalls = @($sourceGitAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        $node.InvocationOperator -eq
          [Management.Automation.Language.TokenKind]::Ampersand -and
        $node.CommandElements.Count -ge 1 -and
        $node.CommandElements[0] -is
          [Management.Automation.Language.VariableExpressionAst] -and
        $node.CommandElements[0].VariablePath.UserPath -ieq 'gitExecutable'
    }, $true))
  if ($sourceGitCalls.Count -ne 2 -or
      -not $sourceGitText.Contains(
        "'ISSUE13_V5_GIT_EXECUTABLE', 'Process'") -or
      -not $sourceGitText.Contains(
        '[IO.Path]::IsPathFullyQualified($gitEnvironment)') -or
      -not $sourceGitText.Contains(
        '$gitExecutable = [IO.Path]::GetFullPath($gitEnvironment)') -or
      -not $sourceGitText.Contains(
        '[IO.File]::Exists($gitExecutable)')) {
    throw "Source Git path is not absolute/sealed: $sourceGitPath"
  }
  $sourceGitDynamicCount += $sourceGitCalls.Count
}
$monitorExecutableAst = $sourceAsts[
  'issue13-evidence-harness/issue13-monitor.ps1']
$recalcExecutableAst = $sourceAsts[
  'issue13-evidence-harness/issue13-run-recalc-bundle.ps1']
$monitorExecutableText = [string]$monitorExecutableAst.Extent.Text
$recalcExecutableText = [string]$recalcExecutableAst.Extent.Text
$recalcRscriptCalls = @($recalcExecutableAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      $node.InvocationOperator -eq
        [Management.Automation.Language.TokenKind]::Ampersand -and
      $node.CommandElements.Count -ge 1 -and
      $node.CommandElements[0] -is
        [Management.Automation.Language.VariableExpressionAst] -and
      $node.CommandElements[0].VariablePath.UserPath -ieq 'rscript'
  }, $true))
if ($sourceGitDynamicCount -ne 4 -or
    -not $monitorExecutableText.Contains(
      "'ISSUE13_V5_RSCRIPT_EXECUTABLE', 'Process'") -or
    -not $monitorExecutableText.Contains(
      '[IO.Path]::IsPathFullyQualified($rscriptEnvironment)') -or
    -not $monitorExecutableText.Contains(
      '$executable, $expectedExecutable') -or
    -not $monitorExecutableText.Contains(
      '[IO.File]::Exists($executable)') -or
    $recalcRscriptCalls.Count -ne 1 -or
    -not $recalcExecutableText.Contains(
      "'ISSUE13_V5_RSCRIPT_EXECUTABLE', 'Process'") -or
    -not $recalcExecutableText.Contains(
      '[IO.Path]::IsPathFullyQualified($rscriptEnvironment)') -or
    -not $recalcExecutableText.Contains(
      '$declaredRscript, $expectedRscript') -or
    -not $recalcExecutableText.Contains(
      '[IO.File]::Exists($expectedRscript)') -or
    -not $recalcExecutableText.Contains('$rscript = $expectedRscript')) {
  throw 'Source executables are not absolute paths held by sealed parents.'
}
$expectedSourcePowerShellSurfaces = @{
  'issue13-evidence-harness/issue13-monitor-selftest.ps1' = @{
    command_count = 62; command_sha256 = '126D458BA3853443222B985B700A38B73EED6935910584C1199A5382638EC4AD'
    redirection_count = 0; redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-evidence-harness/issue13-monitor.ps1' = @{
    command_count = 95; command_sha256 = '8831CF5D9A4A4FC810FFFDC93DB277A4CEFED4C9BDC8875BE3D11EC1A829EFB2'
    redirection_count = 0; redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-evidence-harness/issue13-run-fault-seed-record.ps1' = @{
    command_count = 34; command_sha256 = '7F25C04693847A4AFA3804C3535CF5B665AE7B9AD777871885EAC3A6F0F5C4BE'
    redirection_count = 0; redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-evidence-harness/issue13-run-fault-seeds.ps1' = @{
    command_count = 33; command_sha256 = 'C021C9F3715E5AE02A8408CC6AD04E042727FAC16425E2DC47425ACC1EBE6F98'
    redirection_count = 0; redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-evidence-harness/issue13-run-plan.ps1' = @{
    command_count = 18; command_sha256 = '668C2B8DFC32F328DA95EC2C5548BB9400DE76EAD9E848E7270BB5F8FEB3077C'
    redirection_count = 0; redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-evidence-harness/issue13-run-prep-fault-record.ps1' = @{
    command_count = 49; command_sha256 = 'CAD1F8E68061A92C9FAD9985791379C28CEE5EE31F30CF8A91FBB510A751DA8F'
    redirection_count = 0; redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
  'issue13-evidence-harness/issue13-run-recalc-bundle.ps1' = @{
    command_count = 90; command_sha256 = 'E0A49E7E4C6E06E0EECD415EEA2C7FF308E9E91D0DF35CF5B695F1EE5D1222B5'
    redirection_count = 0; redirection_sha256 = 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
  }
}
foreach ($sourcePowerShell in $expectedSourcePowerShellSurfaces.Keys) {
  if (-not (Test-Issue13V5AstSurface $sourceAsts[$sourcePowerShell] `
      $expectedSourcePowerShellSurfaces[$sourcePowerShell])) {
    throw "Source-tooling AST surface changed: $sourcePowerShell"
  }
}

$sourceHelperMappings = [ordered]@{
  'Get-Issue13ProcessEnvironmentState' =
    'Get-Issue13ProcessEnvironmentStateRecalc'
  'Set-Issue13ProcessEnvironmentState' =
    'Set-Issue13ProcessEnvironmentStateRecalc'
  'Invoke-Issue13WithProcessEnvironment' =
    'Invoke-Issue13WithProcessEnvironmentRecalc'
}
$monitorSourceAst = $sourceAsts[
  'issue13-evidence-harness/issue13-monitor.ps1']
$recalcSourceAst = $sourceAsts[
  'issue13-evidence-harness/issue13-run-recalc-bundle.ps1']
$monitorSelftestAst = $sourceAsts[
  'issue13-evidence-harness/issue13-monitor-selftest.ps1']
$sourceHelperDefinitions = [ordered]@{}
foreach ($sourceHelperName in $sourceHelperMappings.Keys) {
  $recalcHelperName = [string]$sourceHelperMappings[$sourceHelperName]
  $monitorDefinition = @(Get-Issue13V5StaticTopLevelFunctions `
      $monitorSourceAst $sourceHelperName)
  $recalcDefinition = @(Get-Issue13V5StaticTopLevelFunctions `
      $recalcSourceAst $recalcHelperName)
  $selftestMonitorCopies = @(Get-Issue13V5StaticTopLevelFunctions `
      $monitorSelftestAst $sourceHelperName)
  $selftestRecalcCopies = @(Get-Issue13V5StaticTopLevelFunctions `
      $monitorSelftestAst $recalcHelperName)
  $monitorAllDefinitions = @($monitorSourceAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq $sourceHelperName
    }, $true))
  $recalcAllDefinitions = @($recalcSourceAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq $recalcHelperName
    }, $true))
  if ($monitorDefinition.Count -ne 1 -or $recalcDefinition.Count -ne 1 -or
      $monitorAllDefinitions.Count -ne 1 -or
      $recalcAllDefinitions.Count -ne 1 -or
      $selftestMonitorCopies.Count -ne 0 -or
      $selftestRecalcCopies.Count -ne 0 -or
      $monitorDefinition[0].Name -cne $sourceHelperName -or
      $recalcDefinition[0].Name -cne $recalcHelperName) {
    throw "Source environment helper ownership differs: $sourceHelperName"
  }
  $normalizedRecalcText = [string]$recalcDefinition[0].Extent.Text
  foreach ($normalizationName in $sourceHelperMappings.Keys) {
    $normalizedRecalcText = $normalizedRecalcText.Replace(
      [string]$sourceHelperMappings[$normalizationName],
      [string]$normalizationName)
  }
  if ($monitorDefinition[0].Extent.Text -cne $normalizedRecalcText) {
    throw "Source environment helper semantics differ: $sourceHelperName"
  }
  $sourceHelperDefinitions[$sourceHelperName] = $monitorDefinition[0]
  $sourceHelperDefinitions[$recalcHelperName] = $recalcDefinition[0]
}
$monitorNamedCommandNames = [Collections.Generic.HashSet[string]]::new(
  [StringComparer]::OrdinalIgnoreCase)
foreach ($monitorCommand in $monitorSourceAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst]
  }, $true)) {
  $monitorCommandName = [string]$monitorCommand.GetCommandName()
  if (-not [string]::IsNullOrWhiteSpace($monitorCommandName)) {
    $null = $monitorNamedCommandNames.Add(
      (Get-Issue13V5PowerShellCommandLeaf $monitorCommandName))
  }
}
foreach ($sourceParentPath in $sourceAsts.Keys) {
  if ($sourceParentPath -ceq
      'issue13-evidence-harness/issue13-monitor.ps1') {
    continue
  }
  $parentDefinitions = @($sourceAsts[$sourceParentPath].FindAll({
      param($node)
      $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Parent -is [Management.Automation.Language.NamedBlockAst] -and
        [object]::ReferenceEquals(
          $node.Parent.Parent, $sourceAsts[$sourceParentPath])
    }, $true))
  $parentMonitorCollisions = @($parentDefinitions | Where-Object {
      $monitorNamedCommandNames.Contains(
        (Get-Issue13V5PowerShellCommandLeaf $_.Name))
    })
  if ($parentMonitorCollisions.Count -ne 0) {
    throw "Source parent functions collide with monitor: $sourceParentPath"
  }
}
foreach ($sourceEnvironmentContract in @(
    [pscustomobject]@{
      getter = 'Get-Issue13ProcessEnvironmentState'
      setter = 'Set-Issue13ProcessEnvironmentState'
    },
    [pscustomobject]@{
      getter = 'Get-Issue13ProcessEnvironmentStateRecalc'
      setter = 'Set-Issue13ProcessEnvironmentStateRecalc'
    })) {
  $sourceSetter = $sourceHelperDefinitions[$sourceEnvironmentContract.setter]
  $sourceGetter = $sourceHelperDefinitions[$sourceEnvironmentContract.getter]
  if (-not (Test-Issue13V5StaticEnvironmentSetter $sourceSetter `
        $sourceEnvironmentContract.setter)) {
    throw ('Source environment setter is not fail-closed tri-state: ' +
      [string]$sourceEnvironmentContract.setter)
  }
  if (-not $sourceGetter.Extent.Text.Contains(
        'Test-Path -LiteralPath $path') -or
      -not $sourceGetter.Extent.Text.Contains('GetEnvironmentVariable')) {
    throw ('Source environment getter collapses absent and empty states: ' +
      [string]$sourceEnvironmentContract.getter)
  }
}
$environmentRemoveOwners = [Collections.Generic.List[string]]::new()
foreach ($environmentAstRecord in @(
    [pscustomobject]@{ file = 'coordinator'; ast = $centralAst },
    [pscustomobject]@{ file = 'oracle'; ast = $oracleAst },
    [pscustomobject]@{ file = 'monitor'; ast = $monitorSourceAst },
    [pscustomobject]@{ file = 'recalc'; ast = $recalcSourceAst })) {
  foreach ($environmentRemove in @($environmentAstRecord.ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
          (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
            'Remove-Item' -and $node.Extent.Text.Contains("'Env:'")
      }, $true))) {
    $environmentOwner = $environmentRemove.Parent
    while ($null -ne $environmentOwner -and $environmentOwner -isnot
        [Management.Automation.Language.FunctionDefinitionAst]) {
      $environmentOwner = $environmentOwner.Parent
    }
    $environmentRemoveOwners.Add(
      [string]$environmentAstRecord.file + ':' + [string]$environmentOwner.Name)
  }
}
if ([string]::Join("`n", $environmentRemoveOwners.ToArray()) -cne
      "coordinator:Set-Issue13V5ProcessEnvironmentState`n" +
      "oracle:Set-Issue13OracleEffectProcessEnvironmentState`n" +
      "monitor:Set-Issue13ProcessEnvironmentState`n" +
      'recalc:Set-Issue13ProcessEnvironmentStateRecalc') {
  throw 'Env: removal escaped the four semantic setters.'
}
$selftestText = [string]$monitorSelftestAst.Extent.Text
if (-not $selftestText.Contains('$monitorDefinition.Extent.Text -cne') -or
    -not $selftestText.Contains('$normalizedRecalcText =') -or
    -not $selftestText.Contains('$environmentHelpers = [ordered]@{') -or
    -not $selftestText.Contains(
      "'Set-Issue13ProcessEnvironmentStateRecalc'") -or
    -not $selftestText.Contains('Invoke-Expression $monitorDefinition.Extent.Text') -or
    -not $selftestText.Contains('Invoke-Expression $definition.Extent.Text') -or
    -not $selftestText.Contains('present = $true; value = $null') -or
    -not $selftestText.Contains('"truncated`0value"') -or
    @($monitorSelftestAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst]
      }, $true)).Count -ne 3) {
  throw 'Source monitor self-test does not execute the real helper extents/mutants.'
}
foreach ($sourceSetterName in [string[]]@(
    'Set-Issue13ProcessEnvironmentState',
    'Set-Issue13ProcessEnvironmentStateRecalc')) {
  $sourceSetter = $sourceHelperDefinitions[$sourceSetterName]
  $setterMutantText = $sourceSetter.Extent.Text.Replace(
    "Remove-Item -LiteralPath ('Env:' + `$name) -Force -ErrorAction Stop",
    "Set-Item -LiteralPath ('Env:' + `$name) -Value `$null -ErrorAction Stop")
  $setterMutantTokens = $null
  $setterMutantErrors = $null
  $setterMutantAst = [Management.Automation.Language.Parser]::ParseInput(
    $setterMutantText, [ref]$setterMutantTokens, [ref]$setterMutantErrors)
  $setterMutantDefinition = @(Get-Issue13V5StaticTopLevelFunctions `
      $setterMutantAst $sourceSetterName)
  if ($setterMutantText -ceq $sourceSetter.Extent.Text -or
      $setterMutantErrors.Count -ne 0 -or
      $setterMutantDefinition.Count -ne 1 -or
      (Test-Issue13V5StaticEnvironmentSetter $setterMutantDefinition[0] `
        $sourceSetterName)) {
    throw ('Static tri-state verifier accepted absent-as-null/empty ' +
      "mutation: $sourceSetterName")
  }
}
function Test-Issue13V5StaticMonitorLifecycle(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $helperNames = [string[]]@(
    'Process-Key', 'Get-ProcessTable', 'Add-Descendants',
    'Active-KnownRecords', 'Stop-KnownTree', 'Stop-KnownTreeBounded',
    'Assert-KnownTreeStopped')
  $definitions = @{}
  foreach ($helperName in $helperNames) {
    $matches = @(Get-Issue13V5StaticTopLevelFunctions $Ast $helperName)
    if ($matches.Count -ne 1 -or $matches[0].Name -cne $helperName) {
      return $false
    }
    $definitions[$helperName] = $matches[0]
  }
  $text = [string]$Ast.Extent.Text
  $keyText = [string]$definitions['Process-Key'].Extent.Text
  $descendantText = [string]$definitions['Add-Descendants'].Extent.Text
  $activeText = [string]$definitions['Active-KnownRecords'].Extent.Text
  $boundedText = [string]$definitions['Stop-KnownTreeBounded'].Extent.Text
  $stoppedText = [string]$definitions['Assert-KnownTreeStopped'].Extent.Text
  $boundedCalls = @($Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Stop-KnownTreeBounded'
    }, $true))
  $stoppedCalls = @($Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Assert-KnownTreeStopped'
    }, $true))
  $killCalls = @($Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Expression.Extent.Text -ceq '$process' -and
        $node.Member.Extent.Text -ceq 'Kill'
    }, $true))
  $disposeCalls = @($Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Expression.Extent.Text -ceq '$process' -and
        $node.Member.Extent.Text -ceq 'Dispose'
    }, $true))
  $keyText.Contains(
      "return ([string]`$ProcessId + '|' + `$Created)") -and
    $descendantText.Contains(
      '$KnownByPid[$record.ProcessId] -ceq [string]$record.Created') -and
    $descendantText.Contains('$childCreated -le $parentCreated') -and
    $activeText.Contains(
      '$KnownByPid[$_.ProcessId] -eq $_.Created') -and
    $boundedText.Contains(
      '$deadline = [DateTime]::UtcNow.AddSeconds(') -and
    $boundedText.Contains('Add-Descendants $table $KnownByPid $Observed') -and
    $boundedText.Contains('Stop-KnownTree $active') -and
    $boundedText.Contains(
      '} while ([DateTime]::UtcNow -lt $deadline)') -and
    $boundedText.Contains('Authenticated process tree did not terminate:') -and
    $stoppedText.Contains('Add-Descendants $table $KnownByPid $Observed') -and
    $stoppedText.Contains(
      'Authenticated process tree remains active after cleanup:') -and
    $boundedCalls.Count -eq 3 -and $stoppedCalls.Count -eq 1 -and
    $killCalls.Count -eq 2 -and
    @($killCalls | Where-Object {
        $_.Arguments.Count -ne 1 -or $_.Arguments[0].Extent.Text -cne '$true'
      }).Count -eq 0 -and
    $disposeCalls.Count -eq 1 -and
    $text.Contains('$cleanupFailures.Add($_.Exception)') -and
    $text.Contains('$failures.Add($lifecycleError.Exception)') -and
    $text.Contains('Monitor process lifecycle cleanup failed.') -and
    $text.Contains('if ($null -ne $lifecycleError) { throw $lifecycleError }') -and
    -not $text.Contains('Stop-Issue13V5ExternalProcess') -and
    -not $text.Contains('Invoke-Issue13V5WithCleanup')
}
if (-not (Test-Issue13V5StaticMonitorLifecycle $monitorSourceAst)) {
  throw 'Source monitor lifecycle is not independently bounded and rechecked.'
}
$monitorLifecycleText = [string]$monitorSourceAst.Extent.Text
$monitorLifecycleMutantTexts = @(
  $monitorLifecycleText.Replace('$process.Kill($true)', '$process.Kill($false)'),
  $monitorLifecycleText.Replace(
    'Assert-KnownTreeStopped $knownByPid $observed', '$null = $knownByPid'),
  $monitorLifecycleText.Replace(
    "return ([string]`$ProcessId + '|' + `$Created)",
    'return ([string]$ProcessId)'),
  $monitorLifecycleText.Replace(
    '$KnownByPid[$_.ProcessId] -eq $_.Created',
    '$KnownByPid.ContainsKey($_.ProcessId)'),
  $monitorLifecycleText.Replace(
    '$failures.Add($lifecycleError.Exception)', '$null = $lifecycleError'))
foreach ($monitorLifecycleMutantText in $monitorLifecycleMutantTexts) {
  $monitorLifecycleMutantTokens = $null
  $monitorLifecycleMutantErrors = $null
  $monitorLifecycleMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $monitorLifecycleMutantText,
      [ref]$monitorLifecycleMutantTokens,
      [ref]$monitorLifecycleMutantErrors)
  if ($monitorLifecycleMutantText -ceq $monitorLifecycleText -or
      $monitorLifecycleMutantErrors.Count -ne 0 -or
      (Test-Issue13V5StaticMonitorLifecycle $monitorLifecycleMutantAst)) {
    throw 'Source monitor lifecycle verifier accepted a kill/tree mutant.'
  }
}

$attributesPath = Join-Path $RepositoryRoot '.gitattributes'
$attributesBytes = [IO.File]::ReadAllBytes($attributesPath)
$attributesText = $bootstrapEncoding.GetString($attributesBytes)
$requiredAttributeRules = [string[]]@(
  'run_logs/issue13-native-gate-orchestrator-v5/*.ps1 text eol=lf',
  'run_logs/issue13-native-gate-orchestrator-v5/*.md text eol=lf',
  'run_logs/issue13-native-gate-orchestrator-v5/*.json text eol=lf',
  'run_logs/issue13-native-gate-orchestrator-v5/*.csv text eol=lf',
  'run_logs/issue13-evidence-source-v5/** text eol=lf')
if ($attributesBytes -contains 13 -or @($requiredAttributeRules |
      Where-Object {
        $rule = $_
        @($attributesText -split "`n" | Where-Object { $_ -ceq $rule }).Count `
          -ne 1
      }).Count -ne 0) {
  throw '.gitattributes does not singularly force source-v5 UTF-8/LF tooling.'
}

$materializerDefinition = @(Get-Issue13V5StaticTopLevelFunctions `
    $materializerAst 'Get-Issue13V5TrackedSourceTooling')[0]
$materializerGitDefinition = @(Get-Issue13V5StaticTopLevelFunctions `
    $materializerAst 'Invoke-Issue13V5GitBytes')[0]
$centralGitRawDefinition = @(Get-Issue13V5StaticTopLevelFunctions `
    $centralAst 'Invoke-Issue13V5GitRaw')[0]
$materializerDerivations = @($materializerAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Get-Issue13V5TrackedSourceTooling'
  }, $true))
$materializerSourceAssignments = @(Get-Issue13V5VariableWriteAsts `
  $materializerAst '$sourceToolingFiles')
$materializerSourcePaths = if ($materializerSourceAssignments.Count -eq 1) {
  [string[]]@($materializerSourceAssignments[0].Right.FindAll({
      param($node)
      $node -is [Management.Automation.Language.StringConstantExpressionAst]
    }, $true) | ForEach-Object Value)
} else { [string[]]@() }
if ([string]::Join("`n", $materializerSourcePaths) -cne
    [string]::Join("`n", $expectedSourceFiles)) {
  throw 'Materializer source allowlist is not the exact ordered source37 list.'
}
function Test-Issue13V5StaticMaterializerDerivations(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  @($Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Get-Issue13V5TrackedSourceTooling'
    }, $true)).Count -eq 3
}
foreach ($requiredMaterializerText in @(
    "`$sourceToolingRelativeRoot = 'run_logs/issue13-evidence-source-v5'",
    "'ls-tree', '-z'", "'status', '--porcelain=v1', '-z'",
    "'cat-file', 'blob'", "'hash-object', '--no-filters'",
    '$rootEntries.Count -ne 6', '$harnessEntries.Count -ne 32',
    '$gitFiles.Count -ne 37', 'directory_count = 1L',
    'candidate_commit = $Commit', 'repository_relative_root =',
    'physical_root = ConvertTo-Issue13V5CanonicalPath',
    'source_tooling = $sourceInventory')) {
  if (-not $materializerText.Contains($requiredMaterializerText)) {
    throw "Materializer lacks Git-bound source-tooling guard: $requiredMaterializerText"
  }
}
function Test-Issue13V5StaticMaterializerText([string]$Text) {
  foreach ($needle in @(
      "`$sourceToolingRelativeRoot = 'run_logs/issue13-evidence-source-v5'",
      "'ls-tree', '-z'", "'status', '--porcelain=v1', '-z'",
      "'cat-file', 'blob'", "'hash-object', '--no-filters'",
      '$rootEntries.Count -ne 6', '$harnessEntries.Count -ne 32',
      '$gitFiles.Count -ne 37', 'source_tooling = $sourceInventory')) {
    if (-not $Text.Contains($needle)) { return $false }
  }
  -not $Text.Contains('run_logs/issue13-evidence-runtime-v4') -and
    [regex]::IsMatch($Text,
      '(?m)^\s*source_tooling\s*=\s*\$sourceInventory\s*$')
}
if (-not (Test-Issue13V5StaticMaterializerText $materializerText)) {
  throw 'Materializer text predicate rejected the authenticated producer.'
}
foreach ($materializerMutant in @(
    $materializerText.Replace(
      'run_logs/issue13-evidence-source-v5',
      'run_logs/issue13-evidence-runtime-v4'),
    $materializerText.Replace("'ls-tree', '-z'", "'ls-tree'"),
    $materializerText.Replace("'hash-object', '--no-filters'", "'hash-object'"),
    $materializerText.Replace(
      'source_tooling = $sourceInventory',
      'source_tooling = $sourceInventoryAfter'))) {
  if ($materializerMutant -ceq $materializerText -or
      (Test-Issue13V5StaticMaterializerText $materializerMutant)) {
    throw 'Materializer predicate accepted a root/parser/hash/authority mutant.'
  }
}
if ($materializerDerivations.Count -ne 3 -or
    -not (Test-Issue13V5StaticMaterializerDerivations $materializerAst) -or
    $materializerDefinition.Extent.Text.Contains(
      'run_logs/issue13-evidence-runtime-v4') -or
    $materializerGitDefinition.Extent.Text -cne @'
function Invoke-Issue13V5GitBytes(
  [string]$Repository,
  [string[]]$Arguments
) {
  Invoke-Issue13V5GitRaw $Repository $Arguments
}
'@.TrimEnd() -or
    $centralGitRawDefinition.Extent.Text -cnotmatch
      '\$start\.FileName\s*=\s*\[string\]\$binding\.logical_path' -or
    -not $centralGitRawDefinition.Extent.Text.Contains(
      '$start.ArgumentList.Add([string]$argument)') -or
    -not $centralGitRawDefinition.Extent.Text.Contains(
      '$process.StandardOutput.BaseStream.CopyToAsync($stdout)') -or
    -not $centralGitRawDefinition.Extent.Text.Contains(
      '$process.StandardError.BaseStream.CopyToAsync($stderr)') -or
    -not $centralGitRawDefinition.Extent.Text.Contains(
      '$null = Assert-Issue13V5GitExecutableBinding $binding') -or
    -not $centralGitRawDefinition.Extent.Text.Contains(
      '$lease.handle.Dispose()')) {
  throw 'Materializer does not derive source_tooling exactly three times via raw Git.'
}
$lastDerivationName = $materializerDerivations[-1].CommandElements[0]
$derivationMutantText = $materializerText.Remove(
  $lastDerivationName.Extent.StartOffset,
  $lastDerivationName.Extent.EndOffset - $lastDerivationName.Extent.StartOffset).
  Insert($lastDerivationName.Extent.StartOffset,
    'Get-Issue13V5TrackedSourceToolingAfter')
$derivationMutantTokens = $null
$derivationMutantErrors = $null
$derivationMutantAst = [Management.Automation.Language.Parser]::ParseInput(
  $derivationMutantText, [ref]$derivationMutantTokens,
  [ref]$derivationMutantErrors)
if ($derivationMutantErrors.Count -ne 0 -or
    (Test-Issue13V5StaticMaterializerDerivations $derivationMutantAst)) {
  throw 'Materializer derivation checker accepted a missing post-generation seal.'
}
$aggregateSourceKeys = [string[]]@(
  'candidate_commit', 'repository_relative_root', 'root', 'physical_root',
  'file_count', 'directory_count', 'total_bytes', 'path_list_sha256',
  'inventory_sha256', 'trees', 'records')
$treeSourceKeys = [string[]]@(
  'relative_path', 'repository_path', 'mode', 'type', 'tree')
$fileSourceKeys = [string[]]@(
  'relative_path', 'repository_path', 'size_bytes', 'sha256', 'mode', 'type',
  'blob')
$materializerSourceTables = @($materializerDefinition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.HashtableAst]
  }, $true))
$materializerAggregateTables = @($materializerSourceTables | Where-Object {
    [string]::Join("`n", (Get-Issue13V5StaticHashtableKeys $_)) -ceq
      [string]::Join("`n", $aggregateSourceKeys)
  })
$materializerTreeTables = @($materializerSourceTables | Where-Object {
    [string]::Join("`n", (Get-Issue13V5StaticHashtableKeys $_)) -ceq
      [string]::Join("`n", $treeSourceKeys)
  })
$materializerFileTables = @($materializerSourceTables | Where-Object {
    [string]::Join("`n", (Get-Issue13V5StaticHashtableKeys $_)) -ceq
      [string]::Join("`n", $fileSourceKeys)
  })
if ($materializerAggregateTables.Count -ne 1 -or
    $materializerTreeTables.Count -ne 2 -or
    $materializerFileTables.Count -ne 1) {
  throw 'Materializer source_tooling aggregate/tree/file shapes are not exact.'
}

function Test-Issue13V5StaticOracleSchema(
  [object]$Schema,
  [object]$Spec
) {
  $tree = $Schema.'$defs'.sourceToolingTree
  $file = $Schema.'$defs'.sourceToolingFile
  $source = $Schema.'$defs'.sourceTooling
  $rscript = $Schema.'$defs'.rscript
  $harness = $Schema.'$defs'.harness
  $terminalRuntime = $Schema.'$defs'.terminalRuntime
  $runtimeSnapshot = $Schema.'$defs'.runtimeSnapshot
  $runtimeImmutability = $Schema.'$defs'.runtimeImmutability
  (Test-Issue13V5StaticExactProperties $tree.properties @(
      'relative_path', 'repository_path', 'mode', 'type', 'tree')) -and
    [string]::Join("`n", @($tree.required)) -ceq
      "relative_path`nrepository_path`nmode`ntype`ntree" -and
    (Test-Issue13V5ExactBoolean $tree.additionalProperties $false) -and
    [string]$tree.properties.mode.const -ceq '040000' -and
    [string]$tree.properties.type.const -ceq 'tree' -and
    (Test-Issue13V5StaticExactProperties $file.properties @(
      'relative_path', 'repository_path', 'size_bytes', 'sha256', 'mode',
      'type', 'blob')) -and
    [string]::Join("`n", @($file.required)) -ceq
      "relative_path`nrepository_path`nsize_bytes`nsha256`nmode`ntype`nblob" -and
    (Test-Issue13V5ExactBoolean $file.additionalProperties $false) -and
    [string]$file.properties.mode.const -ceq '100644' -and
    [string]$file.properties.type.const -ceq 'blob' -and
    (Test-Issue13V5StaticExactProperties $source.properties @(
      'candidate_commit', 'repository_relative_root', 'root', 'physical_root',
      'file_count', 'directory_count', 'total_bytes', 'path_list_sha256',
      'inventory_sha256', 'trees', 'records')) -and
    [string]::Join("`n", @($source.required)) -ceq
      "candidate_commit`nrepository_relative_root`nroot`nphysical_root`nfile_count`ndirectory_count`ntotal_bytes`npath_list_sha256`ninventory_sha256`ntrees`nrecords" -and
    (Test-Issue13V5ExactBoolean $source.additionalProperties $false) -and
    [long]$source.properties.file_count.const -eq 37L -and
    [long]$source.properties.directory_count.const -eq 1L -and
    [long]$source.properties.trees.minItems -eq 2L -and
    [long]$source.properties.trees.maxItems -eq 2L -and
    [string]$source.properties.trees.items.'$ref' -ceq
      '#/$defs/sourceToolingTree' -and
    [long]$source.properties.records.minItems -eq 37L -and
    [long]$source.properties.records.maxItems -eq 37L -and
    [string]$source.properties.records.items.'$ref' -ceq
      '#/$defs/sourceToolingFile' -and
    (Test-Issue13V5StaticExactProperties $rscript.properties @(
      'logical_path', 'physical_path', 'item_id', 'link_count', 'size_bytes',
      'sha256')) -and
    [string]::Join("`n", @($rscript.required)) -ceq
      "logical_path`nphysical_path`nitem_id`nlink_count`nsize_bytes`nsha256" -and
    (Test-Issue13V5ExactBoolean $rscript.additionalProperties $false) -and
    [string]$rscript.properties.item_id.pattern -ceq
      '^[0-9a-f]{16}:[0-9a-f]{32}$' -and
    [long]$rscript.properties.link_count.const -eq 1L -and
    [long]$rscript.properties.size_bytes.const -eq 94720L -and
    [string]$rscript.properties.sha256.const -ceq
      '3ad097e10d867e09eb7e54d8ed1f8ef933779b82be56482a04a27d65536d15f9' -and
    (Test-Issue13V5StaticExactProperties $harness.properties @(
      'expected_candidate_commit', 'manifest_path', 'manifest_sha256',
      'generation', 'final_evidence_eligible', 'reuses_candidate_evidence',
      'source_controller_commit_sha256', 'source_controller',
      'source_tooling', 'output_tooling', 'sealed_output_tooling',
      'installed_inventory', 'tools')) -and
    [string]::Join("`n", @($harness.required)) -ceq
      "expected_candidate_commit`nmanifest_path`nmanifest_sha256`ngeneration`nfinal_evidence_eligible`nreuses_candidate_evidence`nsource_controller_commit_sha256`nsource_controller`nsource_tooling`noutput_tooling`nsealed_output_tooling`ninstalled_inventory`ntools" -and
    [string]$harness.properties.source_tooling.'$ref' -ceq
      '#/$defs/sourceTooling' -and
    (Test-Issue13V5ExactBoolean $harness.additionalProperties $false) -and
    (Test-Issue13V5StaticExactProperties $terminalRuntime.properties @(
      'comparison_harness', 'rscript', 'r_library',
      'runtime_immutability')) -and
    [string]::Join("`n", @($terminalRuntime.required)) -ceq
      "comparison_harness`nrscript`nr_library`nruntime_immutability" -and
    [string]$terminalRuntime.properties.rscript.'$ref' -ceq
      '#/$defs/rscript' -and
    (Test-Issue13V5ExactBoolean `
      $terminalRuntime.additionalProperties $false) -and
    (Test-Issue13V5StaticExactProperties $runtimeSnapshot.properties @(
      'rscript', 'r_library')) -and
    [string]::Join("`n", @($runtimeSnapshot.required)) -ceq
      "rscript`nr_library" -and
    [string]$runtimeSnapshot.properties.rscript.'$ref' -ceq
      '#/$defs/rscript' -and
    (Test-Issue13V5ExactBoolean `
      $runtimeSnapshot.additionalProperties $false) -and
    [string]::Join("`n", @($runtimeImmutability.required)) -ceq
      "before`nafter`nimmutable" -and
    (Test-Issue13V5StaticExactProperties $runtimeImmutability.properties @(
      'before', 'after', 'immutable')) -and
    [string]$runtimeImmutability.properties.before.'$ref' -ceq
      '#/$defs/runtimeSnapshot' -and
    [string]$runtimeImmutability.properties.after.'$ref' -ceq
      '#/$defs/runtimeSnapshot' -and
    (Test-Issue13V5ExactBoolean `
      $runtimeImmutability.properties.immutable.const $true) -and
    (Test-Issue13V5ExactBoolean `
      $runtimeImmutability.additionalProperties $false) -and
    (Test-Issue13V5StaticExactProperties `
      $Spec.terminal_comparison_runtime.source_tooling @(
        'repository_relative_root', 'file_count', 'directory_count',
        'path_list_sha256', 'tree_relative_paths', 'required_relative_paths',
        'tree_mode', 'file_mode')) -and
    (Test-Issue13V5StaticExactProperties `
      $Spec.terminal_comparison_runtime.rscript @(
        'required_link_count', 'size_bytes', 'sha256'))
}
if (-not (Test-Issue13V5StaticOracleSchema $oracleSchema $oracleSpec) -or
    [string]$oracleSpec.proof_schema_sha256 -cne
      $oracleSchemaSha256.ToLowerInvariant()) {
  throw 'Oracle proof schema/spec do not close source_tooling and Rscript.'
}
$stableSourceSpec = $oracleSpec.terminal_comparison_runtime.source_tooling
$stableRscriptSpec = $oracleSpec.terminal_comparison_runtime.rscript
if ([string]$stableSourceSpec.repository_relative_root -cne
      'run_logs/issue13-evidence-source-v5' -or
    [long]$stableSourceSpec.file_count -ne 37L -or
    [long]$stableSourceSpec.directory_count -ne 1L -or
    [string]$stableSourceSpec.path_list_sha256 -cne $sourcePathSha256 -or
    [string]::Join("`n", @($stableSourceSpec.tree_relative_paths)) -cne
      ".`nissue13-evidence-harness" -or
    [string]::Join("`n", @($stableSourceSpec.required_relative_paths)) -cne
      [string]::Join("`n", $expectedSourceFiles) -or
    [string]$stableSourceSpec.tree_mode -cne '040000' -or
    [string]$stableSourceSpec.file_mode -cne '100644' -or
    [long]$stableRscriptSpec.required_link_count -ne 1L -or
    [long]$stableRscriptSpec.size_bytes -ne 94720L -or
    [string]$stableRscriptSpec.sha256 -cne
      '3ad097e10d867e09eb7e54d8ed1f8ef933779b82be56482a04a27d65536d15f9') {
  throw 'Oracle spec contains dynamic source pins or a stale Rscript authority.'
}
$schemaMutants = [Collections.Generic.List[object]]::new()
foreach ($definitionName in @(
    'sourceToolingTree', 'sourceToolingFile', 'sourceTooling', 'rscript')) {
  $mutant = $oracleSchema | ConvertTo-Json -Depth 100 -Compress |
    ConvertFrom-Json -Depth 100
  $mutant.'$defs'.$definitionName.properties.PSObject.Properties.Add(
    [Management.Automation.PSNoteProperty]::new('extra', @{ type = 'string' }))
  $schemaMutants.Add($mutant)
}
$countMutant = $oracleSchema | ConvertTo-Json -Depth 100 -Compress |
  ConvertFrom-Json -Depth 100
$countMutant.'$defs'.sourceTooling.properties.trees.maxItems = 3
$schemaMutants.Add($countMutant)
$recordCountMutant = $oracleSchema | ConvertTo-Json -Depth 100 -Compress |
  ConvertFrom-Json -Depth 100
$recordCountMutant.'$defs'.sourceTooling.properties.records.minItems = 36
$schemaMutants.Add($recordCountMutant)
$harnessMutant = $oracleSchema | ConvertTo-Json -Depth 100 -Compress |
  ConvertFrom-Json -Depth 100
$harnessMutant.'$defs'.harness.required = @(
  $harnessMutant.'$defs'.harness.required | Where-Object {
    [string]$_ -cne 'source_tooling'
  })
$harnessMutant.'$defs'.harness.properties.PSObject.Properties.Remove(
  'source_tooling')
$schemaMutants.Add($harnessMutant)
$itemIdMutant = $oracleSchema | ConvertTo-Json -Depth 100 -Compress |
  ConvertFrom-Json -Depth 100
$itemIdMutant.'$defs'.rscript.properties.item_id.pattern = '^.+$'
$schemaMutants.Add($itemIdMutant)
foreach ($schemaMutant in $schemaMutants) {
  if (Test-Issue13V5StaticOracleSchema $schemaMutant $oracleSpec) {
    throw 'Oracle schema checker accepted a source/Rscript shape mutant.'
  }
}
$stableSpecMutant = $oracleSpec | ConvertTo-Json -Depth 100 -Compress |
  ConvertFrom-Json -Depth 100
$stableSpecMutant.terminal_comparison_runtime.source_tooling.PSObject.Properties.Add(
  [Management.Automation.PSNoteProperty]::new(
    'candidate_commit', '0000000000000000000000000000000000000000'))
if (Test-Issue13V5StaticOracleSchema $oracleSchema $stableSpecMutant) {
  throw 'Oracle stable spec accepted a dynamic candidate/tree/blob pin.'
}
foreach ($requiredOracleText in @(
    'function Invoke-Issue13OracleEffectGit',
    'function Invoke-Issue13OracleEffectGitBytes',
    'function Get-Issue13OracleEffectExpectedSourceTooling',
    "'run_logs/issue13-evidence-source-v5'",
    "'ls-tree', '-z'", "'cat-file', 'blob'",
    "'hash-object', '--no-filters'",
    'Invoke-Issue13V5SealedGit',
    'Invoke-Issue13V5GitRaw $RepositoryRoot $Arguments',
    'Get-Issue13OracleEffectRscriptIdentity',
    'logical_path = $logical', 'physical_path =', 'item_id =',
    'link_count =', 'size_bytes =', 'sha256 =',
    '$expectedSourceTooling = Get-Issue13OracleEffectExpectedSourceTooling',
    '$currentSourceTooling = Get-Issue13OracleEffectExpectedSourceTooling',
    '$context.harness.source_tooling $currentSourceTooling',
    'source_tooling = $expectedSourceTooling',
    '$currentRscript = Get-Issue13OracleEffectRscriptIdentity',
    'Assert-Issue13OracleEffectRscriptIdentity $context.rscript',
    'rscript = $RuntimeBefore.rscript', 'rscript = $currentRscript',
    "'973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d'",
    "'4ba530a191ef45baaaa08b2aa03ec6dcd0268aa6514caec6520203a0213afdfe'")) {
  if (-not $oracleLibraryText.Contains($requiredOracleText)) {
    throw "Oracle library lacks Commit E authenticated binding: $requiredOracleText"
  }
}
$oracleEnvelopeDefinition = @(Get-Issue13V5StaticTopLevelFunctions $oracleAst `
    'Assert-Issue13OracleEffectHarnessManifestEnvelope')[0]
$oracleEnvelopeText = [string]$oracleEnvelopeDefinition.Extent.Text
foreach ($requiredEnvelopeText in @(
    "'schema', 'generation', 'status', 'materialized_at_utc'",
    "'baseline_commit', 'baseline_policy', 'baseline_runtime_commit'",
    "'strict_negative_evidence_required'",
    "'source_controller', 'source_tooling', 'output_tooling'",
    "'sealed_output_tooling', 'overlays'",
    "'commit_sha256', 'file_count', 'records'",
    "'file_count', 'total_bytes', 'inventory_sha256'",
    '[DateTimeOffset]::TryParseExact(',
    "'authenticated-direct-child-compatibility-oracle'",
    "'authenticated-compatibility-oracle-cc2'",
    "'authenticated-candidate-runtime-sidecar'",
    "'authenticated-arm-specific-source-contracts'")) {
  if (-not $oracleEnvelopeText.Contains($requiredEnvelopeText)) {
    throw "Oracle manifest envelope is not closed: $requiredEnvelopeText"
  }
}
if ($centralText.Contains('$Config.oracle_effect.rscript') -or
    $newConfigText.Contains('$oracleEffect.rscript') -or
    $oracleLibraryText.Contains('run_logs/issue13-evidence-runtime-v4')) {
  throw 'Current Oracle/Rscript/source tooling uses a forbidden fallback.'
}
foreach ($requiredConfigBinding in @(
    '$harnessBinding = Assert-Issue13V5HarnessBinding $pinConfig',
    '$sourceTooling = $harnessBinding.source_tooling',
    'source_tooling = $sourceTooling',
    '$rscriptFull = (Resolve-Path -LiteralPath',
    '$rscriptIdentity = Get-Issue13V5PhysicalItemIdentity',
    'rscript_item_id = [string]$rscriptIdentity.item_id',
    'rscript_link_count = [long]$rscriptIdentity.link_count')) {
  if (-not $newConfigText.Contains($requiredConfigBinding)) {
    throw "New config lacks Git/Rscript binding: $requiredConfigBinding"
  }
}

foreach ($requiredHistoricalText in @(
    "'973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d'",
    "'a17a187621cdd4aff6f24efd6bf43ffbf9336de0a19189dfc7f5a82758a92c23'",
    "'12b63f23e87b12b6afc0beabec9e64518b0ce114f1ae8b7fa481c01c78320edf'",
    "'7bdb481081e12c4522f6dfdace2ec2c00015127139b574356f76e019754592ea'",
    "'5b805a5b9c7d2e1d09b111392b8d0795e60b4866e55f606ac8db9dc4e7cf7657'",
    "'0cb1142cdadd74bf95272010f5393ebe2af79f47'",
    '$isHistoricalStrict', '$baseSummaryProperties',
    '$rscriptSummaryProperties', 'if (-not $isHistoricalStrict)',
    '$summary.records).Count -ne 12',
    '$strictAttemptsBefore.file_count -ne 120L',
    '$strictAttemptsBefore.directory_count -ne 60L',
    '$strictAttemptsBefore.total_bytes -ne 2255912L',
    '$directories.Count -ne 12',
    "'status', '--porcelain=v1', '-z', '--untracked-files=all'",
    '$strictHarnessAfter', '$strictAttemptsAfter', '$strictWorktreesAfter',
    'Get-Issue13V5PhysicalItemIdentity',
    'Baseline smoke Rscript binding changed during validation.')) {
  if (-not $centralText.Contains($requiredHistoricalText)) {
    throw "Historical strict/archive/worktree seal is incomplete: $requiredHistoricalText"
  }
}
if ([regex]::Matches($centralText,
      '973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d').Count `
    -lt 1 -or $script:Issue13V5RscriptSha256 -cne
      '3ad097e10d867e09eb7e54d8ed1f8ef933779b82be56482a04a27d65536d15f9') {
  throw 'Historical strict singular envelope or Rscript authority changed.'
}
$historicalDefinition = @(Get-Issue13V5StaticTopLevelFunctions $centralAst `
    'Assert-Issue13V5BaselineSmokeEvidence')[0]
$historicalShapeCounts = [ordered]@{
  '$result' = 20
  '$result.request' = 13
  '$metrics' = 36
  '$processDocument' = 11
  '$scenarioDocument' = 10
  '$bundleDocument' = 7
  '$checkpointDocument' = 19
  '$startedDocument' = 11
}
foreach ($shapeTarget in $historicalShapeCounts.Keys) {
  $shapeCalls = @($historicalDefinition.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Assert-Issue13V5ExactPropertyNames' -and
        $node.CommandElements.Count -ge 3 -and
        $node.CommandElements[1].Extent.Text -ceq $shapeTarget
    }, $true))
  if ($shapeCalls.Count -ne 1) {
    throw "Historical exact JSON shape is missing: $shapeTarget"
  }
  $shapeFields = @($shapeCalls[0].CommandElements[2].FindAll({
      param($node)
      $node -is [Management.Automation.Language.StringConstantExpressionAst]
    }, $true))
  if ($shapeFields.Count -ne [int]$historicalShapeCounts[$shapeTarget]) {
    throw "Historical exact JSON field count changed: $shapeTarget"
  }
}

$reportTextCommitE = [string]$issue13ControllerPowerShellTexts[
  'issue13-v5-render-report.ps1']
foreach ($requiredReportText in @(
    "'schema', 'label', 'executable', 'arguments', 'environment_set'",
    "'environment_cleared', 'working_directory'",
    '$manifestSourceTooling', '$configuredSourceTooling', '$oracleSourceTooling',
    "'run_logs/issue13-evidence-source-v5'",
    '$manifestSourceToolingJson -cne $configuredSourceToolingJson',
    '$manifestSourceToolingJson -cne $oracleSourceToolingJson',
    '$sourceToolingTrees.Count -ne 2',
    '$sourceToolingRecords.Count -ne 37',
    '$oracleRscriptBefore', '$oracleRscriptAfter',
    '$oracleRscriptJson -cne $oracleRscriptBeforeJson',
    '$oracleRscriptJson -cne $oracleRscriptAfterJson',
    '$strictAttemptsInventory', '$strictWorktreeDirectories',
    'Strict historical smoke summary', 'separate strict historical harness')) {
  if (-not $reportTextCommitE.Contains($requiredReportText)) {
    throw "Renderer omits Commit E evidence: $requiredReportText"
  }
}
function Test-Issue13V5StaticRendererBindings(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  foreach ($variable in @(
      '$manifestSourceTooling', '$configuredSourceTooling', '$oracleSourceTooling',
      '$oracleRscript', '$oracleRscriptBefore', '$oracleRscriptAfter',
      '$strictAttemptsInventory', '$strictWorktreeDirectories')) {
    $writes = @(Get-Issue13V5VariableWriteAsts $Ast $variable)
    if ($writes.Count -ne 1) { return $false }
    $readsAfter = @($Ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.VariableExpressionAst] -and
          (Get-Issue13V5AssignmentBaseVariableName $node) -ieq $variable -and
          $node.Extent.StartOffset -ge $writes[0].Extent.EndOffset
      }, $true))
    if ($readsAfter.Count -eq 0) { return $false }
  }
  $true
}
$rendererAst = $issue13ControllerPowerShellAsts[
  'issue13-v5-render-report.ps1']
if (-not (Test-Issue13V5StaticRendererBindings $rendererAst)) {
  throw 'Renderer Commit E variables are not singularly bound before use.'
}
$rendererOracleWrites = @(Get-Issue13V5VariableWriteAsts `
  $rendererAst '$oracleSourceTooling')
$rendererMutantText = $rendererAst.Extent.Text.Remove(
  $rendererOracleWrites[0].Extent.StartOffset,
  $rendererOracleWrites[0].Extent.EndOffset -
    $rendererOracleWrites[0].Extent.StartOffset).Insert(
      $rendererOracleWrites[0].Extent.StartOffset,
      '$undefinedSourceTooling = $oracleTerminalHarness.source_tooling')
$rendererMutantTokens = $null
$rendererMutantErrors = $null
$rendererMutantAst = [Management.Automation.Language.Parser]::ParseInput(
  $rendererMutantText, [ref]$rendererMutantTokens, [ref]$rendererMutantErrors)
if ($rendererMutantErrors.Count -ne 0 -or
    (Test-Issue13V5StaticRendererBindings $rendererMutantAst)) {
  throw 'Renderer binding checker accepted an undefined-variable mutant.'
}
$documentationRequirements = @{
  'README.md' = [string[]]@(
    'environment_set', 'environment_cleared',
    'run_logs/issue13-evidence-source-v5', '37 arquivos',
    'duas árvores Git', 'manifesto nunca é autoridade isolada',
    'before/after/current',
    '973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d',
    'archive write-once', '120 arquivos', '60 diretórios',
    '2.255.912 bytes', '12 worktrees',
    '0cb1142cdadd74bf95272010f5393ebe2af79f47',
    'não prova retrospectivamente', 'bytes físicos de `Rscript.exe`')
  'issue13-v5-oracle-effect-README.md' = [string[]]@(
    '973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d',
    '4ba530a191ef45baaaa08b2aa03ec6dcd0268aa6514caec6520203a0213afdfe',
    'formatos históricos exatos', 'e nenhum deles contém campo', '`rscript_*`',
    'run_logs/issue13-evidence-source-v5', '37 arquivos',
    'um diretório físico e dois',
    'objetos tree (`.` e `issue13-evidence-harness`)',
    'deliberadamente dinâmicos',
    'git ls-tree -z', 'git cat-file', 'git hash-object --no-filters',
    'mesmo objeto derivado', 'README.md` na posição 32',
    'present=false,value=null', 'present=true,value=""',
    'logical_path', 'physical_path', 'item_id', 'link_count',
    'size_bytes', 'sha256', 'PreparedContext', 'before`/`after')
}
foreach ($documentationName in $documentationRequirements.Keys) {
  $documentationPath = Join-Path $root $documentationName
  $documentationBytes = [IO.File]::ReadAllBytes($documentationPath)
  $documentationText = $bootstrapEncoding.GetString($documentationBytes)
  if ($documentationBytes -contains 13 -or
      $documentationText.Contains([char]0xFFFD) -or
      @($documentationRequirements[$documentationName] | Where-Object {
          -not $documentationText.Contains([string]$_)
        }).Count -ne 0) {
    throw "Commit E documentation is incomplete or not UTF-8/LF: $documentationName"
  }
}

$surfaceControlName = 'issue13-v5-attest-delivery.ps1'
$surfaceControlAst = $issue13ControllerPowerShellAsts[$surfaceControlName]
$surfaceControlText = $surfaceControlAst.Extent.Text
$surfaceMutants = @(
  ($surfaceControlText + "`n" +
    '$p = ''function:Write-Issue13V5Json''; ' +
    'Set-Item -Path $p -Value { throw }'),
  ($surfaceControlText + "`n" +
    '& (''Write-Issue13'' + ''V5Json'')'),
  ($surfaceControlText + "`n" +
    '''x'' > (''VaRiAbLe:\DeLiVeRyPrOtEcTeDrOoTs'')'),
  ($surfaceControlText + "`n" +
    '$p = ''variable:\deliveryProtectedRoots''; ' +
    '$h = Get-Item -LiteralPath $p; $h.Value = ''changed'''),
  ($surfaceControlText + "`n" +
    'Invoke-Expression ''$deliveryProtectedRoots = @()'''),
  ($surfaceControlText + "`n" +
    '$sb = [scriptblock]::(''Cr'' + ''eate'')(''$x = 1''); ' +
    '1 | ForEach-Object $sb')
)
foreach ($surfaceMutantText in $surfaceMutants) {
  $surfaceMutantTokens = $null
  $surfaceMutantErrors = $null
  $surfaceMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $surfaceMutantText, [ref]$surfaceMutantTokens,
      [ref]$surfaceMutantErrors)
  if ($surfaceMutantErrors.Count -ne 0 -or
      (Test-Issue13V5AstSurface $surfaceMutantAst `
        $issue13ExpectedAstSurfaces[$surfaceControlName])) {
    throw 'Controller AST surface accepted a command/provider mutant.'
  }
}
$sourceOnlyMutants = @(
  ($surfaceControlText + "`n" +
    '$h = $deliveryProtectedRoots; $h.Clear()'),
  ($surfaceControlText + "`n" +
    '$h = $deliveryProtectedRoots; $h[0] = ''changed'''),
  ($surfaceControlText + "`n" +
    '$CoNfIg.repository_root = ''C:\unprotected''')
)
foreach ($sourceOnlyMutantText in $sourceOnlyMutants) {
  if ((Get-Issue13V5ControllerSourceSha256 `
      $sourceOnlyMutantText $surfaceControlName) -ceq
      [string]$issue13ExpectedControllerSourceSha256[$surfaceControlName]) {
    throw 'Controller source seal accepted an assignment/member mutant.'
  }
}
$staticSourceText =
  [string]$bootstrapSourceTexts['issue13-v5-static-verify.ps1']
$selfMapMarker = '$issue13ExpectedControllerSourceSha256 = @{'
$selfCaseMutantText = $staticSourceText.Replace(
  $selfMapMarker, '$IsSuE13eXpEcTeDcOnTrOlLeRsOuRcEsHa256 = @{')
$selfCaseAccepted = $false
try {
  $null = Get-Issue13V5ControllerSourceSha256 `
    $selfCaseMutantText 'issue13-v5-static-verify.ps1'
  $selfCaseAccepted = $true
} catch {
  $selfCaseAccepted = $false
}
if ($selfCaseMutantText -ceq $staticSourceText -or $selfCaseAccepted) {
  throw 'Static verifier source seal accepted a case-variant self map.'
}
$selfExpressionMutantText = [regex]::Replace(
  $staticSourceText,
  "(?m)^(?<indent>[ \t]+)'issue13-v5-static-verify\.ps1' = " +
    "'[0-9A-F]{64}'$",
  '${indent}''issue13-v5-static-verify.ps1'' = ' +
    '$([string]::Concat(''00000000000000000000000000000000'', ' +
    '''00000000000000000000000000000000''))',
  1)
$selfExpressionAccepted = $false
try {
  $null = Get-Issue13V5ControllerSourceSha256 `
    $selfExpressionMutantText 'issue13-v5-static-verify.ps1'
  $selfExpressionAccepted = $true
} catch {
  $selfExpressionAccepted = $false
}
if ($selfExpressionMutantText -ceq $staticSourceText -or
    $selfExpressionAccepted) {
  throw 'Static verifier source seal accepted an executable self value.'
}
$criticalMutantTokens = $null
$criticalMutantErrors = $null
$criticalMutantAst = [Management.Automation.Language.Parser]::ParseInput(
  "EvilModule\Assert-Issue13V5ConfigPathIsolation `$a `$b`n" +
    'function local:wRiTe-IsSuE13oRaClEeFfEcTjSoNoNcE {}',
  [ref]$criticalMutantTokens, [ref]$criticalMutantErrors)
if ($criticalMutantErrors.Count -ne 0 -or
    (Test-Issue13V5CanonicalCriticalCommands `
      $criticalMutantAst $issue13CriticalPowerShellNames)) {
  throw 'Critical-command canonicalization accepted a qualified mutant.'
}
$criticalProviderMutantTokens = $null
$criticalProviderMutantErrors = $null
$criticalProviderMutantAst =
  [Management.Automation.Language.Parser]::ParseInput(
    '${FuNcTiOn:Assert-Issue13V5ConfigPathIsolation} = { throw }' + "`n" +
      '${AlIaS:Move-Item} = ''Write-Output''',
    [ref]$criticalProviderMutantTokens,
    [ref]$criticalProviderMutantErrors)
if ($criticalProviderMutantErrors.Count -ne 0 -or
    (Test-Issue13V5CanonicalCriticalCommands `
      $criticalProviderMutantAst $issue13CriticalPowerShellNames)) {
  throw 'Critical-command canonicalization accepted a provider rebind.'
}
$criticalItemProviderMutantTokens = $null
$criticalItemProviderMutantErrors = $null
$criticalItemProviderMutantAst =
  [Management.Automation.Language.Parser]::ParseInput(
    'New-Item -Path function:Write-Issue13V5Json -Value { throw }',
    [ref]$criticalItemProviderMutantTokens,
    [ref]$criticalItemProviderMutantErrors)
if ($criticalItemProviderMutantErrors.Count -ne 0 -or
    (Test-Issue13V5CanonicalCriticalCommands `
      $criticalItemProviderMutantAst $issue13CriticalPowerShellNames)) {
  throw 'Critical-command canonicalization accepted an item-provider rebind.'
}
$criticalAliasMutantTokens = $null
$criticalAliasMutantErrors = $null
$criticalAliasMutantAst =
  [Management.Automation.Language.Parser]::ParseInput(
    "gcm pwsh`nGCM git`nmv `$a `$b`nMOVE `$a `$b`n" +
      "gc `$p`nTYPE `$p",
    [ref]$criticalAliasMutantTokens, [ref]$criticalAliasMutantErrors)
if ($criticalAliasMutantErrors.Count -ne 0 -or
    (Test-Issue13V5CanonicalCriticalCommands `
      $criticalAliasMutantAst $issue13CriticalPowerShellNames)) {
  throw 'Critical-command canonicalization accepted a built-in alias.'
}
$protectedMutationTokens = $null
$protectedMutationErrors = $null
$protectedMutationAst = [Management.Automation.Language.Parser]::ParseInput(
  '$p = ''var'' + ''iable:resolvedProof''' + "`n" +
    'Set-Item -Path $p -Value $ProofPath' + "`n" +
    '$m = ''Set-Variable''' + "`n" +
    '& $m -Name resolvedProof -Value $ProofPath' + "`n" +
    '$s = @{ OutVariable = ''resolvedProof'' }' + "`n" +
    'Write-Output $ProofPath @s',
  [ref]$protectedMutationTokens, [ref]$protectedMutationErrors)
$protectedMutationCommands = @($protectedMutationAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst]
}, $true))
if ($protectedMutationErrors.Count -ne 0 -or
    $protectedMutationCommands.Count -ne 3 -or
    @($protectedMutationCommands | Where-Object {
      -not (Test-Issue13V5ForbiddenProtectedScopeCommand $_)
    }).Count -ne 0) {
  throw 'Protected-scope command guard missed a constructed mutation.'
}
$abbreviatedMutationTokens = $null
$abbreviatedMutationErrors = $null
$abbreviatedMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    'Write-Output x -Pi roots | Out-Null' + "`n" +
      '''x'' | Tee-Object -V roots | Out-Null' + "`n" +
      '& Write-Output x -OuTv roots' + "`n" +
      'Invoke-Expression ''$roots = @()''' + "`n" +
      '''x'' > (''VaRiAbLe:\roots'')' + "`n" +
      '$sb = [scriptblock]::(''Cr'' + ''eate'')(''$roots = @()'')',
    [ref]$abbreviatedMutationTokens,
    [ref]$abbreviatedMutationErrors)
$abbreviatedMutationCommands = @($abbreviatedMutationAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    ($node.Extent.Text -cmatch '-Pi(?:\s|$)' -or
      $node.Extent.Text -cmatch 'Tee-Object\s+-V(?:\s|$)' -or
      $node.Extent.Text -cmatch '-OuTv(?:\s|$)')
}, $true))
$invokeExpressionMutants = @($abbreviatedMutationAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Invoke-Expression'
}, $true))
if ($abbreviatedMutationErrors.Count -ne 0 -or
    $abbreviatedMutationCommands.Count -ne 3 -or
    @($abbreviatedMutationCommands | Where-Object {
      -not (Test-Issue13V5ForbiddenVariableMutationCommand $_)
    }).Count -ne 0 -or
    $invokeExpressionMutants.Count -ne 1 -or
    -not (Test-Issue13V5ForbiddenProtectedScopeCommand `
      $invokeExpressionMutants[0]) -or
    -not (Test-Issue13V5ForbiddenProtectedScopeRedirection `
      $abbreviatedMutationAst) -or
    -not (Test-Issue13V5ForbiddenSessionStateMutation `
      $abbreviatedMutationAst)) {
  throw 'Protected-scope guard accepted an abbreviated/dynamic mutation.'
}
$sessionScopeMutants = @(
  ('$GLOBAL:eXeCuTiOnCoNtExT.SessionState.' +
    '(''PS'' + ''Variable'').Set(''roots'', @())')
  '$script:PSDefaultParameterValues[''*:OutVariable''] = ''roots'''
  '$GLOBAL:pSdEfAuLtPaRaMeTeRvAlUeS[''*:PipelineVariable''] = ''roots'''
)
foreach ($sessionScopeMutantText in $sessionScopeMutants) {
  $sessionScopeMutantTokens = $null
  $sessionScopeMutantErrors = $null
  $sessionScopeMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $sessionScopeMutantText, [ref]$sessionScopeMutantTokens,
      [ref]$sessionScopeMutantErrors)
  if ($sessionScopeMutantErrors.Count -ne 0 -or
      -not (Test-Issue13V5ForbiddenSessionStateMutation `
        $sessionScopeMutantAst)) {
    throw 'Protected-scope guard accepted a scoped session-state mutation.'
  }
}
$criticalOwnerMutantTokens = $null
$criticalOwnerMutantErrors = $null
$criticalOwnerMutantAst =
  [Management.Automation.Language.Parser]::ParseInput(
    'function Assert-Issue13V5ConfigPathIsolation { throw }',
    [ref]$criticalOwnerMutantTokens, [ref]$criticalOwnerMutantErrors)
if ($criticalOwnerMutantErrors.Count -ne 0 -or
    (Test-Issue13V5CriticalDefinitionOwnership `
      $criticalOwnerMutantAst @())) {
  throw 'Critical-function ownership accepted a local shadow definition.'
}
$criticalImportMutantTokens = $null
$criticalImportMutantErrors = $null
$criticalImportMutantAst =
  [Management.Automation.Language.Parser]::ParseInput(
    '. $evil', [ref]$criticalImportMutantTokens,
    [ref]$criticalImportMutantErrors)
if ($criticalImportMutantErrors.Count -ne 0 -or
    (Test-Issue13V5BootstrapImports $criticalImportMutantAst @())) {
  throw 'Critical bootstrap allowlist accepted an extra dot-source.'
}

$captureLibraryPath = Join-Path $root 'issue13-v5-coordinator-lib.ps1'
$captureTokens = @()
$captureErrors = @()
$captureLibraryAst =
  $issue13ControllerPowerShellAsts['issue13-v5-coordinator-lib.ps1']
$physicalCopyDefinitions = @($captureLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Copy-Issue13V5PhysicalDirectorySnapshot'
}, $true))
$physicalProofDefinitions = @($captureLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Get-Issue13V5PhysicalSnapshotProof'
}, $true))
$runtimeCopyDefinitions = @($captureLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5PhysicalCopy'
}, $true))
if ($captureErrors.Count -ne 0 -or $physicalCopyDefinitions.Count -ne 1 -or
    $physicalProofDefinitions.Count -ne 1 -or
    $runtimeCopyDefinitions.Count -ne 1) {
  throw 'Native physical-copy definitions are missing or ambiguous.'
}
$physicalFileCopies = @($physicalCopyDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
    $node.Static -and $node.Member.Extent.Text -ieq 'Copy' -and
    (Test-Issue13V5TypeExpression $node.Expression 'System.IO.File')
}, $true))
$physicalProofCalls = @($physicalCopyDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Get-Issue13V5PhysicalSnapshotProof'
}, $true))
$proofIdentityCalls = @($physicalProofDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Get-Issue13V5PhysicalItemIdentity'
}, $true))
$runtimeIdentityCalls = @($runtimeCopyDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Get-Issue13V5PhysicalItemIdentity'
}, $true))
$officialSourceDefinitions = @($captureLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5OfficialSourceDataInventory'
}, $true))
$officialSourceInventoryCalls = @()
if ($officialSourceDefinitions.Count -eq 1) {
  $officialSourceInventoryCalls = @($officialSourceDefinitions[0].FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Get-Issue13V5TreeInventory'
  }, $true))
}
$officialSourceConstantDefinitions = @($captureLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Set-Issue13V5ScriptConstant'
}, $true))
$officialSourceConstantCalls = @($captureLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Set-Issue13V5ScriptConstant' -and
    $node.CommandElements.Count -eq 3 -and
    $node.CommandElements[1].Extent.Text -cmatch '^Issue13V5Source'
}, $true))
$officialSourceConstantSignatures = @($officialSourceConstantCalls |
  ForEach-Object {
    [string]::Join(' ', @($_.CommandElements | ForEach-Object {
      $_.Extent.Text
    }))
  } | Sort-Object)
$expectedOfficialSourceConstantSignatures = @(
  'Set-Issue13V5ScriptConstant Issue13V5SourceDirectoryCount 5L',
  "Set-Issue13V5ScriptConstant Issue13V5SourceDirectorySha256 '8b3a622a748f2489fe8cfd2a8273ec98ad4c372b2378d587a5ee2e3c5c916640'",
  'Set-Issue13V5ScriptConstant Issue13V5SourceFileCount 84L',
  "Set-Issue13V5ScriptConstant Issue13V5SourceInventorySha256 'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26'",
  "Set-Issue13V5ScriptConstant Issue13V5SourceOrdinalInventorySha256 'd7fc0ba48bed304cf3975f2189ee975b14c16522443b28379d26329ea661b97a'",
  'Set-Issue13V5ScriptConstant Issue13V5SourceTotalBytes 2946498269L'
)
$expectedOfficialSourceConstantHelper = @'
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
'@
$actualOfficialSourceConstantHelper = if (
    $officialSourceConstantDefinitions.Count -eq 1) {
  [regex]::Replace(
    $officialSourceConstantDefinitions[0].Extent.Text.Trim(), '\r\n?', "`n")
} else { '' }
$expectedOfficialSourceConstantHelper = [regex]::Replace(
  $expectedOfficialSourceConstantHelper.Trim(), '\r\n?', "`n")
$officialSourceOrdinalSortCalls = @($officialSourceDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
    $node.Static -and
    (Test-Issue13V5TypeExpression $node.Expression 'System.Array') -and
    $node.Member.Extent.Text -ieq 'Sort'
}, $true))
$officialSourceAddMemberCalls = @($officialSourceDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Add-Member'
}, $true))
if ($physicalFileCopies.Count -ne 1 -or
    $physicalFileCopies[0].Arguments.Count -ne 3 -or
    $physicalProofCalls.Count -ne 1 -or $proofIdentityCalls.Count -ne 2 -or
    $runtimeIdentityCalls.Count -ne 2 -or
    $officialSourceDefinitions.Count -ne 1 -or
    $officialSourceInventoryCalls.Count -ne 1 -or
    $actualOfficialSourceConstantHelper -cne
      $expectedOfficialSourceConstantHelper -or
    [string]::Join("`n", $officialSourceConstantSignatures) -cne
      [string]::Join("`n", $expectedOfficialSourceConstantSignatures) -or
    $officialSourceDefinitions[0].Extent.Text.IndexOf(
      '$script:Issue13V5SourceFileCount',
      [StringComparison]::Ordinal) -lt 0 -or
    $officialSourceDefinitions[0].Extent.Text.IndexOf(
      '$script:Issue13V5SourceDirectoryCount',
      [StringComparison]::Ordinal) -lt 0 -or
    $officialSourceDefinitions[0].Extent.Text.IndexOf(
      '$script:Issue13V5SourceTotalBytes',
      [StringComparison]::Ordinal) -lt 0 -or
    $officialSourceDefinitions[0].Extent.Text.IndexOf(
      '$script:Issue13V5SourceInventorySha256',
      [StringComparison]::Ordinal) -lt 0 -or
    $officialSourceDefinitions[0].Extent.Text.IndexOf(
      '$script:Issue13V5SourceOrdinalInventorySha256',
      [StringComparison]::Ordinal) -lt 0 -or
    $officialSourceDefinitions[0].Extent.Text.IndexOf(
      '$script:Issue13V5SourceDirectorySha256',
      [StringComparison]::Ordinal) -lt 0 -or
    $officialSourceOrdinalSortCalls.Count -ne 1 -or
    [string]::Join("`n", @(
      $officialSourceOrdinalSortCalls[0].Arguments | ForEach-Object {
        $_.Extent.Text
      })) -cne "`$ordinalLines`n[StringComparer]::Ordinal" -or
    $officialSourceAddMemberCalls.Count -ne 1 -or
    [string]::Join("`n", @(
      $officialSourceAddMemberCalls[0].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
      "-NotePropertyName`nordinal_inventory_sha256`n" +
        "-NotePropertyValue`n`$ordinalInventorySha256" -or
    $physicalCopyDefinitions[0].Extent.Text.IndexOf(
      'HardLink', [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
    $physicalCopyDefinitions[0].Extent.Text.IndexOf(
      'Junction', [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
    $captureLibraryAst.Extent.Text.IndexOf(
      'fsutil.exe', [StringComparison]::OrdinalIgnoreCase) -ge 0) {
  throw 'Native physical-copy implementation is no longer exact or isolated.'
}
$officialSourceRuntimePins = [ordered]@{
  Issue13V5SourceFileCount = 84L
  Issue13V5SourceDirectoryCount = 5L
  Issue13V5SourceTotalBytes = 2946498269L
  Issue13V5SourceInventorySha256 =
    'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26'
  Issue13V5SourceOrdinalInventorySha256 =
    'd7fc0ba48bed304cf3975f2189ee975b14c16522443b28379d26329ea661b97a'
  Issue13V5SourceDirectorySha256 =
    '8b3a622a748f2489fe8cfd2a8273ec98ad4c372b2378d587a5ee2e3c5c916640'
}
foreach ($pinName in $officialSourceRuntimePins.Keys) {
  $pin = Get-Variable -Name $pinName -Scope Script -ErrorAction Stop
  if ($pin.Options -ne [Management.Automation.ScopedItemOptions]::Constant -or
      -not [object]::Equals(
        $pin.Value, $officialSourceRuntimePins[$pinName])) {
    throw "Official source pin is not an exact script constant: $pinName"
  }
  Set-Issue13V5ScriptConstant $pinName $officialSourceRuntimePins[$pinName]
  $caseVariantMutationRejected = $false
  try {
    Set-Variable -Name $pinName.ToUpperInvariant() -Scope Script `
      -Value '__issue13_mutant__' -Force -ErrorAction Stop
  } catch {
    $caseVariantMutationRejected = $true
  }
  if (-not $caseVariantMutationRejected -or
      -not [object]::Equals(
        (Get-Variable -Name $pinName -Scope Script).Value,
        $officialSourceRuntimePins[$pinName])) {
    throw "Official source script constant accepted mutation: $pinName"
  }
}
$mismatchedPinRejected = $false
try {
  Set-Issue13V5ScriptConstant Issue13V5SourceInventorySha256 `
    '__issue13_mutant__'
} catch {
  $mismatchedPinRejected = $true
}
if (-not $mismatchedPinRejected) {
  throw 'Idempotent source-pin bootstrap accepted a mismatched value.'
}

function Get-Issue13V5AstAncestorChain(
  [Management.Automation.Language.Ast]$Node,
  [Management.Automation.Language.Ast]$RootAst
) {
  $types = @()
  $current = $Node
  while ($null -ne $current -and
      -not [object]::ReferenceEquals($current, $RootAst)) {
    $types += $current.GetType().Name
    $current = $current.Parent
  }
  if ($null -eq $current) { return '' }
  [string]::Join('>', [string[]]$types)
}
function Test-Issue13V5AstReferencesVariable(
  [Management.Automation.Language.Ast]$Ast,
  [string]$VariableName
) {
  if ($Ast -is [Management.Automation.Language.VariableExpressionAst] -and
      (Get-Issue13V5AssignmentBaseVariableName $Ast) -ieq $VariableName) {
    return $true
  }
  @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.VariableExpressionAst] -and
      (Get-Issue13V5AssignmentBaseVariableName $node) -ieq $VariableName
  }, $true)).Count -ne 0
}
function Test-Issue13V5SingularDirectAssignment(
  [Management.Automation.Language.Ast]$Ast,
  [string]$VariableName,
  [string]$ExpectedChain,
  [AllowNull()][string]$ExpectedRight = $null
) {
  $assignments = @(Get-Issue13V5VariableWriteAsts $Ast $VariableName)
  $checksRight = $PSBoundParameters.ContainsKey('ExpectedRight')
  if ($assignments.Count -ne 1 -or
      $assignments[0].Left.Extent.Text -cne $VariableName -or
      $assignments[0].Operator -ne
        [Management.Automation.Language.TokenKind]::Equals -or
      (Get-Issue13V5AstAncestorChain $assignments[0] $Ast) -cne
        $ExpectedChain -or
      ($checksRight -and
        $assignments[0].Right.Extent.Text -cne $ExpectedRight)) {
    return $false
  }
  $true
}
function Test-Issue13V5OfficialSourcePinsWriteFree(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  foreach ($pinName in $officialSourceRuntimePins.Keys) {
    if (@(Get-Issue13V5VariableWriteAsts `
        $Ast ('$' + $pinName)).Count -ne 0) {
      return $false
    }
  }
  $true
}
function Test-Issue13V5DeliveryBindingAst(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $definitions = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
        'Invoke-Issue13V5DeliveryAttestation'
  }, $true))
  if ($definitions.Count -ne 1) { return $false }
  $definition = $definitions[0]
  if ($definition.Name -cne 'Invoke-Issue13V5DeliveryAttestation') {
    return $false
  }
  $assignments = @(Get-Issue13V5VariableWriteAsts `
    $definition '$deliveryProtectedRoots')
  $outputAssignments = @(Get-Issue13V5VariableWriteAsts `
    $definition '$outputPath')
  $calls = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Resolve-Issue13V5DeliveryOutput'
  }, $true))
  $dynamicMutators = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Test-Issue13V5ForbiddenProtectedScopeCommand $node)
  }, $true))
  $memberMutators = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      (Test-Issue13V5AstReferencesVariable `
        $node '$deliveryProtectedRoots')
  }, $true))
  $writeCalls = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Write-Issue13V5Json'
  }, $true))
  if ($assignments.Count -ne 1 -or
      $assignments[0].Left.Extent.Text -cne '$deliveryProtectedRoots' -or
      (Get-Issue13V5AstAncestorChain $assignments[0] $definition) -cne
        'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' -or
      $outputAssignments.Count -ne 1 -or
      $outputAssignments[0].Left.Extent.Text -cne '$outputPath' -or
      (Get-Issue13V5AstAncestorChain $outputAssignments[0] $definition) -cne
        'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' -or
      $calls.Count -ne 2 -or
      [string]::Join("`n", @($calls[0].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
        "`$Output`n`$deliveryProtectedRoots" -or
      (Get-Issue13V5AstAncestorChain $calls[0] $definition) -cne
        'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' -or
      -not [object]::ReferenceEquals(
        $calls[0].Parent.Parent, $outputAssignments[0]) -or
      [string]::Join("`n", @($calls[1].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
        "`$outputPath`n`$deliveryProtectedRoots" -or
      (Get-Issue13V5AstAncestorChain $calls[1] $definition) -cne
        'CommandAst>PipelineAst>ParenExpressionAst>CommandAst>PipelineAst>' +
          'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' -or
      $writeCalls.Count -ne 1 -or
      -not [object]::ReferenceEquals(
        $calls[1].Parent.Parent.Parent, $writeCalls[0]) -or
      $writeCalls[0].CommandElements[1].Extent.Text -cne '$attestation') {
    return $false
  }
  if ($dynamicMutators.Count -ne 0 -or
      (Test-Issue13V5ForbiddenProtectedScopeRedirection $definition) -or
      (Test-Issue13V5ForbiddenSessionStateMutation $definition) -or
      $memberMutators.Count -ne 0) {
    return $false
  }
  $expectedRoots = '@([string]$config.repository_root,' +
    '[string]$config.worktree_root,' +
    '[string]$config.evidence_root,' +
    '[string]$config.control_root,' +
    '[string]$config.harness_runtime_root,' +
    '[string]$config.source_origin,' +
    '[string]$config.candidate_source_origin,' +
    '[string]$config.r_library,' +
    '[string]$config.rscript,' +
    '[string]$config.oracle_effect.comparisons.primary.root,' +
    '[string]$config.oracle_effect.comparisons.replay.root)'
  [regex]::Replace(
    $assignments[0].Right.Extent.Text, '\s+', '') -ceq $expectedRoots
}

$deliveryTokens = @()
$deliveryErrors = @()
$deliveryAst =
  $issue13ControllerPowerShellAsts['issue13-v5-attest-delivery.ps1']
$deliveryOutputDefinitions = @($deliveryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Resolve-Issue13V5DeliveryOutput'
}, $true))
$deliveryInvokeDefinitions = @($deliveryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Invoke-Issue13V5DeliveryAttestation'
}, $true))
if ($deliveryErrors.Count -ne 0 -or $deliveryOutputDefinitions.Count -ne 1 -or
    $deliveryInvokeDefinitions.Count -ne 1) {
  throw 'Delivery-output resolver AST is missing or ambiguous.'
}
$deliveryPhysicalCalls = @($deliveryOutputDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'ConvertTo-Issue13V5PhysicalPath'
}, $true))
$deliveryContainmentCalls = @($deliveryOutputDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Test-Issue13V5PathContained'
}, $true))
$deliveryDisjointCalls = @($deliveryOutputDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5PathsDisjoint'
}, $true))
$deliveryAncestorCalls = @($deliveryOutputDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5NoReparseAncestors'
}, $true))
if ($deliveryPhysicalCalls.Count -ne 2 -or
    $deliveryContainmentCalls.Count -ne 0 -or
    $deliveryDisjointCalls.Count -ne 1 -or
    (Get-Issue13V5AstAncestorChain `
      $deliveryDisjointCalls[0] $deliveryOutputDefinitions[0]) -cne
      'CommandAst>PipelineAst>StatementBlockAst>ForEachStatementAst>NamedBlockAst>ScriptBlockAst' -or
    $deliveryAncestorCalls.Count -ne 2 -or
    $deliveryOutputDefinitions[0].Extent.Text.Contains('.StartsWith(') -or
    $deliveryOutputDefinitions[0].Extent.Text.Contains(
      'Test-Issue13V5DeliveryPathWithin')) {
  throw 'Delivery output is no longer physically isolated.'
}
$deliveryProtectedAssignments = @(Get-Issue13V5VariableWriteAsts `
  $deliveryInvokeDefinitions[0] '$deliveryProtectedRoots')
$deliveryProtectedVariables = if ($deliveryProtectedAssignments.Count -eq 1) {
  @($deliveryProtectedAssignments[0].Right.FindAll({
    param($node)
    $node -is [Management.Automation.Language.VariableExpressionAst]
  }, $true) | ForEach-Object { '$' + $_.VariablePath.UserPath })
} else { @() }
$deliveryResolverCalls = @($deliveryInvokeDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Resolve-Issue13V5DeliveryOutput'
}, $true))
if ($deliveryProtectedAssignments.Count -ne 1 -or
    $deliveryProtectedAssignments[0].Left.Extent.Text -cne
      '$deliveryProtectedRoots' -or
    (Get-Issue13V5AstAncestorChain $deliveryProtectedAssignments[0] `
      $deliveryInvokeDefinitions[0]) -cne
      'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' -or
    [string]::Join("`n", $deliveryProtectedVariables) -cne
      [string]::Join("`n", @(
        '$config', '$config', '$config', '$config', '$config', '$config',
        '$config', '$config', '$config', '$config', '$config'
      )) -or
    $deliveryResolverCalls.Count -ne 2 -or
    -not (Test-Issue13V5DeliveryBindingAst $deliveryAst)) {
  throw 'Delivery protected-root binding is incomplete or bypassable.'
}
$deliveryText = $deliveryAst.Extent.Text
$deliveryResolverOwner = $deliveryResolverCalls[0].Parent
while ($null -ne $deliveryResolverOwner -and
    $deliveryResolverOwner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
  $deliveryResolverOwner = $deliveryResolverOwner.Parent
}
$deliveryResolverStatement = [string]$deliveryResolverOwner.Extent.Text
$deliveryConditionalStatement = '$outputPath = if ($false) {' + "`n" +
  [string]$deliveryResolverOwner.Right.Extent.Text + "`n} else { `$null }"
$deliveryConditionalText = $deliveryText.Replace(
  $deliveryResolverStatement, $deliveryConditionalStatement)
$deliveryConditionalTokens = $null
$deliveryConditionalErrors = $null
$deliveryConditionalAst = [Management.Automation.Language.Parser]::ParseInput(
  $deliveryConditionalText, [ref]$deliveryConditionalTokens,
  [ref]$deliveryConditionalErrors)
if ($deliveryConditionalErrors.Count -ne 0 -or
    (Test-Issue13V5DeliveryBindingAst $deliveryConditionalAst)) {
  throw 'Delivery binding accepted a conditional resolver call.'
}
$deliverySubassignmentText = $deliveryText.Replace(
  [string]$deliveryProtectedAssignments[0].Extent.Text,
  [string]$deliveryProtectedAssignments[0].Extent.Text +
    "`n  [string[]]`$DeLiVeRyPrOtEcTeDrOoTs = @(`$repository)")
$deliverySubassignmentTokens = $null
$deliverySubassignmentErrors = $null
$deliverySubassignmentAst = [Management.Automation.Language.Parser]::ParseInput(
  $deliverySubassignmentText, [ref]$deliverySubassignmentTokens,
  [ref]$deliverySubassignmentErrors)
if ($deliverySubassignmentErrors.Count -ne 0 -or
    (Test-Issue13V5DeliveryBindingAst $deliverySubassignmentAst)) {
  throw 'Delivery binding accepted a protected-root subassignment.'
}
$deliveryDynamicMutationText = $deliveryText.Replace(
  [string]$deliveryProtectedAssignments[0].Extent.Text,
  [string]$deliveryProtectedAssignments[0].Extent.Text +
    "`n  Microsoft.PowerShell.Utility\Set-Variable " +
      "-Name deliveryProtectedRoots -Value @(`$repository)")
$deliveryDynamicMutationTokens = $null
$deliveryDynamicMutationErrors = $null
$deliveryDynamicMutationAst = [Management.Automation.Language.Parser]::ParseInput(
  $deliveryDynamicMutationText, [ref]$deliveryDynamicMutationTokens,
  [ref]$deliveryDynamicMutationErrors)
if ($deliveryDynamicMutationErrors.Count -ne 0 -or
    (Test-Issue13V5DeliveryBindingAst $deliveryDynamicMutationAst)) {
  throw 'Delivery binding accepted a dynamic protected-root mutation.'
}
$deliveryRootWrapperText = $deliveryText.Replace(
  '[string]$config.repository_root',
  '[System.String]([string]$config.repository_root + ''\x'')')
$deliveryRootWrapperTokens = $null
$deliveryRootWrapperErrors = $null
$deliveryRootWrapperAst = [Management.Automation.Language.Parser]::ParseInput(
  $deliveryRootWrapperText, [ref]$deliveryRootWrapperTokens,
  [ref]$deliveryRootWrapperErrors)
if ($deliveryRootWrapperErrors.Count -ne 0 -or
    (Test-Issue13V5DeliveryBindingAst $deliveryRootWrapperAst)) {
  throw 'Delivery binding accepted a wrapped protected root.'
}
$deliveryWriteCalls = @($deliveryInvokeDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Write-Issue13V5Json'
}, $true))
$deliveryWriteOwner = $deliveryWriteCalls[0].Parent
while ($null -ne $deliveryWriteOwner -and
    $deliveryWriteOwner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
  $deliveryWriteOwner = $deliveryWriteOwner.Parent
}
$deliveryOutputMutationText = $deliveryText.Replace(
  [string]$deliveryWriteOwner.Extent.Text,
  "  `$OuTpUtPaTh = Join-Path `$repository 'issue13-mutant.json'`n" +
    [string]$deliveryWriteOwner.Extent.Text)
$deliveryOutputMutationTokens = $null
$deliveryOutputMutationErrors = $null
$deliveryOutputMutationAst = [Management.Automation.Language.Parser]::ParseInput(
  $deliveryOutputMutationText, [ref]$deliveryOutputMutationTokens,
  [ref]$deliveryOutputMutationErrors)
if ($deliveryOutputMutationErrors.Count -ne 0 -or
    (Test-Issue13V5DeliveryBindingAst $deliveryOutputMutationAst)) {
  throw 'Delivery binding accepted a post-check output mutation.'
}

$materializerTokens = @()
$materializerErrors = @()
$materializerAst =
  $bootstrapSourceAsts['issue13-v5-materialize-harness.ps1']
function Test-Issue13V5MaterializerTargetDataflow(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $definitions = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
        'Assert-Issue13V5AliasFreeLocalPath'
  }, $true))
  if ($definitions.Count -ne 1) { return $false }
  $definition = $definitions[0]
  $calls = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      $node.Static -and
      $node.Expression -is
        [Management.Automation.Language.VariableExpressionAst] -and
      $node.Expression.VariablePath.UserPath -ceq
        'script:Issue13V5MaterializerNativePathType' -and
      $node.Member.Extent.Text -ieq 'DriveTarget'
  }, $true))
  $assignments = @(Get-Issue13V5VariableWriteAsts $definition '$target')
  $dynamicMutators = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Test-Issue13V5ForbiddenProtectedScopeCommand $node)
  }, $true))
  if ($calls.Count -ne 1 -or $assignments.Count -ne 1 -or
      $dynamicMutators.Count -ne 0 -or
      (Test-Issue13V5ForbiddenProtectedScopeRedirection $definition) -or
      (Test-Issue13V5ForbiddenSessionStateMutation $definition)) {
    return $false
  }
  $owner = $calls[0].Parent
  while ($null -ne $owner -and $owner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
    $owner = $owner.Parent
  }
  if ($null -eq $owner -or
      -not [object]::ReferenceEquals($owner, $assignments[0]) -or
      -not [object]::ReferenceEquals(
        $assignments[0].Parent, $definition.Body.EndBlock)) {
    return $false
  }
  $callChain = @()
  $current = $calls[0]
  while ($null -ne $current) {
    $callChain += $current.GetType().Name
    if ([object]::ReferenceEquals($current, $owner)) { break }
    $current = $current.Parent
  }
  if ([string]::Join('>', [string[]]$callChain) -cne
      'InvokeMemberExpressionAst>CommandExpressionAst>AssignmentStatementAst') {
    return $false
  }
  $true
}
$materializerAliasDefinitions = @($materializerAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5AliasFreeLocalPath'
}, $true))
$materializerCanonicalDefinitions = @($materializerAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'ConvertTo-Issue13V5CanonicalPath'
}, $true))
$materializerAliasCalls = @($materializerAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5AliasFreeLocalPath'
}, $true))
$materializerDriveTargetCalls = @($materializerAliasDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
    $node.Static -and
    $node.Expression -is
      [Management.Automation.Language.VariableExpressionAst] -and
    $node.Expression.VariablePath.UserPath -ceq
      'script:Issue13V5MaterializerNativePathType' -and
    $node.Member.Extent.Text -ieq 'DriveTarget'
}, $true))
$materializerDriveTargetAssignment = if (
    $materializerDriveTargetCalls.Count -eq 1) {
  $value = $materializerDriveTargetCalls[0].Parent
  while ($null -ne $value -and $value -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
    $value = $value.Parent
  }
  $value
} else {
  $null
}
$materializerTargetAssignments = @(Get-Issue13V5VariableWriteAsts `
  $materializerAliasDefinitions[0] '$target')
$materializerTargetChecks = @($materializerAliasDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
    -not $node.Static -and $node.Expression.Extent.Text -ieq '$target' -and
    $node.Member.Extent.Text -ieq 'StartsWith'
}, $true))
$materializerAddTypeCalls = @($materializerAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Add-Type'
}, $true))
$materializerText = $materializerAst.Extent.Text
$materializerAliasText = $materializerAliasDefinitions[0].Extent.Text
if ($materializerErrors.Count -ne 0 -or
    $materializerAliasDefinitions.Count -ne 1 -or
    $materializerCanonicalDefinitions.Count -ne 1 -or
    $materializerAliasCalls.Count -ne 4 -or
    -not (Test-Issue13V5MaterializerTargetDataflow $materializerAst) -or
    $materializerDriveTargetCalls.Count -ne 1 -or
    $materializerTargetAssignments.Count -ne 1 -or
    $null -eq $materializerDriveTargetAssignment -or
    -not [object]::ReferenceEquals(
      $materializerDriveTargetAssignment, $materializerTargetAssignments[0]) -or
    $materializerDriveTargetAssignment.Left.Extent.Text -cne '$target' -or
    $materializerDriveTargetCalls[0].Arguments.Count -ne 1 -or
    $materializerDriveTargetCalls[0].Arguments[0].Extent.Text -cne
      '$root.Substring(0, 2)' -or
    $materializerTargetChecks.Count -ne 4 -or
    $materializerAddTypeCalls.Count -ne 1 -or
    $materializerAddTypeCalls[0].CommandElements.Count -ne 6 -or
    $materializerAddTypeCalls[0].CommandElements[1] -isnot
      [Management.Automation.Language.CommandParameterAst] -or
    $materializerAddTypeCalls[0].CommandElements[1].ParameterName -cne
      'PassThru' -or
    $materializerAddTypeCalls[0].CommandElements[2] -isnot
      [Management.Automation.Language.CommandParameterAst] -or
    $materializerAddTypeCalls[0].CommandElements[2].ParameterName -cne
      'ErrorAction' -or
    $materializerAddTypeCalls[0].CommandElements[3].Extent.Text -cne 'Stop' -or
    $materializerAddTypeCalls[0].CommandElements[4] -isnot
      [Management.Automation.Language.CommandParameterAst] -or
    $materializerAddTypeCalls[0].CommandElements[4].ParameterName -cne
      'TypeDefinition' -or
    $materializerText.IndexOf(
      'QueryDosDevice', [StringComparison]::Ordinal) -lt 0 -or
    $materializerAliasText.IndexOf(
      '[IO.DriveType]::Fixed', [StringComparison]::Ordinal) -lt 0 -or
    $materializerAliasText.IndexOf(
      "'\??\'", [StringComparison]::Ordinal) -lt 0 -or
    $materializerAliasText.IndexOf(
      "'\Device\Mup\'", [StringComparison]::Ordinal) -lt 0) {
  throw 'Harness materializer lacks fixed alias-free root isolation.'
}
$materializerNativeSource =
  [string]$materializerAddTypeCalls[0].CommandElements[5].Value
$materializerTargetStatement =
  [string]$materializerTargetAssignments[0].Extent.Text
if ($materializerText.IndexOf(
      $materializerTargetStatement, [StringComparison]::Ordinal) -ne
    $materializerText.LastIndexOf(
      $materializerTargetStatement, [StringComparison]::Ordinal)) {
  throw 'Harness materializer target assignment is not textually unique.'
}
$materializerDeadBranchText = $materializerText.Replace(
  $materializerTargetStatement,
  "if (`$false) {`n$materializerTargetStatement`n  }" +
    "`n  `$target = '\Device\HarddiskVolume3'")
$materializerDeadBranchTokens = $null
$materializerDeadBranchErrors = $null
$materializerDeadBranchAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $materializerDeadBranchText, [ref]$materializerDeadBranchTokens,
    [ref]$materializerDeadBranchErrors)
if ($materializerDeadBranchErrors.Count -ne 0 -or
    (Test-Issue13V5MaterializerTargetDataflow $materializerDeadBranchAst)) {
  throw 'Harness materializer accepted a dead DriveTarget branch mutant.'
}
$materializerConditionalRhsText = $materializerText.Replace(
  $materializerTargetStatement,
  '$target = if ($false) { ' +
    [string]$materializerTargetAssignments[0].Right.Extent.Text +
    " } else { '\Device\HarddiskVolume3' }")
$materializerConditionalRhsTokens = $null
$materializerConditionalRhsErrors = $null
$materializerConditionalRhsAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $materializerConditionalRhsText, [ref]$materializerConditionalRhsTokens,
    [ref]$materializerConditionalRhsErrors)
if ($materializerConditionalRhsErrors.Count -ne 0 -or
    (Test-Issue13V5MaterializerTargetDataflow $materializerConditionalRhsAst)) {
  throw 'Harness materializer accepted a conditional DriveTarget RHS mutant.'
}
$materializerPropertyMutationText = $materializerText.Replace(
  $materializerTargetStatement,
  $materializerTargetStatement + "`n  `$target[0] = 'X'")
$materializerPropertyMutationTokens = $null
$materializerPropertyMutationErrors = $null
$materializerPropertyMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $materializerPropertyMutationText,
    [ref]$materializerPropertyMutationTokens,
    [ref]$materializerPropertyMutationErrors)
if ($materializerPropertyMutationErrors.Count -ne 0 -or
    (Test-Issue13V5MaterializerTargetDataflow `
      $materializerPropertyMutationAst)) {
  throw 'Harness materializer accepted a target subassignment mutant.'
}

$expectedCaptureHeaders = @{
  'issue13-v5-capture-clean-bridge-evidence.ps1' = @(
    'schema', 'baseline_base_commit', 'baseline_base_tree',
    'baseline_runtime_commit', 'baseline_runtime_tree', 'harness_path',
    'harness_inventory_sha256', 'harness_runtime_path',
    'harness_runtime_inventory_before_sha256',
    'harness_runtime_inventory_after_sha256', 'rscript_path',
    'rscript_sha256', 'fsutil_path', 'fsutil_sha256', 'r_library_path',
    'r_library_inventory_before_sha256',
    'r_library_inventory_after_sha256', 'tool_records', 'baseline_worktree',
    'captured_methods', 'verified_records', 'seed_evidence_index_sha256',
    'source_data_origin_path', 'source_data_snapshot_path',
    'source_data_origin_inventory_before_sha256',
    'source_data_origin_inventory_after_sha256',
    'source_data_snapshot_inventory_before_sha256',
    'source_data_snapshot_inventory_after_sha256',
    'source_data_origin_physical_path',
    'source_data_snapshot_physical_path', 'source_data_physical_file_count',
    'source_data_physical_directory_count',
    'source_data_origin_physical_before_sha256',
    'source_data_origin_physical_after_sha256',
    'source_data_snapshot_physical_before_sha256',
    'source_data_snapshot_physical_after_sha256',
    'source_data_independence_before_sha256',
    'source_data_independence_after_sha256',
    'source_wiodr13_manifest_sha256', 'source_wiodr16_manifest_sha256',
    'source_wiodr13_inventory_before_sha256',
    'source_wiodr13_inventory_after_sha256',
    'source_wiodr16_inventory_before_sha256',
    'source_wiodr16_inventory_after_sha256', 'evidence_index',
    'evidence_index_sha256'
  )
  'issue13-v5-capture-clean-stage5-evidence.ps1' = @(
    'schema', 'baseline_base_commit', 'baseline_base_tree',
    'baseline_runtime_commit', 'baseline_runtime_tree', 'harness_path',
    'harness_inventory_sha256', 'harness_runtime_path',
    'harness_runtime_inventory_before_sha256',
    'harness_runtime_inventory_after_sha256', 'rscript_path',
    'rscript_sha256', 'fsutil_path', 'fsutil_sha256', 'r_library_path',
    'r_library_inventory_before_sha256',
    'r_library_inventory_after_sha256', 'methods', 'stages',
    'bridge_capture_record_sha256', 'bridge_evidence_index_sha256',
    'bridge_manifest_sha256', 'stage5_evidence_index_sha256',
    'source_data_origin_path',
    'source_data_origin_inventory_before_sha256',
    'source_data_origin_inventory_after_sha256',
    'bridge_source_data_snapshot_path',
    'bridge_source_data_snapshot_inventory_before_sha256',
    'bridge_source_data_snapshot_inventory_after_sha256',
    'source_data_origin_physical_path', 'source_data_physical_file_count',
    'source_data_physical_directory_count',
    'source_data_origin_physical_before_sha256',
    'source_data_origin_physical_after_sha256',
    'bridge_source_data_snapshot_physical_path',
    'bridge_source_data_snapshot_physical_before_sha256',
    'bridge_source_data_snapshot_physical_after_sha256',
    'bridge_source_data_independence_before_sha256',
    'bridge_source_data_independence_after_sha256',
    'source_wiodr13_inventory_before_sha256',
    'source_wiodr13_inventory_after_sha256',
    'source_wiodr16_inventory_before_sha256',
    'source_wiodr16_inventory_after_sha256', 'recipe_records',
    'reference_records', 'seed_records', 'target_records',
    'worktree_records', 'source_snapshot_records'
  )
}
$expectedPhysicalCaptureCalls = @{
  'issue13-v5-capture-clean-bridge-evidence.ps1' = @(
    '$sourceDataPhysicalBefore|Copy-Issue13V5PhysicalDirectorySnapshot|$sourceData|$sourceSnapshot|"Bridge source-data snapshot"',
    '$sourceDataPhysicalAfter|Get-Issue13V5PhysicalSnapshotProof|$sourceData|$sourceSnapshot|"Bridge source-data snapshot"'
  )
  'issue13-v5-capture-clean-stage5-evidence.ps1' = @(
    '$bridgeSourcePhysicalBefore|Get-Issue13V5PhysicalSnapshotProof|$sourceData|$bridgeSourceSnapshotPath|"Bridge source-data snapshot"',
    '$sourceSnapshotPhysical|Copy-Issue13V5PhysicalDirectorySnapshot|$sourceData|$sourceSnapshot|"Stage-$stage source-data snapshot"',
    '$physicalAfter|Get-Issue13V5PhysicalSnapshotProof|$sourceData|$before.path|"Stage source-data snapshot $key"',
    '$bridgeSourcePhysicalAfter|Get-Issue13V5PhysicalSnapshotProof|$sourceData|$bridgeSourceSnapshotPath|"Bridge source-data snapshot"'
  )
}
$expectedPhysicalAssignmentChains = @{
  'issue13-v5-capture-clean-bridge-evidence.ps1' = @{
    '$sourceDataPhysicalBefore' = 'AssignmentStatementAst>NamedBlockAst'
    '$sourceDataPhysicalAfter' = 'AssignmentStatementAst>NamedBlockAst'
  }
  'issue13-v5-capture-clean-stage5-evidence.ps1' = @{
    '$bridgeSourcePhysicalBefore' = 'AssignmentStatementAst>NamedBlockAst'
    '$sourceSnapshotPhysical' =
      'AssignmentStatementAst>StatementBlockAst>ForEachStatementAst>' +
      'StatementBlockAst>ForEachStatementAst>NamedBlockAst'
    '$physicalAfter' =
      'AssignmentStatementAst>StatementBlockAst>ForEachStatementAst>' +
      'AssignmentStatementAst>NamedBlockAst'
    '$bridgeSourcePhysicalAfter' = 'AssignmentStatementAst>NamedBlockAst'
  }
}
function Test-Issue13V5CapturePhysicalDataflow(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string[]]$ExpectedSignatures,
  [Collections.IDictionary]$ExpectedChains
) {
  $calls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -iin @(
        'Copy-Issue13V5PhysicalDirectorySnapshot',
        'Get-Issue13V5PhysicalSnapshotProof')
  }, $true))
  $records = @($calls | ForEach-Object {
    $assignment = $_.Parent
    while ($null -ne $assignment -and $assignment -isnot
        [Management.Automation.Language.AssignmentStatementAst]) {
      $assignment = $assignment.Parent
    }
    if ($null -eq $assignment) { return }
    [pscustomobject]@{
      assignment = $assignment
      call = $_
      signature = [string]$assignment.Left.Extent.Text + '|' +
        [string]::Join('|', @($_.CommandElements | ForEach-Object {
          [string]$_.Extent.Text
        }))
    }
  })
  if ($records.Count -ne $ExpectedSignatures.Count -or
      [string]::Join("`n", @($records.signature)) -cne
        [string]::Join("`n", $ExpectedSignatures)) {
    return $false
  }
  $allowedSealedGitProbes = @(
    ('Invoke-Issue13V5SealedGit-C$repositorycat-file-e' +
      '($baselineBaseCommit+"^{commit}")'),
    ('Invoke-Issue13V5SealedGit-C$repositorycat-file-e' +
      '($baselineRuntimeCommit+"^{commit}")')
  )
  $dynamicMutators = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Test-Issue13V5ForbiddenVariableMutationCommand $node) -and
      $allowedSealedGitProbes -cnotcontains
        [regex]::Replace($node.Extent.Text, '[\s`]', '')
  }, $true))
  $forbiddenSessionMutation = $false
  $topLevelStatements = @($Ast.EndBlock.Statements)
  for ($statementIndex = 2;
      $statementIndex -lt $topLevelStatements.Count;
      $statementIndex++) {
    if (Test-Issue13V5ForbiddenSessionStateMutation `
        $topLevelStatements[$statementIndex]) {
      $forbiddenSessionMutation = $true
      break
    }
  }
  if ($dynamicMutators.Count -ne 0 -or $forbiddenSessionMutation) {
    return $false
  }
  foreach ($target in @($ExpectedChains.Keys)) {
    $assignments = @(Get-Issue13V5VariableWriteAsts $Ast $target)
    if ($assignments.Count -ne 1 -or
        (Get-Issue13V5AstAncestorChain $assignments[0] $Ast) -cne
          [string]$ExpectedChains[$target]) {
      return $false
    }
    $owners = @($records | Where-Object {
      $_.assignment.Extent.StartOffset -eq
        $assignments[0].Extent.StartOffset -and
      $_.assignment.Extent.EndOffset -eq $assignments[0].Extent.EndOffset
    })
    if ($owners.Count -ne 1) { return $false }
    $callChain = @()
    $current = $owners[0].call
    while ($null -ne $current) {
      $callChain += $current.GetType().Name
      if ([object]::ReferenceEquals($current, $assignments[0])) { break }
      $current = $current.Parent
    }
    if ([string]::Join('>', [string[]]$callChain) -cne
        'CommandAst>PipelineAst>AssignmentStatementAst') {
      return $false
    }
  }
  $true
}
$validatedCaptureAsts = @{}
foreach ($captureName in @($expectedCaptureHeaders.Keys | Sort-Object)) {
  $capturePath = Join-Path $root $captureName
  $captureTokens = @()
  $captureErrors = @()
  $captureAst = $bootstrapSourceAsts[$captureName]
  $validatedCaptureAsts[$captureName] = $captureAst
  $captureAssignments = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
      (Get-Issue13V5AssignmentBaseVariableName $node.Left) -ieq
        '$captureRecord'
  }, $true))
  $sharedCopyCalls = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Copy-Issue13V5PhysicalDirectorySnapshot'
  }, $true))
  $coordinatorDotSources = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      $node.InvocationOperator -eq
        [Management.Automation.Language.TokenKind]::Dot -and
      $node.Extent.Text.IndexOf(
        'issue13-v5-coordinator-lib.ps1',
        [StringComparison]::Ordinal) -ge 0
  }, $true))
  $systemDirectoryReads = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.MemberExpressionAst] -and
      $node.Static -and
      (Test-Issue13V5TypeExpression `
        $node.Expression 'System.Environment') -and
      $node.Member.Extent.Text -ieq 'SystemDirectory'
  }, $true))
  $pathResolvedFsutil = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Get-Command' -and
      $node.Extent.Text.IndexOf(
        'fsutil', [StringComparison]::OrdinalIgnoreCase) -ge 0
  }, $true))
  $localSnapshotDefinitions = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      $node.Name -match '(?i)Copy.*DirectorySnapshot'
  }, $true))
  $officialSourceCalls = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5OfficialSourceDataInventory'
  }, $true))
  $sourceOriginHashAssignments = @($captureAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
      (Get-Issue13V5AssignmentBaseVariableName $node.Left) -ieq
        '$sourceDataOriginInventoryBefore'
  }, $true))
  if ($captureErrors.Count -ne 0 -or $captureAssignments.Count -ne 1 -or
      -not (Test-Issue13V5SingularDirectAssignment $captureAst `
        '$captureRecord' 'AssignmentStatementAst>NamedBlockAst') -or
      $sharedCopyCalls.Count -ne 1 -or $coordinatorDotSources.Count -ne 1 -or
      $systemDirectoryReads.Count -ne 1 -or $pathResolvedFsutil.Count -ne 0 -or
      $localSnapshotDefinitions.Count -ne 0 -or
      $officialSourceCalls.Count -ne 1 -or
      [string]::Join("`n", @($officialSourceCalls[0].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
        '$sourceData' -or
      (Get-Issue13V5AstAncestorChain $officialSourceCalls[0] $captureAst) -cne
        'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst' -or
      $officialSourceCalls[0].Parent.Parent.Left.Extent.Text -cne
        '$officialSourceInventoryBefore' -or
      -not (Test-Issue13V5SingularDirectAssignment $captureAst `
        '$officialSourceInventoryBefore' `
        'AssignmentStatementAst>NamedBlockAst') -or
      $officialSourceCalls[0].Extent.StartOffset -ge
        $sharedCopyCalls[0].Extent.StartOffset -or
      $sourceOriginHashAssignments.Count -ne 1 -or
      -not (Test-Issue13V5SingularDirectAssignment $captureAst `
        '$sourceDataOriginInventoryBefore' `
        'AssignmentStatementAst>NamedBlockAst' `
        '[string]$officialSourceInventoryBefore.ordinal_inventory_sha256') -or
      $officialSourceCalls[0].Extent.EndOffset -ge
        $sourceOriginHashAssignments[0].Extent.StartOffset -or
      $sourceOriginHashAssignments[0].Extent.EndOffset -ge
        $sharedCopyCalls[0].Extent.StartOffset -or
      -not (Test-Issue13V5OfficialSourcePinsWriteFree $captureAst)) {
    throw "Capture AST does not use one shared physical copy: $captureName"
  }
  $headerKeys = @($captureAssignments[0].Right.FindAll({
    param($node)
    ($node -is [Management.Automation.Language.StringConstantExpressionAst] -or
      $node -is
        [Management.Automation.Language.ExpandableStringExpressionAst]) -and
      $node.Value -cmatch '^[a-z][a-z0-9_]*='
  }, $true) | ForEach-Object {
    ([string]$_.Value) -replace '=.*$', ''
  })
  if ([string]::Join("`n", $headerKeys) -cne [string]::Join(
      "`n", [string[]]$expectedCaptureHeaders[$captureName])) {
    throw "Capture record AST has an invalid exact header: $captureName"
  }
  if (-not (Test-Issue13V5CapturePhysicalDataflow $captureAst `
      ([string[]]$expectedPhysicalCaptureCalls[$captureName]) `
      $expectedPhysicalAssignmentChains[$captureName])) {
    throw "Capture before/after physical proof AST changed: $captureName"
  }
}
foreach ($captureName in @($validatedCaptureAsts.Keys | Sort-Object)) {
  $captureAst = $validatedCaptureAsts[$captureName]
  $captureText = $captureAst.Extent.Text
  foreach ($target in @(
      $expectedPhysicalAssignmentChains[$captureName].Keys | Sort-Object)) {
    $assignments = @(Get-Issue13V5VariableWriteAsts $captureAst $target)
    if ($assignments.Count -ne 1) {
      throw "Capture physical target is not singular: $captureName $target"
    }
    $statement = [string]$assignments[0].Extent.Text
    if ($captureText.IndexOf($statement, [StringComparison]::Ordinal) -ne
        $captureText.LastIndexOf($statement, [StringComparison]::Ordinal)) {
      throw "Capture physical statement is not textually unique: $target"
    }
    $deadBranchText = $captureText.Replace(
      $statement,
      "if (`$false) {`n$statement`n}" + "`n$target = `$null")
    $deadBranchTokens = $null
    $deadBranchErrors = $null
    $deadBranchAst = [Management.Automation.Language.Parser]::ParseInput(
      $deadBranchText, [ref]$deadBranchTokens, [ref]$deadBranchErrors)
    if ($deadBranchErrors.Count -ne 0 -or
        (Test-Issue13V5CapturePhysicalDataflow $deadBranchAst `
          ([string[]]$expectedPhysicalCaptureCalls[$captureName]) `
          $expectedPhysicalAssignmentChains[$captureName])) {
      throw "Capture accepted a dead physical-proof branch: $captureName $target"
    }
    $conditionalRhsStatement = $target + ' = if ($false) {' + "`n" +
      [string]$assignments[0].Right.Extent.Text + "`n} else { `$null }"
    $conditionalRhsText = $captureText.Replace(
      $statement, $conditionalRhsStatement)
    $conditionalRhsTokens = $null
    $conditionalRhsErrors = $null
    $conditionalRhsAst = [Management.Automation.Language.Parser]::ParseInput(
      $conditionalRhsText, [ref]$conditionalRhsTokens,
      [ref]$conditionalRhsErrors)
    if ($conditionalRhsErrors.Count -ne 0 -or
        (Test-Issue13V5CapturePhysicalDataflow $conditionalRhsAst `
          ([string[]]$expectedPhysicalCaptureCalls[$captureName]) `
          $expectedPhysicalAssignmentChains[$captureName])) {
      throw "Capture accepted a conditional physical-proof RHS: $captureName $target"
    }
    $subassignmentText = $captureText.Replace(
      $statement,
      $statement + "`n$target.__issue13_mutant = `$null")
    $subassignmentTokens = $null
    $subassignmentErrors = $null
    $subassignmentAst = [Management.Automation.Language.Parser]::ParseInput(
      $subassignmentText, [ref]$subassignmentTokens,
      [ref]$subassignmentErrors)
    if ($subassignmentErrors.Count -ne 0 -or
        (Test-Issue13V5CapturePhysicalDataflow $subassignmentAst `
          ([string[]]$expectedPhysicalCaptureCalls[$captureName]) `
          $expectedPhysicalAssignmentChains[$captureName])) {
      throw "Capture accepted a physical-proof subassignment: $captureName $target"
    }
  }
}

if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
  $staticMaterializerNativePathAssembliesBefore =
    [Reflection.Assembly[]]@([AppDomain]::CurrentDomain.GetAssemblies())
  $preexistingStaticMaterializerNativePathTypes = [type[]]@(
    [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
      $_.GetType('Issue13V5.NativePath', $false, $true)
    } | Where-Object { $null -ne $_ })
  if ($preexistingStaticMaterializerNativePathTypes.Count -ne 0) {
    throw 'The static verifier materializer native path type was preloaded.'
  }
  $staticMaterializerNativePathTypes = [object[]]@(
    Add-Type -PassThru -ErrorAction Stop `
      -TypeDefinition $materializerNativeSource)
  $staticMaterializerNativePathType = 'Issue13V5.NativePath' -as [type]
  $staticMaterializerNativePathNonTypes = [object[]]@(
    $staticMaterializerNativePathTypes | Where-Object { $_ -isnot [type] })
  $staticMaterializerNativePathReturnedAssemblies = [Reflection.Assembly[]]@(
    $staticMaterializerNativePathTypes | ForEach-Object { $_.Assembly } |
      Select-Object -Unique)
  $staticMaterializerNativePathAssemblyWasPreexisting = [object[]]@(
    $staticMaterializerNativePathAssembliesBefore | Where-Object {
      [object]::ReferenceEquals(
        $_, $staticMaterializerNativePathReturnedAssemblies[0])
    })
  $loadedStaticMaterializerNativePathTypes = [type[]]@(
    [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
      $_.GetType('Issue13V5.NativePath', $false, $true)
    } | Where-Object { $null -ne $_ })
  $staticMaterializerNativePathMethods = [string[]]@(
    $staticMaterializerNativePathTypes[0].GetMethods(
      [Reflection.BindingFlags]'Public, Static, DeclaredOnly') |
      ForEach-Object { $_.ToString() } | Sort-Object)
  if ($staticMaterializerNativePathTypes.Count -ne 1 -or
      $staticMaterializerNativePathTypes[0] -isnot [type] -or
      $staticMaterializerNativePathNonTypes.Count -ne 0 -or
      $staticMaterializerNativePathReturnedAssemblies.Count -ne 1 -or
      $staticMaterializerNativePathAssemblyWasPreexisting.Count -ne 0 -or
      [string]$staticMaterializerNativePathTypes[0].FullName -cne
        'Issue13V5.NativePath' -or
      $loadedStaticMaterializerNativePathTypes.Count -ne 1 -or
      $null -eq $staticMaterializerNativePathType -or
      -not [object]::ReferenceEquals(
        $staticMaterializerNativePathTypes[0],
        $staticMaterializerNativePathType) -or
      -not [object]::ReferenceEquals(
        $staticMaterializerNativePathTypes[0],
        $loadedStaticMaterializerNativePathTypes[0]) -or
      [string]::Join('|', $staticMaterializerNativePathMethods) -cne
        'System.String DriveTarget(System.String)|System.String Resolve(System.String)') {
    throw 'The static materializer native path type was not singular.'
  }
  New-Variable -Name Issue13V5StaticMaterializerNativePathType `
    -Scope Script -Option Constant `
    -Value $staticMaterializerNativePathTypes[0]
  $physicalSelftestParent = [IO.Path]::GetFullPath(
    [IO.Path]::GetTempPath()).TrimEnd('\')
  $physicalSelftestRoot = Join-Path $physicalSelftestParent (
    'issue13-v5-physical-selftest-' + [Guid]::NewGuid().ToString('N'))
  $physicalSelftestSource = Join-Path $physicalSelftestRoot 'source'
  $physicalSelftestSnapshot = Join-Path $physicalSelftestRoot 'snapshot'
  $sourceJunction = Join-Path $physicalSelftestRoot 'source-junction'
  $snapshotJunction = Join-Path $physicalSelftestRoot 'snapshot-junction'
  $null = [IO.Directory]::CreateDirectory(
    (Join-Path $physicalSelftestSource 'nested'))
  $selftestUtf8 = [Text.UTF8Encoding]::new($false)
  [IO.File]::WriteAllText(
    (Join-Path $physicalSelftestSource 'alpha.txt'), 'alpha', $selftestUtf8)
  [IO.File]::WriteAllText(
    (Join-Path $physicalSelftestSource 'nested\beta.txt'),
    'beta', $selftestUtf8)
  $unofficialSourceRejected = $false
  try {
    $null = Assert-Issue13V5OfficialSourceDataInventory `
      $physicalSelftestSource
  } catch {
    $unofficialSourceRejected = $_.Exception.Message.Contains(
      'Official source_data inventory differs:')
  }
  if (-not $unofficialSourceRejected) {
    throw 'Official source_data assertion accepted a synthetic tree.'
  }
  try {
    $usedDriveLetters = @([IO.DriveInfo]::GetDrives() | ForEach-Object {
      $_.Name.Substring(0, 2).ToUpperInvariant()
    })
    $deliveryAliasDrive = @(
      90..68 | ForEach-Object { ([char]$_).ToString() + ':' } |
        Where-Object { $_ -cnotin $usedDriveLetters }
    )[0]
    if ([string]::IsNullOrWhiteSpace($deliveryAliasDrive)) {
      throw 'No free drive letter exists for delivery alias self-test.'
    }
    $substPath = Join-Path ([Environment]::SystemDirectory) 'subst.exe'
    $deliveryAliasCreated = $false
    try {
      $null = & $substPath $deliveryAliasDrive $RepositoryRoot
      if ($LASTEXITCODE -ne 0) {
        throw 'Could not create delivery SUBST negative fixture.'
      }
      $deliveryAliasCreated = $true
      $materializerAliasTarget =
        $script:Issue13V5StaticMaterializerNativePathType::DriveTarget(
          $deliveryAliasDrive)
      if (-not $materializerAliasTarget.StartsWith(
          '\??\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Materializer native helper did not expose the SUBST target.'
      }
      $deliveryAliasRejected = $false
      try {
        $null = Resolve-Issue13V5DeliveryOutput `
          (Join-Path ($deliveryAliasDrive + '\run_logs') (
            'issue13-delivery-alias-' +
              [Guid]::NewGuid().ToString('N') + '.json')) `
          @($RepositoryRoot, $HarnessRuntimeRoot)
      } catch {
        $deliveryAliasRejected = $true
      }
      if (-not $deliveryAliasRejected) {
        throw 'Delivery output accepted a SUBST alias into the repository.'
      }
      $deliveryProtectedRootRejected = $false
      try {
        $null = Resolve-Issue13V5DeliveryOutput `
          (Join-Path $HarnessRuntimeRoot (
            'issue13-delivery-protected-' +
              [Guid]::NewGuid().ToString('N') + '.json')) `
          @($RepositoryRoot, $HarnessRuntimeRoot)
      } catch {
        $deliveryProtectedRootRejected = $_.Exception.Message.Contains(
          'Delivery attestation/protected-root isolation paths overlap:')
      }
      if (-not $deliveryProtectedRootRejected) {
        throw 'Delivery output accepted a protected harness descendant.'
      }
      $oracleProofAliasRejected = $false
      try {
        $null = Assert-Issue13OracleEffectProofPathIsolation `
          (Join-Path ($deliveryAliasDrive + '\run_logs') (
            'issue13-oracle-proof-alias-' +
              [Guid]::NewGuid().ToString('N') + '.json')) `
          @($RepositoryRoot, $HarnessRuntimeRoot)
      } catch {
        $oracleProofAliasRejected = $true
      }
      if (-not $oracleProofAliasRejected) {
        throw 'Oracle proof output accepted a SUBST repository alias.'
      }
    } finally {
      if ($deliveryAliasCreated) {
        $null = & $substPath $deliveryAliasDrive '/D'
        if ($LASTEXITCODE -ne 0) {
          throw 'Could not remove delivery SUBST negative fixture.'
        }
      }
    }
    $firstPhysicalProof = Copy-Issue13V5PhysicalDirectorySnapshot `
      $physicalSelftestSource $physicalSelftestSnapshot `
      'Static physical-copy self-test'
    if ($firstPhysicalProof.file_count -ne 2L -or
        $firstPhysicalProof.directory_count -ne 1L) {
      throw 'Static physical-copy self-test has invalid topology.'
    }
    $runtimePhysicalInventory = Get-Issue13V5TreeInventory `
      $physicalSelftestSnapshot
    if (-not (Assert-Issue13V5PhysicalCopy `
        $physicalSelftestSource $physicalSelftestSnapshot `
        $runtimePhysicalInventory)) {
      throw 'Runtime physical-copy assertion rejected an exact copy.'
    }
    $externalHardlink = Join-Path $physicalSelftestRoot 'external-hardlink.txt'
    $null = New-Item -ItemType HardLink -Path $externalHardlink -Target (
      Join-Path $physicalSelftestSnapshot 'alpha.txt')
    $hardlinkRejected = $false
    $runtimeHardlinkRejected = $false
    try {
      $null = Get-Issue13V5PhysicalSnapshotProof `
        $physicalSelftestSource $physicalSelftestSnapshot `
        'Static hard-link mutation'
    } catch {
      $hardlinkRejected = $true
    }
    try {
      $null = Assert-Issue13V5PhysicalCopy `
        $physicalSelftestSource $physicalSelftestSnapshot `
        $runtimePhysicalInventory
    } catch {
      $runtimeHardlinkRejected = $true
    } finally {
      if ([IO.File]::Exists($externalHardlink)) {
        [IO.File]::Delete($externalHardlink)
      }
    }
    if (-not $hardlinkRejected -or -not $runtimeHardlinkRejected) {
      throw 'Physical-copy proof accepted an external hard link.'
    }
    $null = New-Item -ItemType Junction -Path $sourceJunction -Target `
      $physicalSelftestSource
    $sourceJunctionRejected = $false
    try {
      $null = Get-Issue13V5PhysicalSnapshotProof `
        $sourceJunction $physicalSelftestSnapshot `
        'Static source-junction mutation'
    } catch {
      $sourceJunctionRejected = $true
    }
    if ([IO.Directory]::Exists($sourceJunction)) {
      [IO.Directory]::Delete($sourceJunction)
    }
    $null = New-Item -ItemType Junction -Path $snapshotJunction -Target `
      $physicalSelftestSnapshot
    $snapshotJunctionRejected = $false
    try {
      $null = Get-Issue13V5PhysicalSnapshotProof `
        $physicalSelftestSource $snapshotJunction `
        'Static snapshot-junction mutation'
    } catch {
      $snapshotJunctionRejected = $true
    }
    if ([IO.Directory]::Exists($snapshotJunction)) {
      [IO.Directory]::Delete($snapshotJunction)
    }
    if (-not $sourceJunctionRejected -or -not $snapshotJunctionRejected) {
      throw 'Physical-copy proof accepted a junction root.'
    }
    if (-not (Test-Issue13V5PathContained `
        $physicalSelftestSnapshot $physicalSelftestRoot)) {
      throw 'Static snapshot cleanup target escaped its self-test root.'
    }
    [IO.Directory]::Delete($physicalSelftestSnapshot, $true)
    $secondPhysicalProof = Copy-Issue13V5PhysicalDirectorySnapshot `
      $physicalSelftestSource $physicalSelftestSnapshot `
      'Static physical-copy recreation self-test'
    if ($firstPhysicalProof.source_physical_inventory_sha256 -cne
          $secondPhysicalProof.source_physical_inventory_sha256 -or
        $firstPhysicalProof.snapshot_physical_inventory_sha256 -ceq
          $secondPhysicalProof.snapshot_physical_inventory_sha256 -or
        $firstPhysicalProof.independence_sha256 -ceq
          $secondPhysicalProof.independence_sha256) {
      throw 'Physical recreation did not change snapshot identity.'
    }
  } finally {
    if ([IO.Directory]::Exists($sourceJunction)) {
      [IO.Directory]::Delete($sourceJunction)
    }
    if ([IO.Directory]::Exists($snapshotJunction)) {
      [IO.Directory]::Delete($snapshotJunction)
    }
    if ([IO.Directory]::Exists($physicalSelftestRoot)) {
      if ([IO.Path]::GetFileName($physicalSelftestRoot) -cnotmatch
          '^issue13-v5-physical-selftest-[0-9a-f]{32}$' -or
          -not (Test-Issue13V5PathContained `
            $physicalSelftestRoot $physicalSelftestParent)) {
        throw 'Unsafe static physical-copy self-test cleanup target.'
      }
      [IO.Directory]::Delete($physicalSelftestRoot, $true)
    }
  }
}

$oracleProofProtectedRejected = $false
try {
  $null = Assert-Issue13OracleEffectProofPathIsolation `
    (Join-Path $RepositoryRoot (
      'issue13-oracle-proof-protected-' +
        [Guid]::NewGuid().ToString('N') + '.json')) `
    @($RepositoryRoot, $HarnessRuntimeRoot)
} catch {
  $oracleProofProtectedRejected = $_.Exception.Message.Contains(
    'oracle-effect proof/protected-root isolation paths overlap:')
}
if (-not $oracleProofProtectedRejected) {
  throw 'Oracle proof output accepted a repository descendant.'
}

$diagnosticBridgePath = Join-Path $root $diagnosticBridges
$commitEProvisionalSeal =
  [string]$oracleSpec.terminal_comparison_runtime.sealed_inventory.status -ceq
      'requires-terminal-reseal' -and
    [long]$oracleSpec.terminal_comparison_runtime.sealed_inventory.file_count -eq
      39L -and
    [long]$oracleSpec.terminal_comparison_runtime.sealed_inventory.total_bytes -eq
      594386L -and
    [string]$oracleSpec.terminal_comparison_runtime.sealed_inventory.inventory_sha256 -ceq
      '9f50c978ffc5f1f2d69d70ca8e5a7205eca39ec8441843cd5fa43b959eaf03c1'
if (-not $commitEProvisionalSeal) {
  throw 'Commit E static verifier accepts only the exact provisional output seal.'
}
$expectedBridgeColumns = @(
  'schema_version', 'bridge_id', 'artifact_name', 'method', 'source',
  'artifact', 'indicator', 'checkpoint', 'stage', 'action', 'output',
  'original_value', 'policy_id', 'level', 'strategy', 'baseline_module',
  'candidate_module', 'candidate_producer_id', 'candidate_write_action',
  'evidence_baseline_run_id', 'evidence_baseline_artifact_sha256',
  'evidence_baseline_request_sha256', 'evidence_baseline_source_sha256',
  'evidence_baseline_commit', 'evidence_baseline_tree',
  'evidence_candidate_run_id', 'evidence_candidate_artifact_sha256',
  'evidence_candidate_request_sha256', 'evidence_candidate_source_sha256',
  'evidence_candidate_commit', 'evidence_candidate_tree',
  'expected_baseline_evidence_rows', 'expected_candidate_evidence_rows',
  'derivation_sha256'
)
$bridgeLines = [IO.File]::ReadAllLines(
  $diagnosticBridgePath, [Text.UTF8Encoding]::new($false, $true))
$observedBridgeColumns = [string[]]@(
  $bridgeLines[0].Split(';') | ForEach-Object { $_.Trim('"') })
$bridgeRows = @(Import-Csv -LiteralPath $diagnosticBridgePath -Delimiter ';')
if ($bridgeLines.Count -ne 1 -or $bridgeRows.Count -ne 0 -or
    [string]::Join("`n", $observedBridgeColumns) -cne
      [string]::Join("`n", $expectedBridgeColumns) -or
    $bridgeLines[0] -cne [string]::Join(';', $expectedBridgeColumns)) {
  throw 'Commit E diagnostic-module bridge CSV is not the exact header-only seed.'
}
$records.Add([ordered]@{
  name = $diagnosticBridges
  sha256 = Get-Issue13V5Sha256 $diagnosticBridgePath
  command_ast_count = 0L
})

$stage5ProfilePath = Join-Path $root $stage5Profiles
$expectedStage5Columns = @(
  'schema_version', 'profile_id', 'scenario_id', 'method', 'mode',
  'at_stage', 'sea_vars_sha256', 'workers', 'request_sha256',
  'candidate_stage5_rows', 'candidate_stage5_sha256',
  'baseline_stage5_rows', 'baseline_stage5_sha256',
  'difference_key_count', 'difference_sha256',
  'evidence_candidate_reference_run_id',
  'evidence_candidate_reference_anomalies_sha256',
  'evidence_candidate_reference_request_sha256',
  'evidence_candidate_reference_commit',
  'evidence_candidate_reference_tree',
  'evidence_candidate_reference_source_sha256',
  'evidence_candidate_reference_run_manifest_sha256',
  'evidence_candidate_reference_run_inventory_sha256',
  'evidence_baseline_reference_run_id',
  'evidence_baseline_reference_anomalies_sha256',
  'evidence_baseline_reference_request_sha256',
  'evidence_baseline_reference_commit',
  'evidence_baseline_reference_tree',
  'evidence_baseline_reference_source_sha256',
  'evidence_baseline_reference_run_manifest_sha256',
  'evidence_baseline_reference_run_inventory_sha256',
  'evidence_baseline_target_run_id',
  'evidence_baseline_target_anomalies_sha256',
  'evidence_baseline_target_request_sha256',
  'evidence_baseline_target_commit', 'evidence_baseline_target_tree',
  'evidence_baseline_target_source_sha256',
  'evidence_baseline_target_run_manifest_sha256',
  'evidence_baseline_target_run_inventory_sha256',
  'evidence_capture_record_sha256', 'reference_stage5_sha256',
  'derivation_sha256'
)
$stage5Lines = [IO.File]::ReadAllLines(
  $stage5ProfilePath, [Text.UTF8Encoding]::new($false, $true))
$observedStage5Columns = [string[]]@(
  $stage5Lines[0].Split(';') | ForEach-Object { $_.Trim('"') })
$stage5Rows = @(Import-Csv -LiteralPath $stage5ProfilePath -Delimiter ';')
if ($stage5Lines.Count -ne 1 -or $stage5Rows.Count -ne 0 -or
    [string]::Join("`n", $observedStage5Columns) -cne
      [string]::Join("`n", $expectedStage5Columns) -or
    $stage5Lines[0] -cne [string]::Join(';', $expectedStage5Columns)) {
  throw 'Commit E stage-five profile CSV is not the exact header-only seed.'
}
$records.Add([ordered]@{
  name = $stage5Profiles
  sha256 = Get-Issue13V5Sha256 $stage5ProfilePath
  command_ast_count = 0L
})
$preparationBuildText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-build-preparation-equivalence.R'),
  [Text.UTF8Encoding]::new($false, $true))
$preparationEquivalenceText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-preparation-equivalence.R'),
  [Text.UTF8Encoding]::new($false, $true))
$preparationEquivalence = Read-Issue13V5Json (
  Join-Path $root 'issue13-v5-preparation-equivalence.json')
if (-not $preparationBuildText.Contains('no field, row, wildcard, tolerance or row-order projection.') -or
    -not $preparationEquivalenceText.Contains('wlv13_v5p_compare_source <- function') -or
    -not $preparationEquivalenceText.Contains('wlv13_v5p_exact_table <- function') -or
    -not $preparationEquivalenceText.Contains(
      'sealed-exhaustive-unit-contract-equivalence') -or
    -not $preparationEquivalenceText.Contains(
      'sealed-exhaustive-source-manifest-equivalence') -or
    -not $preparationEquivalenceText.Contains('wlv13_v5p_selftest <- function') -or
    [string]$preparationEquivalence.schema -cne
      'wlv-issue13-preparation-equivalence/1' -or
    @($preparationEquivalence.sources).Count -ne 2 -or
    @($preparationEquivalence.artifacts).Count -ne 2 -or
    @($preparationEquivalence.profiles).Count -ne 2 -or
    [string]$preparationEquivalence.derivation -cne
      'Exact authenticated normalized-source tables paired by source and arm; no field, row, wildcard, tolerance or row-order projection.' -or
    $preparationEquivalence.PSObject.Properties.Name -ccontains
      'architecture_projection') {
  throw 'V5 exhaustive preparation equivalence sources are incomplete.'
}
foreach ($name in $preparationEquivalenceFiles) {
  $path = Join-Path $root $name
  $records.Add([ordered]@{
    name = $name
    sha256 = if ($bootstrapSourceFileSha256.ContainsKey($name)) {
      [string]$bootstrapSourceFileSha256[$name]
    } else {
      Get-Issue13V5Sha256 $path
    }
    command_ast_count = 0L
  })
}
$materializerText = [string]$bootstrapSourceTexts[
  'issue13-v5-materialize-harness.ps1']
$materializerTokens = @()
$materializerErrors = @()
$materializerAst =
  $bootstrapSourceAsts['issue13-v5-materialize-harness.ps1']
$materializerControllerAssignments = @($materializerAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.AssignmentStatementAst] -and
    (Get-Issue13V5AssignmentBaseVariableName $node.Left) -ieq
      '$controllerFiles'
}, $true))
$materializerControllerFiles = if ($materializerControllerAssignments.Count `
    -eq 1) {
  [string[]]@($materializerControllerAssignments[0].Right.FindAll({
    param($node)
    $node -is [Management.Automation.Language.StringConstantExpressionAst]
  }, $true) | ForEach-Object Value)
} else {
  [string[]]@()
}
if ($materializerErrors.Count -ne 0 -or
    [string]::Join("`n", $materializerControllerFiles) -cne
      [string]::Join("`n", $expectedControllerFiles) -or
    $forbiddenAbsoluteEvidenceSeed -cin $materializerControllerFiles) {
  throw 'V5 materializer does not pin the exact 34 controller files.'
}
foreach ($required in @(
    "'issue13-v5-diagnostic-module-bridges.csv'",
    "'issue13-v5-diagnostics-override.R'",
    "'issue13-v5-stage5-multiplicity-profiles.csv'",
    "'issue13-v5-preparation-equivalence.R'",
    "'issue13-v5-preparation-equivalence.json'",
    'sys.source(file.path(script_dir, "issue13-v5-diagnostics-override.R")',
    'metadata_assertions <- wlv13_v5_metadata_selftest()',
    'identical(metadata_assertions, 626L)',
    'wlv13_v5d_selftest()', 'identical(diagnostic_assertions, 226L)',
    'wlv13_v5p_selftest(file.path(',
    'identical(preparation_assertions, 173L)',
    'source_equivalence <- wlv13_v5p_compare_source(',
    'source_unit_contract_bridge <- wlv13_v5d_compare_source_unit_contract(',
    'source_equivalence$unit_contract$cross_engine_bridge <-',
    'isTRUE(source_unit_contract_bridge$passed)'
  )) {
  if (-not $materializerText.Contains($required)) {
    throw "V5 materializer lacks terminal diagnostic/preparation binding: $required"
  }
}
$oracleSpec = Read-Issue13V5Json (
  Join-Path $root 'issue13-v5-oracle-effect-spec.json')
$oracleSchema = Read-Issue13V5Json (
  Join-Path $root 'issue13-v5-oracle-effect-proof.schema.json')
$oracleValidateText = [string]$bootstrapSourceTexts[
  'issue13-v5-oracle-effect-validate.ps1']
$oracleLibraryText = [string]$bootstrapSourceTexts[
  'issue13-v5-oracle-effect-lib.ps1']
$oracleGenerateText = [string]$bootstrapSourceTexts[
  'issue13-v5-oracle-effect-generate.ps1']
$oracleSchemaSha256 = Get-Issue13V5Sha256 (
  Join-Path $root 'issue13-v5-oracle-effect-proof.schema.json')
$oracleTerminal = $oracleSpec.terminal_comparison_runtime
$expectedOracleCleared = [string[]]@(
  'LANG', 'LC_ALL', 'LC_CTYPE',
  'R_ARCH', 'R_DEFAULT_PACKAGES', 'R_ENVIRON', 'R_ENVIRON_USER', 'R_HOME',
  'R_LIBS', 'R_LIBS_SITE', 'R_PROFILE', 'R_PROFILE_USER', 'R_STARTUP_DEBUG',
  'RENV_CONFIG_AUTOLOADER_ENABLED', 'RENV_PATHS_LIBRARY', 'RENV_PATHS_ROOT'
)
$expectedOraclePackages = [string[]]@('fst', 'jsonlite', 'openssl')
if ([string]$oracleSpec.schema -cne 'wlv-issue13-v5-oracle-effect-spec/2' -or
    [string]$oracleSpec.status -cne
      'requires-terminal-primary-and-replay-comparisons' -or
    -not (Test-Issue13V5ExactBoolean $oracleSpec.final_evidence_eligible $false) -or
    @($oracleSpec.method_partition.strict_common).Count -ne 5 -or
    @($oracleSpec.method_partition.recovered).Count -ne 7 -or
    [long]$oracleSpec.comparison_contract.required_comparison_count -ne 5L -or
    [long]$oracleSpec.comparison_contract.required_execution_count -ne 10L -or
    [long]$oracleSpec.comparison_contract.approved_run_count -ne 17L -or
    [string]::Join("`n", @(
      $oracleSpec.comparison_contract.required_phases)) -cne
      "primary`nreplay" -or
    [string]$oracleSpec.oracle.canonical_patch_sha256 -cne
      $script:Issue13V5BaselineOverlaySha256 -or
    [string]$oracleSpec.oracle.stable_patch_id -cne
      $script:Issue13V5BaselineOverlayPatchId -or
    [string]$oracleTerminal.generation -cne 'v5-terminal' -or
    [string]$oracleTerminal.source_controller_commit_field -cne
      'commit_sha256' -or
    [string]$oracleTerminal.sealed_inventory.status -cne
      'requires-terminal-reseal' -or
    [long]$oracleTerminal.sealed_inventory.file_count -ne 39L -or
    [long]$oracleTerminal.sealed_inventory.total_bytes -ne 594386L -or
    [string]$oracleTerminal.sealed_inventory.inventory_sha256 -cne
      '9f50c978ffc5f1f2d69d70ca8e5a7205eca39ec8441843cd5fa43b959eaf03c1' -or
    [string]::Join("`n", @(
      $oracleTerminal.required_controller_files)) -cne
      [string]::Join("`n", $expectedControllerFiles) -or
    [string]$oracleTerminal.r_library_environment_variable -cne
      'R_LIBS_USER' -or
    [string]$oracleTerminal.r_environment_set.R_LIBS_USER -cne
      'configured-r-library' -or
    [string]$oracleTerminal.r_environment_set.TZ -cne 'UTC' -or
    [string]::Join("`n", @($oracleTerminal.r_environment_cleared)) -cne
      [string]::Join("`n", $expectedOracleCleared) -or
    [string]::Join("`n", @($oracleTerminal.required_r_packages)) -cne
      [string]::Join("`n", $expectedOraclePackages) -or
    [string]$oracleSpec.proof_schema_sha256 -cne $oracleSchemaSha256 -or
    [string]$oracleSchema.properties.schema.const -cne
      'wlv-issue13-v5-oracle-effect-proof/2' -or
    [string]$oracleSchema.properties.status.const -cne 'passed' -or
    -not (Test-Issue13V5ExactBoolean `
      $oracleSchema.properties.passed.const $true) -or
    -not (Test-Issue13V5ExactBoolean `
      $oracleSchema.properties.final_evidence_eligible.const $false) -or
    [string]::Join("`n", @($oracleSchema.required)) -cne
      "schema`nstatus`npassed`nfinal_evidence_eligible`npurpose`ngenerated_at_utc`nevidence`nconclusion" -or
    [string]$oracleSchema.properties.evidence.'$ref' -cne
      '#/$defs/evidence' -or
    [string]$oracleSchema.'$defs'.evidence.properties.terminal_runtime.'$ref' `
      -cne '#/$defs/terminalRuntime' -or
    [string]$oracleSchema.'$defs'.terminalRuntime.properties.
      comparison_harness.'$ref' -cne '#/$defs/harness' -or
    [string]$oracleSchema.'$defs'.terminalRuntime.properties.r_library.'$ref' `
      -cne '#/$defs/rLibrary' -or
    [string]$oracleSchema.'$defs'.terminalRuntime.properties.
      runtime_immutability.'$ref' -cne '#/$defs/runtimeImmutability' -or
    [string]::Join("`n", @(
      $oracleSchema.'$defs'.runtimeImmutability.required)) -cne
      "before`nafter`nimmutable" -or
    [string]::Join("`n", @(
      $oracleSchema.'$defs'.sourceController.required)) -cne
      "commit_sha256`nfile_count`ninventory_sha256`nrecords" -or
    [string]::Join("`n", @(
      $oracleSchema.'$defs'.rEnvironment.required)) -cne "set`ncleared" -or
    [string]::Join("`n", @(
      $oracleSchema.'$defs'.rLibrary.required)) -cne
      "path`nenvironment_variable`nenvironment`nr_version`nplatform`nlib_paths`nrequired_packages`nloaded_packages`ninventory_sha256" -or
    [string]::Join("`n", @(
      $oracleSchema.'$defs'.comparisonWorkflow.required)) -cne
      "primary_root`nreplay_root`ngenerator_created_both_roots`nmethods`ncommands`ncomparisons" -or
    [long]$oracleSchema.'$defs'.comparisonWorkflow.properties.commands.
      minItems -ne 10L -or
    [long]$oracleSchema.'$defs'.comparisonWorkflow.properties.commands.
      maxItems -ne 10L -or
    -not $oracleValidateText.Contains('Get-Issue13OracleEffectEvidence') -or
    -not $oracleValidateText.Contains('Test-Issue13OracleEffectProofObject') -or
    -not $oracleValidateText.Contains(
      'source_controller_inventory_sha256') -or
    -not $oracleValidateText.Contains('r_runtime_inventory_sha256') -or
    -not $oracleLibraryText.Contains('Get-Issue13OracleEffectEvidence') -or
    -not $oracleLibraryText.Contains('Test-Issue13OracleEffectProofObject') -or
    -not $oracleLibraryText.Contains(
      'Test-Issue13OracleEffectExactBoolean') -or
    -not $oracleLibraryText.Contains(
      'ConvertTo-Issue13OracleEffectPhysicalPath') -or
    -not $oracleLibraryText.Contains(
      'Test-Issue13OracleEffectForbiddenDriveTarget') -or
    -not $oracleLibraryText.Contains('VolumeNameGuid') -or
    -not $oracleLibraryText.Contains('QueryDosDevice') -or
    -not $oracleLibraryText.Contains(
      'must not use a SUBST or mapped-drive alias') -or
    -not $oracleLibraryText.Contains("'--vanilla'") -or
    -not $oracleLibraryText.Contains('$commands.Count -eq 10') -or
    -not $oracleLibraryText.Contains('$approved.Count -eq 17') -or
    -not $oracleLibraryText.Contains(
      '$externalInventory.status -ceq ''sealed''') -or
    -not $oracleLibraryText.Contains('source_controller = $expectedController') -or
    -not $oracleLibraryText.Contains('runtime_immutability =') -or
    -not $oracleLibraryText.Contains(
      'function Assert-Issue13OracleEffectProofPathIsolation') -or
    -not $oracleLibraryText.Contains(
      'oracle-effect proof/protected-root isolation') -or
    -not $oracleLibraryText.Contains(
      '[Parameter(Mandatory = $true)][string[]]$ProtectedRoots') -or
    -not $oracleGenerateText.Contains(
      'Assert-Issue13OracleEffectComparisonIsolation') -or
    -not $oracleGenerateText.Contains('$proofProtectedRoots = @(') -or
    -not $oracleGenerateText.Contains(
      'Assert-Issue13OracleEffectProofPathIsolation') -or
    -not $oracleGenerateText.Contains(
      '-ProtectedRoots $proofProtectedRoots') -or
    -not $oracleValidateText.Contains('$proofProtectedRoots = @(') -or
    -not $oracleValidateText.Contains(
      'Assert-Issue13OracleEffectProofPathIsolation') -or
    -not $oracleGenerateText.Contains(
      'terminal harness/Rscript/RLibrary changed during primary/replay execution.')) {
  throw 'Oracle-effect static /2 terminal 5+7 proof contract changed.'
}

$coordinatorText = [string]$bootstrapSourceTexts['issue13-v5-coordinator.ps1']
foreach ($required in @(
    "'ValidateConfig'", "'PrepareWorktrees'", "'RunNext'", "'RunAll'",
    "'Aggregate'", "'Report'", 'Get-Issue13V5WorktreeBindings',
    'issue13-build-calculate-bundle.R', 'issue13-build-recalc-bundle.R',
    'issue13-build-paper-bundle.R', 'issue13-build-prep-fault-specs.R',
    'issue13-aggregate-prep-fault.R', 'issue13-aggregate.R',
    'issue13-v5-render-report.ps1', '162', '202',
    'Planned comparison output already exists:',
    'Planned prep/fault aggregate output already exists.',
    'Planned final aggregate output already exists.',
    'Assert-Issue13V5PhaseEvidenceState',
    'Assert-Issue13V5CompletedEvidenceState',
    'Test-Issue13V5ExactBoolean',
    'pair_result_sha256', 'aggregate_sha256'
  )) {
  if (-not $coordinatorText.Contains($required)) {
    throw "Coordinator lacks required closed-gate binding: $required"
  }
}
function Test-Issue13V5StaticCoordinatorReportLifecycle(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $definitions = @(Get-Issue13V5StaticTopLevelFunctions $Ast `
      'Invoke-Issue13V5Report')
  if ($definitions.Count -ne 1 -or
      $definitions[0].Name -cne 'Invoke-Issue13V5Report') {
    return $false
  }
  $definition = $definitions[0]
  $text = [string]$definition.Extent.Text
  $rendererOffset = $text.IndexOf('Invoke-Issue13V5PwshTransient @(',
    [StringComparison]::Ordinal)
  $postRenderOffset = $text.IndexOf(
    '$currentBinding = Assert-Issue13V5Config ([string]$Binding.path)',
    [StringComparison]::Ordinal)
  $commitRecheckOffset = $text.IndexOf(
    '$commitBinding = Assert-Issue13V5Config ([string]$Binding.path)',
    [StringComparison]::Ordinal)
  $saveOffset = $text.IndexOf(
    'Save-Issue13V5State $commitBinding.config $verifiedState',
    [StringComparison]::Ordinal)
  $commitFlagOffset = $text.IndexOf('$stateCommitted = $true',
    [Math]::Max(0, $saveOffset), [StringComparison]::Ordinal)
  $cleanupOffset = $text.IndexOf(
    '$cleanupFailures = [Collections.Generic.List[Exception]]::new()',
    [StringComparison]::Ordinal)
  $deleteCalls = @($definition.FindAll({
      param($node)
      $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Static -and
        $node.Member.Extent.Text -ceq 'Delete' -and
        $node.Expression.Extent.Text -ceq '[IO.File]'
    }, $true))
  $rendererOffset -ge 0 -and $postRenderOffset -gt $rendererOffset -and
    $commitRecheckOffset -gt $postRenderOffset -and
    $saveOffset -gt $commitRecheckOffset -and
    $commitFlagOffset -gt $saveOffset -and $cleanupOffset -gt $saveOffset -and
    $text.Contains(
      '(Get-Issue13V5Sha256 $statePath) -cne $initialStateSha256') -and
    $text.Contains(
      '$verifiedState = Read-Issue13V5State $currentBinding.config') -and
    $text.Contains(
      'Assert-Issue13V5FinalBindings $currentBinding.config $verifiedState') -and
    $text.Contains("status '--porcelain=v1'") -and
    $text.Contains("'--untracked-files=no'") -and
    $text.Contains(
      '$head -cne [string]$currentBinding.config.candidate_commit') -and
    $text.Contains(
      '(Get-Issue13V5Sha256 $output) -cne') -and
    $text.Contains(
      'if ($null -ne $primary -and -not $stateCommitted -and') -and
    $text.Contains('Refusing to remove a non-canonical failed report output.') -and
    $deleteCalls.Count -eq 1 -and
    $deleteCalls[0].Arguments.Count -eq 1 -and
    $deleteCalls[0].Arguments[0].Extent.Text -ceq '$output' -and
    $text.Contains('Failed report output remains after cleanup.') -and
    $text.Contains('$failures.Add($primary.Exception)') -and
    $text.Contains('Report generation cleanup failed.') -and
    $text.Contains('if ($null -ne $primary) { throw $primary }')
}
$coordinatorAst = $issue13ControllerPowerShellAsts['issue13-v5-coordinator.ps1']
if (-not (Test-Issue13V5StaticCoordinatorReportLifecycle $coordinatorAst)) {
  throw 'Coordinator report lifecycle lacks post-render reauthentication.'
}
$coordinatorReportMutants = @(
  $coordinatorText.Replace(
    'Invoke-Issue13V5PwshTransient @(', '& $renderer @(')
  $coordinatorText.Replace(
    '$currentBinding = Assert-Issue13V5Config ([string]$Binding.path)',
    '$currentBinding = $Binding')
  $coordinatorText.Replace(
    '$commitBinding = Assert-Issue13V5Config ([string]$Binding.path)',
    '$commitBinding = $currentBinding')
  $coordinatorText.Replace(
    'if ($null -ne $primary -and -not $stateCommitted -and',
    'if ($null -ne $primary -and $true -and')
  $coordinatorText.Replace('[IO.File]::Delete($output)', '$null = $output')
  $coordinatorText.Replace("'--untracked-files=no'", "'--untracked-files=all'")
)
foreach ($coordinatorReportMutant in $coordinatorReportMutants) {
  $coordinatorReportMutantTokens = $null
  $coordinatorReportMutantErrors = $null
  $coordinatorReportMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $coordinatorReportMutant,
      [ref]$coordinatorReportMutantTokens,
      [ref]$coordinatorReportMutantErrors)
  if ($coordinatorReportMutant -ceq $coordinatorText -or
      $coordinatorReportMutantErrors.Count -ne 0 -or
      (Test-Issue13V5StaticCoordinatorReportLifecycle `
        $coordinatorReportMutantAst)) {
    throw 'Coordinator report lifecycle accepted a TOCTOU/cleanup mutant.'
  }
}

$newConfigText = [string]$bootstrapSourceTexts['issue13-v5-new-config.ps1']
foreach ($required in @(
    '[Parameter(Mandatory = $true)][string]$OracleEffectSmokeSummary',
    '[Parameter(Mandatory = $true)][string]$ProofPath',
    '[Parameter(Mandatory = $true)][string]$ComparisonRoot',
    '[Parameter(Mandatory = $true)][string]$ReplayRoot',
    'Invoke-Issue13V5OracleEffectValidation',
    'oracle_effect = $oracleEffect', 'required_by_final_gate = $true',
    'final_evidence_eligible = $false',
    "schema = 'wlv-issue13-v5-oracle-effect-binding/2'",
    "schema = 'wlv-issue13-v5-oracle-effect-proof/2'",
    'primary = [ordered]@{', 'replay = [ordered]@{',
    'source_controller = $oracleProof.evidence.terminal_runtime.',
    'r_library = $oracleProof.evidence.terminal_runtime.r_library',
    'Assert-Issue13V5PathsDisjoint $oraclePrimaryRoot $oracleReplayRoot',
    'preparation_equivalence_profile = $preparationEquivalenceBinding',
    'all_rows_fields_and_order_exact = $true',
    'architecture_projection = @()',
    "source_unit_contract_bridge = 'exhaustive-source-unit-contract-bridge'",
    'Test-Issue13V5ExactBoolean'
  )) {
  if (-not $newConfigText.Contains($required)) {
    throw "V5 config generator lacks oracle-effect binding: $required"
  }
}

$reportText = [string]$bootstrapSourceTexts['issue13-v5-render-report.ps1']
foreach ($required in @(
    '$oracle.Count -ne 60',
    'wlv-issue13-complete-recalculation-delta/1',
    'complete_delta_equal', 'baseline_delta_sha256',
    'candidate_delta_sha256',
    'rss_recomputed_from_authenticated_samples',
    '$performance.scenario', 'Sort-Object scenario',
    'baseline_rss_sample_count', 'candidate_rss_sample_count',
    'baseline_samples_sha256', 'candidate_samples_sha256',
    '$expectedPerformanceScenarios', '$expectedOraclePhases',
    'oracle_effect_proof', '$oracleDeltaInventorySha256',
    '$rssEvidenceInventorySha256', '$oracleValidationCommandLine',
    '$oracleSourceController', '$oracleRLibrary',
    '$oracleRuntimeImmutability',
    '$oracleSourceController.file_count -ne 34L',
    "@(`$_.arguments) -cnotcontains '--vanilla'",
    '$oracleRuntimeImmutability.immutable',
    '$config.comparison.preparation_equivalence_profile',
    '$preparationEquivalenceBinding.architecture_projection',
    "'exhaustive-source-unit-contract-bridge'",
    '$unitComparison.cross_engine_bridge',
    'Test-Issue13V5ExactBoolean'
  )) {
  if (-not $reportText.Contains($required)) {
    throw "V5 report lacks fail-closed oracle/RSS evidence: $required"
  }
}
function Test-Issue13V5StaticRendererFinalWrite(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $text = [string]$Ast.Extent.Text
  $writeOffset = $text.IndexOf(
    '[IO.File]::WriteAllText($temporary, $text, $utf8)',
    [StringComparison]::Ordinal)
  $configOffset = $text.IndexOf(
    '$finalBinding = Assert-Issue13V5Config $initialConfigPath',
    [StringComparison]::Ordinal)
  $stateOffset = $text.IndexOf(
    '$finalState = Read-Issue13V5Json $finalStatePath',
    [StringComparison]::Ordinal)
  $bindingOffset = $text.IndexOf(
    'Assert-Issue13V5FinalBindings $finalConfig $finalState',
    [StringComparison]::Ordinal)
  $repositoryOffset = $text.IndexOf(
    '$finalRepository = (Resolve-Path -LiteralPath',
    [StringComparison]::Ordinal)
  $moveOffset = $text.IndexOf(
    '[IO.File]::Move($temporary, $outputPath)',
    [StringComparison]::Ordinal)
  $catchOffset = $text.IndexOf('$writePrimary = $_',
    [StringComparison]::Ordinal)
  $cleanupOffset = $text.IndexOf(
    '$writeCleanupFailures = [Collections.Generic.List[Exception]]::new()',
    [StringComparison]::Ordinal)
  $moveCalls = @($Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Static -and $node.Expression.Extent.Text -ceq '[IO.File]' -and
        $node.Member.Extent.Text -ceq 'Move'
    }, $true))
  $deleteCalls = @($Ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Static -and $node.Expression.Extent.Text -ceq '[IO.File]' -and
        $node.Member.Extent.Text -ceq 'Delete'
    }, $true))
  $writeOffset -ge 0 -and $configOffset -gt $writeOffset -and
    $stateOffset -gt $configOffset -and $bindingOffset -gt $stateOffset -and
    $repositoryOffset -gt $bindingOffset -and $moveOffset -gt $repositoryOffset -and
    $catchOffset -gt $moveOffset -and $cleanupOffset -gt $catchOffset -and
    $text.Contains(
      '[string]$finalBinding.sha256 -cne $initialConfigSha256') -and
    $text.Contains(
      '$finalConfigDiskCanonical -cne $initialConfigCanonical') -and
    $text.Contains('$finalStateSha256 -cne $initialStateSha256') -and
    $text.Contains(
      '$finalStateDiskCanonical -cne $initialStateCanonical') -and
    $text.Contains(
      '(Get-Issue13V5Sha256 $initialConfigPath) -cne') -and
    $text.Contains('(Get-Issue13V5Sha256 $finalStatePath) -cne') -and
    $text.Contains('$finalHeadExitCode = $LASTEXITCODE') -and
    $text.Contains('$finalStatusExitCode = $LASTEXITCODE') -and
    $text.Contains(
      '$finalTrackedStatus = @(Invoke-Issue13V5SealedGit') -and
    $text.Contains('-C $finalRepository status') -and
    $text.Contains("'--porcelain=v1' '--untracked-files=no'") -and
    $text.Contains(
      '$finalHead -cne [string]$finalConfig.candidate_commit') -and
    $text.Contains('Report output appeared before atomic installation:') -and
    $moveCalls.Count -eq 1 -and $moveCalls[0].Arguments.Count -eq 2 -and
    $moveCalls[0].Arguments[0].Extent.Text -ceq '$temporary' -and
    $moveCalls[0].Arguments[1].Extent.Text -ceq '$outputPath' -and
    $deleteCalls.Count -eq 1 -and $deleteCalls[0].Arguments.Count -eq 1 -and
    $deleteCalls[0].Arguments[0].Extent.Text -ceq '$temporary' -and
    $text.Contains('Installed Issue #13 report differs from verified UTF-8 payload.') -and
    $text.Contains('Issue #13 report temporary file survived cleanup.') -and
    $text.Contains('$writeFailures.Add($writePrimary.Exception)') -and
    $text.Contains('Issue #13 report write or temporary cleanup failed.') -and
    $text.Contains('if ($null -ne $writePrimary) { throw $writePrimary }')
}
if (-not (Test-Issue13V5StaticRendererFinalWrite $rendererAst)) {
  throw 'Renderer lacks final config/state/repository TOCTOU reauthentication.'
}
$rendererFinalWriteMutants = @(
  $reportText.Replace(
    '$finalBinding = Assert-Issue13V5Config $initialConfigPath',
    '$finalBinding = $binding')
  $reportText.Replace(
    'Assert-Issue13V5FinalBindings $finalConfig $finalState', '$true')
  $reportText.Replace("'--untracked-files=no'", "'--untracked-files=all'")
  $reportText.Replace(
    '[IO.File]::Move($temporary, $outputPath)',
    '[IO.File]::Move($temporary, $parent)')
  $reportText.Replace('[IO.File]::Delete($temporary)', '$null = $temporary')
  $reportText.Replace(
    '$writeFailures.Add($writePrimary.Exception)', '$null = $writePrimary')
)
foreach ($rendererFinalWriteMutant in $rendererFinalWriteMutants) {
  $rendererFinalWriteMutantTokens = $null
  $rendererFinalWriteMutantErrors = $null
  $rendererFinalWriteMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $rendererFinalWriteMutant,
      [ref]$rendererFinalWriteMutantTokens,
      [ref]$rendererFinalWriteMutantErrors)
  if ($rendererFinalWriteMutant -ceq $reportText -or
      $rendererFinalWriteMutantErrors.Count -ne 0 -or
      (Test-Issue13V5StaticRendererFinalWrite $rendererFinalWriteMutantAst)) {
    throw 'Renderer final-write verifier accepted a TOCTOU/cleanup mutant.'
  }
}

$smokeText = [string]$bootstrapSourceTexts['issue13-v5-baseline-smoke.ps1']
foreach ($required in @(
    "'R.exe'", "'Rscript.exe'", "'Rterm.exe'", "'Rgui.exe'",
    "'Rcmd.exe'", "'Rfe.exe'",
    "throw 'The V5 baseline smoke is Windows-only.'",
    'VolumeNameGuid',
    'DriveTarget',
    'must not use a SUBST or mapped-drive alias',
    'Assert-Issue13V5NoReparseAncestors $SmokeRoot',
    'ConvertTo-Issue13V5BaselineSmokePhysicalPath',
    'Test-Issue13V5BaselineSmokePhysicalOverlap',
    'Assert-Issue13V5BaselineSmokeRscriptSeal',
    'Rscript executable changed after its physical seal.',
    'rscript_physical_path = [string]$rscriptIdentity.physical_path',
    'rscript_item_id = [string]$rscriptIdentity.item_id',
    'rscript_link_count = [uint64]$rscriptIdentity.link_count',
    'rscript_sha256 = $rscriptSha256',
    'physically overlaps the',
    'The created V5 smoke root changed physical identity.',
    '$smokeEnvironment = New-Issue13V5ClosedREnvironment $library',
    '$builderEnvironment = New-Issue13V5ClosedREnvironment $library',
    'Invoke-Issue13V5WithProcessEnvironment',
    'Invoke-Issue13V5WithCleanup',
    'environment_removed = [object[]]$localeEnvironmentNames',
    'Test-Issue13V5ExactBoolean'
  )) {
  if (-not $smokeText.Contains($required)) {
    throw "Baseline smoke lacks required R-process guard: $required"
  }
}
function Test-Issue13V5StaticLiveBaselineSmoke([string]$Text) {
  $Text.Contains(
      "[ValidateSet('compatibility-oracle-executability-preflight')]") -and
    $Text.Contains(
      "[string]`$Purpose = 'compatibility-oracle-executability-preflight'") -and
    $Text.Contains(
      "`$compatibilityRuntimeCommit =`n  'e2f4d6dae9a6d35c966b305fabac52e489faa3e7'") -and
    $Text.Contains(
      "`$Purpose -cne 'compatibility-oracle-executability-preflight'") -and
    $Text.Contains(
      '$baselineCommit -cne $compatibilityRuntimeCommit') -and
    $Text.Contains(
      'The live baseline smoke accepts only the sealed compatibility oracle.') -and
    $Text.Contains('$parentCommit -cne $baselineBaseCommit') -and
    $Text.Contains(
      "`$runtimeTree -cne '7da19c4f2913e857040ba228280f404b0e54eaab'") -and
    $Text.Contains(
      '$smokeEnvironment = New-Issue13V5ClosedREnvironment $library') -and
    $Text.Contains(
      '$builderEnvironment = New-Issue13V5ClosedREnvironment $library') -and
    -not $Text.Contains('strict-cc2-executability-preflight')
}
if (-not (Test-Issue13V5StaticLiveBaselineSmoke $smokeText)) {
  throw 'Live baseline smoke is not restricted to the sealed compatibility oracle.'
}
$liveSmokeMutants = @(
  $smokeText.Replace(
    "[ValidateSet('compatibility-oracle-executability-preflight')]",
    "[ValidateSet('strict-cc2-executability-preflight', 'compatibility-oracle-executability-preflight')]")
  $smokeText.Replace(
    'e2f4d6dae9a6d35c966b305fabac52e489faa3e7',
    'cc2c86189a06676bcb9f0e05e08033d710a92509')
  $smokeText.Replace(
    '$baselineCommit -cne $compatibilityRuntimeCommit',
    '$baselineCommit -cne $baselineBaseCommit')
  $smokeText.Replace(
    '$parentCommit -cne $baselineBaseCommit', '$false')
  $smokeText.Replace(
    '$smokeEnvironment = New-Issue13V5ClosedREnvironment $library',
    '$smokeEnvironment = [ordered]@{ R_LIBS_USER = $library; TZ = ''UTC'' }')
)
foreach ($liveSmokeMutant in $liveSmokeMutants) {
  if ($liveSmokeMutant -ceq $smokeText -or
      (Test-Issue13V5StaticLiveBaselineSmoke $liveSmokeMutant)) {
    throw 'Live baseline smoke predicate accepted a purpose/runtime/TZ mutant.'
  }
}
$smokeTokens = @()
$smokeErrors = @()
$smokeAst = $bootstrapSourceAsts['issue13-v5-baseline-smoke.ps1']
function Test-Issue13V5BaselineSmokeRscriptPhysicalAst(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $sealDefinitions = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
        'Assert-Issue13V5BaselineSmokeRscriptSeal'
  }, $true))
  if ($sealDefinitions.Count -ne 1 -or
      $sealDefinitions[0].Name -cne
        'Assert-Issue13V5BaselineSmokeRscriptSeal') {
    return $false
  }
  $sealDefinition = $sealDefinitions[0]
  $inputWrites = @(Get-Issue13V5VariableWriteAsts $Ast '$Rscript')
  $pathWrites = @(Get-Issue13V5VariableWriteAsts `
    $sealDefinition '$Path')
  $expectedIdentityWrites = @(Get-Issue13V5VariableWriteAsts `
    $sealDefinition '$ExpectedIdentity')
  $expectedShaWrites = @(Get-Issue13V5VariableWriteAsts `
    $sealDefinition '$ExpectedSha256')
  $bindingWrites = @(Get-Issue13V5VariableWriteAsts `
    $Ast '$rscriptBinding')
  $fullWrites = @(Get-Issue13V5VariableWriteAsts $Ast '$rscriptFull')
  $identityWrites = @(Get-Issue13V5VariableWriteAsts `
    $Ast '$rscriptIdentity')
  $shaWrites = @(Get-Issue13V5VariableWriteAsts $Ast '$rscriptSha256')
  $protectedWrites = @(Get-Issue13V5VariableWriteAsts `
    $Ast '$protectedPhysicalPaths')
  $noReparseCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5NoReparseAncestors' -and
      [string]::Join('|', @($node.CommandElements | ForEach-Object {
        $_.Extent.Text
      })) -ceq
        "Assert-Issue13V5NoReparseAncestors|`$Rscript|'Rscript executable'"
  }, $true))
  $physicalCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'ConvertTo-Issue13V5BaselineSmokePhysicalPath' -and
      [string]::Join('|', @($node.CommandElements | ForEach-Object {
        $_.Extent.Text
      })) -ceq
        "ConvertTo-Issue13V5BaselineSmokePhysicalPath|`$rscriptFull|" +
          "'Rscript executable'"
  }, $true))
  $sealCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5BaselineSmokeRscriptSeal'
  }, $true))
  $rscriptInvocations = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Invoke-Issue13V5RscriptBounded'
  }, $true))
  $monitorInvocations = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Invoke-Issue13V5PwshTransient'
  }, $true))
  $sealChains = @($sealCalls | ForEach-Object {
    Get-Issue13V5AstAncestorChain $_ $Ast
  })
  $expectedSealChains = @(
    ('CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>' +
      'ScriptBlockAst>ScriptBlockExpressionAst>ArrayLiteralAst>' +
      'CommandExpressionAst>PipelineAst>StatementBlockAst>' +
      'ArrayExpressionAst>CommandExpressionAst>AssignmentStatementAst>' +
      'NamedBlockAst'),
    ('CommandAst>PipelineAst>AssignmentStatementAst>StatementBlockAst>' +
      'TryStatementAst>StatementBlockAst>ForEachStatementAst>NamedBlockAst>' +
      'ScriptBlockAst>ScriptBlockExpressionAst>CommandExpressionAst>' +
      'AssignmentStatementAst>NamedBlockAst'),
    ('CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>' +
      'ScriptBlockAst>ScriptBlockExpressionAst>' +
      'CommandExpressionAst>' +
      'PipelineAst>StatementBlockAst>ArrayExpressionAst>CommandAst>' +
      'PipelineAst>AssignmentStatementAst>StatementBlockAst>TryStatementAst>' +
      'StatementBlockAst>ForEachStatementAst>NamedBlockAst>ScriptBlockAst>' +
      'ScriptBlockExpressionAst>CommandExpressionAst>AssignmentStatementAst>' +
      'NamedBlockAst'),
    ('CommandAst>PipelineAst>AssignmentStatementAst>StatementBlockAst>' +
      'TryStatementAst>StatementBlockAst>ForEachStatementAst>NamedBlockAst>' +
      'ScriptBlockAst>ScriptBlockExpressionAst>CommandExpressionAst>' +
      'AssignmentStatementAst>NamedBlockAst'),
    ('CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>' +
      'ScriptBlockAst>ScriptBlockExpressionAst>CommandExpressionAst>' +
      'PipelineAst>StatementBlockAst>ArrayExpressionAst>CommandAst>' +
      'PipelineAst>AssignmentStatementAst>StatementBlockAst>TryStatementAst>' +
      'StatementBlockAst>ForEachStatementAst>NamedBlockAst>ScriptBlockAst>' +
      'ScriptBlockExpressionAst>CommandExpressionAst>AssignmentStatementAst>' +
      'NamedBlockAst'),
    'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst'
  )
  if ($inputWrites.Count -ne 0 -or $pathWrites.Count -ne 0 -or
      $expectedIdentityWrites.Count -ne 0 -or $expectedShaWrites.Count -ne 0 -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$rscriptBinding' 'AssignmentStatementAst>NamedBlockAst' `
        'Get-Issue13V5RscriptExecutableBinding $Rscript') -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$rscriptFull' 'AssignmentStatementAst>NamedBlockAst' `
        '[string]$rscriptBinding.logical_path') -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$rscriptIdentity' 'AssignmentStatementAst>NamedBlockAst') -or
      [regex]::Replace($identityWrites[0].Right.Extent.Text, '[\s`]', '') -cne
        ('[pscustomobject][ordered]@{' +
          'physical_path=[string]$rscriptBinding.physical_path' +
          'item_id=[string]$rscriptBinding.item_id' +
          'link_count=[uint64]$rscriptBinding.link_count}') -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$rscriptSha256' 'AssignmentStatementAst>NamedBlockAst' `
        '[string]$rscriptBinding.sha256') -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$protectedPhysicalPaths' 'AssignmentStatementAst>NamedBlockAst') -or
      $noReparseCalls.Count -ne 1 -or $physicalCalls.Count -ne 1 -or
      $sealCalls.Count -ne 6 -or $rscriptInvocations.Count -ne 1 -or
      $monitorInvocations.Count -ne 1 -or
      [string]::Join("`n", $sealChains) -cne
        [string]::Join("`n", $expectedSealChains) -or
      (Get-Issue13V5AstAncestorChain $rscriptInvocations[0] $Ast) -cne
        ('CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>' +
          'ScriptBlockAst>ScriptBlockExpressionAst>CommandAst>PipelineAst>' +
          'AssignmentStatementAst>StatementBlockAst>TryStatementAst>' +
          'StatementBlockAst>ForEachStatementAst>NamedBlockAst>' +
          'ScriptBlockAst>ScriptBlockExpressionAst>CommandExpressionAst>' +
          'AssignmentStatementAst>NamedBlockAst') -or
      (Get-Issue13V5AstAncestorChain $monitorInvocations[0] $Ast) -cne
        ('CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>' +
          'ScriptBlockAst>ScriptBlockExpressionAst>CommandAst>PipelineAst>' +
          'AssignmentStatementAst>StatementBlockAst>TryStatementAst>' +
          'StatementBlockAst>ForEachStatementAst>NamedBlockAst>' +
          'ScriptBlockAst>ScriptBlockExpressionAst>CommandExpressionAst>' +
          'AssignmentStatementAst>NamedBlockAst') -or
      [regex]::Replace(
        $rscriptInvocations[0].Extent.Text, '[\s`]', '') -cne
        ('Invoke-Issue13V5RscriptBounded' +
          '-RscriptPath$rscriptFull' +
          '-Arguments$builderArguments' +
          '-Label"Baselinesmokebuilderfor$method"' +
          '-TimeoutSeconds600' +
          '-ExpectedExitCodes$null' +
          '-WorkingDirectory$project' +
          '-Environment$builderEnvironment') -or
      [regex]::Replace(
        [string]::Join('|', @($monitorInvocations[0].CommandElements |
            ForEach-Object { $_.Extent.Text })), '[\s`]', '') -cne
        ("Invoke-Issue13V5PwshTransient|@(" +
          "'-NoLogo','-NoProfile','-NonInteractive','-File',`$monitor," +
          "'-SpecPath',[string]`$bundle.process_spec," +
          "'-EvidenceDir',[string]`$bundle.scenario_evidence)|" +
          '("baseline-smoke-monitor/$method")|18000|@(0)|' +
          '$repository|$null|$rscriptFull') -or
      @($sealCalls | Where-Object {
        [string]::Join('|', @($_.CommandElements | ForEach-Object {
          $_.Extent.Text
        })) -cne
          'Assert-Issue13V5BaselineSmokeRscriptSeal|$rscriptFull|' +
            '$rscriptIdentity|$rscriptSha256'
      }).Count -ne 0) {
    return $false
  }
  $physicalOwner = $physicalCalls[0].Parent
  while ($null -ne $physicalOwner -and $physicalOwner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
    $physicalOwner = $physicalOwner.Parent
  }
  if (-not [object]::ReferenceEquals($physicalOwner, $protectedWrites[0]) -or
      $noReparseCalls[0].Extent.EndOffset -ge
        $bindingWrites[0].Extent.StartOffset -or
      $bindingWrites[0].Extent.EndOffset -ge
        $fullWrites[0].Extent.StartOffset -or
      $fullWrites[0].Extent.EndOffset -ge
        $identityWrites[0].Extent.StartOffset -or
      $identityWrites[0].Extent.EndOffset -ge
        $physicalCalls[0].Extent.StartOffset -or
      $physicalCalls[0].Extent.EndOffset -ge
        $sealCalls[0].Extent.StartOffset -or
      $sealCalls[0].Extent.EndOffset -ge
        $sealCalls[1].Extent.StartOffset -or
      $sealCalls[1].Extent.EndOffset -ge
        $rscriptInvocations[0].Extent.StartOffset -or
      $rscriptInvocations[0].Extent.EndOffset -ge
        $sealCalls[2].Extent.StartOffset -or
      $sealCalls[2].Extent.EndOffset -ge
        $sealCalls[3].Extent.StartOffset -or
      $sealCalls[3].Extent.EndOffset -ge
        $monitorInvocations[0].Extent.StartOffset -or
      $monitorInvocations[0].Extent.EndOffset -ge
        $sealCalls[4].Extent.StartOffset -or
      $sealCalls[4].Extent.EndOffset -ge
        $sealCalls[5].Extent.StartOffset) {
    return $false
  }
  $true
}
if ($smokeErrors.Count -ne 0 -or
    -not (Test-Issue13V5BaselineSmokeRscriptPhysicalAst $smokeAst)) {
  throw 'Baseline smoke Rscript is not physically sealed end-to-end.'
}
$smokeText = $smokeAst.Extent.Text
$smokeSealCalls = @($smokeAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5BaselineSmokeRscriptSeal'
}, $true))
$smokePhysicalCalls = @($smokeAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'ConvertTo-Issue13V5BaselineSmokePhysicalPath' -and
    [string]::Join('|', @($node.CommandElements | ForEach-Object {
      $_.Extent.Text
    })) -ceq
      "ConvertTo-Issue13V5BaselineSmokePhysicalPath|`$rscriptFull|" +
        "'Rscript executable'"
}, $true))
$smokeRscriptInvocations = @($smokeAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Invoke-Issue13V5RscriptBounded'
}, $true))
$smokeMonitorInvocations = @($smokeAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Invoke-Issue13V5PwshTransient'
}, $true))
$smokeBindingWrites = @(Get-Issue13V5VariableWriteAsts `
  $smokeAst '$rscriptBinding')
$smokeFullWrites = @(Get-Issue13V5VariableWriteAsts `
  $smokeAst '$rscriptFull')
$smokeIdentityWrites = @(Get-Issue13V5VariableWriteAsts `
  $smokeAst '$rscriptIdentity')
$smokeShaWrites = @(Get-Issue13V5VariableWriteAsts `
  $smokeAst '$rscriptSha256')
if ($smokeSealCalls.Count -ne 6 -or $smokePhysicalCalls.Count -ne 1 -or
    $smokeRscriptInvocations.Count -ne 1 -or
    $smokeMonitorInvocations.Count -ne 1 -or
    $smokeBindingWrites.Count -ne 1 -or
    $smokeFullWrites.Count -ne 1 -or
    $smokeIdentityWrites.Count -ne 1 -or $smokeShaWrites.Count -ne 1) {
  throw 'Cannot construct the baseline Rscript negative self-tests.'
}
$deadSeal = $smokeSealCalls[1]
$physicalCall = $smokePhysicalCalls[0]
$rscriptCall = $smokeRscriptInvocations[0]
$monitorCall = $smokeMonitorInvocations[0]
$smokeRscriptMutants = @(
  $smokeText.Remove(
    $deadSeal.Extent.StartOffset,
    $deadSeal.Extent.EndOffset - $deadSeal.Extent.StartOffset).Insert(
      $deadSeal.Extent.StartOffset,
      'if ($false) { ' + $deadSeal.Extent.Text + ' }'),
  $smokeText.Remove(
    $physicalCall.Extent.StartOffset,
    $physicalCall.Extent.EndOffset - $physicalCall.Extent.StartOffset).Insert(
      $physicalCall.Extent.StartOffset,
      $physicalCall.Extent.Text.Replace('$rscriptFull', '$library')),
  $smokeText.Remove(
    $rscriptCall.Extent.StartOffset,
    $rscriptCall.Extent.EndOffset - $rscriptCall.Extent.StartOffset).
      Insert($rscriptCall.Extent.StartOffset,
        '& $rscriptFull @builderArguments'),
  $smokeText.Remove(
    $rscriptCall.Extent.StartOffset,
    $rscriptCall.Extent.EndOffset - $rscriptCall.Extent.StartOffset).
      Insert($rscriptCall.Extent.StartOffset,
        $rscriptCall.Extent.Text.Replace(
          '-TimeoutSeconds 600', '-TimeoutSeconds 0')),
  $smokeText.Remove(
    $rscriptCall.Extent.StartOffset,
    $rscriptCall.Extent.EndOffset - $rscriptCall.Extent.StartOffset).
      Insert($rscriptCall.Extent.StartOffset,
        $rscriptCall.Extent.Text.Replace(
          '-WorkingDirectory $project', '-WorkingDirectory $null')),
  $smokeText.Remove(
    $rscriptCall.Extent.StartOffset,
    $rscriptCall.Extent.EndOffset - $rscriptCall.Extent.StartOffset).
      Insert($rscriptCall.Extent.StartOffset,
        $rscriptCall.Extent.Text.Replace(
          '-Environment $builderEnvironment', '-Environment $null')),
  $smokeText.Remove(
    $monitorCall.Extent.StartOffset,
    $monitorCall.Extent.EndOffset - $monitorCall.Extent.StartOffset).Insert(
      $monitorCall.Extent.StartOffset,
      $monitorCall.Extent.Text.Replace(' 18000 @(0) ', ' 0 @(0) ')),
  $smokeText.Remove(
    $monitorCall.Extent.StartOffset,
    $monitorCall.Extent.EndOffset - $monitorCall.Extent.StartOffset).Insert(
      $monitorCall.Extent.StartOffset,
      $monitorCall.Extent.Text.Replace(
        '$rscriptFull', '$null')),
  $smokeText.Insert(
    $smokeBindingWrites[0].Extent.EndOffset,
    "`n`$rscriptBinding = [pscustomobject]`$rscriptBinding"),
  $smokeText.Insert(
    $smokeFullWrites[0].Extent.EndOffset,
    "`n`$rscriptFull = [string]`$rscriptFull"),
  $smokeText.Insert(
    $smokeIdentityWrites[0].Extent.EndOffset,
    "`n`$rscriptIdentity = [pscustomobject]`$rscriptIdentity"),
  $smokeText.Insert(
    $smokeShaWrites[0].Extent.EndOffset,
    "`n`$rscriptSha256 = `$rscriptSha256.ToLowerInvariant()")
)
$smokeRscriptMutantIndex = 0
foreach ($smokeRscriptMutantText in $smokeRscriptMutants) {
  $smokeRscriptMutantIndex++
  $smokeRscriptMutantTokens = $null
  $smokeRscriptMutantErrors = $null
  $smokeRscriptMutantAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $smokeRscriptMutantText, [ref]$smokeRscriptMutantTokens,
      [ref]$smokeRscriptMutantErrors)
  if ($smokeRscriptMutantErrors.Count -ne 0 -or
      (Test-Issue13V5BaselineSmokeRscriptPhysicalAst `
        $smokeRscriptMutantAst)) {
    throw ('Baseline Rscript seal accepted dataflow/placement mutant ' +
      $smokeRscriptMutantIndex + '.')
  }
}

$libraryText = [string]$bootstrapSourceTexts['issue13-v5-coordinator-lib.ps1']
foreach ($required in @(
    "'R.exe'", "'Rscript.exe'", "'Rterm.exe'", "'Rgui.exe'",
    "'Rcmd.exe'", "'Rfe.exe'", 'Assert-Issue13V5ReportBinding',
    'Worktree/evidence/control isolation', '$Process.Kill($true)',
    'New-Issue13V5ClosedREnvironment',
    '$ProcessStartInfo.Environment.Remove($name)',
    'Enter-Issue13V5GitExecutableLease',
    'Get-Issue13V5GitExecutableBinding',
    'Assert-Issue13V5GitExecutableBinding',
    'Exit-Issue13V5GitExecutableLease',
    'Enter-Issue13V5PwshExecutableLease',
    'Get-Issue13V5PwshExecutableBinding',
    'Assert-Issue13V5PwshExecutableBinding',
    'Exit-Issue13V5PwshExecutableLease',
    'Enter-Issue13V5RscriptExecutableLease',
    'Get-Issue13V5RscriptExecutableBinding',
    'Assert-Issue13V5RscriptExecutableBinding',
    'Exit-Issue13V5RscriptExecutableLease',
    'Invoke-Issue13V5SealedGit',
    'Invoke-Issue13V5GitRaw',
    'Invoke-Issue13V5GitExternal',
    '$script:Issue13V5GitLogicalPath',
    '$script:Issue13V5GitPhysicalPath',
    '$script:Issue13V5GitItemId',
    '$script:Issue13V5GitLinkCount',
    '$script:Issue13V5GitSizeBytes',
    '$script:Issue13V5GitSha256',
    '$script:Issue13V5PwshLogicalPath',
    '$script:Issue13V5RscriptLogicalPath',
    '[IO.FileShare]::Read',
    '$start.ArgumentList.Add($argument)',
    '$start.FileName = [string]$binding.logical_path',
    'ISSUE13_V5_GIT_EXECUTABLE',
    'ISSUE13_V5_RSCRIPT_EXECUTABLE',
    'The sealed V5 Git invocation failed its lifecycle recheck.',
    'Sealed Git lifecycle cleanup failed.',
    'Bounded Rscript lifecycle cleanup failed: $Label',
    'Bounded Rscript exceeded its $TimeoutSeconds-second timeout: $Label',
    'environment_set = [object[]]$environmentBinding.environment_set',
    'environment_cleared = [object[]]$environmentBinding.environment_cleared',
    'Environment variable is duplicated case-insensitively',
    'Get-Issue13V5ConfiguredPaths', 'Test-Issue13V5LegacyPath',
    'Get-Issue13V5SourceBinding', 'Get-Issue13V5SourceContractSha256',
    'Assert-Issue13V5SourceContractBindings', 'candidate_source_origin',
    'wlv-issue13-native-gate-config/3',
    'Invoke-Issue13V5OracleEffectValidation',
    'Assert-Issue13V5OracleEffectControlRecord',
    '''-OracleSmokeSummary'', [string]$oracle.oracle_smoke.path',
    '''-ComparisonHarnessManifest'',',
    '[string]$Config.harness_manifest_path',
    '$Config.oracle_effect.comparisons.primary.root',
    '$Config.oracle_effect.comparisons.replay.root',
    '$Config.oracle_effect.comparison_harness.manifest_path',
    '$Config.comparison.preparation_equivalence_profile.path',
    "'wlv-issue13-v5-oracle-effect-binding/2'",
    "'wlv-issue13-v5-oracle-effect-proof/2'",
    "'source_controller_inventory_sha256'", "'r_runtime_inventory_sha256'",
    "'comparison_harness', 'rscript', 'r_library', 'runtime_immutability'",
    'Assert-Issue13V5ScenarioStateHashes',
    'Scenario samples are not anchored by the state-bound metrics',
    'Assert-Issue13V5CompletedEvidenceState',
    'Test-Issue13V5ExactBoolean',
    'ConvertTo-Issue13V5PhysicalPath', 'CoordinatorNativePath',
    'VolumeNameGuid', 'QueryDosDevice',
    'Test-Issue13V5ForbiddenDriveTarget',
    'must not use a SUBST or mapped-drive alias'
  )) {
  if (-not $libraryText.Contains($required)) {
    throw "Coordinator library lacks required safety guard: $required"
  }
}

$booleanGuardFiles = @($script:Issue13V5ControllerFiles | Where-Object {
  [IO.Path]::GetExtension([string]$_) -ceq '.ps1'
})
$booleanConversions = [Collections.Generic.List[string]]::new()
foreach ($name in $booleanGuardFiles) {
  $tokens = @()
  $errors = @()
  $ast = $bootstrapSourceAsts[$name]
  if ($errors.Count -ne 0) {
    throw "PowerShell parser rejected boolean-guard source $name`: $($errors[0].Message)"
  }
  foreach ($conversion in @($ast.FindAll({
      param($node)
      $node -is [Management.Automation.Language.ConvertExpressionAst] -and
        (Test-Issue13V5TypeConstraint $node.Type 'System.Boolean')
    }, $true))) {
    $booleanConversions.Add("$name|$($conversion.Extent.Text)")
  }
}
$expectedBooleanConversions = @(
  'issue13-v5-coordinator-lib.ps1|[bool]$_.present',
  'issue13-v5-coordinator-lib.ps1|[bool]$Expected',
  'issue13-v5-coordinator-lib.ps1|[bool]$mutation.present',
  'issue13-v5-coordinator-lib.ps1|[bool]$observed[0].present',
  'issue13-v5-coordinator-lib.ps1|[bool]$observed[1].present',
  'issue13-v5-coordinator-lib.ps1|[bool]$observed[2].present',
  'issue13-v5-coordinator-lib.ps1|[bool]$present',
  'issue13-v5-coordinator-lib.ps1|[bool]$restored[0].present',
  'issue13-v5-coordinator-lib.ps1|[bool]$restored[1].present',
  'issue13-v5-coordinator-lib.ps1|[bool]$restored[2].present',
  'issue13-v5-coordinator-lib.ps1|[bool]$restoredAfterFailure[0].present',
  'issue13-v5-coordinator-lib.ps1|[bool]$restoredAfterFailure[1].present',
  'issue13-v5-coordinator-lib.ps1|[bool]$restoredAfterFailure[2].present',
  'issue13-v5-coordinator-lib.ps1|[bool]$state.present',
  'issue13-v5-coordinator-lib.ps1|[bool]$state.present',
  'issue13-v5-coordinator-lib.ps1|[bool]$state.present',
  'issue13-v5-coordinator-lib.ps1|[bool]$timedOut',
  'issue13-v5-coordinator-lib.ps1|[bool]$Value',
  'issue13-v5-oracle-effect-lib.ps1|[bool]$_.present',
  'issue13-v5-oracle-effect-lib.ps1|[bool]$Expected',
  'issue13-v5-oracle-effect-lib.ps1|[bool]$Value',
  ('issue13-v5-static-verify.ps1|[bool](' + "`n" +
    '      $issue13AliasCollisionPreflightResult.' +
    'set_strict_mode_protected)'),
  'issue13-v5-static-verify.ps1|[bool]$issue13AliasCollisionPreflightResult.resolve_path_protected',
  'issue13-v5-static-verify.ps1|[bool]$names.Contains(''Resolve-Path'')',
  'issue13-v5-static-verify.ps1|[bool]$names.Contains(''Set-StrictMode'')'
)
if ([string]::Join("`n", @($booleanConversions.ToArray() | Sort-Object)) -cne
    [string]::Join("`n", $expectedBooleanConversions)) {
  throw 'External boolean validation acquired an unapproved Boolean conversion.'
}
$booleanMutantTokens = $null
$booleanMutantErrors = $null
$booleanMutantAst = [Management.Automation.Language.Parser]::ParseInput(
  '[System.Boolean]$externalValue', [ref]$booleanMutantTokens,
  [ref]$booleanMutantErrors)
$booleanMutantConversions = @($booleanMutantAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.ConvertExpressionAst] -and
    (Test-Issue13V5TypeConstraint $node.Type 'System.Boolean')
}, $true))
if ($booleanMutantErrors.Count -ne 0 -or
    $booleanMutantConversions.Count -ne 1) {
  throw 'Boolean identity guard missed a System.Boolean conversion.'
}

$exactBooleanCases = @(
  [pscustomobject]@{
    value = $true; expected = $true; accepted = $true
  },
  [pscustomobject]@{
    value = $false; expected = $false; accepted = $true
  },
  [pscustomobject]@{
    value = 'true'; expected = $true; accepted = $false
  },
  [pscustomobject]@{
    value = 'false'; expected = $false; accepted = $false
  },
  [pscustomobject]@{
    value = 1; expected = $true; accepted = $false
  },
  [pscustomobject]@{
    value = $null; expected = $false; accepted = $false
  },
  [pscustomobject]@{
    value = $true; expected = 'true'; accepted = $false
  }
)
foreach ($case in $exactBooleanCases) {
  $coordinatorAccepted = Test-Issue13V5ExactBoolean `
    $case.value $case.expected
  $oracleAccepted = Test-Issue13OracleEffectExactBoolean `
    $case.value $case.expected
  if ($coordinatorAccepted -isnot [bool] -or
      $oracleAccepted -isnot [bool] -or
      $coordinatorAccepted -cne $case.accepted -or
      $oracleAccepted -cne $case.accepted) {
    throw 'Exact-Boolean negative self-test failed.'
  }
}

$driveTargetCases = @(
  [pscustomobject]@{ target = '\??\D:\alias'; forbidden = $true },
  [pscustomobject]@{
    target = '\Device\Mup\server\share'; forbidden = $true
  },
  [pscustomobject]@{
    target = '\Device\LanmanRedirector\server\share'; forbidden = $true
  },
  [pscustomobject]@{
    target = '\Device\WebDavRedirector\server\share'; forbidden = $true
  },
  [pscustomobject]@{
    target = '\Device\HarddiskVolume3'; forbidden = $false
  }
)
foreach ($case in $driveTargetCases) {
  $coordinatorForbidden = Test-Issue13V5ForbiddenDriveTarget $case.target
  $oracleForbidden = Test-Issue13OracleEffectForbiddenDriveTarget $case.target
  if ($coordinatorForbidden -isnot [bool] -or
      $oracleForbidden -isnot [bool] -or
      $coordinatorForbidden -cne $case.forbidden -or
      $oracleForbidden -cne $case.forbidden) {
    throw "Drive-target negative self-test failed: $($case.target)"
  }
}

$physicalRepository = ConvertTo-Issue13V5PhysicalPath `
  $RepositoryRoot 'static repository root'
$oraclePhysicalRepository = ConvertTo-Issue13OracleEffectPhysicalPath `
  $RepositoryRoot 'static repository root'
$missingRepositoryDescendant = Join-Path $RepositoryRoot `
  'static-missing-descendant\child'
if (-not (Test-Issue13V5PathContained `
      $missingRepositoryDescendant $RepositoryRoot) -or
    -not (Test-Issue13OracleEffectPathContained `
      $missingRepositoryDescendant $RepositoryRoot)) {
  throw 'Physical containment rejected a missing descendant.'
}
$configPathIsolationRejected = $false
try {
  $null = Assert-Issue13V5ConfigPathIsolation `
    $missingRepositoryDescendant @($RepositoryRoot)
} catch {
  $configPathIsolationRejected = $_.Exception.Message.Contains(
    'V5 config/immutable-root isolation paths overlap:')
}
if (-not $configPathIsolationRejected) {
  throw 'Config-path isolation accepted a repository descendant.'
}
if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
  if ($physicalRepository -cnotmatch
        '^\\\\\?\\Volume\{[0-9A-Fa-f-]+\}\\' -or
      $oraclePhysicalRepository -cnotmatch
        '^\\\\\?\\Volume\{[0-9A-Fa-f-]+\}\\') {
    throw 'Physical canonicalization did not return volume-GUID identity.'
  }
  $systemDirectory = [Environment]::SystemDirectory
  Assert-Issue13V5PathsDisjoint $RepositoryRoot $systemDirectory `
    'Static repository/system-directory isolation'
  Assert-Issue13OracleEffectPathsDisjoint $RepositoryRoot $systemDirectory `
    'Static repository/system-directory isolation'
  foreach ($converter in @('coordinator', 'oracle')) {
    $uncRejected = $false
    try {
      if ($converter -ceq 'coordinator') {
        $null = ConvertTo-Issue13V5PhysicalPath `
          '\\server\share\issue13' 'static UNC path'
      } else {
        $null = ConvertTo-Issue13OracleEffectPhysicalPath `
          '\\server\share\issue13' 'static UNC path'
      }
    } catch {
      $uncRejected = $_.Exception.Message.Contains(
        'must use a local drive-letter path')
    }
    if (-not $uncRejected) {
      throw "Physical $converter canonicalization accepted a UNC path."
    }
  }
}

$tokens = @()
$errors = @()
$libraryAst = $bootstrapSourceAsts['issue13-v5-coordinator-lib.ps1']
function Test-Issue13V5FrozenCommandDataflow(
  [Management.Automation.Language.Ast]$RootAst,
  [string]$CommandName,
  [string[]]$ExpectedArguments,
  [string]$ExpectedChain
) {
  $calls = @($RootAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        $CommandName
  }, $true))
  if ($calls.Count -ne 1 -or
      [string]::Join("`n", @($calls[0].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
        [string]::Join("`n", $ExpectedArguments) -or
      (Get-Issue13V5AstAncestorChain $calls[0] $RootAst) -cne
        $ExpectedChain) {
    return $false
  }
  $true
}
$configDefinitions = @($libraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5Config'
}, $true))
$configPathIsolationDefinitions = @($libraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5ConfigPathIsolation'
}, $true))
$oracleIsolationDefinitions = @($libraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5OracleComparisonIsolation'
}, $true))
if ($errors.Count -ne 0 -or $configDefinitions.Count -ne 1 -or
    $configPathIsolationDefinitions.Count -ne 1 -or
    $oracleIsolationDefinitions.Count -ne 1) {
  throw 'Coordinator root-isolation AST is missing or ambiguous.'
}
$configDisjointCalls = @($configDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5PathsDisjoint'
}, $true))
$configPhysicalCalls = @($configDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'ConvertTo-Issue13V5PhysicalPath'
}, $true))
$configPathIsolationCalls = @($configDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5ConfigPathIsolation'
}, $true))
$configPathIsolationDisjointCalls =
  @($configPathIsolationDefinitions[0].FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5PathsDisjoint'
  }, $true))
$oracleIsolationDisjointCalls = @($oracleIsolationDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5PathsDisjoint'
}, $true))
function Test-Issue13V5ConfigValidatorIsolationAst(
  [Management.Automation.Language.FunctionDefinitionAst]$Definition
) {
  $pathWrites = @(Get-Issue13V5VariableWriteAsts $Definition '$path')
  $rootWrites = @(Get-Issue13V5VariableWriteAsts `
    $Definition '$immutableRoots')
  $allowedSealedGitProbes = @(
    ('Invoke-Issue13V5SealedGit-C([string]$config.repository_root)' +
      "cat-file-e([string]`$config.candidate_commit+'^{commit}')2>`$null"),
    ('Invoke-Issue13V5SealedGit-C([string]$config.repository_root)' +
      "cat-file-e([string]`$config.baseline_runtime_commit+'^{commit}')" +
      '2>$null')
  )
  $dynamicMutators = @($Definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Test-Issue13V5ForbiddenProtectedScopeCommand $node) -and
      $allowedSealedGitProbes -cnotcontains
        [regex]::Replace($node.Extent.Text, '[\s`]', '')
  }, $true))
  $memberMutators = @($Definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      (Test-Issue13V5AstReferencesVariable $node '$immutableRoots')
  }, $true))
  if ($Definition.Name -cne 'Assert-Issue13V5Config' -or
      -not (Test-Issue13V5SingularDirectAssignment $Definition `
        '$path' 'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' `
        '(Resolve-Path -LiteralPath $ConfigPath).Path') -or
      -not (Test-Issue13V5SingularDirectAssignment $Definition `
        '$immutableRoots' `
        'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst') -or
      [regex]::Replace($rootWrites[0].Right.Extent.Text, '\s+', '') -cne
        '@((ConvertTo-Issue13V5Path([string]$config.repository_root))' +
        '(ConvertTo-Issue13V5Path([string]$config.source_origin))' +
        '(ConvertTo-Issue13V5Path([string]$config.candidate_source_origin))' +
        '(ConvertTo-Issue13V5Path([string]$config.harness_runtime_root))' +
        '(ConvertTo-Issue13V5Path([string]$config.r_library))' +
        '(ConvertTo-Issue13V5Path([string]$config.rscript))' +
        '(ConvertTo-Issue13V5Path([string]$config.oracle_effect.' +
          'comparisons.primary.root))' +
        '(ConvertTo-Issue13V5Path([string]$config.oracle_effect.' +
          'comparisons.replay.root)))' -or
      -not (Test-Issue13V5FrozenCommandDataflow `
        $Definition 'Assert-Issue13V5ConfigPathIsolation' `
        @('$path', '$immutableRoots') `
        ('CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>' +
          'ScriptBlockAst')) -or
      $pathWrites[0].Extent.StartOffset -ge $rootWrites[0].Extent.StartOffset -or
      $dynamicMutators.Count -ne 0 -or
      (Test-Issue13V5ForbiddenProtectedScopeRedirection `
        $Definition @('2>$null')) -or
      (Test-Issue13V5ForbiddenSessionStateMutation $Definition) -or
      $memberMutators.Count -ne 0) {
    return $false
  }
  $true
}
if ($configDefinitions[0].Extent.Text.Contains('.StartsWith(') -or
    $configDisjointCalls.Count -ne 4 -or
    $configPhysicalCalls.Count -ne 2 -or
    $configPathIsolationCalls.Count -ne 1 -or
    $configPathIsolationCalls[0].CommandElements.Count -ne 3 -or
    $configPathIsolationCalls[0].CommandElements[1].Extent.Text -cne '$path' -or
    $configPathIsolationCalls[0].CommandElements[2].Extent.Text -cne
      '$immutableRoots' -or
    -not (Test-Issue13V5FrozenCommandDataflow `
      $configDefinitions[0] 'Assert-Issue13V5ConfigPathIsolation' `
      @('$path', '$immutableRoots') `
      'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>ScriptBlockAst') -or
    -not (Test-Issue13V5ConfigValidatorIsolationAst $configDefinitions[0]) -or
    $configPathIsolationDefinitions[0].Extent.Text.Contains('.StartsWith(') -or
    $configPathIsolationDisjointCalls.Count -ne 1 -or
    -not (Test-Issue13V5FrozenCommandDataflow `
      $configPathIsolationDefinitions[0] 'Assert-Issue13V5PathsDisjoint' `
      @('$ConfigPath', '$immutableRoot',
        "'V5 config/immutable-root isolation'") `
      'CommandAst>PipelineAst>StatementBlockAst>ForEachStatementAst>NamedBlockAst>ScriptBlockAst') -or
    $oracleIsolationDefinitions[0].Extent.Text.Contains('.StartsWith(') -or
    $oracleIsolationDisjointCalls.Count -ne 2) {
  throw 'Coordinator root isolation is no longer physically canonical.'
}

$pathContainedDefinitions = @($libraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Test-Issue13V5PathContained'
}, $true))
if ($pathContainedDefinitions.Count -ne 1 -or
    @($pathContainedDefinitions[0].FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'ConvertTo-Issue13V5PhysicalPath'
    }, $true)).Count -ne 2 -or
    $pathContainedDefinitions[0].Extent.Text.Contains(
      'ConvertTo-Issue13V5Path ')) {
  throw 'Coordinator containment no longer consumes physical identities.'
}

$tokens = @()
$errors = @()
$newConfigAst = $bootstrapSourceAsts['issue13-v5-new-config.ps1']
$newConfigDisjointCalls = @($newConfigAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5PathsDisjoint'
}, $true))
$newConfigPathIsolationCalls = @($newConfigAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5ConfigPathIsolation'
}, $true))
$newConfigFreshRootCalls = @($newConfigAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13V5FreshRoot'
}, $true))
$newConfigImmutableAssignments = @(Get-Issue13V5VariableWriteAsts `
  $newConfigAst '$configImmutableRoots')
function Test-Issue13V5ConfigGeneratorIsolationAst(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $topLevelStatements = @($Ast.EndBlock.Statements)
  if ($topLevelStatements.Count -lt 2) { return $false }
  $allowedDynamicSignatures = @(
    '$importModuleCmdlet|-Name|$manifest|-Global|-Force|-ErrorAction|Stop',
    '$issue13V5CommandCollisionGuard|$MyInvocation.MyCommand.ScriptBlock.Ast',
    '([IO.Path]::Combine($PSScriptRoot, ''issue13-v5-coordinator-lib.ps1''))',
    ('Invoke-Issue13V5SealedGit|-C|$repository|cat-file|-e|' +
      '($BaselineRuntimeCommit + ''^{commit}'')'),
    ('Invoke-Issue13V5SealedGit|-C|$repository|cat-file|-e|' +
      '($CandidateCommit + ''^{commit}'')')
  )
  $allowedMutationSignatures = [string[]]@(
    $allowedDynamicSignatures
    'New-Item|-ItemType|Directory|-Path|$outputParent'
    'Move-Item|-LiteralPath|$temporary|-Destination|$finalOutputFull'
  )
  $rootWrites = @(Get-Issue13V5VariableWriteAsts `
    $Ast '$configImmutableRoots')
  $temporaryWrites = @(Get-Issue13V5VariableWriteAsts $Ast '$temporary')
  $isolationCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5ConfigPathIsolation'
  }, $true))
  $freshCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5FreshRoot'
  }, $true))
  $moveCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Move-Item'
  }, $true))
  $physicalCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'ConvertTo-Issue13V5PhysicalPath' -and
      -not (Get-Issue13V5AstAncestorChain $node $Ast).Contains(
        'FunctionDefinitionAst')
  }, $true))
  $ancestorCalls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13V5NoReparseAncestors' -and
      -not (Get-Issue13V5AstAncestorChain $node $Ast).Contains(
        'FunctionDefinitionAst')
  }, $true))
  $dynamicMutators = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Test-Issue13V5ForbiddenProtectedScopeCommand `
        $node $allowedMutationSignatures)
  }, $true))
  $rootMemberMutators = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      (Test-Issue13V5AstReferencesVariable `
        $node '$configImmutableRoots')
  }, $true))
  $signatures = @($isolationCalls | ForEach-Object {
    [string]::Join('|', @($_.CommandElements | ForEach-Object {
      $_.Extent.Text
    })) + '|' + (Get-Issue13V5AstAncestorChain $_ $Ast)
  })
  $ancestorSignatures = @($ancestorCalls | ForEach-Object {
    [string]::Join('|', @($_.CommandElements | ForEach-Object {
      $_.Extent.Text
    })) + '|' + (Get-Issue13V5AstAncestorChain $_ $Ast)
  })
  if ([string]::Join("`n", $signatures) -cne [string]::Join("`n", @(
      ('Assert-Issue13V5ConfigPathIsolation|$outputFull|' +
        '$configImmutableRoots|CommandAst>PipelineAst>' +
        'AssignmentStatementAst>NamedBlockAst'),
      ('Assert-Issue13V5ConfigPathIsolation|$finalOutputFull|' +
        '$configImmutableRoots|CommandAst>PipelineAst>' +
        'AssignmentStatementAst>NamedBlockAst'),
      ('Assert-Issue13V5ConfigPathIsolation|$finalOutputFull|' +
        '$configImmutableRoots|CommandAst>PipelineAst>' +
        'AssignmentStatementAst>NamedBlockAst')
    )) -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$outputFull' 'AssignmentStatementAst>NamedBlockAst' `
        'ConvertTo-Issue13V5FullPath $Output $false') -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$finalOutputFull' 'AssignmentStatementAst>NamedBlockAst' `
        'Join-Path $outputParent ([IO.Path]::GetFileName($outputFull))') -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$configImmutableRoots' 'AssignmentStatementAst>NamedBlockAst') -or
      -not (Test-Issue13V5SingularDirectAssignment $Ast `
        '$temporary' 'AssignmentStatementAst>NamedBlockAst') -or
      [regex]::Replace($rootWrites[0].Right.Extent.Text, '\s+', '') -cne
        '@($repository,$harnessRuntime,$source,$candidateSource,$library,' +
          '$rscriptFull,$oraclePrimaryRoot,$oracleReplayRoot)' -or
      [regex]::Replace(
        $temporaryWrites[0].Right.Extent.Text, '\s+', '') -cne
        "Join-Path`$outputParent('.'+[IO.Path]::GetFileName(" +
          "`$finalOutputFull)+'-'+[Guid]::NewGuid().ToString('N')+'.tmp')" -or
      $freshCalls.Count -ne 3 -or
      $isolationCalls[0].Extent.StartOffset -ge
        [int](@($freshCalls | ForEach-Object { $_.Extent.StartOffset } |
          Measure-Object -Minimum)[0].Minimum) -or
      $physicalCalls.Count -ne 3 -or
      [string]::Join("`n", $ancestorSignatures) -cne
        [string]::Join("`n", @(
          ('Assert-Issue13V5NoReparseAncestors|$protectedRoot|' +
            "'Oracle-effect protected root'|CommandAst>PipelineAst>" +
            'StatementBlockAst>ForEachStatementAst>StatementBlockAst>' +
            'ForEachStatementAst>NamedBlockAst'),
          ('Assert-Issue13V5NoReparseAncestors|$outputFull|' +
            "'V5 config output'|CommandAst>PipelineAst>NamedBlockAst"),
          ('Assert-Issue13V5NoReparseAncestors|$finalOutputFull|' +
            "'Resolved V5 config output'|CommandAst>PipelineAst>NamedBlockAst"),
          ('Assert-Issue13V5NoReparseAncestors|$finalOutputFull|' +
            "'Final V5 config output'|CommandAst>PipelineAst>NamedBlockAst")
        )) -or
      $moveCalls.Count -ne 1 -or
      $moveCalls[0].GetCommandName() -cne 'Move-Item' -or
      [string]::Join("`n", @($moveCalls[0].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
        "-LiteralPath`n`$temporary`n-Destination`n`$finalOutputFull" -or
      $isolationCalls[2].Extent.EndOffset -ge
        $moveCalls[0].Extent.StartOffset -or
      $dynamicMutators.Count -ne 0 -or
      (Test-Issue13V5ForbiddenProtectedScopeRedirection `
        $Ast @('2>$null')) -or
      (Test-Issue13V5ForbiddenSessionStateMutation `
        $Ast @($topLevelStatements[0])) -or
      $rootMemberMutators.Count -ne 0) {
    return $false
  }
  $true
}
$newConfigImmutableVariables = if (
    $newConfigImmutableAssignments.Count -eq 1) {
  @($newConfigImmutableAssignments[0].Right.FindAll({
    param($node)
    $node -is [Management.Automation.Language.VariableExpressionAst]
  }, $true) | ForEach-Object { '$' + $_.VariablePath.UserPath })
} else { @() }
$newConfigFirstFreshRootOffset = if ($newConfigFreshRootCalls.Count -gt 0) {
  [int](@($newConfigFreshRootCalls | ForEach-Object {
    $_.Extent.StartOffset
  } | Measure-Object -Minimum)[0].Minimum)
} else { -1 }
$newConfigTopLevelStatements = @($newConfigAst.EndBlock.Statements)
$newConfigStartsWithCalls = @($newConfigAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
    [string]$node.Member.Value -ceq 'StartsWith'
}, $true))
$newConfigUntrustedStartsWithCount = 0
foreach ($startsWithCall in $newConfigStartsWithCalls) {
  if ($startsWithCall.Extent.StartOffset -lt
      $newConfigTopLevelStatements[0].Extent.StartOffset -or
      $startsWithCall.Extent.EndOffset -gt
      $newConfigTopLevelStatements[0].Extent.EndOffset) {
    $newConfigUntrustedStartsWithCount++
  }
}
if ($errors.Count -ne 0 -or
    $newConfigTopLevelStatements.Count -lt 2 -or
    $newConfigStartsWithCalls.Count -ne 2 -or
    $newConfigUntrustedStartsWithCount -ne 0 -or
    $newConfigDisjointCalls.Count -ne 7 -or
    $newConfigPathIsolationCalls.Count -ne 3 -or
    $newConfigFreshRootCalls.Count -ne 3 -or
    $newConfigPathIsolationCalls[0].Extent.StartOffset -ge
      $newConfigFirstFreshRootOffset -or
    $newConfigImmutableAssignments.Count -ne 1 -or
    [string]::Join("`n", $newConfigImmutableVariables) -cne
    [string]::Join("`n", @(
        '$repository', '$harnessRuntime', '$source', '$candidateSource',
        '$library', '$rscriptFull', '$oraclePrimaryRoot', '$oracleReplayRoot'
      )) -or
    -not (Test-Issue13V5ConfigGeneratorIsolationAst $newConfigAst)) {
  throw 'Config generator root isolation is no longer physically canonical.'
}
$newConfigIsolationOwner = $newConfigPathIsolationCalls[0].Parent
while ($null -ne $newConfigIsolationOwner -and
    $newConfigIsolationOwner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
  $newConfigIsolationOwner = $newConfigIsolationOwner.Parent
}
$newConfigIsolationStatement = [string]$newConfigIsolationOwner.Extent.Text
if ($newConfigText.IndexOf(
      $newConfigIsolationStatement, [StringComparison]::Ordinal) -ne
    $newConfigText.LastIndexOf(
      $newConfigIsolationStatement, [StringComparison]::Ordinal)) {
  throw 'Config generator isolation statement is not textually unique.'
}
$newConfigDeadBranchText = $newConfigText.Replace(
  $newConfigIsolationStatement,
  "if (`$false) {`n$newConfigIsolationStatement`n}")
$newConfigDeadBranchTokens = $null
$newConfigDeadBranchErrors = $null
$newConfigDeadBranchAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $newConfigDeadBranchText, [ref]$newConfigDeadBranchTokens,
    [ref]$newConfigDeadBranchErrors)
if ($newConfigDeadBranchErrors.Count -ne 0 -or
    (Test-Issue13V5ConfigGeneratorIsolationAst $newConfigDeadBranchAst)) {
  throw 'Config generator accepted a dead path-isolation branch.'
}
$newConfigTypedRootText = $newConfigText.Replace(
  [string]$newConfigImmutableAssignments[0].Extent.Text,
  [string]$newConfigImmutableAssignments[0].Extent.Text +
    "`n[string[]]`$CoNfIgImMuTaBlErOoTs = @(`$repository)")
$newConfigTypedRootTokens = $null
$newConfigTypedRootErrors = $null
$newConfigTypedRootAst = [Management.Automation.Language.Parser]::ParseInput(
  $newConfigTypedRootText, [ref]$newConfigTypedRootTokens,
  [ref]$newConfigTypedRootErrors)
if ($newConfigTypedRootErrors.Count -ne 0 -or
    (Test-Issue13V5ConfigGeneratorIsolationAst $newConfigTypedRootAst)) {
  throw 'Config generator accepted a typed case-variant root mutation.'
}
$newConfigWrappedRootText = $newConfigText.Replace(
  '$repository, $harnessRuntime',
  '[System.String]($repository + ''\x''), $harnessRuntime')
$newConfigWrappedRootTokens = $null
$newConfigWrappedRootErrors = $null
$newConfigWrappedRootAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $newConfigWrappedRootText, [ref]$newConfigWrappedRootTokens,
    [ref]$newConfigWrappedRootErrors)
if ($newConfigWrappedRootErrors.Count -ne 0 -or
    (Test-Issue13V5ConfigGeneratorIsolationAst `
      $newConfigWrappedRootAst)) {
  throw 'Config generator accepted a wrapped immutable root.'
}
$newConfigDynamicRootText = $newConfigText.Replace(
  [string]$newConfigImmutableAssignments[0].Extent.Text,
  [string]$newConfigImmutableAssignments[0].Extent.Text +
    "`nsV -Name configImmutableRoots -Value @(`$repository)")
$newConfigDynamicRootTokens = $null
$newConfigDynamicRootErrors = $null
$newConfigDynamicRootAst = [Management.Automation.Language.Parser]::ParseInput(
  $newConfigDynamicRootText, [ref]$newConfigDynamicRootTokens,
  [ref]$newConfigDynamicRootErrors)
if ($newConfigDynamicRootErrors.Count -ne 0 -or
    (Test-Issue13V5ConfigGeneratorIsolationAst $newConfigDynamicRootAst)) {
  throw 'Config generator accepted an alias-based root mutation.'
}
$newConfigMoveCalls = @($newConfigAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Move-Item'
}, $true))
$newConfigMoveStatement = [string]$newConfigMoveCalls[0].Parent.Extent.Text
$newConfigOutputMutationText = $newConfigText.Replace(
  $newConfigMoveStatement,
  "`$FiNaLoUtPuTfUlL = Join-Path `$repository 'issue13-mutant.json'`n" +
    $newConfigMoveStatement)
$newConfigOutputMutationTokens = $null
$newConfigOutputMutationErrors = $null
$newConfigOutputMutationAst = [Management.Automation.Language.Parser]::ParseInput(
  $newConfigOutputMutationText, [ref]$newConfigOutputMutationTokens,
  [ref]$newConfigOutputMutationErrors)
if ($newConfigOutputMutationErrors.Count -ne 0 -or
    (Test-Issue13V5ConfigGeneratorIsolationAst `
      $newConfigOutputMutationAst)) {
  throw 'Config generator accepted a post-check output mutation.'
}
$configIsolationOwner = $configPathIsolationCalls[0].Parent
while ($null -ne $configIsolationOwner -and
    $configIsolationOwner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
  $configIsolationOwner = $configIsolationOwner.Parent
}
$libraryText = $libraryAst.Extent.Text
$configIsolationStatement = [string]$configIsolationOwner.Extent.Text
if ($libraryText.IndexOf(
      $configIsolationStatement, [StringComparison]::Ordinal) -ne
    $libraryText.LastIndexOf(
      $configIsolationStatement, [StringComparison]::Ordinal)) {
  throw 'Config validator isolation statement is not textually unique.'
}
$configDeadBranchText = $libraryText.Replace(
  $configIsolationStatement,
  "if (`$false) {`n$configIsolationStatement`n  }")
$configDeadBranchTokens = $null
$configDeadBranchErrors = $null
$configDeadBranchAst = [Management.Automation.Language.Parser]::ParseInput(
  $configDeadBranchText, [ref]$configDeadBranchTokens,
  [ref]$configDeadBranchErrors)
$configDeadBranchDefinitions = @($configDeadBranchAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5Config'
}, $true))
if ($configDeadBranchErrors.Count -ne 0 -or
    $configDeadBranchDefinitions.Count -ne 1 -or
    (Test-Issue13V5ConfigValidatorIsolationAst `
      $configDeadBranchDefinitions[0])) {
  throw 'Config validator accepted a dead path-isolation branch.'
}
$configRootWrites = @(Get-Issue13V5VariableWriteAsts `
  $configDefinitions[0] '$immutableRoots')
$configTypedRootText = $libraryText.Replace(
  [string]$configRootWrites[0].Extent.Text,
  [string]$configRootWrites[0].Extent.Text +
    "`n  [string[]]`$ImMuTaBlErOoTs = @(`$config.repository_root)")
$configTypedRootTokens = $null
$configTypedRootErrors = $null
$configTypedRootAst = [Management.Automation.Language.Parser]::ParseInput(
  $configTypedRootText, [ref]$configTypedRootTokens,
  [ref]$configTypedRootErrors)
$configTypedRootDefinitions = @($configTypedRootAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5Config'
}, $true))
if ($configTypedRootErrors.Count -ne 0 -or
    $configTypedRootDefinitions.Count -ne 1 -or
    (Test-Issue13V5ConfigValidatorIsolationAst `
      $configTypedRootDefinitions[0])) {
  throw 'Config validator accepted a typed case-variant root mutation.'
}
$configDynamicRootText = $libraryText.Replace(
  [string]$configRootWrites[0].Extent.Text,
  [string]$configRootWrites[0].Extent.Text +
    "`n  Microsoft.PowerShell.Utility\Set-Variable " +
      "-Name immutableRoots -Value @(`$config.repository_root)")
$configDynamicRootTokens = $null
$configDynamicRootErrors = $null
$configDynamicRootAst = [Management.Automation.Language.Parser]::ParseInput(
  $configDynamicRootText, [ref]$configDynamicRootTokens,
  [ref]$configDynamicRootErrors)
$configDynamicRootDefinitions = @($configDynamicRootAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13V5Config'
}, $true))
if ($configDynamicRootErrors.Count -ne 0 -or
    $configDynamicRootDefinitions.Count -ne 1 -or
    (Test-Issue13V5ConfigValidatorIsolationAst `
      $configDynamicRootDefinitions[0])) {
  throw 'Config validator accepted a qualified dynamic root mutation.'
}

$tokens = @()
$errors = @()
$oracleLibraryAst =
  $bootstrapSourceAsts['issue13-v5-oracle-effect-lib.ps1']
function Test-Issue13V5OracleProofConsumerAst(
  [Management.Automation.Language.ScriptBlockAst]$Ast,
  [string]$ProofArgument,
  [string]$ResolvedVariable,
  [string]$BarrierCommand,
  [string]$FirstConsumerCommand,
  [string[]]$FirstConsumerElements,
  [string]$FirstConsumerChain
) {
  $topLevelStatements = @($Ast.EndBlock.Statements)
  if ($topLevelStatements.Count -lt 2) { return $false }
  $allowedDynamicSignatures = [string[]]@(
    '$importModuleCmdlet|-Name|$manifest|-Global|-Force|-ErrorAction|Stop'
    '$issue13V5CommandCollisionGuard|$MyInvocation.MyCommand.ScriptBlock.Ast'
    '([IO.Path]::Combine($PSScriptRoot, ''issue13-v5-oracle-effect-lib.ps1''))'
  )
  $assignments = @(Get-Issue13V5VariableWriteAsts `
    $Ast '$proofProtectedRoots')
  $proofArgumentWrites = @(Get-Issue13V5VariableWriteAsts `
    $Ast $ProofArgument)
  $resolvedWrites = @(Get-Issue13V5VariableWriteAsts `
    $Ast $ResolvedVariable)
  $calls = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13OracleEffectProofPathIsolation'
  }, $true))
  $barriers = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        $BarrierCommand
  }, $true))
  $dynamicMutators = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Test-Issue13V5ForbiddenProtectedScopeCommand `
        $node $allowedDynamicSignatures)
  }, $true))
  $memberMutators = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      (Test-Issue13V5AstReferencesVariable `
        $node '$proofProtectedRoots')
  }, $true))
  $resolvedMemberUses = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      (Test-Issue13V5AstReferencesVariable $node $ResolvedVariable)
  }, $true))
  $expectedRoots = '@($RepositoryRoot,' +
    '(Split-Path-Parent([IO.Path]::GetFullPath($ComparisonHarnessManifest))),' +
    '$RLibrary,$Rscript,' +
    '(Split-Path-Parent([IO.Path]::GetFullPath($StrictSmokeSummary))),' +
    '(Split-Path-Parent([IO.Path]::GetFullPath($OracleSmokeSummary))),' +
    '$OraclePatch,$SpecPath,$SchemaPath,$ComparisonRoot,$ReplayRoot)'
  if ($assignments.Count -ne 1 -or
      $proofArgumentWrites.Count -ne 0 -or
      $assignments[0].Left.Extent.Text -cne '$proofProtectedRoots' -or
      (Get-Issue13V5AstAncestorChain $assignments[0] $Ast) -cne
        'AssignmentStatementAst>NamedBlockAst' -or
      [regex]::Replace($assignments[0].Right.Extent.Text, '\s+', '') -cne
        $expectedRoots -or
      $resolvedWrites.Count -ne 1 -or
      $resolvedWrites[0].Left.Extent.Text -cne $ResolvedVariable -or
      $calls.Count -ne 1 -or
      [string]::Join("`n", @($calls[0].CommandElements |
        Select-Object -Skip 1 | ForEach-Object { $_.Extent.Text })) -cne
        ($ProofArgument + "`n`$proofProtectedRoots") -or
      (Get-Issue13V5AstAncestorChain $calls[0] $Ast) -cne
        'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst' -or
      -not [object]::ReferenceEquals(
        $calls[0].Parent.Parent, $resolvedWrites[0]) -or
      $barriers.Count -lt 1 -or
      $calls[0].Extent.StartOffset -ge
        [int](@($barriers | ForEach-Object {
          $_.Extent.StartOffset
        } | Measure-Object -Minimum)[0].Minimum) -or
      $dynamicMutators.Count -ne 0 -or
      (Test-Issue13V5ForbiddenProtectedScopeRedirection $Ast) -or
      (Test-Issue13V5ForbiddenSessionStateMutation `
        $Ast @($topLevelStatements[0])) -or
      $memberMutators.Count -ne 0 -or
      $resolvedMemberUses.Count -ne 0) {
    return $false
  }
  $reads = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.VariableExpressionAst] -and
      (Get-Issue13V5AssignmentBaseVariableName $node) -ieq
        $ResolvedVariable -and
      $node.Extent.StartOffset -ge $resolvedWrites[0].Extent.EndOffset
  }, $true) | Sort-Object { $_.Extent.StartOffset })
  if ($reads.Count -lt 1 -or
      $reads[0].Extent.Text -cne $ResolvedVariable) {
    return $false
  }
  $firstConsumer = $reads[0]
  while ($null -ne $firstConsumer -and
      $firstConsumer -isnot [Management.Automation.Language.CommandAst]) {
    $firstConsumer = $firstConsumer.Parent
  }
  if ($null -eq $firstConsumer -or
      $firstConsumer.GetCommandName() -cne $FirstConsumerCommand -or
      $firstConsumer.InvocationOperator -ne
        [Management.Automation.Language.TokenKind]::Unknown -or
      [string]::Join("`n", @($firstConsumer.CommandElements |
        ForEach-Object { $_.Extent.Text })) -cne
        [string]::Join("`n", $FirstConsumerElements) -or
      (Get-Issue13V5AstAncestorChain $firstConsumer $Ast) -cne
        $FirstConsumerChain) {
    return $false
  }
  $true
}
function Test-Issue13V5OracleWriterIsolationAst(
  [Management.Automation.Language.ScriptBlockAst]$Ast
) {
  $definitions = @($Ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
        'Write-Issue13OracleEffectJsonOnce'
  }, $true))
  if ($definitions.Count -ne 1) { return $false }
  $definition = $definitions[0]
  $isolationCalls = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13OracleEffectProofPathIsolation'
  }, $true))
  $signatures = @($isolationCalls | ForEach-Object {
    [string]::Join('|', @($_.CommandElements | ForEach-Object {
      $_.Extent.Text
    })) + '|' + (Get-Issue13V5AstAncestorChain $_ $definition)
  })
  $pathAssignments = @(Get-Issue13V5VariableWriteAsts $definition '$Path')
  $fullAssignments = @(Get-Issue13V5VariableWriteAsts $definition '$full')
  $parentAssignments = @(Get-Issue13V5VariableWriteAsts `
    $definition '$parent')
  $temporaryAssignments = @(Get-Issue13V5VariableWriteAsts `
    $definition '$temporary')
  $protectedAssignments = @(Get-Issue13V5VariableWriteAsts `
    $definition '$ProtectedRoots')
  $dynamicMutators = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Test-Issue13V5ForbiddenProtectedScopeCommand $node @(
        'Remove-Item|-LiteralPath|$temporary|-Force'
      ))
  }, $true))
  $protectedMemberMutators = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      (Test-Issue13V5AstReferencesVariable $node '$ProtectedRoots')
  }, $true))
  $fileCalls = @($definition.FindAll({
    param($node)
    $node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      $node.Static -and
      (Test-Issue13V5TypeExpression $node.Expression 'System.IO.File')
  }, $true))
  if ([string]::Join("`n", $signatures) -cne
      [string]::Join("`n", @(
        ('Assert-Issue13OracleEffectProofPathIsolation|$Path|$ProtectedRoots|' +
          'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>ScriptBlockAst'),
        ('Assert-Issue13OracleEffectProofPathIsolation|$full|$ProtectedRoots|' +
          'CommandAst>PipelineAst>AssignmentStatementAst>StatementBlockAst>' +
          'TryStatementAst>NamedBlockAst>ScriptBlockAst')
      )) -or
      $pathAssignments.Count -ne 0 -or
      $fullAssignments.Count -ne 1 -or
      $fullAssignments[0].Left.Extent.Text -cne '$full' -or
      -not [object]::ReferenceEquals(
        $fullAssignments[0], $isolationCalls[0].Parent.Parent) -or
      -not (Test-Issue13V5SingularDirectAssignment $definition `
        '$parent' `
        'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst' `
        'Split-Path -Parent $full') -or
      -not (Test-Issue13V5SingularDirectAssignment $definition `
        '$temporary' `
        'AssignmentStatementAst>NamedBlockAst>ScriptBlockAst') -or
      [regex]::Replace(
        $temporaryAssignments[0].Right.Extent.Text, '[\s`]', '') -cne
        "Join-Path`$parent('.'+[IO.Path]::GetFileName(`$full)+'.'+" +
          "[Guid]::NewGuid().ToString('N')+'.tmp')" -or
      $protectedAssignments.Count -ne 0 -or
      $dynamicMutators.Count -ne 0 -or
      (Test-Issue13V5ForbiddenProtectedScopeRedirection $definition) -or
      (Test-Issue13V5ForbiddenSessionStateMutation $definition) -or
      $protectedMemberMutators.Count -ne 0 -or
      $fileCalls.Count -ne 3 -or
      $fileCalls[0].Member -isnot
        [Management.Automation.Language.StringConstantExpressionAst] -or
      $fileCalls[0].Member.Extent.Text -cne 'WriteAllText' -or
      $fileCalls[0].Arguments.Count -ne 3 -or
      $fileCalls[0].Arguments[0].Extent.Text -cne '$temporary' -or
      $fileCalls[0].Arguments[1].Extent.Text -cne '$json + "`n"' -or
      $fileCalls[0].Arguments[2].Extent.Text -cne '$encoding' -or
      $fileCalls[1].Member -isnot
        [Management.Automation.Language.StringConstantExpressionAst] -or
      $fileCalls[1].Member.Extent.Text -cne 'Move' -or
      $fileCalls[1].Arguments.Count -ne 2 -or
      $fileCalls[1].Arguments[0].Extent.Text -cne '$temporary' -or
      $fileCalls[1].Arguments[1].Extent.Text -cne '$full' -or
      $fileCalls[2].Member -isnot
        [Management.Automation.Language.StringConstantExpressionAst] -or
      $fileCalls[2].Member.Extent.Text -cne 'Delete' -or
      $fileCalls[2].Arguments.Count -ne 1 -or
      $fileCalls[2].Arguments[0].Extent.Text -cne '$temporary' -or
      -not $definition.Extent.Text.Contains(
        'if (Test-Path -LiteralPath $temporary -PathType Leaf) {') -or
      $fullAssignments[0].Extent.EndOffset -ge
        $parentAssignments[0].Extent.StartOffset -or
      $parentAssignments[0].Extent.EndOffset -ge
        $temporaryAssignments[0].Extent.StartOffset -or
      $temporaryAssignments[0].Extent.EndOffset -ge
        $fileCalls[0].Extent.StartOffset -or
      $fileCalls[0].Extent.EndOffset -ge
        $isolationCalls[1].Extent.StartOffset -or
      $isolationCalls[1].Extent.EndOffset -ge
        $fileCalls[1].Extent.StartOffset -or
      $fileCalls[1].Extent.EndOffset -ge
        $fileCalls[2].Extent.StartOffset) {
    return $false
  }
  $true
}
$oraclePathFunctions = @(
  'Test-Issue13OracleEffectPathEqual',
  'Test-Issue13OracleEffectPathContained'
)
foreach ($functionName in $oraclePathFunctions) {
  $definitions = @($oracleLibraryAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq $functionName
  }, $true))
  if ($errors.Count -ne 0 -or $definitions.Count -ne 1 -or
      @($definitions[0].FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
          (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
            'ConvertTo-Issue13OracleEffectPhysicalPath'
      }, $true)).Count -ne 2) {
    throw "Oracle $functionName no longer consumes physical identities."
  }
}
$oracleComparisonDefinitions = @($oracleLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13OracleEffectComparisonIsolation'
}, $true))
if ($oracleComparisonDefinitions.Count -ne 1 -or
    $oracleComparisonDefinitions[0].Extent.Text.Contains('.StartsWith(') -or
    @($oracleComparisonDefinitions[0].FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst] -and
        (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
          'Assert-Issue13OracleEffectPathsDisjoint'
    }, $true)).Count -ne 2) {
  throw 'Oracle comparison isolation is no longer physically canonical.'
}
$oracleProofIsolationDefinitions = @($oracleLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Assert-Issue13OracleEffectProofPathIsolation'
}, $true))
$oracleWriterDefinitions = @($oracleLibraryAst.FindAll({
  param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    (Get-Issue13V5PowerShellCommandLeaf $node.Name) -ieq
      'Write-Issue13OracleEffectJsonOnce'
}, $true))
if ($oracleProofIsolationDefinitions.Count -ne 1 -or
    $oracleWriterDefinitions.Count -ne 1) {
  throw 'Oracle proof path-isolation definitions are missing or ambiguous.'
}
$oracleProofDisjointCalls = @($oracleProofIsolationDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13OracleEffectPathsDisjoint'
}, $true))
$oracleProofPhysicalCalls = @($oracleProofIsolationDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'ConvertTo-Issue13OracleEffectPhysicalPath'
}, $true))
$oracleWriterIsolationCalls = @($oracleWriterDefinitions[0].FindAll({
  param($node)
  $node -is [Management.Automation.Language.CommandAst] -and
    (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
      'Assert-Issue13OracleEffectProofPathIsolation'
}, $true))
$oracleWriterIsolationSignatures = @($oracleWriterIsolationCalls |
  ForEach-Object {
    [string]::Join('|', @($_.CommandElements | ForEach-Object {
      $_.Extent.Text
    })) + '|' +
      (Get-Issue13V5AstAncestorChain $_ $oracleWriterDefinitions[0])
  })
if ($oracleProofIsolationDefinitions[0].Extent.Text.Contains('.StartsWith(') -or
    $oracleProofDisjointCalls.Count -ne 1 -or
    (Get-Issue13V5AstAncestorChain $oracleProofDisjointCalls[0] `
      $oracleProofIsolationDefinitions[0]) -cne
      'CommandAst>PipelineAst>StatementBlockAst>ForEachStatementAst>NamedBlockAst>ScriptBlockAst' -or
    $oracleProofPhysicalCalls.Count -ne 2 -or
    [string]::Join("`n", $oracleWriterIsolationSignatures) -cne
      [string]::Join("`n", @(
        ('Assert-Issue13OracleEffectProofPathIsolation|$Path|$ProtectedRoots|' +
          'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst>ScriptBlockAst'),
        ('Assert-Issue13OracleEffectProofPathIsolation|$full|$ProtectedRoots|' +
          'CommandAst>PipelineAst>AssignmentStatementAst>StatementBlockAst>' +
          'TryStatementAst>NamedBlockAst>ScriptBlockAst')
      )) -or
    -not (Test-Issue13V5OracleWriterIsolationAst $oracleLibraryAst)) {
  throw 'Oracle proof writer path isolation is no longer physically canonical.'
}
$oracleWriterText = $oracleLibraryAst.Extent.Text
$oracleSecondIsolationOwner = $oracleWriterIsolationCalls[1].Parent
while ($null -ne $oracleSecondIsolationOwner -and
    $oracleSecondIsolationOwner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
  $oracleSecondIsolationOwner = $oracleSecondIsolationOwner.Parent
}
$oracleWriterFullMutationText = $oracleWriterText.Replace(
  [string]$oracleSecondIsolationOwner.Extent.Text,
  [string]$oracleSecondIsolationOwner.Extent.Text +
    "`n    `$full = Join-Path `$ProtectedRoots[0] 'proof.json'")
$oracleWriterFullMutationTokens = $null
$oracleWriterFullMutationErrors = $null
$oracleWriterFullMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterFullMutationText, [ref]$oracleWriterFullMutationTokens,
    [ref]$oracleWriterFullMutationErrors)
if ($oracleWriterFullMutationErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst $oracleWriterFullMutationAst)) {
  throw 'Oracle proof writer accepted a post-check destination mutation.'
}
$oracleWriterProtectedMutationText = $oracleWriterText.Replace(
  [string]$oracleSecondIsolationOwner.Extent.Text,
  [string]$oracleSecondIsolationOwner.Extent.Text +
    "`n    Set-Variable -Name ProtectedRoots -Value @(`$full)")
$oracleWriterProtectedMutationTokens = $null
$oracleWriterProtectedMutationErrors = $null
$oracleWriterProtectedMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterProtectedMutationText,
    [ref]$oracleWriterProtectedMutationTokens,
    [ref]$oracleWriterProtectedMutationErrors)
if ($oracleWriterProtectedMutationErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst `
      $oracleWriterProtectedMutationAst)) {
  throw 'Oracle proof writer accepted a protected-root mutation.'
}
$oracleWriterTemporaryMutationText = $oracleWriterText.Replace(
  [string]$oracleSecondIsolationOwner.Extent.Text,
  [string]$oracleSecondIsolationOwner.Extent.Text +
    "`n    `$TeMpOrArY = 'C:\issue13-sensitive.tmp'")
$oracleWriterTemporaryMutationTokens = $null
$oracleWriterTemporaryMutationErrors = $null
$oracleWriterTemporaryMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterTemporaryMutationText,
    [ref]$oracleWriterTemporaryMutationTokens,
    [ref]$oracleWriterTemporaryMutationErrors)
if ($oracleWriterTemporaryMutationErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst `
      $oracleWriterTemporaryMutationAst)) {
  throw 'Oracle proof writer accepted a post-check temporary mutation.'
}
$oracleWriterTemporaryAssignments = @(Get-Issue13V5VariableWriteAsts `
  $oracleWriterDefinitions[0] '$temporary')
$oracleWriterParentMutationText = $oracleWriterText.Replace(
  [string]$oracleWriterTemporaryAssignments[0].Extent.Text,
  "  `$PaReNt = `$ProtectedRoots[0]`n" +
    [string]$oracleWriterTemporaryAssignments[0].Extent.Text)
$oracleWriterParentMutationTokens = $null
$oracleWriterParentMutationErrors = $null
$oracleWriterParentMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterParentMutationText, [ref]$oracleWriterParentMutationTokens,
    [ref]$oracleWriterParentMutationErrors)
if ($oracleWriterParentMutationErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst $oracleWriterParentMutationAst)) {
  throw 'Oracle proof writer accepted a protected parent mutation.'
}
$oracleWriterPathMutationText = $oracleWriterText.Replace(
  [string]$oracleWriterIsolationCalls[0].Parent.Parent.Extent.Text,
  "  `$PaTh = `$ProtectedRoots[0]`n" +
    [string]$oracleWriterIsolationCalls[0].Parent.Parent.Extent.Text)
$oracleWriterPathMutationTokens = $null
$oracleWriterPathMutationErrors = $null
$oracleWriterPathMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterPathMutationText, [ref]$oracleWriterPathMutationTokens,
    [ref]$oracleWriterPathMutationErrors)
if ($oracleWriterPathMutationErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst $oracleWriterPathMutationAst)) {
  throw 'Oracle proof writer accepted an input-path mutation.'
}
$oracleWriterWriteArgumentText = $oracleWriterText.Replace(
  '[IO.File]::WriteAllText($temporary,',
  '[IO.File]::WriteAllText($Path,')
$oracleWriterWriteArgumentTokens = $null
$oracleWriterWriteArgumentErrors = $null
$oracleWriterWriteArgumentAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterWriteArgumentText, [ref]$oracleWriterWriteArgumentTokens,
    [ref]$oracleWriterWriteArgumentErrors)
if ($oracleWriterWriteArgumentErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst $oracleWriterWriteArgumentAst)) {
  throw 'Oracle proof writer accepted an unsealed staging destination.'
}
$oracleWriterDynamicMoveText = $oracleWriterText.Replace(
  '[IO.File]::Move($temporary, $full)',
  "[IO.File]::('M' + 'ove')(`$temporary, `$full)")
$oracleWriterDynamicMoveTokens = $null
$oracleWriterDynamicMoveErrors = $null
$oracleWriterDynamicMoveAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterDynamicMoveText, [ref]$oracleWriterDynamicMoveTokens,
    [ref]$oracleWriterDynamicMoveErrors)
if ($oracleWriterDynamicMoveErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst $oracleWriterDynamicMoveAst)) {
  throw 'Oracle proof writer accepted a dynamic File.Move member.'
}
$oracleWriterCleanupMutationText = $oracleWriterText.Replace(
  'if (Test-Path -LiteralPath $temporary -PathType Leaf) {',
  'if ($true) {')
$oracleWriterCleanupMutationTokens = $null
$oracleWriterCleanupMutationErrors = $null
$oracleWriterCleanupMutationAst =
  [Management.Automation.Language.Parser]::ParseInput(
    $oracleWriterCleanupMutationText, [ref]$oracleWriterCleanupMutationTokens,
    [ref]$oracleWriterCleanupMutationErrors)
if ($oracleWriterCleanupMutationText -ceq $oracleWriterText -or
    $oracleWriterCleanupMutationErrors.Count -ne 0 -or
    (Test-Issue13V5OracleWriterIsolationAst $oracleWriterCleanupMutationAst)) {
  throw 'Oracle proof writer accepted an unconditional cleanup mutant.'
}
$oracleConsumerAsts = @{}
foreach ($consumer in @(
    [pscustomobject]@{
      name = 'issue13-v5-oracle-effect-generate.ps1'
      proof = '$OutputPath'
      resolved = '$proofFull'
      barrier = 'Get-Issue13OracleEffectInputContext'
      first_command = 'Test-Path'
      first_elements = @('Test-Path', '-LiteralPath', '$proofFull')
      first_chain = 'CommandAst>PipelineAst>ParenExpressionAst>' +
        'UnaryExpressionAst>CommandExpressionAst>PipelineAst>' +
        'ParenExpressionAst>CommandAst>PipelineAst>NamedBlockAst'
    },
    [pscustomobject]@{
      name = 'issue13-v5-oracle-effect-validate.ps1'
      proof = '$ProofPath'
      resolved = '$resolvedProof'
      barrier = 'Get-Issue13OracleEffectEvidence'
      first_command = 'Get-Content'
      first_elements = @(
        'Get-Content', '-Raw', '-LiteralPath', '$resolvedProof'
      )
      first_chain =
        'CommandAst>PipelineAst>AssignmentStatementAst>NamedBlockAst'
    }
  )) {
  $consumerTokens = @()
  $consumerErrors = @()
  $consumerAst = $bootstrapSourceAsts[$consumer.name]
  if ($consumerErrors.Count -ne 0 -or
      -not (Test-Issue13V5OracleProofConsumerAst `
        $consumerAst $consumer.proof $consumer.resolved $consumer.barrier `
        $consumer.first_command $consumer.first_elements `
        $consumer.first_chain)) {
    throw "Oracle proof consumer isolation changed: $($consumer.name)"
  }
  $oracleConsumerAsts[$consumer.name] = [pscustomobject]@{
    ast = $consumerAst
    proof = $consumer.proof
    resolved = $consumer.resolved
    barrier = $consumer.barrier
    first_command = $consumer.first_command
    first_elements = $consumer.first_elements
    first_chain = $consumer.first_chain
  }
}
foreach ($consumerName in @($oracleConsumerAsts.Keys | Sort-Object)) {
  $record = $oracleConsumerAsts[$consumerName]
  $consumerAst = $record.ast
  $consumerText = $consumerAst.Extent.Text
  $isolationCalls = @($consumerAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      (Get-Issue13V5PowerShellCommandLeaf ($node.GetCommandName())) -ieq
        'Assert-Issue13OracleEffectProofPathIsolation'
  }, $true))
  $owner = $isolationCalls[0].Parent
  while ($null -ne $owner -and $owner -isnot
      [Management.Automation.Language.AssignmentStatementAst]) {
    $owner = $owner.Parent
  }
  $statement = [string]$owner.Extent.Text
  $conditionalText = $consumerText.Replace(
    $statement, [string]$owner.Left.Extent.Text + ' = if ($false) {' +
      "`n" + [string]$owner.Right.Extent.Text + "`n} else { `$null }")
  $conditionalTokens = $null
  $conditionalErrors = $null
  $conditionalAst = [Management.Automation.Language.Parser]::ParseInput(
    $conditionalText, [ref]$conditionalTokens, [ref]$conditionalErrors)
  if ($conditionalErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $conditionalAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted conditional isolation: $consumerName"
  }
  $proofArgumentName = $record.proof.TrimStart('$')
  $proofArgumentMutationText = $consumerText.Replace(
    $statement, "[string]`$" + $proofArgumentName.ToUpperInvariant() +
      " = `$RepositoryRoot`n" + $statement)
  $proofArgumentMutationTokens = $null
  $proofArgumentMutationErrors = $null
  $proofArgumentMutationAst =
    [Management.Automation.Language.Parser]::ParseInput(
      $proofArgumentMutationText, [ref]$proofArgumentMutationTokens,
      [ref]$proofArgumentMutationErrors)
  if ($proofArgumentMutationErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $proofArgumentMutationAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted input-path mutation: $consumerName"
  }
  $resolvedName = $record.resolved.TrimStart('$')
  $resolvedMutationText = $consumerText.Replace(
    $statement, $statement + "`n[string]`$" +
      $resolvedName.ToUpperInvariant() + ' = $RepositoryRoot')
  $resolvedMutationTokens = $null
  $resolvedMutationErrors = $null
  $resolvedMutationAst = [Management.Automation.Language.Parser]::ParseInput(
    $resolvedMutationText, [ref]$resolvedMutationTokens,
    [ref]$resolvedMutationErrors)
  if ($resolvedMutationErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $resolvedMutationAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted resolved-path mutation: $consumerName"
  }
  $resolvedReads = @($consumerAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.VariableExpressionAst] -and
      (Get-Issue13V5AssignmentBaseVariableName $node) -ieq
        $record.resolved -and
      $node.Extent.StartOffset -ge $owner.Extent.EndOffset
  }, $true) | Sort-Object { $_.Extent.StartOffset })
  if ($resolvedReads.Count -lt 1 -or
      $resolvedReads[0].Extent.Text -cne $record.resolved) {
    throw "Oracle proof consumer first read is missing: $consumerName"
  }
  $firstRead = $resolvedReads[0]
  $originalArgumentText = $consumerText.Substring(
      0, $firstRead.Extent.StartOffset) + $record.proof +
    $consumerText.Substring($firstRead.Extent.EndOffset)
  $originalArgumentTokens = $null
  $originalArgumentErrors = $null
  $originalArgumentAst = [Management.Automation.Language.Parser]::ParseInput(
    $originalArgumentText, [ref]$originalArgumentTokens,
    [ref]$originalArgumentErrors)
  if ($originalArgumentErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $originalArgumentAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted an unisolated first read: $consumerName"
  }
  $dummyReadText = $consumerText.Substring(0, $owner.Extent.EndOffset) +
    ("`n`$null = " + $record.resolved + "`n") +
    $consumerText.Substring($owner.Extent.EndOffset)
  $dummyReadTokens = $null
  $dummyReadErrors = $null
  $dummyReadAst = [Management.Automation.Language.Parser]::ParseInput(
    $dummyReadText, [ref]$dummyReadTokens, [ref]$dummyReadErrors)
  if ($dummyReadErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $dummyReadAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted a dummy first read: $consumerName"
  }
  $assignments = @(Get-Issue13V5VariableWriteAsts `
    $consumerAst '$proofProtectedRoots')
  $subassignmentText = $consumerText.Replace(
    [string]$assignments[0].Extent.Text,
    [string]$assignments[0].Extent.Text +
      "`n`$proofProtectedRoots[0] = `$null")
  $subassignmentTokens = $null
  $subassignmentErrors = $null
  $subassignmentAst = [Management.Automation.Language.Parser]::ParseInput(
    $subassignmentText, [ref]$subassignmentTokens,
    [ref]$subassignmentErrors)
  if ($subassignmentErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $subassignmentAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted root subassignment: $consumerName"
  }
  $dynamicText = $consumerText.Replace(
    [string]$assignments[0].Extent.Text,
    [string]$assignments[0].Extent.Text +
      "`nSet-Variable -Name proofProtectedRoots -Value @(`$RLibrary)")
  $dynamicTokens = $null
  $dynamicErrors = $null
  $dynamicAst = [Management.Automation.Language.Parser]::ParseInput(
    $dynamicText, [ref]$dynamicTokens, [ref]$dynamicErrors)
  if ($dynamicErrors.Count -ne 0 -or
      (Test-Issue13V5OracleProofConsumerAst $dynamicAst `
        $record.proof $record.resolved $record.barrier `
        $record.first_command $record.first_elements $record.first_chain)) {
    throw "Oracle proof consumer accepted dynamic root mutation: $consumerName"
  }
}

$legacyPathCases = @(
  [pscustomobject]@{ path = 'D:\root\v4\child'; expected = $true },
  [pscustomobject]@{ path = 'D:\root\V4R12-candidate'; expected = $true },
  [pscustomobject]@{ path = '/tmp/final-v4r2/run'; expected = $true },
  [pscustomobject]@{ path = 'D:\root\v5c4'; expected = $false },
  [pscustomobject]@{
    path = 'docs/validation/issue-13.md'
    expected = $false
  }
)
foreach ($case in $legacyPathCases) {
  if (-not (Test-Issue13V5ExactBoolean `
      (Test-Issue13V5LegacyPath ([string]$case.path)) $case.expected)) {
    throw "Legacy path matcher failed its static case: $($case.path)"
  }
}

$pathProjectionConfig = [pscustomobject]@{
  reuse_policy = [pscustomobject]@{ v4_evidence_allowed = $false }
  repository_root = 'D:\root\v4\repo'
  harness_runtime_root = 'D:\root\v5-runtime'
  harness_root = 'D:\root\v5-runtime\harness'
  harness_manifest_path = 'D:\root\v5-runtime\manifest.json'
  worktree_root = 'D:\root\v5-worktrees'
  evidence_root = 'D:\root\v5-evidence'
  control_root = 'D:\root\v5-control'
  source_origin = 'D:\root\sources'
  candidate_source_origin = 'D:\root\candidate-sources'
  rscript = 'D:\R\Rscript.exe'
  r_library = 'D:\R\library'
  baseline_runtime_index = 'D:\root\v5-index.json'
  baseline_overlay = [pscustomobject]@{ path = 'D:\root\v5.patch' }
  strict_baseline_smoke = [pscustomobject]@{
    path = 'D:\root\v5-strict.json'
  }
  compatibility_baseline_smoke = [pscustomobject]@{
    path = 'D:\root\v5-compat.json'
  }
  oracle_effect = [pscustomobject]@{
    oracle_smoke = [pscustomobject]@{ path = 'D:\root\v5-oracle-smoke.json' }
    proof = [pscustomobject]@{ path = 'D:\root\v5-oracle-proof.json' }
    comparisons = [pscustomobject]@{
      primary = [pscustomobject]@{
        root = 'D:\root\v5-oracle-primary'
      }
      replay = [pscustomobject]@{
        root = 'D:\root\v5-oracle-replay'
      }
    }
    comparison_harness = [pscustomobject]@{
      manifest_path = 'D:\root\v5-runtime\manifest.json'
    }
    tooling = @($oracleEffectFiles | ForEach-Object {
      [pscustomobject]@{ path = Join-Path $root $_ }
    })
  }
  comparison = [pscustomobject]@{
    preparation_equivalence_profile = [pscustomobject]@{
      path = 'D:\root\v5-runtime\issue13-evidence-harness\issue13-v5-preparation-equivalence.json'
    }
  }
  report = [pscustomobject]@{
    required_path = 'docs/validation/issue-13.md'
  }
  methods = @([pscustomobject]@{
    baseline = 'D:\root\v5-baseline'
    candidate = 'D:\root\V4R12-candidate'
  })
  supplemental_roots = [pscustomobject]@{
    candidate_fault = '/tmp/final-v4r2/run'
    baseline_paper0 = '/tmp/v5-paper0'
  }
}
$projectedPaths = @(Get-Issue13V5ConfiguredPaths $pathProjectionConfig)
$projectedLegacyPaths = @($projectedPaths | Where-Object {
  Test-Issue13V5LegacyPath $_
})
$expectedProjectedPathCount = 12L + 10L +
  [long]$oracleEffectFiles.Count +
  (2L * [long]@($pathProjectionConfig.methods).Count) +
  [long]@($pathProjectionConfig.supplemental_roots.PSObject.Properties).Count
if ($expectedProjectedPathCount -ne 32L -or
    $projectedPaths.Count -ne $expectedProjectedPathCount -or
    @($projectedPaths | Where-Object {
      [string]::IsNullOrWhiteSpace([string]$_)
    }).Count -ne 0 -or
    $projectedLegacyPaths.Count -ne 3) {
  throw 'Configured path projection failed its static cases.'
}

$wiodr13Contract = Get-Issue13V5SourceContractSha256 @(
  (Join-Path $RepositoryRoot 'contracts\units\wiodr13_v2-units.csv'),
  (Join-Path $RepositoryRoot 'contracts\units\wiodr13_v2-aggregations.csv')
)
$wiodr16Contract = Get-Issue13V5SourceContractSha256 @(
  (Join-Path $RepositoryRoot 'contracts\units\wiodr16_v2-units.csv'),
  (Join-Path $RepositoryRoot 'contracts\units\wiodr16_v2-aggregations.csv')
)
if ($wiodr13Contract -cne
      '1f2462835e70d5681d7a5b9b29be5f0598cdb35a9abd72d3d147a6636ae5c905' -or
    $wiodr16Contract -cne
      '3b23ab671df4905dee50b35efd8dff8d4897f65f2b74a2677d7614d9137e801a') {
  throw 'Candidate source contracts differ from the arm-specific bindings.'
}

$tamperRoot = Join-Path ([IO.Path]::GetTempPath()) (
  'wlv-issue13-v5-state-anchor-' + [Guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($tamperRoot)
try {
  $tamperUtf8 = [Text.UTF8Encoding]::new($false, $true)
  $tamperResult = Join-Path $tamperRoot 'scenario-result.json'
  $tamperMetrics = Join-Path $tamperRoot 'process-metrics.json'
  $tamperSamples = Join-Path $tamperRoot 'process-samples.csv'
  $tamperStdout = Join-Path $tamperRoot 'stdout.log'
  $tamperStderr = Join-Path $tamperRoot 'stderr.log'
  $tamperSpec = Join-Path $tamperRoot 'process-spec.json'
  [IO.File]::WriteAllText($tamperResult, "{}`n", $tamperUtf8)
  [IO.File]::WriteAllText($tamperSamples,
    "sample_at_utc,pid,parent_pid,name,created_at_utc,working_set_bytes,private_bytes,cpu_seconds`n2026-01-01T00:00:00Z,1,,R,2026-01-01T00:00:00Z,1,1,0`n",
    $tamperUtf8)
  [IO.File]::WriteAllText($tamperStdout, '', $tamperUtf8)
  [IO.File]::WriteAllText($tamperStderr, '', $tamperUtf8)
  [IO.File]::WriteAllText($tamperSpec, "{}`n", $tamperUtf8)
  $tamperMetricsDocument = [ordered]@{
    samples_path = Join-Path $tamperRoot `
      'stale-attempt\process-samples.csv'
    samples_sha256 = Get-Issue13V5Sha256 $tamperSamples
    stdout_path = $tamperStdout
    stdout_sha256 = Get-Issue13V5Sha256 $tamperStdout
    stderr_path = $tamperStderr
    stderr_sha256 = Get-Issue13V5Sha256 $tamperStderr
    process_spec_path = $tamperSpec
    process_spec_sha256 = Get-Issue13V5Sha256 $tamperSpec
  }
  [IO.File]::WriteAllText($tamperMetrics,
    (($tamperMetricsDocument | ConvertTo-Json -Depth 10) + "`n"),
    $tamperUtf8)
  $stateResultSha = Get-Issue13V5Sha256 $tamperResult
  $stateMetricsSha = Get-Issue13V5Sha256 $tamperMetrics
  $null = Assert-Issue13V5ScenarioStateHashes $tamperRoot `
    $stateResultSha $stateMetricsSha 'static-authentic'
  [IO.File]::AppendAllText($tamperSamples,
    "2026-01-01T00:00:01Z,1,,R,2026-01-01T00:00:00Z,2,2,1`n",
    $tamperUtf8)
  $tamperMetricsDocument.samples_sha256 =
    Get-Issue13V5Sha256 $tamperSamples
  [IO.File]::WriteAllText($tamperMetrics,
    (($tamperMetricsDocument | ConvertTo-Json -Depth 10) + "`n"),
    $tamperUtf8)
  $coherentTamperRejected = $false
  try {
    $null = Assert-Issue13V5ScenarioStateHashes $tamperRoot `
      $stateResultSha $stateMetricsSha 'static-coherent-tamper'
  } catch {
    $coherentTamperRejected = $_.Exception.Message.Contains(
      'Scenario state hash changed')
  }
  if (-not $coherentTamperRejected) {
    throw 'State anchor accepted coherent samples+metrics tampering.'
  }
} finally {
  if ([IO.Directory]::Exists($tamperRoot)) {
    [IO.Directory]::Delete($tamperRoot, $true)
  }
}

$coordinatorText = [string]$bootstrapSourceTexts['issue13-v5-coordinator.ps1']
foreach ($required in @(
    'Get-Issue13V5SourceBinding', '-Arm ([string]$record.arm)',
    "'cross_engine_source_v1'"
  )) {
  if (-not $coordinatorText.Contains($required)) {
    throw "Coordinator lacks arm-specific source routing: $required"
  }
}

$compareText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-compare-override.R'),
  [Text.UTF8Encoding]::new($false, $true))
foreach ($required in @(
    'run_root <- dirname(path)',
    'identical(run_root, context_run_root)',
    'identical(expected_commit, observed_commit)',
    'context$input_binding_sha256',
    'input_binding_valid',
    'identical(wlv13_git_commit(project_root), expected_commit)',
    'isTRUE(wlv13_git_runtime_clean(project_root))'
  )) {
  if (-not $compareText.Contains($required)) {
    throw "V5 compare override lacks structural runtime binding: $required"
  }
}

$recordNames = @($records.ToArray() | ForEach-Object { [string]$_.name })
if (@($recordNames | Sort-Object -Unique).Count -ne $recordNames.Count) {
  throw 'Static controller records contain a duplicate source.'
}
foreach ($name in $expectedControllerFiles) {
  if ($name -cin $recordNames) { continue }
  $path = Join-Path $root $name
  if (-not $bootstrapSourceFileSha256.ContainsKey($name) -and
      -not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "V5 controller source is missing: $name"
  }
  $commandCount = 0L
  if ([IO.Path]::GetExtension($name) -ceq '.ps1') {
    $tokens = @()
    $errors = @()
    $controllerAst = $bootstrapSourceAsts[$name]
    if ($errors.Count -ne 0) {
      throw "PowerShell parser rejected controller $name`: $($errors[0].Message)"
    }
    $commandCount = [long]@($controllerAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.CommandAst]
    }, $true)).Count
  }
  $records.Add([ordered]@{
    name = $name
    sha256 = if ($bootstrapSourceFileSha256.ContainsKey($name)) {
      [string]$bootstrapSourceFileSha256[$name]
    } else {
      Get-Issue13V5Sha256 $path
    }
    command_ast_count = $commandCount
  })
}
$controllerRecords = @($expectedControllerFiles | ForEach-Object {
  $name = $_
  $match = @($records.ToArray() | Where-Object {
    [string]$_.name -ceq $name
  })
  if ($match.Count -ne 1) {
    throw "Static controller record is missing or ambiguous: $name"
  }
  $match[0]
})
if ($controllerRecords.Count -ne 34 -or
    [string]::Join("`n", @($controllerRecords.name)) -cne
      [string]::Join("`n", $expectedControllerFiles)) {
  throw 'Static controller records do not cover the exact 34-file inventory.'
}

$runtime = (Resolve-Path -LiteralPath $HarnessRuntimeRoot).Path
$manifestPath = Join-Path $runtime 'v5-harness-manifest.json'
$repository = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$staticConfig = [pscustomobject]@{
  repository_root = $repository
  candidate_commit = $CandidateCommit
  harness_runtime_root = $runtime
  harness_root = (Join-Path $runtime 'issue13-evidence-harness')
  harness_manifest_path = $manifestPath
  harness_manifest_sha256 = Get-Issue13V5Sha256 $manifestPath
}
$harnessBinding = Assert-Issue13V5HarnessBinding $staticConfig
$manifest = $harnessBinding.manifest
$inventory = $harnessBinding.inventory
$expectedHarnessFileCount = 39L
$expectedHarnessTotalBytes = 594386L
$expectedHarnessInventorySha256 =
  '9f50c978ffc5f1f2d69d70ca8e5a7205eca39ec8441843cd5fa43b959eaf03c1'
if ($inventory.file_count -ne $expectedHarnessFileCount -or
    $inventory.total_bytes -ne $expectedHarnessTotalBytes -or
    $inventory.inventory_sha256 -cne $expectedHarnessInventorySha256 -or
    [long]$manifest.output_tooling.file_count -ne $expectedHarnessFileCount -or
    [long]$manifest.output_tooling.total_bytes -ne
      $expectedHarnessTotalBytes -or
    [string]$manifest.output_tooling.inventory_sha256 -cne
      $expectedHarnessInventorySha256 -or
    [long]$manifest.sealed_output_tooling.file_count -ne
      $expectedHarnessFileCount -or
    [long]$manifest.sealed_output_tooling.total_bytes -ne
      $expectedHarnessTotalBytes -or
    [string]$manifest.sealed_output_tooling.inventory_sha256 -cne
      $expectedHarnessInventorySha256) {
  throw 'Materialized V5 harness failed its static authentication.'
}

$materializedCompare = [IO.File]::ReadAllText(
  (Join-Path $runtime 'issue13-evidence-harness\issue13-compare-lib.R'),
  [Text.UTF8Encoding]::new($false, $true))
$materializedPreparationCompare = [IO.File]::ReadAllText(
  (Join-Path $runtime 'issue13-preparation-compare.R'),
  [Text.UTF8Encoding]::new($false, $true))
$materializedPreparationLibrary = [IO.File]::ReadAllText(
  (Join-Path $runtime 'issue13-prep-paper-lib.R'),
  [Text.UTF8Encoding]::new($false, $true))
$materializedPreparationEquivalence = [IO.File]::ReadAllText(
  (Join-Path $runtime `
    'issue13-evidence-harness\issue13-v5-preparation-equivalence.R'),
  [Text.UTF8Encoding]::new($false, $true))
$materializedSelftest = [IO.File]::ReadAllText(
  (Join-Path $runtime 'issue13-evidence-harness\issue13-selftest.R'),
  [Text.UTF8Encoding]::new($false, $true))
$materializedDiagnosticBridgesPath = Join-Path $runtime `
  'issue13-evidence-harness\issue13-v5-diagnostic-module-bridges.csv'
$materializedStage5ProfilesPath = Join-Path $runtime `
  'issue13-evidence-harness\issue13-v5-stage5-multiplicity-profiles.csv'
if ((Get-Issue13V5Sha256 $materializedDiagnosticBridgesPath) -cne
      (Get-Issue13V5Sha256 $diagnosticBridgePath) -or
    (Get-Issue13V5Sha256 $materializedStage5ProfilesPath) -cne
      (Get-Issue13V5Sha256 $stage5ProfilePath) -or
    @(Import-Csv -LiteralPath $materializedDiagnosticBridgesPath `
      -Delimiter ';').Count -le 0 -or
    @(Import-Csv -LiteralPath $materializedStage5ProfilesPath `
      -Delimiter ';').Count -le 0) {
  throw 'Materialized diagnostic bridge/profile manifests are not sealed.'
}
foreach ($required in @(
    'cross_engine_source_v1',
    'cross_engine_source && (!identical(candidate$kind, "source")',
    'normalized = "file:_unit_contract.csv"'
  )) {
  if (-not $materializedCompare.Contains($required)) {
    throw "Materialized comparison runtime lacks source projection: $required"
  }
}
foreach ($required in @(
    'manifest_tables_equivalence_profile_exact',
    'source_equivalence <- wlv13_v5p_compare_source(',
    'source_unit_contract_bridge <- wlv13_v5d_compare_source_unit_contract(',
    'source_equivalence$unit_contract$cross_engine_bridge <-',
    'isTRUE(source_unit_contract_bridge$passed)',
    'csv[["_unit_contract.csv"]] <- source_equivalence$unit_contract',
    'csv[["_source_manifest.csv"]] <- source_equivalence$source_manifest',
    'wlv-issue13-preparation-rule-matrix/2'
  )) {
  if (-not $materializedPreparationCompare.Contains($required)) {
    throw "Materialized preparation runtime lacks exhaustive bridge: $required"
  }
}
foreach ($required in @(
    'sealed-exhaustive-source-manifest-equivalence',
    'sealed-exhaustive-unit-contract-equivalence',
    'wlv13_v5p_exact_table', 'file_sha256', 'table_sha256',
    'expected_file_sha256', 'expected_table_sha256',
    'wlv13_v5p_selftest <- function'
  )) {
  if (-not $materializedPreparationEquivalence.Contains($required)) {
    throw "Materialized preparation profile lacks exact binding: $required"
  }
}
foreach ($required in @(
    'sidecar_architecture_valid <- isTRUE(left_contract$legacy)',
    'identical(right_contract$schema_version, "1")',
    'identical(right_contract$fst_sha256, right_sha)',
    'baseline_sidecar_format = "legacy-positional"',
    'candidate_sidecar_format = "versioned-v1"'
  )) {
  if (-not $materializedPreparationLibrary.Contains($required)) {
    throw "Materialized preparation library lacks sidecar gate: $required"
  }
}
foreach ($required in @(
    'issue13-aggregate-core-selftest.R',
    'issue13-v5-compatibility-baseline-override.R',
    'output-v5-policy-reject',
    'V5 aggregate accepted a synthetic unbound baseline profile.',
    'identical(metadata_assertions, 626L)',
    'identical(diagnostic_assertions, 226L)',
    'identical(preparation_assertions, 173L)'
  )) {
  if (-not $materializedSelftest.Contains($required)) {
    throw "Materialized self-test lacks V5 aggregate separation: $required"
  }
}
$ruleMatrixPath = Join-Path $runtime 'issue13-preparation-rule-matrix.json'
$ruleMatrix = [IO.File]::ReadAllText(
  $ruleMatrixPath, [Text.UTF8Encoding]::new($false, $true)) |
  ConvertFrom-Json -DateKind String
$preparationMode = $ruleMatrix.comparison_modes.preparation_cross_engine
$faultMode = $ruleMatrix.comparison_modes.fault_within_engine
$manifestRule = @($preparationMode.rules | Where-Object {
  [string]$_.id -ceq 'source-manifests'
})
$contractRule = @($preparationMode.rules | Where-Object {
  [string]$_.id -ceq 'contracts-and-labels'
})
$arrayRule = @($preparationMode.rules | Where-Object {
  [string]$_.id -ceq 'normalized-arrays'
})
if ([string]$ruleMatrix.schema -cne
      'wlv-issue13-preparation-rule-matrix/2' -or
    [string]$preparationMode.candidate -cne
      'candidate-runtime-pinned-by-v5-config' -or
    [string]$faultMode.candidate -cne
      'candidate-runtime-pinned-by-v5-config' -or
    @($preparationMode.ignored_artifacts).Count -ne 0 -or
    [string]$preparationMode.numeric_tolerance -cne 'none-bitwise' -or
    $manifestRule.Count -ne 1 -or $contractRule.Count -ne 1 -or
    $arrayRule.Count -ne 1 -or
    -not ([string]$manifestRule[0].comparison).Contains(
      'complete controller-pinned source manifest table') -or
    -not ([string]$contractRule[0].comparison).Contains(
      'complete controller-pinned _unit_contract.csv table') -or
    -not ([string]$arrayRule[0].comparison).Contains(
      'candidate versioned-v1 sidecars')) {
  throw 'Materialized preparation rule matrix is not the sealed V5 equivalence contract.'
}

foreach ($bootstrapName in @(
    $bootstrapSourceFileSha256.Keys | Sort-Object)) {
  $bootstrapPath = Join-Path $root $bootstrapName
  $bootstrapFinalBytes = [IO.File]::ReadAllBytes($bootstrapPath)
  $bootstrapFinalHash = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($bootstrapFinalBytes))
  if ($bootstrapFinalHash -cne
      [string]$bootstrapSourceFileSha256[$bootstrapName]) {
    throw "Controller source changed during static verification: $bootstrapName"
  }
}

[pscustomobject][ordered]@{
  status = 'requires-terminal-reseal'
  r_started = $false
  terminal_reseal_required = $true
  generation = 'v5'
  baseline_commit = $script:Issue13V5BaselineCommit
  baseline_runtime_commit = $script:Issue13V5BaselineRuntimeCommit
  baseline_policy = [string]$manifest.baseline_policy
  controller_files = [object[]]$controllerRecords
  harness_file_count = [long]$inventory.file_count
  harness_inventory_sha256 = [string]$inventory.inventory_sha256
  expected_worktrees = 29
  expected_pairs = 76
  expected_scenarios = 162
  expected_comparisons = 202
  expected_faults = 10
}
