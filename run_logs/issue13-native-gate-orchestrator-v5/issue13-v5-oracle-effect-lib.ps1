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

$script:Issue13OracleEffectControllerRoot =
  [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\', '/')
$script:Issue13OracleEffectRequiredRPackages = @('fst', 'jsonlite', 'openssl')
$script:Issue13OracleEffectRClearedEnvironment = @(
  'LANG', 'LC_ALL', 'LC_CTYPE',
  'RENV_ACTIVATE_PROJECT', 'RENV_AUTOLOADER_ENABLED',
  'RENV_AUTOLOAD_ENABLED',
  'RENV_CONFIG_AUTOLOADER_ENABLED', 'RENV_CONFIG_EXTERNAL_LIBRARIES',
  'RENV_CONFIG_STARTUP_QUIET', 'RENV_CONFIG_SYNCHRONIZED_CHECK',
  'RENV_CONFIG_USER_PROFILE', 'RENV_PATHS_LIBRARY_ROOT',
  'RENV_PATHS_LIBRARY_ROOT_ASIS', 'RENV_PATHS_LOCKFILE',
  'RENV_PATHS_PREFIX', 'RENV_PATHS_PREFIX_AUTO', 'RENV_PATHS_RENV',
  'RENV_PATHS_ROOT', 'RENV_PATHS_SANDBOX', 'RENV_PATHS_VERSION',
  'RENV_PROCESS_TYPE', 'RENV_PROFILE', 'RENV_PROJECT',
  'RENV_SANDBOX_LOCKING_ENABLED', 'RENV_STARTUP_DIAGNOSTICS',
  'R_ARCH', 'R_DEFAULT_PACKAGES', 'R_ENVIRON', 'R_ENVIRON_USER', 'R_HOME',
  'R_LIBS', 'R_LIBS_SITE', 'R_PROFILE', 'R_PROFILE_USER', 'R_STARTUP_DEBUG'
)
$script:Issue13OracleEffectRSetEnvironment = [ordered]@{
  RENV_CONFIG_AUTO_SNAPSHOT = 'FALSE'
  RENV_CONFIG_CACHE_ENABLED = 'FALSE'
  RENV_CONFIG_LOCKING_ENABLED = 'FALSE'
  RENV_CONFIG_SANDBOX_ENABLED = 'FALSE'
  RENV_CONFIG_UPDATES_CHECK = 'FALSE'
  RENV_CONFIG_USER_ENVIRON = 'FALSE'
  RENV_CONFIG_USER_LIBRARY = 'FALSE'
  TZ = 'UTC'
}
$script:Issue13OracleEffectControllerFiles = @(
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
$script:Issue13OracleEffectSourceToolingRelativeRoot =
  'run_logs/issue13-evidence-source-v5'
$script:Issue13OracleEffectSourceToolingTreePaths = @(
  '.', 'issue13-evidence-harness'
)
$script:Issue13OracleEffectSourceToolingFiles = @(
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
$script:Issue13OracleEffectSourceToolingPathListSha256 =
  '7bf2e27807e9bc36d3d3766789439d0d9afdd7b2cc5127145ce0e0f6819db00d'
$script:Issue13OracleEffectRscriptLinkCount = 1L
$script:Issue13OracleEffectRscriptSizeBytes = 94720L
$script:Issue13OracleEffectRscriptSha256 =
  '3ad097e10d867e09eb7e54d8ed1f8ef933779b82be56482a04a27d65536d15f9'

function Assert-Issue13OracleEffect {
  param(
    [Parameter(Mandatory = $true)][AllowNull()][object]$Condition,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if (-not (Test-Issue13OracleEffectExactBoolean $Condition $true)) {
    throw "Issue #13 oracle-effect proof rejected: $Message"
  }
}

function Test-Issue13OracleEffectExactBoolean {
  param(
    [Parameter(Mandatory = $true)][AllowNull()][object]$Value,
    [Parameter(Mandatory = $true)][AllowNull()][object]$Expected
  )
  ($Value -is [bool]) -and ($Expected -is [bool]) -and
    ([bool]$Value -eq [bool]$Expected)
}

function Resolve-Issue13OracleEffectFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Label
  )
  Assert-Issue13OracleEffect (Test-Path -LiteralPath $Path -PathType Leaf) `
    "$Label does not exist as a file: $Path"
  $resolved = (Get-Item -LiteralPath $Path -Force).FullName
  Assert-Issue13OracleEffectNoReparseAncestors $resolved $Label
  $resolved
}

function Resolve-Issue13OracleEffectDirectory {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Label
  )
  Assert-Issue13OracleEffect (Test-Path -LiteralPath $Path -PathType Container) `
    "$Label does not exist as a directory: $Path"
  $resolved = (Get-Item -LiteralPath $Path -Force).FullName.TrimEnd('\', '/')
  Assert-Issue13OracleEffectNoReparseAncestors $resolved $Label
  $resolved
}

function Get-Issue13OracleEffectSha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-Issue13OracleEffectUtf8Sha256 {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
  $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
  $hasher = [Security.Cryptography.HashAlgorithm]::Create('SHA256')
  try {
    (($hasher.ComputeHash($bytes) | ForEach-Object {
      $_.ToString('x2')
    }) -join '')
  } finally {
    $hasher.Dispose()
  }
}

if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
  $oracleEffectNativePathAssembliesBefore =
    [Reflection.Assembly[]]@([AppDomain]::CurrentDomain.GetAssemblies())
  $preexistingOracleEffectNativePathTypes = [type[]]@(
    [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
      $_.GetType('Issue13V5.OracleEffectNativePath', $false, $true)
    } | Where-Object { $null -ne $_ })
  if ($preexistingOracleEffectNativePathTypes.Count -ne 0) {
    throw 'The oracle-effect native path type was preloaded.'
  }
  $oracleEffectNativePathTypes = [object[]]@(
    Add-Type -PassThru -ErrorAction Stop -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace Issue13V5 {
  public static class OracleEffectNativePath {
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
  $oracleEffectNativePathTargetTypes = [type[]]@(
    $oracleEffectNativePathTypes | Where-Object {
      [string]$_.FullName -ceq 'Issue13V5.OracleEffectNativePath'
    })
  $oracleEffectNativePathReturnedNames = [string[]]@(
    $oracleEffectNativePathTypes | ForEach-Object { $_.FullName } |
      Sort-Object)
  $oracleEffectNativePathNonTypes = [object[]]@(
    $oracleEffectNativePathTypes | Where-Object { $_ -isnot [type] })
  $oracleEffectNativePathReturnedAssemblies = [Reflection.Assembly[]]@(
    $oracleEffectNativePathTypes | ForEach-Object { $_.Assembly } |
      Select-Object -Unique)
  $oracleEffectNativePathAssemblyWasPreexisting = [object[]]@(
    $oracleEffectNativePathAssembliesBefore | Where-Object {
      [object]::ReferenceEquals(
        $_, $oracleEffectNativePathReturnedAssemblies[0])
    })
  $oracleEffectNativePathType =
    'Issue13V5.OracleEffectNativePath' -as [type]
  $loadedOracleEffectNativePathTypes = [type[]]@(
    [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
      $_.GetType('Issue13V5.OracleEffectNativePath', $false, $true)
    } | Where-Object { $null -ne $_ })
  $oracleEffectNativePathMethods = [string[]]@(
    $oracleEffectNativePathTargetTypes[0].GetMethods(
      [Reflection.BindingFlags]'Public, Static, DeclaredOnly') |
      ForEach-Object { $_.ToString() } | Sort-Object)
  if ($oracleEffectNativePathTypes.Count -ne 3 -or
      $oracleEffectNativePathTargetTypes.Count -ne 1 -or
      $oracleEffectNativePathNonTypes.Count -ne 0 -or
      $oracleEffectNativePathReturnedAssemblies.Count -ne 1 -or
      $oracleEffectNativePathAssemblyWasPreexisting.Count -ne 0 -or
      [string]::Join(',', $oracleEffectNativePathReturnedNames) -cne
        ('Issue13V5.OracleEffectNativePath,' +
          'Issue13V5.OracleEffectNativePath+ByHandleFileInformation,' +
          'Issue13V5.OracleEffectNativePath+FileIdInformation') -or
      $loadedOracleEffectNativePathTypes.Count -ne 1 -or
      $null -eq $oracleEffectNativePathType -or
      -not [object]::ReferenceEquals(
        $oracleEffectNativePathTargetTypes[0], $oracleEffectNativePathType) -or
      -not [object]::ReferenceEquals(
        $oracleEffectNativePathTargetTypes[0],
        $loadedOracleEffectNativePathTypes[0]) -or
      [string]::Join('|', $oracleEffectNativePathMethods) -cne
        'System.String DriveTarget(System.String)|System.String Identity(System.String)|System.String Resolve(System.String)') {
    throw 'The oracle-effect native path type compilation was not singular.'
  }
  New-Variable -Name Issue13OracleEffectNativePathType `
    -Scope Script -Option Constant -Value $oracleEffectNativePathTargetTypes[0]
}

function Test-Issue13OracleEffectForbiddenDriveTarget {
  param([Parameter(Mandatory = $true)][string]$Target)
  $Target.StartsWith('\??\', [StringComparison]::OrdinalIgnoreCase) -or
    $Target.StartsWith('\Device\Mup',
      [StringComparison]::OrdinalIgnoreCase) -or
    $Target.StartsWith('\Device\LanmanRedirector',
      [StringComparison]::OrdinalIgnoreCase) -or
    $Target.StartsWith('\Device\WebDavRedirector',
      [StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-Issue13OracleEffectPhysicalPath {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
  if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    return $full
  }
  $root = [IO.Path]::GetPathRoot($full)
  Assert-Issue13OracleEffect (
    -not [string]::IsNullOrWhiteSpace($root) -and
    $root -cmatch '^[A-Za-z]:\\$'
  ) "$Label must use a local drive-letter path: $full"
  $drive = [IO.DriveInfo]::new($root)
  Assert-Issue13OracleEffect (
    $drive.IsReady -and $drive.DriveType -eq [IO.DriveType]::Fixed
  ) "$Label must use a ready fixed local drive: $full"
  $target = $script:Issue13OracleEffectNativePathType::DriveTarget(
    $root.Substring(0, 2))
  Assert-Issue13OracleEffect (
    -not (Test-Issue13OracleEffectForbiddenDriveTarget $target)
  ) "$Label must not use a SUBST or mapped-drive alias: $full"
  $missing = [Collections.Generic.List[string]]::new()
  $cursor = $full
  while (-not (Test-Path -LiteralPath $cursor)) {
    $leaf = [IO.Path]::GetFileName($cursor)
    Assert-Issue13OracleEffect (
      -not [string]::IsNullOrWhiteSpace($leaf)
    ) "Cannot canonicalize $Label path: $full"
    $missing.Add($leaf)
    $parent = [IO.Directory]::GetParent($cursor)
    Assert-Issue13OracleEffect ($null -ne $parent) "Cannot find an existing ancestor for $Label path: $full"
    $cursor = $parent.FullName
  }
  $canonical = $script:Issue13OracleEffectNativePathType::Resolve($cursor).
    TrimEnd('\')
  for ($index = $missing.Count - 1; $index -ge 0; $index--) {
    $canonical = $canonical + '\' + $missing[$index]
  }
  $canonical.TrimEnd('\')
}

function Get-Issue13OracleEffectRscriptIdentity {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][object]$Spec
  )
  Assert-Issue13OracleEffect (
    [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
  ) 'Rscript physical identity requires Windows.'
  $validated = Resolve-Issue13OracleEffectFile $Path 'comparison Rscript'
  $logical = (Resolve-Path -LiteralPath $validated).Path
  Assert-Issue13OracleEffect ([IO.Path]::GetFileName($logical) -ceq
      'Rscript.exe') 'comparison Rscript must name Rscript.exe exactly.'
  $physical = ConvertTo-Issue13OracleEffectPhysicalPath $logical `
    'comparison Rscript'
  $rawIdentity = $script:Issue13OracleEffectNativePathType::Identity($logical)
  $parts = [string[]]$rawIdentity.Split(':')
  Assert-Issue13OracleEffect ($parts.Count -eq 3 -and
      $parts[0] -cmatch '^[0-9a-f]{16}$' -and
      $parts[1] -cmatch '^[0-9a-f]{32}$' -and
      $parts[2] -cmatch '^[0-9]+$') `
    'comparison Rscript returned an invalid physical identity.'
  $item = Get-Item -LiteralPath $logical -Force
  $identity = [pscustomobject][ordered]@{
    logical_path = $logical
    physical_path = $physical
    item_id = $parts[0] + ':' + $parts[1]
    link_count = [int64]$parts[2]
    size_bytes = [int64]$item.Length
    sha256 = Get-Issue13OracleEffectSha256 $logical
  }
  Assert-Issue13OracleEffectExactProperties $Spec @(
    'required_link_count', 'size_bytes', 'sha256'
  ) 'terminal Rscript spec'
  Assert-Issue13OracleEffect (
    [int64]$Spec.required_link_count -eq
      $script:Issue13OracleEffectRscriptLinkCount -and
    [int64]$Spec.size_bytes -eq
      $script:Issue13OracleEffectRscriptSizeBytes -and
    [string]$Spec.sha256 -ceq
      $script:Issue13OracleEffectRscriptSha256 -and
    [int64]$identity.link_count -eq [int64]$Spec.required_link_count -and
    [int64]$identity.size_bytes -eq [int64]$Spec.size_bytes -and
    [string]$identity.sha256 -ceq [string]$Spec.sha256
  ) 'comparison Rscript identity differs from the stable terminal pin.'
  $identity
}

function Assert-Issue13OracleEffectRscriptIdentity {
  param(
    [Parameter(Mandatory = $true)][object]$Observed,
    [Parameter(Mandatory = $true)][object]$Expected,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $fields = @(
    'logical_path', 'physical_path', 'item_id', 'link_count', 'size_bytes',
    'sha256'
  )
  Assert-Issue13OracleEffectExactProperties $Observed $fields $Label
  Assert-Issue13OracleEffectExactProperties $Expected $fields `
    "$Label expected"
  foreach ($record in @($Observed, $Expected)) {
    Assert-Issue13OracleEffect (
      $record.logical_path -is [string] -and
      -not [string]::IsNullOrWhiteSpace([string]$record.logical_path) -and
      $record.physical_path -is [string] -and
      -not [string]::IsNullOrWhiteSpace([string]$record.physical_path) -and
      $record.item_id -is [string] -and
      [string]$record.item_id -cmatch '^[0-9a-f]{16}:[0-9a-f]{32}$' -and
      $record.link_count -is [long] -and [long]$record.link_count -gt 0L -and
      $record.size_bytes -is [long] -and [long]$record.size_bytes -gt 0L -and
      $record.sha256 -is [string] -and
      [string]$record.sha256 -cmatch '^[0-9a-f]{64}$'
    ) "$Label contains an invalid Rscript identity field."
  }
  foreach ($field in $fields) {
    Assert-Issue13OracleEffect (
      [string]$Observed.$field -ceq [string]$Expected.$field
    ) "$Label differs: $field"
  }
  $true
}

function Test-Issue13OracleEffectPathEqual {
  param(
    [Parameter(Mandatory = $true)][string]$Left,
    [Parameter(Mandatory = $true)][string]$Right
  )
  $comparison = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
    [StringComparison]::OrdinalIgnoreCase
  } else {
    [StringComparison]::Ordinal
  }
  $leftPhysical = ConvertTo-Issue13OracleEffectPhysicalPath $Left 'left'
  $rightPhysical = ConvertTo-Issue13OracleEffectPhysicalPath $Right 'right'
  [string]::Equals($leftPhysical, $rightPhysical, $comparison)
}

function Test-Issue13OracleEffectPathContained {
  param(
    [Parameter(Mandatory = $true)][string]$Child,
    [Parameter(Mandatory = $true)][string]$Parent
  )
  $childFull = ConvertTo-Issue13OracleEffectPhysicalPath $Child 'child'
  $parentFull = ConvertTo-Issue13OracleEffectPhysicalPath $Parent 'parent'
  $comparison = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
    [StringComparison]::OrdinalIgnoreCase
  } else { [StringComparison]::Ordinal }
  if ([string]::Equals($childFull, $parentFull, $comparison)) { return $true }
  $separator = [IO.Path]::DirectorySeparatorChar
  $childFull.StartsWith($parentFull + $separator, $comparison)
}

function Assert-Issue13OracleEffectPathsDisjoint {
  param(
    [Parameter(Mandatory = $true)][string]$Left,
    [Parameter(Mandatory = $true)][string]$Right,
    [Parameter(Mandatory = $true)][string]$Label
  )
  Assert-Issue13OracleEffect (
    -not (Test-Issue13OracleEffectPathContained $Left $Right) -and
    -not (Test-Issue13OracleEffectPathContained $Right $Left)
  ) "$Label paths overlap: $Left ; $Right"
}

function Assert-Issue13OracleEffectProofPathIsolation {
  param(
    [Parameter(Mandatory = $true)][string]$ProofPath,
    [Parameter(Mandatory = $true)][string[]]$ProtectedRoots
  )
  $full = [IO.Path]::GetFullPath($ProofPath)
  $parent = Split-Path -Parent $full
  Assert-Issue13OracleEffect (
    Test-Path -LiteralPath $parent -PathType Container
  ) "proof output parent does not exist: $parent"
  Assert-Issue13OracleEffectNoReparseAncestors $parent 'proof output parent'
  $null = ConvertTo-Issue13OracleEffectPhysicalPath `
    $full 'oracle-effect proof path'
  Assert-Issue13OracleEffect ($ProtectedRoots.Count -gt 0) `
    'proof protected roots are empty.'
  foreach ($protectedRoot in $ProtectedRoots) {
    Assert-Issue13OracleEffect (
      -not [string]::IsNullOrWhiteSpace($protectedRoot)
    ) 'proof protected roots contain an empty path.'
    Assert-Issue13OracleEffectNoReparseAncestors `
      $protectedRoot 'proof protected root'
    $null = ConvertTo-Issue13OracleEffectPhysicalPath `
      $protectedRoot 'proof protected root'
    Assert-Issue13OracleEffectPathsDisjoint $full $protectedRoot `
      'oracle-effect proof/protected-root isolation'
  }
  $full
}

function Test-Issue13OracleEffectReparseAttribute {
  param([Parameter(Mandatory = $true)][IO.FileAttributes]$Attributes)
  ($Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

function Assert-Issue13OracleEffectNoReparseAncestors {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
  $current = if (Test-Path -LiteralPath $full) {
    $full
  } else {
    Split-Path -Parent $full
  }
  $comparison = if (
    [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
  ) { [StringComparison]::OrdinalIgnoreCase } else {
    [StringComparison]::Ordinal
  }
  while (-not [string]::IsNullOrWhiteSpace($current)) {
    if (Test-Path -LiteralPath $current) {
      $item = Get-Item -LiteralPath $current -Force
      Assert-Issue13OracleEffect (
        -not (Test-Issue13OracleEffectReparseAttribute $item.Attributes)
      ) "$Label has a reparse-point ancestor: $($item.FullName)"
    }
    $parent = Split-Path -Parent $current
    if ([string]::IsNullOrWhiteSpace($parent) -or
        [string]::Equals($parent, $current, $comparison)) { break }
    $current = $parent
  }
}

function Assert-Issue13OracleEffectNoReparseTree {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Label
  )
  Assert-Issue13OracleEffectNoReparseAncestors $Root $Label
  $items = @(
    Get-Item -LiteralPath $Root -Force
    Get-ChildItem -LiteralPath $Root -Recurse -Force
  )
  $reparse = @($items | Where-Object {
    Test-Issue13OracleEffectReparseAttribute $_.Attributes
  })
  $reparseNames = @($reparse | ForEach-Object { [string]$_.FullName })
  Assert-Issue13OracleEffect ($reparse.Count -eq 0) `
    "$Label contains a reparse point: $($reparseNames -join ', ')."
}

function Resolve-Issue13OracleEffectNewDirectoryPath {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
  Assert-Issue13OracleEffect (-not (Test-Path -LiteralPath $full)) `
    "$Label already exists; pre-fabricated comparison roots are forbidden: $full"
  $parent = Split-Path -Parent $full
  Assert-Issue13OracleEffect (Test-Path -LiteralPath $parent -PathType Container) `
    "$Label parent does not exist: $parent"
  $parentItem = Get-Item -LiteralPath $parent -Force
  Assert-Issue13OracleEffect (
    ($parentItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0
  ) "$Label parent is a reparse point."
  Assert-Issue13OracleEffectNoReparseAncestors $parent "$Label parent"
  $full
}

function Test-Issue13OracleEffectJsonSchemaFile {
  param(
    [Parameter(Mandatory = $true)][string]$JsonPath,
    [Parameter(Mandatory = $true)][string]$SchemaPath,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $json = [IO.File]::ReadAllText(
    (Resolve-Issue13OracleEffectFile $JsonPath $Label),
    [Text.UTF8Encoding]::new($false, $true)
  )
  try {
    $valid = $json | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop
  } catch {
    throw "Issue #13 oracle-effect proof rejected: $Label fails JSON Schema validation: $($_.Exception.Message)"
  }
  Assert-Issue13OracleEffect (
    Test-Issue13OracleEffectExactBoolean $valid $true
  ) `
    "$Label fails JSON Schema validation."
  $true
}

function Get-Issue13OracleEffectTextHash {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Keys,
    [Parameter(Mandatory = $true)][ValidateSet('MD5', 'SHA256')][string]$Algorithm
  )
  $ordered = [string[]]$Keys.Clone()
  [Array]::Sort($ordered, [StringComparer]::Ordinal)
  $bytes = [Text.Encoding]::UTF8.GetBytes(($ordered -join "`n"))
  $hasher = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
  try {
    (($hasher.ComputeHash($bytes) | ForEach-Object {
      $_.ToString('x2')
    }) -join '')
  } finally {
    $hasher.Dispose()
  }
}

function Read-Issue13OracleEffectJson {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $resolved = Resolve-Issue13OracleEffectFile $Path $Label
  $bytes = [IO.File]::ReadAllBytes($resolved)
  $encoding = New-Object Text.UTF8Encoding($false, $true)
  try {
    $text = $encoding.GetString($bytes)
  } catch {
    throw "Issue #13 oracle-effect proof rejected: $Label is not valid UTF-8."
  }
  Assert-Issue13OracleEffect (-not $text.Contains([char]0xFFFD)) `
    "$Label contains U+FFFD."
  try {
    $text | ConvertFrom-Json -DateKind String
  } catch {
    throw "Issue #13 oracle-effect proof rejected: $Label is not valid JSON: $($_.Exception.Message)"
  }
}

function Assert-Issue13OracleEffectExactSet {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Observed,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Expected,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $left = [string[]]$Observed.Clone()
  $right = [string[]]$Expected.Clone()
  [Array]::Sort($left, [StringComparer]::Ordinal)
  [Array]::Sort($right, [StringComparer]::Ordinal)
  Assert-Issue13OracleEffect (($left -join "`n") -ceq ($right -join "`n")) `
    "$Label differs. Observed=[$($left -join ', ')]; expected=[$($right -join ', ')]."
}

function Get-Issue13OracleEffectPropertyNames {
  param([Parameter(Mandatory = $true)][object]$Value)
  [string[]]@($Value.PSObject.Properties.Name)
}

function Assert-Issue13OracleEffectExactProperties {
  param(
    [Parameter(Mandatory = $true)][object]$Value,
    [Parameter(Mandatory = $true)][string[]]$Expected,
    [Parameter(Mandatory = $true)][string]$Label
  )
  Assert-Issue13OracleEffectExactSet `
    (Get-Issue13OracleEffectPropertyNames $Value) $Expected $Label
}

function Invoke-Issue13OracleEffectGit {
  param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )
  $lines = @(Invoke-Issue13V5SealedGit `
    -C $RepositoryRoot @Arguments 2>&1)
  Assert-Issue13OracleEffect ($LASTEXITCODE -eq 0) `
    "git $($Arguments -join ' ') failed: $($lines -join ' ')"
  (($lines | ForEach-Object { [string]$_ }) -join "`n").Trim()
}

function Get-Issue13OracleEffectGitBlobIdentity {
  param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][string]$Commit,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )
  $relative = Get-Issue13OracleEffectSafeRelativePath $RelativePath `
    'controller Git path'
  $objectSpec = "$Commit`:$relative"
  $blob = Invoke-Issue13OracleEffectGit $RepositoryRoot @(
    'rev-parse', $objectSpec
  )
  Assert-Issue13OracleEffect ($blob -cmatch '^[0-9a-f]{40}$') `
    "controller Git blob is malformed: $relative"
  $sizeText = Invoke-Issue13OracleEffectGit $RepositoryRoot @(
    'cat-file', '-s', $objectSpec
  )
  $size = [int64]0
  Assert-Issue13OracleEffect ([int64]::TryParse(
      $sizeText, [Globalization.NumberStyles]::None,
      [Globalization.CultureInfo]::InvariantCulture, [ref]$size
    ) -and $size -ge 0) "controller Git blob size is malformed: $relative"

  $raw = Invoke-Issue13V5GitRaw $RepositoryRoot @(
    'cat-file', 'blob', $objectSpec)
  Assert-Issue13OracleEffect `
    ([long]$raw.stdout.LongLength -eq $size) `
    "controller Git blob length changed: $relative"
  $sha = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
      [byte[]]$raw.stdout)).ToLowerInvariant()
  [pscustomobject][ordered]@{
    git_blob = $blob
    size_bytes = $size
    sha256 = $sha
  }
}

function Invoke-Issue13OracleEffectGitBytes {
  param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $raw = Invoke-Issue13V5GitRaw $RepositoryRoot $Arguments
  [byte[]]$raw.stdout
}

function ConvertFrom-Issue13OracleEffectGitText {
  param(
    [Parameter(Mandatory = $true)][byte[]]$Bytes,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $encoding = [Text.UTF8Encoding]::new($false, $true)
  try {
    $encoding.GetString($Bytes)
  } catch {
    throw "Issue #13 oracle-effect proof rejected: git returned non-UTF-8 text for $Label."
  }
}

function Get-Issue13OracleEffectGitLsTreeRecords {
  param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][string]$Commit,
    [Parameter(Mandatory = $true)][string]$RepositoryPath,
    [switch]$Recursive
  )
  $arguments = [Collections.Generic.List[string]]::new()
  foreach ($value in @('ls-tree', '-z', '--full-tree')) {
    $arguments.Add($value)
  }
  if ($Recursive) { $arguments.Add('-r') }
  foreach ($value in @($Commit, '--', $RepositoryPath)) {
    $arguments.Add($value)
  }
  $bytes = Invoke-Issue13OracleEffectGitBytes $RepositoryRoot `
    $arguments.ToArray() "ls-tree $RepositoryPath"
  Assert-Issue13OracleEffect ($bytes.Length -gt 1 -and
      $bytes[$bytes.Length - 1] -eq 0) `
    "git ls-tree is empty or not NUL-terminated: $RepositoryPath"
  $text = ConvertFrom-Issue13OracleEffectGitText $bytes `
    "ls-tree $RepositoryPath"
  $rows = [string[]]$text.Split([char]0)
  Assert-Issue13OracleEffect ($rows[$rows.Count - 1] -ceq '') `
    "git ls-tree lacks its terminal empty NUL field: $RepositoryPath"
  @(
    for ($index = 0; $index -lt $rows.Count - 1; $index++) {
      $match = [regex]::Match($rows[$index],
        '^([0-7]{6}) ([a-z]+) ([0-9a-f]{40})\t(.+)$')
      Assert-Issue13OracleEffect $match.Success `
        "malformed NUL-safe ls-tree record: $RepositoryPath"
      [pscustomobject][ordered]@{
        mode = $match.Groups[1].Value
        type = $match.Groups[2].Value
        object = $match.Groups[3].Value
        repository_path = $match.Groups[4].Value
      }
    }
  )
}

function Test-Issue13OracleEffectBytesEqual {
  param(
    [Parameter(Mandatory = $true)][byte[]]$Left,
    [Parameter(Mandatory = $true)][byte[]]$Right
  )
  if ($Left.Length -ne $Right.Length) { return $false }
  for ($index = 0; $index -lt $Left.Length; $index++) {
    if ($Left[$index] -ne $Right[$index]) { return $false }
  }
  $true
}

function Get-Issue13OracleEffectExpectedSourceTooling {
  param(
    [Parameter(Mandatory = $true)][object]$Spec,
    [Parameter(Mandatory = $true)][string]$ExpectedCandidateCommit,
    [Parameter(Mandatory = $true)][string]$RepositoryRoot
  )
  $repository = Resolve-Issue13OracleEffectDirectory $RepositoryRoot `
    'source-tooling repository root'
  Assert-Issue13OracleEffect ($ExpectedCandidateCommit -cmatch
      '^[0-9a-f]{40}$') `
    'source-tooling candidate commit is not lowercase 40-hex.'
  $resolvedCommitBytes = Invoke-Issue13OracleEffectGitBytes $repository @(
    'rev-parse', "$ExpectedCandidateCommit^{commit}"
  ) 'source-tooling candidate commit'
  $resolvedCommit = (ConvertFrom-Issue13OracleEffectGitText `
      $resolvedCommitBytes 'source-tooling candidate commit').Trim()
  Assert-Issue13OracleEffect ($resolvedCommit -ceq $ExpectedCandidateCommit) `
    'source-tooling candidate commit is unavailable or differs.'
  $sourceSpec = $Spec.terminal_comparison_runtime.source_tooling
  Assert-Issue13OracleEffectExactProperties $sourceSpec @(
    'repository_relative_root', 'file_count', 'directory_count',
    'path_list_sha256', 'tree_relative_paths', 'required_relative_paths',
    'tree_mode', 'file_mode'
  ) 'stable source-tooling spec'
  Assert-Issue13OracleEffect (
    [string]$sourceSpec.repository_relative_root -ceq
      $script:Issue13OracleEffectSourceToolingRelativeRoot -and
    [int64]$sourceSpec.file_count -eq 37L -and
    [int64]$sourceSpec.directory_count -eq 1L -and
    [string]$sourceSpec.path_list_sha256 -ceq
      $script:Issue13OracleEffectSourceToolingPathListSha256 -and
    [string]$sourceSpec.tree_mode -ceq '040000' -and
    [string]$sourceSpec.file_mode -ceq '100644'
  ) 'stable source-tooling scalar contract differs.'
  Assert-Issue13OracleEffectExactSet @($sourceSpec.tree_relative_paths) `
    $script:Issue13OracleEffectSourceToolingTreePaths `
    'stable source-tooling tree paths'
  Assert-Issue13OracleEffectExactSet @($sourceSpec.required_relative_paths) `
    $script:Issue13OracleEffectSourceToolingFiles `
    'stable source-tooling file paths'
  Assert-Issue13OracleEffect (
    [string]::Join("`n", @($sourceSpec.tree_relative_paths)) -ceq
      [string]::Join("`n", $script:Issue13OracleEffectSourceToolingTreePaths) -and
    [string]::Join("`n", @($sourceSpec.required_relative_paths)) -ceq
      [string]::Join("`n", $script:Issue13OracleEffectSourceToolingFiles)
  ) 'stable source-tooling path order differs.'
  $pathList = Get-Issue13OracleEffectUtf8Sha256 (
    [string]::Join("`n", @($sourceSpec.required_relative_paths)))
  Assert-Issue13OracleEffect ($pathList -ceq
      [string]$sourceSpec.path_list_sha256) `
    'stable source-tooling path-list hash differs.'
  $root = Resolve-Issue13OracleEffectDirectory (
    Join-Path $repository ([string]$sourceSpec.repository_relative_root)) `
    'tracked source-tooling root'
  $physicalRoot = ConvertTo-Issue13OracleEffectPhysicalPath $root `
    'tracked source-tooling root'
  Assert-Issue13OracleEffectNoReparseTree $root 'tracked source-tooling root'
  $localDirectories = @(Get-ChildItem -LiteralPath $root -Directory `
    -Recurse -Force)
  $localDirectoryPaths = [string[]]@($localDirectories | ForEach-Object {
    $_.FullName.Substring($root.Length + 1).Replace('\', '/')
  })
  [Array]::Sort($localDirectoryPaths, [StringComparer]::Ordinal)
  Assert-Issue13OracleEffect ($localDirectoryPaths.Count -eq 1 -and
      $localDirectoryPaths[0] -ceq 'issue13-evidence-harness') `
    'tracked source-tooling physical directory topology differs.'
  $treeRecords = @(
    foreach ($relativeTree in @($sourceSpec.tree_relative_paths)) {
      $repositoryPath = if ([string]$relativeTree -ceq '.') {
        [string]$sourceSpec.repository_relative_root
      } else {
        [string]$sourceSpec.repository_relative_root + '/' +
          [string]$relativeTree
      }
      $rows = @(Get-Issue13OracleEffectGitLsTreeRecords $repository `
        $ExpectedCandidateCommit $repositoryPath)
      Assert-Issue13OracleEffect ($rows.Count -eq 1 -and
          [string]$rows[0].repository_path -ceq $repositoryPath -and
          [string]$rows[0].mode -ceq [string]$sourceSpec.tree_mode -and
          [string]$rows[0].type -ceq 'tree') `
        "source-tooling Git tree differs: $relativeTree"
      $treeTypeBytes = Invoke-Issue13OracleEffectGitBytes $repository @(
        'cat-file', '-t', [string]$rows[0].object
      ) "source-tooling tree type $relativeTree"
      $treeType = (ConvertFrom-Issue13OracleEffectGitText $treeTypeBytes `
        "source-tooling tree type $relativeTree").Trim()
      Assert-Issue13OracleEffect ($treeType -ceq 'tree') `
        "source-tooling object is not a tree: $relativeTree"
      [pscustomobject][ordered]@{
        relative_path = [string]$relativeTree
        repository_path = $repositoryPath
        mode = [string]$rows[0].mode
        type = [string]$rows[0].type
        tree = [string]$rows[0].object
      }
    }
  )
  $gitFiles = @(Get-Issue13OracleEffectGitLsTreeRecords $repository `
    $ExpectedCandidateCommit ([string]$sourceSpec.repository_relative_root) `
    -Recursive)
  Assert-Issue13OracleEffect ($gitFiles.Count -eq 37) `
    'source-tooling recursive Git file count differs from 37.'
  $rawRecords = @(
    foreach ($gitFile in $gitFiles) {
      $prefix = [string]$sourceSpec.repository_relative_root + '/'
      Assert-Issue13OracleEffect (
        ([string]$gitFile.repository_path).StartsWith(
          $prefix, [StringComparison]::Ordinal)
      ) 'source-tooling Git file escaped its repository root.'
      $relative = [string]$gitFile.repository_path.Substring($prefix.Length)
      Assert-Issue13OracleEffect (
        [string]$gitFile.mode -ceq [string]$sourceSpec.file_mode -and
        [string]$gitFile.type -ceq 'blob'
      ) "source-tooling Git file mode/type differs: $relative"
      $local = Resolve-Issue13OracleEffectFile (
        Join-Path $root $relative.Replace('/', '\')) `
        "source-tooling local file $relative"
      $blobBytes = Invoke-Issue13OracleEffectGitBytes $repository @(
        'cat-file', 'blob', [string]$gitFile.object
      ) "source-tooling blob $relative"
      $localBytes = [IO.File]::ReadAllBytes($local)
      Assert-Issue13OracleEffect (
        Test-Issue13OracleEffectBytesEqual $localBytes $blobBytes
      ) "source-tooling local bytes differ from Git blob: $relative"
      $hashObjectBytes = Invoke-Issue13OracleEffectGitBytes $repository @(
        'hash-object', '--no-filters', '--', $local
      ) "source-tooling hash-object $relative"
      $localBlob = (ConvertFrom-Issue13OracleEffectGitText $hashObjectBytes `
        "source-tooling hash-object $relative").Trim()
      Assert-Issue13OracleEffect ($localBlob -ceq
          [string]$gitFile.object) `
        "source-tooling hash-object differs from Git blob: $relative"
      [pscustomobject][ordered]@{
        relative_path = $relative
        repository_path = [string]$gitFile.repository_path
        size_bytes = [int64]$localBytes.Length
        sha256 = Get-Issue13OracleEffectSha256 $local
        mode = [string]$gitFile.mode
        type = [string]$gitFile.type
        blob = [string]$gitFile.object
      }
    }
  )
  $recordMap = [Collections.Generic.Dictionary[string, object]]::new(
    [StringComparer]::Ordinal)
  foreach ($record in $rawRecords) {
    Assert-Issue13OracleEffect ($recordMap.TryAdd(
        [string]$record.relative_path, $record)) `
      "source-tooling Git returned a duplicate file: $($record.relative_path)"
  }
  $records = [object[]]@(
    foreach ($relative in @($sourceSpec.required_relative_paths)) {
      Assert-Issue13OracleEffect ($recordMap.ContainsKey([string]$relative)) `
        "source-tooling Git/local file is missing: $relative"
      $recordMap[[string]$relative]
    }
  )
  Assert-Issue13OracleEffect ($recordMap.Count -eq $records.Count) `
    'source-tooling Git returned a file outside the stable allowlist.'
  Assert-Issue13OracleEffect (
    [string]::Join("`n", @($records.relative_path)) -ceq
      [string]::Join("`n", @($sourceSpec.required_relative_paths))
  ) 'source-tooling Git/local file set or order differs.'
  $physicalFiles = @(Get-ChildItem -LiteralPath $root -File -Recurse -Force)
  Assert-Issue13OracleEffect ($physicalFiles.Count -eq 37) `
    'source-tooling physical file count differs from 37.'
  $inventoryPayload = [string]::Join("`n", @($records | ForEach-Object {
    [string]$_.relative_path + '|' + [string]$_.size_bytes + '|' +
      [string]$_.sha256
  }))
  [pscustomobject][ordered]@{
    candidate_commit = $ExpectedCandidateCommit
    repository_relative_root = [string]$sourceSpec.repository_relative_root
    root = $root
    physical_root = $physicalRoot
    file_count = [int64]$records.Count
    directory_count = [int64]$localDirectoryPaths.Count
    total_bytes = [int64](($records | Measure-Object size_bytes -Sum).Sum)
    path_list_sha256 = $pathList
    inventory_sha256 = Get-Issue13OracleEffectUtf8Sha256 $inventoryPayload
    trees = [object[]]$treeRecords
    records = [object[]]$records
  }
}

function Assert-Issue13OracleEffectSourceTooling {
  param(
    [Parameter(Mandatory = $true)][object]$Observed,
    [Parameter(Mandatory = $true)][object]$Expected,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $fields = @(
    'candidate_commit', 'repository_relative_root', 'root', 'physical_root',
    'file_count', 'directory_count', 'total_bytes', 'path_list_sha256',
    'inventory_sha256', 'trees', 'records'
  )
  Assert-Issue13OracleEffectExactProperties $Observed $fields $Label
  Assert-Issue13OracleEffectExactProperties $Expected $fields `
    "$Label expected"
  Assert-Issue13OracleEffect (
    ($Observed | ConvertTo-Json -Depth 30 -Compress) -ceq
      ($Expected | ConvertTo-Json -Depth 30 -Compress)
  ) "$Label differs from independently derived Git/local source tooling."
  $true
}

function Assert-Issue13OracleEffectControllerRecords {
  param(
    [Parameter(Mandatory = $true)][object[]]$Observed,
    [Parameter(Mandatory = $true)][object[]]$Expected,
    [Parameter(Mandatory = $true)][string]$Label
  )
  Assert-Issue13OracleEffect ($Observed.Count -eq $Expected.Count) `
    "$Label controller record count differs."
  Assert-Issue13OracleEffectExactSet `
    @($Observed | ForEach-Object { [string]$_.name }) `
    @($Expected | ForEach-Object { [string]$_.name }) "$Label controller names"
  foreach ($expectedRecord in $Expected) {
    $matches = @($Observed | Where-Object {
      [string]$_.name -ceq [string]$expectedRecord.name
    })
    Assert-Issue13OracleEffect ($matches.Count -eq 1) `
      "$Label controller record is missing or duplicated: $($expectedRecord.name)"
    foreach ($field in @('name', 'relative_path', 'sha256', 'git_blob')) {
      Assert-Issue13OracleEffect (
        [string]$matches[0].$field -ceq [string]$expectedRecord.$field
      ) "$Label controller record differs: name=$($expectedRecord.name) field=$field"
    }
  }
  $true
}

function Get-Issue13OracleEffectExpectedController {
  param(
    [Parameter(Mandatory = $true)][object]$Spec,
    [Parameter(Mandatory = $true)][string]$ExpectedCandidateCommit,
    [Parameter(Mandatory = $true)][string]$RepositoryRoot
  )
  $repository = Resolve-Issue13OracleEffectDirectory $RepositoryRoot `
    'controller repository root'
  $controllerRoot = Resolve-Issue13OracleEffectDirectory `
    $script:Issue13OracleEffectControllerRoot 'oracle-effect controller root'
  Assert-Issue13OracleEffect (
    Test-Issue13OracleEffectPathContained $controllerRoot $repository
  ) 'oracle-effect controller root is outside RepositoryRoot.'
  $relativeRoot = $controllerRoot.Substring($repository.Length).
    TrimStart('\', '/').Replace('\', '/')
  $names = [string[]]@(
    $Spec.terminal_comparison_runtime.required_controller_files)
  Assert-Issue13OracleEffect ($names.Count -gt 0 -and
      @($names | Select-Object -Unique).Count -eq $names.Count) `
    'terminal controller filename contract is empty or duplicated.'
  $records = @(
    foreach ($name in $names) {
      Assert-Issue13OracleEffect ($name -cmatch '^[A-Za-z0-9._-]+$') `
        "terminal controller filename is unsafe: $name"
      $local = Resolve-Issue13OracleEffectFile (Join-Path $controllerRoot $name) `
        "terminal controller source $name"
      $relative = Get-Issue13OracleEffectSafeRelativePath `
        ($relativeRoot + '/' + $name) "terminal controller Git path $name"
      $blob = Get-Issue13OracleEffectGitBlobIdentity $repository `
        $ExpectedCandidateCommit $relative
      Assert-Issue13OracleEffect ([int64](Get-Item -LiteralPath $local).Length -eq
          [int64]$blob.size_bytes -and
          (Get-Issue13OracleEffectSha256 $local) -ceq [string]$blob.sha256) `
        "terminal controller working bytes differ from candidate blob: $relative"
      $localBlob = Invoke-Issue13OracleEffectGit $repository @(
        'hash-object', '--', $local
      )
      Assert-Issue13OracleEffect ($localBlob -ceq [string]$blob.git_blob) `
        "terminal controller Git object differs from candidate blob: $relative"
      [pscustomobject][ordered]@{
        name = $name
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
    commit_sha256 = $ExpectedCandidateCommit
    file_count = [int64]$records.Count
    inventory_sha256 = Get-Issue13OracleEffectUtf8Sha256 $payload
    records = $records
  }
}

function Get-Issue13OracleEffectRenvLibraryRoot {
  param([Parameter(Mandatory = $true)][string]$RLibrary)
  Assert-Issue13OracleEffect (-not [string]::IsNullOrWhiteSpace($RLibrary)) `
    'renv library root requires an R library path.'
  $library = [IO.Path]::GetFullPath($RLibrary).TrimEnd('\', '/')
  $architecture = [IO.DirectoryInfo]::new($library)
  $version = $architecture.Parent
  $platform = if ($null -eq $version) { $null } else { $version.Parent }
  $root = if ($null -eq $platform) { $null } else { $platform.Parent }
  Assert-Issue13OracleEffect (
    $null -ne $version -and $null -ne $platform -and $null -ne $root -and
    $architecture.Name -cmatch '^[A-Za-z0-9._+-]+$' -and
    $version.Name -cmatch '^R-[0-9]+[.][0-9]+$' -and
    $platform.Name -cmatch '^[A-Za-z0-9._+-]+$' -and
    $root.Name -ceq 'library'
  ) 'R library lacks the sealed renv profile layout.'
  $reconstructed = [IO.Path]::GetFullPath([IO.Path]::Combine(
      $root.FullName, $platform.Name, $version.Name, $architecture.Name
    )).TrimEnd('\', '/')
  Assert-Issue13OracleEffect (
    [string]::Equals(
      $reconstructed, $library, [StringComparison]::OrdinalIgnoreCase)
  ) 'sealed renv library root reconstruction differs.'
  $root.FullName.TrimEnd('\', '/')
}

function Get-Issue13OracleEffectEnvironmentContract {
  param([Parameter(Mandatory = $true)][string]$RLibrary)
  $values = [ordered]@{}
  $values['R_LIBS_USER'] = $RLibrary
  $values['RENV_PATHS_LIBRARY'] =
    Get-Issue13OracleEffectRenvLibraryRoot $RLibrary
  foreach ($entry in $script:Issue13OracleEffectRSetEnvironment.GetEnumerator()) {
    $values[[string]$entry.Key] = [string]$entry.Value
  }
  $setNames = [string[]]@($values.Keys)
  [Array]::Sort($setNames, [StringComparer]::Ordinal)
  $set = @(
    foreach ($name in $setNames) {
      [pscustomobject][ordered]@{
        name = $name
        value = [string]$values[$name]
      }
    }
  )
  [pscustomobject][ordered]@{
    set = $set
    cleared = [string[]]$script:Issue13OracleEffectRClearedEnvironment
  }
}

function Assert-Issue13OracleEffectProcessEnvironmentName {
  param([Parameter(Mandatory = $true)][string]$Name)
  Assert-Issue13OracleEffect (
    $Name -cmatch '^[A-Za-z_][A-Za-z0-9_]*$'
  ) "unsafe process environment variable name: $Name"
  $Name
}

function Get-Issue13OracleEffectProcessEnvironmentState {
  param([Parameter(Mandatory = $true)][string]$Name)
  $validated = Assert-Issue13OracleEffectProcessEnvironmentName $Name
  $matches = @(
    [Environment]::GetEnvironmentVariables(
      [EnvironmentVariableTarget]::Process).GetEnumerator() |
      Where-Object {
        [string]::Equals([string]$_.Key, $validated,
          [StringComparison]::OrdinalIgnoreCase)
      }
  )
  Assert-Issue13OracleEffect ($matches.Count -le 1) `
    "process environment contains duplicate case aliases: $validated"
  [pscustomobject][ordered]@{
    name = $validated
    present = ($matches.Count -eq 1)
    value = if ($matches.Count -eq 1) { [string]$matches[0].Value } else { $null }
  }
}

function Test-Issue13OracleEffectProcessEnvironmentState {
  param(
    [Parameter(Mandatory = $true)][object]$Observed,
    [Parameter(Mandatory = $true)][object]$Expected
  )
  $fields = @('name', 'present', 'value')
  Assert-Issue13OracleEffectExactProperties $Observed $fields `
    'observed process environment state'
  Assert-Issue13OracleEffectExactProperties $Expected $fields `
    'expected process environment state'
  if (-not [string]::Equals([string]$Observed.name, [string]$Expected.name,
      [StringComparison]::OrdinalIgnoreCase) -or
      -not (Test-Issue13OracleEffectExactBoolean `
        $Observed.present $Expected.present)) {
    return $false
  }
  if (Test-Issue13OracleEffectExactBoolean $Expected.present $true) {
    return ($Observed.value -is [string]) -and
      ($Expected.value -is [string]) -and
      ([string]$Observed.value -ceq [string]$Expected.value)
  }
  ($null -eq $Observed.value) -and ($null -eq $Expected.value)
}

function Set-Issue13OracleEffectProcessEnvironmentState {
  param([Parameter(Mandatory = $true)][object]$State)
  Assert-Issue13OracleEffectExactProperties $State @(
    'name', 'present', 'value'
  ) 'process environment target state'
  $name = Assert-Issue13OracleEffectProcessEnvironmentName `
    ([string]$State.name)
  Assert-Issue13OracleEffect ($State.present -is [bool]) `
    "process environment presence is not boolean: $name"
  if (Test-Issue13OracleEffectExactBoolean $State.present $true) {
    Assert-Issue13OracleEffect ($State.value -is [string]) `
      "present process environment value is not a string: $name"
    [Environment]::SetEnvironmentVariable(
      $name, [string]$State.value, [EnvironmentVariableTarget]::Process)
  } else {
    Assert-Issue13OracleEffect ($null -eq $State.value) `
      "absent process environment state carries a value: $name"
    if ((Get-Issue13OracleEffectProcessEnvironmentState $name).present) {
      Remove-Item -LiteralPath ('Env:' + $name) -ErrorAction Stop
    }
  }
  $observed = Get-Issue13OracleEffectProcessEnvironmentState $name
  Assert-Issue13OracleEffect (
    Test-Issue13OracleEffectProcessEnvironmentState $observed $State
  ) "process environment target state was not installed: $name"
  $observed
}

function Enter-Issue13OracleEffectSanitizedREnvironment {
  param(
    [Parameter(Mandatory = $true)][string]$RLibrary,
    [scriptblock]$MutationObserver
  )
  $contract = Get-Issue13OracleEffectEnvironmentContract $RLibrary
  $seen = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  $targets = [Collections.Generic.List[object]]::new()
  foreach ($nameValue in @($contract.cleared)) {
    Assert-Issue13OracleEffect ($nameValue -is [string]) `
      'cleared process environment name is not a string.'
    $name = Assert-Issue13OracleEffectProcessEnvironmentName `
      ([string]$nameValue)
    Assert-Issue13OracleEffect ($seen.Add($name)) `
      "duplicate cleared process environment name: $name"
    $targets.Add([pscustomobject][ordered]@{
      name = $name; present = $false; value = $null
    })
  }
  foreach ($record in @($contract.set)) {
    Assert-Issue13OracleEffectExactProperties $record @('name', 'value') `
      'set process environment record'
    $name = Assert-Issue13OracleEffectProcessEnvironmentName `
      ([string]$record.name)
    Assert-Issue13OracleEffect ($record.value -is [string]) `
      "set process environment value is not a string: $name"
    Assert-Issue13OracleEffect ($seen.Add($name)) `
      "set/cleared process environment names overlap or duplicate: $name"
    $targets.Add([pscustomobject][ordered]@{
      name = $name; present = $true; value = [string]$record.value
    })
  }
  $previous = [object[]]@($targets | ForEach-Object {
    Get-Issue13OracleEffectProcessEnvironmentState ([string]$_.name)
  })
  $applied = [Collections.Generic.List[object]]::new()
  try {
    for ($index = 0; $index -lt $targets.Count; $index++) {
      $applied.Add($previous[$index])
      $null = Set-Issue13OracleEffectProcessEnvironmentState $targets[$index]
      if ($null -ne $MutationObserver) {
        & $MutationObserver ([string]$targets[$index].name) ($index + 1)
      }
    }
  } catch {
    $enterError = $_
    $rollbackErrors = [Collections.Generic.List[string]]::new()
    for ($index = $applied.Count - 1; $index -ge 0; $index--) {
      try {
        $null = Set-Issue13OracleEffectProcessEnvironmentState $applied[$index]
      } catch {
        $rollbackErrors.Add($_.Exception.Message)
      }
    }
    $suffix = if ($rollbackErrors.Count -eq 0) { '' } else {
      '; rollback failures: ' + [string]::Join(' | ', $rollbackErrors)
    }
    throw [InvalidOperationException]::new(
      'sanitized R environment entry failed: ' +
      $enterError.Exception.Message + $suffix, $enterError.Exception)
  }
  [pscustomobject][ordered]@{
    previous = $previous
    contract = $contract
  }
}

function Exit-Issue13OracleEffectSanitizedREnvironment {
  param([Parameter(Mandatory = $true)][object]$State)
  Assert-Issue13OracleEffectExactProperties $State @('previous', 'contract') `
    'sanitized R environment state'
  $previous = @($State.previous)
  $errors = [Collections.Generic.List[string]]::new()
  for ($index = $previous.Count - 1; $index -ge 0; $index--) {
    try {
      $null = Set-Issue13OracleEffectProcessEnvironmentState $previous[$index]
    } catch {
      $errors.Add($_.Exception.Message)
    }
  }
  if ($errors.Count -ne 0) {
    throw [InvalidOperationException]::new(
      'sanitized R environment restoration failed: ' +
      [string]::Join(' | ', $errors))
  }
}

function Invoke-Issue13OracleEffectWithProcessEnvironment {
  param(
    [Parameter(Mandatory = $true)][string]$RLibrary,
    [Parameter(Mandatory = $true)][scriptblock]$Action
  )
  $state = Enter-Issue13OracleEffectSanitizedREnvironment $RLibrary
  $result = $null
  $actionError = $null
  try {
    $result = @(& $Action)
  } catch {
    $actionError = $_
  }
  $restoreError = $null
  try {
    Exit-Issue13OracleEffectSanitizedREnvironment $state
  } catch {
    $restoreError = $_
  }
  if ($null -ne $actionError -and $null -ne $restoreError) {
    throw [AggregateException]::new(
      'Sanitized R environment action and restoration failed.',
      [Exception[]]@($actionError.Exception, $restoreError.Exception))
  }
  if ($null -ne $actionError) { throw $actionError }
  if ($null -ne $restoreError) { throw $restoreError }
  $result
}

function Invoke-Issue13OracleEffectWithLocation {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][scriptblock]$Action
  )
  $target = Resolve-Issue13OracleEffectDirectory $Path `
    'Oracle-effect command working directory'
  $previousLocation = Get-Location
  Assert-Issue13OracleEffect (
    [string]$previousLocation.Provider.Name -ceq 'FileSystem'
  ) 'Oracle-effect command requires a filesystem current location.'
  $result = $null
  $actionError = $null
  try {
    Set-Location -LiteralPath $target
    $result = @(& $Action)
  } catch {
    $actionError = $_
  }
  $restoreError = $null
  try {
    Set-Location -LiteralPath ([string]$previousLocation.Path)
  } catch {
    $restoreError = $_
  }
  if ($null -ne $actionError -and $null -ne $restoreError) {
    throw [AggregateException]::new(
      'Oracle-effect command action and location restoration failed.',
      [Exception[]]@($actionError.Exception, $restoreError.Exception))
  }
  if ($null -ne $actionError) { throw $actionError }
  if ($null -ne $restoreError) { throw $restoreError }
  $result
}

function Get-Issue13OracleEffectDirectoryInventory {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $resolved = Resolve-Issue13OracleEffectDirectory $Root $Label
  Assert-Issue13OracleEffectNoReparseTree $resolved $Label
  $files = @(Get-ChildItem -LiteralPath $resolved -File -Recurse -Force)
  $records = @($files | ForEach-Object {
    [pscustomobject][ordered]@{
      relative_path = $_.FullName.Substring($resolved.Length + 1).
        Replace('\', '/')
      size_bytes = [int64]$_.Length
      sha256 = Get-Issue13OracleEffectSha256 $_.FullName
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
    inventory_sha256 = Get-Issue13OracleEffectUtf8Sha256 $payload
  }
}

function Get-Issue13OracleEffectRRuntime {
  param(
    [Parameter(Mandatory = $true)][string]$Rscript,
    [Parameter(Mandatory = $true)][string]$RLibrary,
    [Parameter(Mandatory = $true)][string]$ProjectRoot
  )
  $rscriptPath = Resolve-Issue13OracleEffectFile $Rscript 'comparison Rscript'
  $libraryPath = Resolve-Issue13OracleEffectDirectory $RLibrary `
    'comparison R library'
  $projectPath = Resolve-Issue13OracleEffectDirectory $ProjectRoot `
    'activation source project'
  Assert-Issue13OracleEffectNoReparseTree $libraryPath `
    'comparison R library'
  Assert-Issue13OracleEffectNoReparseTree $projectPath `
    'activation source project'
  $renvLibraryRoot = Get-Issue13OracleEffectRenvLibraryRoot $libraryPath
  $activationSource = Resolve-Issue13OracleEffectFile `
    (Join-Path $projectPath 'renv\activate.R') 'renv activation source'
  $lockfileSource = Resolve-Issue13OracleEffectFile `
    (Join-Path $projectPath 'renv.lock') 'renv activation lockfile'
  $settingsSource = Resolve-Issue13OracleEffectFile `
    (Join-Path $projectPath 'renv\settings.json') 'renv activation settings'
  $ignoreSource = Resolve-Issue13OracleEffectFile `
    (Join-Path $projectPath 'renv\.gitignore') 'renv activation ignore file'
  $descriptionSource = Resolve-Issue13OracleEffectFile `
    (Join-Path $projectPath 'DESCRIPTION') 'renv activation DESCRIPTION'
  $probeCopies = [object[]]@(
    [pscustomobject][ordered]@{
      relative_path = 'DESCRIPTION'
      source = $descriptionSource
      size_bytes = [int64](Get-Item -LiteralPath $descriptionSource).Length
      sha256 = Get-Issue13OracleEffectSha256 $descriptionSource
    }
    [pscustomobject][ordered]@{
      relative_path = 'renv.lock'
      source = $lockfileSource
      size_bytes = [int64](Get-Item -LiteralPath $lockfileSource).Length
      sha256 = Get-Issue13OracleEffectSha256 $lockfileSource
    }
    [pscustomobject][ordered]@{
      relative_path = 'renv/.gitignore'
      source = $ignoreSource
      size_bytes = [int64](Get-Item -LiteralPath $ignoreSource).Length
      sha256 = Get-Issue13OracleEffectSha256 $ignoreSource
    }
    [pscustomobject][ordered]@{
      relative_path = 'renv/activate.R'
      source = $activationSource
      size_bytes = [int64](Get-Item -LiteralPath $activationSource).Length
      sha256 = Get-Issue13OracleEffectSha256 $activationSource
    }
    [pscustomobject][ordered]@{
      relative_path = 'renv/settings.json'
      source = $settingsSource
      size_bytes = [int64](Get-Item -LiteralPath $settingsSource).Length
      sha256 = Get-Issue13OracleEffectSha256 $settingsSource
    }
  )
  Assert-Issue13OracleEffect (
    $probeCopies.Count -eq 5 -and
    @($probeCopies.relative_path | Select-Object -Unique).Count -eq 5 -and
    [string]::Join("`n", @($probeCopies.relative_path)) -ceq
      "DESCRIPTION`nrenv.lock`nrenv/.gitignore`nrenv/activate.R`nrenv/settings.json"
  ) 'renv activation probe input inventory is not exact.'
  $libraryInventoryBefore = Get-Issue13OracleEffectDirectoryInventory `
    $libraryPath 'comparison R library before activation probe'
  $expression = @'
arguments <- commandArgs(TRUE)
if (length(arguments) != 1L) {
  stop("activation probe received invalid arguments", call. = FALSE)
}
project <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
activation <- file.path(project, "renv", "activate.R")
project_library <- file.path(project, "renv", "library")
Sys.setenv(RENV_PROJECT = project)
leaf <- normalizePath(Sys.getenv("R_LIBS_USER"),
  winslash = "/", mustWork = TRUE)
root <- normalizePath(Sys.getenv("RENV_PATHS_LIBRARY"),
  winslash = "/", mustWork = TRUE)
project_entries <- sort(list.files(
  project, all.files = TRUE, recursive = TRUE, full.names = FALSE,
  include.dirs = TRUE, no.. = TRUE
), method = "radix")
expected_entries <- sort(c(
  "DESCRIPTION", "renv", "renv.lock", "renv/.gitignore",
  "renv/activate.R", "renv/settings.json"
), method = "radix")
if (!identical(project_entries, expected_entries) ||
    file.exists(file.path(project, ".Renviron")) ||
    file.exists(file.path(project, ".Rprofile")) ||
    file.exists(file.path(project, "renv", "profile")) ||
    file.exists(file.path(project, "renv", "settings.R")) ||
    file.exists(project_library)) {
  stop("isolated activation project contains an implicit input", call. = FALSE)
}
renv_namespace <- loadNamespace("renv", lib.loc = leaf)
root_environ <- get("renv_paths_root", envir = renv_namespace)(".Renviron")
if (file.exists(root_environ)) {
  stop("renv root environment file is an implicit input", call. = FALSE)
}
root_projects <- get("renv_paths_root", envir = renv_namespace)("projects")
root_renvignore <- get("renv_paths_root", envir = renv_namespace)("renvignore")
capture_root_file <- function(path) {
  if (!file.exists(path)) return(list(exists = FALSE, bytes = raw()))
  size <- file.info(path)$size
  if (is.na(size) || size < 0 || size > .Machine$integer.max) {
    stop("renv global state file has an invalid size", call. = FALSE)
  }
  list(
    exists = TRUE,
    bytes = readBin(path, what = "raw", n = as.integer(size))
  )
}
global_projects_before <- capture_root_file(root_projects)
global_renvignore_before <- capture_root_file(root_renvignore)
unloadNamespace("renv")
activation_messages <- character()
activation_output <- capture.output({
  activation_messages <- capture.output(
    suppressWarnings(source(activation, local = TRUE)), type = "message"
  )
}, type = "output")
activation_console <- c(activation_output, activation_messages)
forbidden_activation <- grepl(
  paste(c(
    "bootstrapping renv", "downloading renv", "installing renv",
    "installing package"
  ), collapse = "|"),
  activation_console, ignore.case = TRUE, perl = TRUE
)
if (any(forbidden_activation) || file.exists(project_library)) {
  stop("renv activation attempted bootstrap, install, or local library use",
    call. = FALSE
  )
}
project_entries_after <- sort(list.files(
  project, all.files = TRUE, recursive = TRUE, full.names = FALSE,
  include.dirs = TRUE, no.. = TRUE
), method = "radix")
if (!identical(project_entries_after, expected_entries)) {
  stop("renv activation changed the isolated project shape", call. = FALSE)
}
if (!identical(capture_root_file(root_projects), global_projects_before) ||
    !identical(capture_root_file(root_renvignore), global_renvignore_before)) {
  stop("renv activation changed global cache state", call. = FALSE)
}
if (!identical(
    normalizePath(.libPaths()[[1L]], winslash = "/", mustWork = TRUE), leaf
  ) || !identical(as.character(utils::packageVersion("renv")), "1.2.4")) {
  stop("renv activation did not bind the sealed library", call. = FALSE)
}
renv_path <- normalizePath(
  getNamespaceInfo(asNamespace("renv"), "path"),
  winslash = "/", mustWork = TRUE
)
if (!startsWith(tolower(renv_path), paste0(tolower(leaf), "/"))) {
  stop("renv namespace is outside the sealed leaf", call. = FALSE)
}
required <- c("fst", "jsonlite", "openssl")
for (package in required) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop(sprintf("required package is unavailable: %s", package), call. = FALSE)
  }
  package_path <- normalizePath(
    getNamespaceInfo(asNamespace(package), "path"),
    winslash = "/", mustWork = TRUE
  )
  if (!startsWith(tolower(package_path), paste0(tolower(leaf), "/"))) {
    stop(sprintf("required package is outside sealed leaf: %s", package),
      call. = FALSE
    )
  }
}
clean <- function(value) {
  value <- enc2utf8(as.character(value))
  unsafe <- grepl("\t", value, fixed = TRUE) |
    grepl("\r", value, fixed = TRUE) | grepl("\n", value, fixed = TRUE)
  if (any(unsafe)) stop("unsafe probe field", call. = FALSE)
  value
}
cat("R_VERSION\t", clean(R.version.string), "\n", sep = "")
cat("R_PLATFORM\t", clean(R.version$platform), "\n", sep = "")
cat("ACTIVATION\tTRUE\t1.2.4\t", length(activation_console), "\t",
    clean(root), "\t", clean(leaf), "\n", sep = "")
for (path in .libPaths()) {
  cat("LIB\t", clean(normalizePath(path, winslash = "/", mustWork = TRUE)),
      "\n", sep = "")
}
for (package in required) cat("REQUIRED\t", clean(package), "\n", sep = "")
for (package in sort(loadedNamespaces(), method = "radix")) {
  path <- normalizePath(find.package(package), winslash = "/", mustWork = TRUE)
  cat("PACKAGE\t", clean(package), "\t",
      clean(as.character(packageVersion(package))), "\t", clean(path), "\t",
      if (package %in% required) "TRUE" else "FALSE", "\n", sep = "")
}
'@
  $temporaryBase = Resolve-Issue13OracleEffectDirectory `
    ([IO.Path]::GetTempPath()) 'renv activation probe parent'
  $temporaryLeaf =
    'issue13-oracle-renv-' + [Guid]::NewGuid().ToString('N')
  Assert-Issue13OracleEffect (
    $temporaryLeaf -cmatch '^issue13-oracle-renv-[0-9a-f]{32}$'
  ) 'renv activation probe leaf is not canonical.'
  $temporaryRoot = [IO.Path]::GetFullPath(
    [IO.Path]::Combine($temporaryBase, $temporaryLeaf))
  Assert-Issue13OracleEffect (
    [string]::Equals(
      [IO.Directory]::GetParent($temporaryRoot).FullName.TrimEnd('\', '/'),
      $temporaryBase.TrimEnd('\', '/'),
      [StringComparison]::OrdinalIgnoreCase)
  ) 'renv activation probe root is not a fresh direct child.'
  Assert-Issue13OracleEffectPathsDisjoint $temporaryRoot $libraryPath `
    'renv activation probe/R library isolation'
  Assert-Issue13OracleEffectPathsDisjoint $temporaryRoot $projectPath `
    'renv activation probe/source project isolation'
  Assert-Issue13OracleEffectPathsDisjoint $temporaryRoot `
    $script:Issue13OracleEffectControllerRoot `
    'renv activation probe/controller isolation'
  $probeState = [pscustomobject][ordered]@{
    result = $null
    project_inventory_before = $null
    project_inventory_after = $null
    project_library_absent_before = $false
    project_library_absent_after = $false
    library_inventory_after = $null
    temporary_root_owned = $false
  }
  $probeAction = {
    $createdRoot = New-Item -Path $temporaryRoot -ItemType Directory `
      -ErrorAction Stop
    $probeState.temporary_root_owned = $true
    Assert-Issue13OracleEffect (
      [string]::Equals(
        [IO.Path]::GetFullPath([string]$createdRoot.FullName).TrimEnd('\', '/'),
        $temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -and
      @((Get-ChildItem -LiteralPath $temporaryRoot -Force)).Count -eq 0
    ) 'renv activation probe root was not created exclusively.'
    $createdRenv = New-Item -Path ([IO.Path]::Combine(
        $temporaryRoot, 'renv')) -ItemType Directory -ErrorAction Stop
    Assert-Issue13OracleEffect (
      [string]::Equals(
        [IO.Path]::GetFullPath([string]$createdRenv.FullName).TrimEnd('\', '/'),
        [IO.Path]::Combine($temporaryRoot, 'renv'),
        [StringComparison]::OrdinalIgnoreCase)
    ) 'renv activation probe directory creation differed.'
    foreach ($copy in $probeCopies) {
      $target = [IO.Path]::GetFullPath(
        [IO.Path]::Combine(
          $temporaryRoot, ([string]$copy.relative_path).Replace('/', '\')))
      [IO.File]::Copy([string]$copy.source, $target, $false)
      Assert-Issue13OracleEffect (
        [int64](Get-Item -LiteralPath $target).Length -eq
          [int64]$copy.size_bytes -and
        (Get-Issue13OracleEffectSha256 $target) -ceq [string]$copy.sha256 -and
        (Get-Issue13OracleEffectSha256 ([string]$copy.source)) -ceq
          [string]$copy.sha256
      ) 'renv activation probe copy differs from authenticated source.'
    }
    Assert-Issue13OracleEffectNoReparseTree $temporaryRoot `
      'renv activation probe project'
    $projectEntries = @(Get-ChildItem -LiteralPath $temporaryRoot `
      -Recurse -Force)
    $projectFiles = @($projectEntries | Where-Object { -not $_.PSIsContainer })
    $projectDirectories = @($projectEntries | Where-Object { $_.PSIsContainer })
    $projectRelativeFiles = [string[]]@($projectFiles | ForEach-Object {
      $_.FullName.Substring($temporaryRoot.Length + 1).Replace('\', '/')
    })
    $projectRelativeDirectories = [string[]]@(
      $projectDirectories | ForEach-Object {
        $_.FullName.Substring($temporaryRoot.Length + 1).Replace('\', '/')
      })
    [Array]::Sort($projectRelativeFiles, [StringComparer]::Ordinal)
    [Array]::Sort($projectRelativeDirectories, [StringComparer]::Ordinal)
    Assert-Issue13OracleEffect (
      [string]::Join("`n", $projectRelativeFiles) -ceq
        "DESCRIPTION`nrenv.lock`nrenv/.gitignore`nrenv/activate.R`nrenv/settings.json" -and
      [string]::Join("`n", $projectRelativeDirectories) -ceq 'renv' -and
      -not [IO.File]::Exists((Join-Path $temporaryRoot '.Rprofile')) -and
      -not [IO.Directory]::Exists((Join-Path $temporaryRoot '.Rprofile')) -and
      -not [IO.File]::Exists((Join-Path $temporaryRoot 'renv\settings.R')) -and
      -not [IO.Directory]::Exists((Join-Path $temporaryRoot 'renv\settings.R'))
    ) 'renv activation probe project contains an unauthenticated input.'
    $probeState.project_inventory_before =
      Get-Issue13OracleEffectDirectoryInventory $temporaryRoot `
        'renv activation probe project before execution'
    $projectLibrary = Join-Path $temporaryRoot 'renv\library'
    $probeState.project_library_absent_before =
      -not [IO.Directory]::Exists($projectLibrary) -and
      -not [IO.File]::Exists($projectLibrary)
    Assert-Issue13OracleEffect $probeState.project_library_absent_before `
      'isolated project library exists before renv activation.'
    $probeEnvironment = New-Issue13V5ClosedREnvironment $libraryPath
    $probeState.result = Invoke-Issue13V5RscriptBounded `
      -RscriptPath $rscriptPath `
      -Arguments @('--vanilla', '-e', $expression, $temporaryRoot) `
      -Label 'Oracle-effect isolated renv activation probe' `
      -TimeoutSeconds 600 `
      -ExpectedExitCodes $null `
      -WorkingDirectory $temporaryRoot `
      -Environment $probeEnvironment
    $expectedEnvironment = Get-Issue13OracleEffectEnvironmentContract `
      $libraryPath
    Assert-Issue13OracleEffect (
      (@($probeState.result.environment_set) |
          ConvertTo-Json -Depth 10 -Compress) -ceq
        (@($expectedEnvironment.set) |
          ConvertTo-Json -Depth 10 -Compress) -and
      [string]::Join(
        "`n", @($probeState.result.environment_cleared)) -ceq
        [string]::Join(
          "`n", @($expectedEnvironment.cleared))
    ) 'renv activation probe process environment differs.'
  }
  $probeCleanup = {
    if (-not $probeState.temporary_root_owned -or
        -not [IO.Directory]::Exists($temporaryRoot)) { return }
    Assert-Issue13OracleEffectNoReparseTree $temporaryRoot `
      'renv activation probe project cleanup'
    $projectLibrary = Join-Path $temporaryRoot 'renv\library'
    $probeState.project_library_absent_after =
      -not [IO.Directory]::Exists($projectLibrary) -and
      -not [IO.File]::Exists($projectLibrary)
    $probeState.project_inventory_after =
      Get-Issue13OracleEffectDirectoryInventory $temporaryRoot `
        'renv activation probe project after execution'
    $projectEntriesAfter = @(Get-ChildItem -LiteralPath $temporaryRoot `
      -Recurse -Force)
    $projectFilesAfter = @($projectEntriesAfter | Where-Object {
        -not $_.PSIsContainer
      })
    $projectDirectoriesAfter = @($projectEntriesAfter | Where-Object {
        $_.PSIsContainer
      })
    $projectRelativeFilesAfter = [string[]]@(
      $projectFilesAfter | ForEach-Object {
        $_.FullName.Substring($temporaryRoot.Length + 1).Replace('\', '/')
      })
    $projectRelativeDirectoriesAfter = [string[]]@(
      $projectDirectoriesAfter | ForEach-Object {
        $_.FullName.Substring($temporaryRoot.Length + 1).Replace('\', '/')
      })
    [Array]::Sort($projectRelativeFilesAfter, [StringComparer]::Ordinal)
    [Array]::Sort($projectRelativeDirectoriesAfter, [StringComparer]::Ordinal)
    $projectShapeUnchanged =
      [string]::Join("`n", $projectRelativeFilesAfter) -ceq
        "DESCRIPTION`nrenv.lock`nrenv/.gitignore`nrenv/activate.R`nrenv/settings.json" -and
      [string]::Join("`n", $projectRelativeDirectoriesAfter) -ceq 'renv'
    $probeState.library_inventory_after =
      Get-Issue13OracleEffectDirectoryInventory $libraryPath `
        'comparison R library after activation probe'
    $projectUnchanged = $projectShapeUnchanged -and
      ($probeState.project_inventory_before | ConvertTo-Json -Compress) -ceq
      ($probeState.project_inventory_after | ConvertTo-Json -Compress)
    $libraryUnchanged =
      ($libraryInventoryBefore | ConvertTo-Json -Compress) -ceq
      ($probeState.library_inventory_after | ConvertTo-Json -Compress)
    [IO.Directory]::Delete($temporaryRoot, $true)
    Assert-Issue13OracleEffect (
      -not [IO.Directory]::Exists($temporaryRoot) -and
      -not [IO.File]::Exists($temporaryRoot)
    ) 'renv activation probe project survived cleanup.'
    Assert-Issue13OracleEffect $probeState.project_library_absent_after `
      'renv activation wrote a project-local library.'
    Assert-Issue13OracleEffect $projectUnchanged `
      'renv activation changed the isolated project copy.'
    Assert-Issue13OracleEffect $libraryUnchanged `
      'renv activation changed the sealed R library.'
  }
  Invoke-Issue13V5WithCleanup $probeAction $probeCleanup `
    'Oracle-effect isolated renv activation lifecycle failed'
  $probeResult = $probeState.result
  $probe = [pscustomobject]@{
    native = [string[]]$probeResult.combined_lines
    exit_code = [long]$probeResult.exit_code
  }
  $native = @($probe.native)
  $exitCode = [long]$probe.exit_code
  Assert-Issue13OracleEffect ($exitCode -eq 0) `
    "R runtime probe failed: $($native -join ' ')"
  $versionRows = @($native | Where-Object { $_.StartsWith("R_VERSION`t") })
  $platformRows = @($native | Where-Object { $_.StartsWith("R_PLATFORM`t") })
  $activationRows = @($native | Where-Object {
      $_.StartsWith("ACTIVATION`t")
    })
  $libRows = @($native | Where-Object { $_.StartsWith("LIB`t") })
  $requiredRows = @($native | Where-Object { $_.StartsWith("REQUIRED`t") })
  $packageRows = @($native | Where-Object { $_.StartsWith("PACKAGE`t") })
  $recognized = $versionRows.Count + $platformRows.Count +
    $activationRows.Count + $libRows.Count + $requiredRows.Count +
    $packageRows.Count
  Assert-Issue13OracleEffect ($recognized -eq $native.Count -and
      $versionRows.Count -eq 1 -and $platformRows.Count -eq 1 -and
      $activationRows.Count -eq 1 -and $libRows.Count -gt 0 -and
      $packageRows.Count -gt 0) `
    'R runtime probe returned an unexpected or incomplete line.'
  $activationFields = [string[]]$activationRows[0].Split("`t")
  $activationRoot = if ($activationFields.Count -eq 6) {
    Resolve-Issue13OracleEffectDirectory $activationFields[4] `
      'effective renv library root'
  } else { '' }
  $activationLeaf = if ($activationFields.Count -eq 6) {
    Resolve-Issue13OracleEffectDirectory $activationFields[5] `
      'effective renv library leaf'
  } else { '' }
  $capturedLineCount = 0L
  $capturedLineParsed = $activationFields.Count -eq 6 -and
    [long]::TryParse([string]$activationFields[3], [ref]$capturedLineCount)
  Assert-Issue13OracleEffect (
    $activationFields.Count -eq 6 -and
    $activationFields[1] -ceq 'TRUE' -and
    $activationFields[2] -ceq '1.2.4' -and $capturedLineParsed -and
    $capturedLineCount -ge 0L -and
    (Test-Issue13OracleEffectPathEqual $activationRoot $renvLibraryRoot) -and
    (Test-Issue13OracleEffectPathEqual $activationLeaf $libraryPath)
  ) 'R runtime probe returned an invalid activation record.'
  $libPaths = [string[]]@($libRows | ForEach-Object {
    $fields = [string[]]$_.Split("`t")
    Assert-Issue13OracleEffect ($fields.Count -eq 2) `
      'R runtime probe returned a malformed LIB row.'
    Resolve-Issue13OracleEffectDirectory $fields[1] `
      'effective R library path'
  })
  Assert-Issue13OracleEffect (@($libPaths | Select-Object -Unique).Count -eq
      $libPaths.Count) 'R runtime probe repeated an effective library path.'
  Assert-Issue13OracleEffect (
    Test-Issue13OracleEffectPathEqual $libPaths[0] $libraryPath
  ) 'RLibrary is not the first effective .libPaths() entry.'
  $required = [string[]]@($requiredRows | ForEach-Object {
    ([string[]]$_.Split("`t"))[1]
  })
  Assert-Issue13OracleEffectExactSet $required `
    $script:Issue13OracleEffectRequiredRPackages 'required R packages'
  $packages = @(
    foreach ($line in $packageRows) {
      $fields = [string[]]$line.Split("`t")
      Assert-Issue13OracleEffect ($fields.Count -eq 5 -and
          $fields[1] -cmatch '^[A-Za-z][A-Za-z0-9.]*$' -and
          $fields[2] -cmatch '^[0-9]+(?:\.[0-9]+)+(?:[-.][A-Za-z0-9]+)*$' -and
          $fields[4] -cin @('TRUE', 'FALSE')) `
        'R runtime probe returned a malformed PACKAGE row.'
      $path = Resolve-Issue13OracleEffectDirectory $fields[3] `
        "loaded R package $($fields[1])"
      $isRequired = $fields[4] -ceq 'TRUE'
      if ($isRequired) {
        Assert-Issue13OracleEffect (
          Test-Issue13OracleEffectPathContained $path $libraryPath
        ) "required R package is outside RLibrary: $($fields[1])"
      }
      $inventory = Get-Issue13OracleEffectDirectoryInventory $path `
        "loaded R package $($fields[1])"
      [pscustomobject][ordered]@{
        name = $fields[1]
        version = $fields[2]
        path = $path
        required = $isRequired
        file_count = [int64]$inventory.file_count
        total_bytes = [int64]$inventory.total_bytes
        inventory_sha256 = [string]$inventory.inventory_sha256
      }
    }
  )
  Assert-Issue13OracleEffectExactSet @($packages | Where-Object required |
      ForEach-Object name) $script:Issue13OracleEffectRequiredRPackages `
    'loaded required R packages'
  Assert-Issue13OracleEffect (@($packages.name | Select-Object -Unique).Count -eq
      $packages.Count) 'R runtime probe repeated a loaded package.'
  $environment = Get-Issue13OracleEffectEnvironmentContract $libraryPath
  $payload = [string]::Join("`n", @(
    'r-version|' + $versionRows[0].Substring("R_VERSION`t".Length)
    'r-platform|' + $platformRows[0].Substring("R_PLATFORM`t".Length)
    'activation|isolated-project-copy|1.2.4|' +
      [string]$capturedLineCount + '|' + $activationRoot + '|' +
      [string]$probeState.project_inventory_before.inventory_sha256 + '|' +
      [string]$libraryInventoryBefore.inventory_sha256
    @($libPaths | ForEach-Object { 'lib|' + $_ })
    @($environment.set | ForEach-Object {
      'set|' + [string]$_.name + '|' + [string]$_.value
    })
    @($environment.cleared | ForEach-Object { 'clear|' + [string]$_ })
    @($packages | Sort-Object name | ForEach-Object {
      'package|' + [string]$_.name + '|' + [string]$_.version + '|' +
        [string]$_.path + '|' + [string]$_.required + '|' +
        [string]$_.file_count + '|' + [string]$_.total_bytes + '|' +
        [string]$_.inventory_sha256
    })
  ))
  [pscustomobject][ordered]@{
    path = $libraryPath
    environment_variable = 'R_LIBS_USER'
    environment = $environment
    activation = [pscustomobject][ordered]@{
      mode = 'isolated-project-copy'
      verified = $true
      renv_version = '1.2.4'
      captured_console_line_count = [long]$capturedLineCount
      renv_library_root = $activationRoot
      project_inventory_sha256 =
        [string]$probeState.project_inventory_before.inventory_sha256
      project_library_absent_before =
        [bool]$probeState.project_library_absent_before
      project_library_absent_after =
        [bool]$probeState.project_library_absent_after
      r_library_inventory_before_sha256 =
        [string]$libraryInventoryBefore.inventory_sha256
      r_library_inventory_after_sha256 =
        [string]$probeState.library_inventory_after.inventory_sha256
    }
    r_version = $versionRows[0].Substring("R_VERSION`t".Length)
    platform = $platformRows[0].Substring("R_PLATFORM`t".Length)
    lib_paths = $libPaths
    required_packages = [string[]]$script:Issue13OracleEffectRequiredRPackages
    loaded_packages = $packages
    inventory_sha256 = Get-Issue13OracleEffectUtf8Sha256 $payload
  }
}

function Test-Issue13OracleEffectNegativeSelfTests {
  $mustReject = {
    param([scriptblock]$Body, [string]$Label)
    $rejected = $false
    try { & $Body } catch { $rejected = $true }
    Assert-Issue13OracleEffect $rejected "negative self-test did not reject $Label"
  }
  & $mustReject {
    $null = Get-Issue13OracleEffectSafeRelativePath '../escape' 'self-test path'
  } 'relative-path traversal'
  $anchorRoot = [IO.Path]::GetFullPath((Join-Path `
        ([IO.Path]::GetTempPath()) 'issue13-oracle-selftest\library'))
  $anchor = [IO.Path]::GetFullPath((Join-Path $anchorRoot `
        'windows\R-4.6\x86_64-w64-mingw32'))
  & $mustReject {
    Assert-Issue13OracleEffectPathsDisjoint $anchor (Join-Path $anchor 'nested') `
      'self-test overlap'
  } 'nested roots'
  & $mustReject {
    Assert-Issue13OracleEffect (
      -not (Test-Issue13OracleEffectReparseAttribute `
        [IO.FileAttributes]::ReparsePoint)
    ) 'self-test synthetic reparse point'
  } 'reparse-point attribute'
  $expected = @([pscustomobject]@{
    name = 'a'; relative_path = 'x/a'; sha256 = ('0' * 64); git_blob = ('1' * 40)
  })
  $tampered = @([pscustomobject]@{
    name = 'a'; relative_path = 'x/b'; sha256 = ('0' * 64); git_blob = ('1' * 40)
  })
  & $mustReject {
    $null = Assert-Issue13OracleEffectControllerRecords $tampered $expected `
      'self-test controller'
  } 'controller name/path substitution'
  $tampered[0].relative_path = 'x/a'
  $tampered[0].sha256 = ('2' * 64)
  & $mustReject {
    $null = Assert-Issue13OracleEffectControllerRecords $tampered $expected `
      'self-test controller hash'
  } 'controller raw-byte hash substitution'
  $validManifestEnvelope = [pscustomobject][ordered]@{
    schema = 'wlv-issue13-v5-harness-materialization/1'
    generation = 'v5-terminal'
    status = 'materialized'
    materialized_at_utc = '2026-08-27T00:00:00.0000000Z'
    baseline_commit = ('a' * 40)
    baseline_policy = 'authenticated-direct-child-compatibility-oracle'
    baseline_runtime_commit = ('b' * 40)
    baseline_runtime_tree = ('c' * 40)
    baseline_overlay_sha256 = ('d' * 64)
    baseline_overlay_patch_id = ('e' * 40)
    strict_negative_evidence_required = $true
    final_evidence_eligible = $true
    reuses_candidate_evidence = $false
    source_controller = [pscustomobject][ordered]@{
      commit_sha256 = ('f' * 40)
      file_count = [int64]0
      records = @()
    }
    source_tooling = [pscustomobject]@{}
    output_tooling = [pscustomobject][ordered]@{
      file_count = [int64]1
      total_bytes = [int64]1
      inventory_sha256 = ('0' * 64)
    }
    sealed_output_tooling = [pscustomobject][ordered]@{
      file_count = [int64]1
      total_bytes = [int64]1
      inventory_sha256 = ('0' * 64)
    }
    overlays = @(
      'authenticated-compatibility-oracle-cc2',
      'authenticated-candidate-runtime-sidecar',
      'authenticated-arm-specific-source-contracts'
    )
  }
  $null = Assert-Issue13OracleEffectHarnessManifestEnvelope `
    $validManifestEnvelope
  $cloneManifestEnvelope = {
    param([object]$Value)
    $Value | ConvertTo-Json -Depth 10 | ConvertFrom-Json
  }
  $legacyCommit = & $cloneManifestEnvelope $validManifestEnvelope
  $legacyCommit | Add-Member -NotePropertyName candidate_commit `
    -NotePropertyValue ('1' * 40)
  & $mustReject {
    $null = Assert-Issue13OracleEffectHarnessManifestEnvelope $legacyCommit
  } 'legacy top-level candidate_commit in harness manifest'
  $arbitraryField = & $cloneManifestEnvelope $validManifestEnvelope
  $arbitraryField | Add-Member -NotePropertyName arbitrary_field `
    -NotePropertyValue 'forbidden'
  & $mustReject {
    $null = Assert-Issue13OracleEffectHarnessManifestEnvelope $arbitraryField
  } 'arbitrary top-level field in harness manifest'
  $wrongPolicy = & $cloneManifestEnvelope $validManifestEnvelope
  $wrongPolicy.baseline_policy = 'legacy'
  & $mustReject {
    $null = Assert-Issue13OracleEffectHarnessManifestEnvelope $wrongPolicy
  } 'legacy harness baseline policy'
  $missingStrictNegative = & $cloneManifestEnvelope $validManifestEnvelope
  $missingStrictNegative.strict_negative_evidence_required = $false
  & $mustReject {
    $null = Assert-Issue13OracleEffectHarnessManifestEnvelope `
      $missingStrictNegative
  } 'disabled strict-negative harness evidence'
  $wrongOverlayOrder = & $cloneManifestEnvelope $validManifestEnvelope
  [Array]::Reverse($wrongOverlayOrder.overlays)
  & $mustReject {
    $null = Assert-Issue13OracleEffectHarnessManifestEnvelope $wrongOverlayOrder
  } 'reordered harness overlays'
  $extraOutputField = & $cloneManifestEnvelope $validManifestEnvelope
  $extraOutputField.output_tooling | Add-Member -NotePropertyName legacy_hash `
    -NotePropertyValue ('2' * 64)
  & $mustReject {
    $null = Assert-Issue13OracleEffectHarnessManifestEnvelope $extraOutputField
  } 'extra harness output-tooling field'
  $contract = Get-Issue13OracleEffectEnvironmentContract $anchor
  $sortedCleared = [string[]]@($contract.cleared)
  [Array]::Sort($sortedCleared, [StringComparer]::Ordinal)
  Assert-Issue13OracleEffect (
    [string]::Join("`n", @($contract.cleared)) -ceq
      [string]::Join("`n", $sortedCleared)
  ) 'negative self-test cleared R environment is not ordinal.'
  Assert-Issue13OracleEffectExactSet @($contract.cleared) `
    $script:Issue13OracleEffectRClearedEnvironment `
    'negative self-test cleared R environment'
  Assert-Issue13OracleEffect (@($contract.set | Where-Object {
        $_.name -ceq 'R_LIBS_USER' -and $_.value -ceq $anchor
      }).Count -eq 1) 'negative self-test lacks the exact R_LIBS_USER binding.'
  Assert-Issue13OracleEffect (@($contract.set | Where-Object {
        $_.name -ceq 'RENV_PATHS_LIBRARY' -and $_.value -ceq $anchorRoot
      }).Count -eq 1) `
    'negative self-test lacks the exact RENV_PATHS_LIBRARY binding.'
  Assert-Issue13OracleEffect (
    @($contract.set).Count -eq 10 -and
    [string]::Join("`n", @($contract.set | ForEach-Object {
          [string]$_.name
        })) -ceq [string]::Join("`n", @(
          'RENV_CONFIG_AUTO_SNAPSHOT', 'RENV_CONFIG_CACHE_ENABLED',
          'RENV_CONFIG_LOCKING_ENABLED', 'RENV_CONFIG_SANDBOX_ENABLED',
          'RENV_CONFIG_UPDATES_CHECK', 'RENV_CONFIG_USER_ENVIRON',
          'RENV_CONFIG_USER_LIBRARY', 'RENV_PATHS_LIBRARY',
          'R_LIBS_USER', 'TZ'
        )) -and
    @($contract.set | Where-Object {
        $_.name -ceq 'RENV_CONFIG_AUTO_SNAPSHOT' -and $_.value -ceq 'FALSE'
      }).Count -eq 1 -and
    @($contract.set | Where-Object {
        $_.name -ceq 'RENV_CONFIG_CACHE_ENABLED' -and $_.value -ceq 'FALSE'
      }).Count -eq 1 -and
    @($contract.set | Where-Object {
        $_.name -ceq 'RENV_CONFIG_LOCKING_ENABLED' -and $_.value -ceq 'FALSE'
      }).Count -eq 1 -and
    @($contract.set | Where-Object {
        $_.name -ceq 'RENV_CONFIG_SANDBOX_ENABLED' -and $_.value -ceq 'FALSE'
      }).Count -eq 1 -and
    @($contract.set | Where-Object {
        $_.name -ceq 'RENV_CONFIG_UPDATES_CHECK' -and $_.value -ceq 'FALSE'
      }).Count -eq 1 -and
    @($contract.set | Where-Object {
        $_.name -ceq 'RENV_CONFIG_USER_ENVIRON' -and $_.value -ceq 'FALSE'
      }).Count -eq 1 -and
    @($contract.set | Where-Object {
        $_.name -ceq 'RENV_CONFIG_USER_LIBRARY' -and $_.value -ceq 'FALSE'
      }).Count -eq 1 -and
    @($contract.set | Where-Object {
        $_.name -ceq 'TZ' -and $_.value -ceq 'UTC'
      }).Count -eq 1
  ) 'negative self-test lacks the exact renv configuration bindings.'
  & $mustReject {
    $null = Get-Issue13OracleEffectEnvironmentContract `
      (Join-Path $anchor 'unexpected')
  } 'invalid renv profile layout'
  & $mustReject {
    Assert-Issue13OracleEffectExactSet `
      @($contract.cleared | Where-Object { $_ -cne 'R_LIBS_SITE' }) `
      $script:Issue13OracleEffectRClearedEnvironment `
      'self-test tampered R environment'
  } 'missing R_LIBS_SITE sanitization'
  $environmentNames = [string[]]@(
    @($contract.cleared) + @($contract.set | ForEach-Object name))
  $external = [object[]]@($environmentNames | ForEach-Object {
    Get-Issue13OracleEffectProcessEnvironmentState ([string]$_)
  })
  $setup = [object[]]@($external | ForEach-Object {
    [pscustomobject][ordered]@{
      name = [string]$_.name
      present = [bool]$_.present
      value = $_.value
    }
  })
  $setupByName = @{}
  foreach ($record in $setup) { $setupByName[[string]$record.name] = $record }
  $setupByName['LANG'].present = $false
  $setupByName['LANG'].value = $null
  $setupByName['LC_ALL'].present = $true
  $setupByName['LC_ALL'].value = ''
  $setupByName['LC_CTYPE'].present = $true
  $setupByName['LC_CTYPE'].value = 'issue13-value'
  $setupByName['R_LIBS'].present = $true
  $setupByName['R_LIBS'].value = 'issue13-sentinel'
  try {
    foreach ($record in $setup) {
      $null = Set-Issue13OracleEffectProcessEnvironmentState $record
    }
    foreach ($record in $setup) {
      Assert-Issue13OracleEffect (
        Test-Issue13OracleEffectProcessEnvironmentState `
          (Get-Issue13OracleEffectProcessEnvironmentState $record.name) $record
      ) "tri-state setup differs: $($record.name)"
    }
    $state = Enter-Issue13OracleEffectSanitizedREnvironment $anchor
    foreach ($name in @($contract.cleared)) {
      $observed = Get-Issue13OracleEffectProcessEnvironmentState $name
      Assert-Issue13OracleEffect (
        Test-Issue13OracleEffectExactBoolean $observed.present $false
      ) "sanitized environment retained a cleared name: $name"
    }
    foreach ($record in @($contract.set)) {
      $observed = Get-Issue13OracleEffectProcessEnvironmentState $record.name
      Assert-Issue13OracleEffect (
        (Test-Issue13OracleEffectExactBoolean $observed.present $true) -and
        [string]$observed.value -ceq [string]$record.value
      ) "sanitized environment did not set an exact value: $($record.name)"
    }
    Exit-Issue13OracleEffectSanitizedREnvironment $state
    foreach ($record in $setup) {
      Assert-Issue13OracleEffect (
        Test-Issue13OracleEffectProcessEnvironmentState `
          (Get-Issue13OracleEffectProcessEnvironmentState $record.name) $record
      ) "tri-state restoration differs: $($record.name)"
    }
    & $mustReject {
      $null = Invoke-Issue13OracleEffectWithProcessEnvironment $anchor {
        throw 'issue13 injected action failure'
      }
    } 'action failure with exact restoration'
    foreach ($record in $setup) {
      Assert-Issue13OracleEffect (
        Test-Issue13OracleEffectProcessEnvironmentState `
          (Get-Issue13OracleEffectProcessEnvironmentState $record.name) $record
      ) "action-exception restoration differs: $($record.name)"
    }
    & $mustReject {
      $null = Enter-Issue13OracleEffectSanitizedREnvironment $anchor {
        param($name, $mutationIndex)
        if ($mutationIndex -eq 2) {
          throw "issue13 injected partial entry failure after $name"
        }
      }
    } 'partial Enter failure with rollback'
    foreach ($record in $setup) {
      Assert-Issue13OracleEffect (
        Test-Issue13OracleEffectProcessEnvironmentState `
          (Get-Issue13OracleEffectProcessEnvironmentState $record.name) $record
      ) "partial-entry rollback differs: $($record.name)"
    }
  } finally {
    $restoreErrors = [Collections.Generic.List[string]]::new()
    for ($index = $external.Count - 1; $index -ge 0; $index--) {
      try {
        $null = Set-Issue13OracleEffectProcessEnvironmentState $external[$index]
      } catch {
        $restoreErrors.Add($_.Exception.Message)
      }
    }
    if ($restoreErrors.Count -ne 0) {
      throw [InvalidOperationException]::new(
        'negative self-test external environment restoration failed: ' +
        [string]::Join(' | ', $restoreErrors))
    }
  }
  $locationRoot = [IO.Path]::GetFullPath((Join-Path `
      ([IO.Path]::GetTempPath()) (
        'issue13-oracle-location-selftest-' + [Guid]::NewGuid().ToString('N'))))
  $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).
    TrimEnd([IO.Path]::DirectorySeparatorChar)
  Assert-Issue13OracleEffect (
    $locationRoot.StartsWith(
      $temporaryRoot + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase)
  ) 'location self-test root escaped the system temporary directory.'
  $null = [IO.Directory]::CreateDirectory($locationRoot)
  $locationBefore = (Get-Location).Path
  try {
    & $mustReject {
      $null = Invoke-Issue13OracleEffectWithLocation $locationRoot {
        throw 'issue13 injected location action failure'
      }
    } 'location action failure with exact restoration'
    Assert-Issue13OracleEffect (
      [string]::Equals(
        (Get-Location).Path, $locationBefore,
        [StringComparison]::OrdinalIgnoreCase)
    ) 'location action failure did not restore the current directory.'
  } finally {
    if (Test-Path -LiteralPath $locationRoot -PathType Container) {
      [IO.Directory]::Delete($locationRoot, $true)
    }
  }
  $true
}

function Test-Issue13OracleEffectSpec {
  param(
    [Parameter(Mandatory = $true)][object]$Spec,
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][string]$OraclePatch
  )
  $expectedBase = 'cc2c86189a06676bcb9f0e05e08033d710a92509'
  $expectedBaseTree = '0cb1142cdadd74bf95272010f5393ebe2af79f47'
  $expectedRuntime = 'e2f4d6dae9a6d35c966b305fabac52e489faa3e7'
  $expectedRuntimeTree = '7da19c4f2913e857040ba228280f404b0e54eaab'
  $expectedPatchSha = '9f9b878f8e557973127e6260a0f224c868a0c4e8dc2db52dd6aa3f7131f28cd9'
  $expectedPatchId = '253ca5f1397132f94e3432264084a37395c60ec3'
  $common = @('wiodr13', 'wiodr16', 'wiodr16v09', 'zerodep_1', 'zerodep_2')
  $recovered = @(
    'alternative_1', 'alternative_2', 'norow_w13', 'ochoa_1',
    'ochoa_2', 'petrovic', 'wiodr13v09'
  )

  Assert-Issue13OracleEffect ($Spec.schema -ceq 'wlv-issue13-v5-oracle-effect-spec/2') `
    'unexpected spec schema.'
  Assert-Issue13OracleEffect ($Spec.purpose -ceq 'closed-authorized-oracle-effect-cc2-to-e2f') `
    'unexpected spec purpose.'
  Assert-Issue13OracleEffect ($Spec.status -ceq `
      'requires-terminal-primary-and-replay-comparisons') `
    'the static spec must require fresh terminal primary/replay comparisons.'
  Assert-Issue13OracleEffect ($Spec.proof_schema_sha256 -ceq `
      'f86fb70b9bbd2e7c0851ab239f62ab14ea85268855082ea143d71992b2016063') `
    'proof schema hash differs.'
  Assert-Issue13OracleEffect (
    Test-Issue13OracleEffectExactBoolean $Spec.final_evidence_eligible $false
  ) `
    'the auxiliary oracle proof must not claim final-gate eligibility.'
  Assert-Issue13OracleEffect ($Spec.oracle.base_commit -ceq $expectedBase) `
    'base commit is not cc2c861.'
  Assert-Issue13OracleEffect ($Spec.oracle.base_tree -ceq $expectedBaseTree) `
    'base tree differs.'
  Assert-Issue13OracleEffect ($Spec.oracle.runtime_commit -ceq $expectedRuntime) `
    'runtime commit is not e2f4d6d.'
  Assert-Issue13OracleEffect ($Spec.oracle.runtime_tree -ceq $expectedRuntimeTree) `
    'runtime tree differs.'
  Assert-Issue13OracleEffect ($Spec.oracle.canonical_patch_sha256 -ceq $expectedPatchSha) `
    'canonical patch hash differs.'
  Assert-Issue13OracleEffect ($Spec.oracle.stable_patch_id -ceq $expectedPatchId) `
    'stable patch-id differs.'
  Assert-Issue13OracleEffect ([int]$Spec.oracle.changed_file_count -eq 8) `
    'the oracle must change exactly eight files.'
  Assert-Issue13OracleEffectExactSet @($Spec.method_partition.strict_common) $common `
    'strict-common method partition'
  Assert-Issue13OracleEffectExactSet @($Spec.method_partition.recovered) $recovered `
    'recovered method partition'
  Assert-Issue13OracleEffect (@($Spec.common_methods).Count -eq 5) `
    'common method record count must be five.'
  Assert-Issue13OracleEffect (@($Spec.recovered_methods).Count -eq 7) `
    'recovered method record count must be seven.'
  Assert-Issue13OracleEffectExactSet @($Spec.common_methods | ForEach-Object method) `
    $common 'common method records'
  Assert-Issue13OracleEffectExactSet @($Spec.recovered_methods | ForEach-Object method) `
    $recovered 'recovered method records'
  $terminal = $Spec.terminal_comparison_runtime
  Assert-Issue13OracleEffect ($terminal.generation -ceq 'v5-terminal' -and `
      $terminal.source_controller_commit_field -ceq 'commit_sha256' -and `
      $terminal.harness_directory -ceq 'issue13-evidence-harness' -and `
      $terminal.comparison_script -ceq 'issue13-compare-results.R' -and `
      $terminal.r_library_environment_variable -ceq 'R_LIBS_USER') `
    'terminal comparison runtime contract differs.'
  Assert-Issue13OracleEffectExactProperties $terminal.r_environment_set @(
    'RENV_CONFIG_AUTO_SNAPSHOT', 'RENV_CONFIG_CACHE_ENABLED',
    'RENV_CONFIG_LOCKING_ENABLED',
    'RENV_CONFIG_SANDBOX_ENABLED', 'RENV_CONFIG_UPDATES_CHECK',
    'RENV_CONFIG_USER_ENVIRON', 'RENV_CONFIG_USER_LIBRARY',
    'RENV_PATHS_LIBRARY', 'R_LIBS_USER', 'TZ'
  ) 'terminal R environment set contract'
  Assert-Issue13OracleEffect (
    [string]$terminal.r_environment_set.R_LIBS_USER -ceq `
      'configured-r-library' -and
    [string]$terminal.r_environment_set.RENV_PATHS_LIBRARY -ceq `
      'configured-renv-library-root' -and
    [string]$terminal.r_environment_set.RENV_CONFIG_AUTO_SNAPSHOT -ceq `
      'FALSE' -and
    [string]$terminal.r_environment_set.RENV_CONFIG_CACHE_ENABLED -ceq `
      'FALSE' -and
    [string]$terminal.r_environment_set.RENV_CONFIG_LOCKING_ENABLED -ceq `
      'FALSE' -and
    [string]$terminal.r_environment_set.RENV_CONFIG_SANDBOX_ENABLED -ceq `
      'FALSE' -and
    [string]$terminal.r_environment_set.RENV_CONFIG_UPDATES_CHECK -ceq `
      'FALSE' -and
    [string]$terminal.r_environment_set.RENV_CONFIG_USER_ENVIRON -ceq `
      'FALSE' -and
    [string]$terminal.r_environment_set.RENV_CONFIG_USER_LIBRARY -ceq `
      'FALSE' -and
    [string]$terminal.r_environment_set.TZ -ceq 'UTC'
  ) 'terminal R environment set values differ.'
  Assert-Issue13OracleEffect (
    [string]::Join("`n", @($terminal.r_environment_cleared)) -ceq
      [string]::Join(
        "`n", $script:Issue13OracleEffectRClearedEnvironment)
  ) 'terminal cleared R environment variables differ or were reordered.'
  Assert-Issue13OracleEffectExactSet @($terminal.required_r_packages) `
    $script:Issue13OracleEffectRequiredRPackages 'terminal required R packages'
  Assert-Issue13OracleEffectExactSet @($terminal.required_controller_files) `
    $script:Issue13OracleEffectControllerFiles 'terminal controller files'
  Assert-Issue13OracleEffectExactProperties $terminal.source_tooling @(
    'repository_relative_root', 'file_count', 'directory_count',
    'path_list_sha256', 'tree_relative_paths', 'required_relative_paths',
    'tree_mode', 'file_mode'
  ) 'terminal stable source-tooling contract'
  Assert-Issue13OracleEffect (
    [string]$terminal.source_tooling.repository_relative_root -ceq
      $script:Issue13OracleEffectSourceToolingRelativeRoot -and
    [int64]$terminal.source_tooling.file_count -eq 37L -and
    [int64]$terminal.source_tooling.directory_count -eq 1L -and
    [string]$terminal.source_tooling.path_list_sha256 -ceq
      $script:Issue13OracleEffectSourceToolingPathListSha256 -and
    [string]$terminal.source_tooling.tree_mode -ceq '040000' -and
    [string]$terminal.source_tooling.file_mode -ceq '100644'
  ) 'terminal stable source-tooling scalar contract differs.'
  Assert-Issue13OracleEffect (
    [string]::Join("`n", @($terminal.source_tooling.tree_relative_paths)) -ceq
      [string]::Join("`n", $script:Issue13OracleEffectSourceToolingTreePaths) -and
    [string]::Join("`n", @($terminal.source_tooling.required_relative_paths)) `
      -ceq [string]::Join("`n", $script:Issue13OracleEffectSourceToolingFiles)
  ) 'terminal stable source-tooling ordered paths differ.'
  Assert-Issue13OracleEffectExactProperties $terminal.rscript @(
    'required_link_count', 'size_bytes', 'sha256'
  ) 'terminal Rscript stable contract'
  Assert-Issue13OracleEffect (
    [int64]$terminal.rscript.required_link_count -eq
      $script:Issue13OracleEffectRscriptLinkCount -and
    [int64]$terminal.rscript.size_bytes -eq
      $script:Issue13OracleEffectRscriptSizeBytes -and
    [string]$terminal.rscript.sha256 -ceq
      $script:Issue13OracleEffectRscriptSha256
  ) 'terminal Rscript stable contract differs.'
  Assert-Issue13OracleEffect (
    [string]$terminal.sealed_inventory.status -ceq 'sealed' -and
    [int64]$terminal.sealed_inventory.file_count -gt 0 -and
    [int64]$terminal.sealed_inventory.total_bytes -gt 0 -and
    [string]$terminal.sealed_inventory.inventory_sha256 -cmatch `
      '^[0-9a-f]{64}$'
  ) 'terminal external sealed harness inventory differs.'
  Assert-Issue13OracleEffectExactSet @($terminal.forbidden_runtime_basenames) `
    @('v5c5', 'v5c6') 'forbidden pre-terminal runtime basenames'
  Assert-Issue13OracleEffectExactSet @($terminal.required_tool_files) @(
    'issue13-compare-results.R', 'issue13-compare-lib.R',
    'issue13-v5-compare-override.R', 'issue13-lib.R'
  ) 'terminal comparison tool files'
  Assert-Issue13OracleEffect ([int]$Spec.comparison_contract.required_execution_count -eq 10 -and `
      [int]$Spec.comparison_contract.approved_run_count -eq 17 -and `
      $Spec.comparison_contract.json_replay_normalization -ceq `
        'remove-top-level-compared_at') `
    'terminal comparison/replay contract differs.'

  $go = $Spec.coordinate_contracts.go_price_row_from_usa
  $goKeys = @(
    foreach ($year in @($go.years)) {
      foreach ($sector in @($go.sectors)) {
        "$($go.indicator)|$year|$($go.target_country)|$sector"
      }
    }
  )
  Assert-Issue13OracleEffect ($goKeys.Count -eq 525) 'go-price coordinate count differs.'
  Assert-Issue13OracleEffect ([int]$go.coordinate_count -eq $goKeys.Count) `
    'go-price declared count differs from its axes.'
  Assert-Issue13OracleEffect (
    (Get-Issue13OracleEffectTextHash $goKeys SHA256) -ceq
      '59d531c9417e058ef5ed57fb3fdff696293e11108e761937dbfa2ee4c4fec241'
  ) 'go-price coordinate hash differs.'
  Assert-Issue13OracleEffect ($go.coordinate_sha256 -ceq `
      '59d531c9417e058ef5ed57fb3fdff696293e11108e761937dbfa2ee4c4fec241') `
    'go-price declared coordinate hash differs.'
  Assert-Issue13OracleEffectExactSet @($go.methods) `
    @('alternative_1', 'alternative_2', 'norow_w13', 'ochoa_1', 'ochoa_2', 'petrovic') `
    'go-price methods'

  $nan = $Spec.coordinate_contracts.historical_nan_clean
  $nanKeys = @(
    foreach ($indicator in @($nan.indicators)) {
      foreach ($year in @($nan.years)) {
        foreach ($pair in @($nan.country_sector_pairs)) {
          "$indicator|$year|$pair"
        }
      }
    }
  )
  Assert-Issue13OracleEffect ($nanKeys.Count -eq 405) 'historical-NaN coordinate count differs.'
  Assert-Issue13OracleEffect (
    (Get-Issue13OracleEffectTextHash $nanKeys SHA256) -ceq
      '52c0f3c1224bec91b29e3ce2e2a77c855c8e81ee59e6054696a8da13e21052ca'
  ) 'historical-NaN SHA-256 differs.'
  Assert-Issue13OracleEffect (
    (Get-Issue13OracleEffectTextHash $nanKeys MD5) -ceq
      'e667f3c2de78d48614b6e24a09f52a9d'
  ) 'historical-NaN MD5 differs.'
  Assert-Issue13OracleEffect ([int]$nan.coordinate_count -eq 405) `
    'historical-NaN declared count differs.'
  Assert-Issue13OracleEffect ([int]$nan.per_indicator_count -eq 135) `
    'historical-NaN per-indicator count differs.'

  $stable = $Spec.coordinate_contracts.leontief_zero_output.profiles.stable
  $v09 = $Spec.coordinate_contracts.leontief_zero_output.profiles.v09
  Assert-Issue13OracleEffect ([int]$stable.coordinate_count -eq 3150 -and `
      $stable.coordinate_md5 -ceq 'f66341eea44e71728bbda6f8e25765ba') `
    'stable Leontief profile differs.'
  Assert-Issue13OracleEffect ([int]$v09.coordinate_count -eq 2945 -and `
      $v09.coordinate_md5 -ceq '3fd6663ca00317b42d3044df5019db4c') `
    'v09 Leontief profile differs.'
  Assert-Issue13OracleEffect ([int]$Spec.coordinate_contracts.leontief_signed_diagnostic.stable.signed_coefficient_count -eq 397) `
    'stable signed-coefficient count differs.'
  Assert-Issue13OracleEffect ([int]$Spec.coordinate_contracts.leontief_signed_diagnostic.v09.signed_coefficient_count -eq 396) `
    'v09 signed-coefficient count differs.'
  Assert-Issue13OracleEffect ($Spec.coordinate_contracts.norow_utf8.expected_value -ceq `
      'Teste sem suposições para resto do mundo') 'norow UTF-8 value differs.'
  Assert-Issue13OracleEffect ($Spec.coordinate_contracts.norow_utf8.expected_value_utf8_sha256 -ceq `
      '7dd0229f4bd175d60fb873a09ada3560192e960d71f1238809c62d90f4bb5203') `
    'norow UTF-8 value hash differs.'

  $patchPath = Resolve-Issue13OracleEffectFile $OraclePatch 'canonical oracle patch'
  Assert-Issue13OracleEffect ((Get-Issue13OracleEffectSha256 $patchPath) -ceq $expectedPatchSha) `
    'canonical oracle patch bytes differ.'
  $repository = Resolve-Issue13OracleEffectDirectory $RepositoryRoot 'repository root'
  Assert-Issue13OracleEffect (
    (Invoke-Issue13OracleEffectGit $repository @('rev-parse', "$expectedBase^{tree}")) -ceq
      $expectedBaseTree
  ) 'observed cc2 tree differs.'
  Assert-Issue13OracleEffect (
    (Invoke-Issue13OracleEffectGit $repository @('rev-parse', "$expectedRuntime^{tree}")) -ceq
      $expectedRuntimeTree
  ) 'observed e2f tree differs.'
  Assert-Issue13OracleEffect (
    (Invoke-Issue13OracleEffectGit $repository @('rev-parse', "$expectedRuntime^")) -ceq
      $expectedBase
  ) 'e2f is not a direct child of cc2.'

  $raw = Invoke-Issue13OracleEffectGit $repository @(
    'diff-tree', '--no-commit-id', '-r', '--raw', $expectedBase, $expectedRuntime
  )
  $rawRows = @($raw -split "`n" | Where-Object { $_.Length -gt 0 })
  Assert-Issue13OracleEffect ($rawRows.Count -eq 8) `
    'git reports a change set other than exactly eight files.'
  $observedByPath = @{}
  foreach ($line in $rawRows) {
    $match = [regex]::Match($line, '^:([0-7]{6}) ([0-7]{6}) ([0-9a-f]{40}) ([0-9a-f]{40}) M\t(.+)$')
    Assert-Issue13OracleEffect $match.Success "unexpected git raw-diff row: $line"
    $path = $match.Groups[5].Value
    Assert-Issue13OracleEffect (-not $observedByPath.ContainsKey($path)) `
      "duplicate git raw-diff path: $path"
    $observedByPath[$path] = [pscustomobject]@{
      old_mode = $match.Groups[1].Value
      new_mode = $match.Groups[2].Value
      old_blob = $match.Groups[3].Value
      new_blob = $match.Groups[4].Value
    }
  }
  Assert-Issue13OracleEffect (@($Spec.patch_files).Count -eq 8) `
    'spec patch-file count must be eight.'
  Assert-Issue13OracleEffectExactSet @($Spec.patch_files | ForEach-Object path) `
    @($observedByPath.Keys) 'patch paths'
  foreach ($file in @($Spec.patch_files)) {
    $observed = $observedByPath[[string]$file.path]
    foreach ($field in @('old_mode', 'new_mode', 'old_blob', 'new_blob')) {
      Assert-Issue13OracleEffect ([string]$file.$field -ceq [string]$observed.$field) `
      "$field differs for $($file.path)."
    }
  }
  $effects = @($Spec.recovered_file_method_effects)
  Assert-Issue13OracleEffect ($effects.Count -eq 25) `
    'recovered file/method effect count must be 25.'
  $effectPairs = New-Object Collections.Generic.List[string]
  $allowedContractRefs = @(
    '/coordinate_contracts/go_price_row_from_usa',
    '/coordinate_contracts/historical_nan_clean',
    '/coordinate_contracts/leontief_zero_output/profiles/stable',
    '/coordinate_contracts/leontief_zero_output/profiles/v09',
    '/coordinate_contracts/leontief_signed_diagnostic/stable',
    '/coordinate_contracts/leontief_signed_diagnostic/v09',
    '/coordinate_contracts/norow_utf8'
  )
  foreach ($effect in $effects) {
    Assert-Issue13OracleEffectExactProperties $effect @(
      'file', 'method', 'change_id', 'expected_contract_ref'
    ) 'recovered file/method effect properties'
    $file = @($Spec.patch_files | Where-Object {
      $_.path -ceq [string]$effect.file
    })
    $method = @($Spec.recovered_methods | Where-Object {
      $_.method -ceq [string]$effect.method
    })
    Assert-Issue13OracleEffect ($file.Count -eq 1 -and $method.Count -eq 1) `
      'recovered file/method effect references an unknown file or method.'
    Assert-Issue13OracleEffect (@($file[0].semantic_methods | Where-Object {
        $_ -ceq [string]$effect.method
      }).Count -eq 1 -and @($file[0].change_ids | Where-Object {
        $_ -ceq [string]$effect.change_id
      }).Count -eq 1 -and @($method[0].change_ids | Where-Object {
        $_ -ceq [string]$effect.change_id
      }).Count -eq 1) `
      'recovered file/method effect is inconsistent with its file or method record.'
    Assert-Issue13OracleEffect (@($allowedContractRefs | Where-Object {
        $_ -ceq [string]$effect.expected_contract_ref
      }).Count -eq 1) 'recovered file/method effect has an unknown contract reference.'
    $effectPairs.Add("$($effect.method)|$($effect.file)")
  }
  Assert-Issue13OracleEffect (($effectPairs | Select-Object -Unique).Count -eq `
      $effectPairs.Count) 'recovered file/method effects repeat a pair.'
  $expectedEffectPairs = @(
    foreach ($file in @($Spec.patch_files)) {
      foreach ($method in @($file.semantic_methods)) {
        if ($method -in $recovered) { "$method|$($file.path)" }
      }
    }
  )
  Assert-Issue13OracleEffectExactSet $effectPairs.ToArray() $expectedEffectPairs `
    'recovered file/method effect pairs'
  foreach ($method in @($Spec.recovered_methods)) {
    Assert-Issue13OracleEffectExactSet `
      @($effects | Where-Object { $_.method -ceq $method.method } | `
        ForEach-Object change_id) @($method.change_ids) `
      "$($method.method) recovered change ids"
  }
  $routes = @($Spec.reachability_contracts)
  Assert-Issue13OracleEffect ($routes.Count -eq 3) `
    'reachability contract count must be three.'
  $rowRoute = @($routes | Where-Object {
    $_.patched_file -ceq 'R/modules/assumptions/row/row-reduction_problem.R'
  })
  $noRowRoute = @($routes | Where-Object {
    $_.patched_file -ceq 'R/modules/assumptions/row/no_row.R'
  })
  $nanRoute = @($routes | Where-Object {
    $_.patched_file -ceq 'R/modules/variables/sea_sectors.R'
  })
  Assert-Issue13OracleEffect ($rowRoute.Count -eq 1 -and `
      $noRowRoute.Count -eq 1 -and $nanRoute.Count -eq 1) `
    'reachability contracts do not bind each routed patch exactly once.'
  Assert-Issue13OracleEffectExactSet @($rowRoute[0].methods) `
    @('alternative_1', 'alternative_2', 'ochoa_1', 'ochoa_2', 'petrovic') `
    'row-reduction route methods'
  Assert-Issue13OracleEffectExactSet @($noRowRoute[0].methods) @('norow_w13') `
    'no-row route methods'
  Assert-Issue13OracleEffectExactSet @($nanRoute[0].methods) `
    @('alternative_2', 'petrovic') 'historical-NaN route methods'
  $expectedAssumptions = @{
    alternative_1 = 'row/row-reduction_problem.R'
    alternative_2 = 'row/row-reduction_problem.R'
    norow_w13 = 'row/no_row.R'
    ochoa_1 = 'row/row-reduction_problem.R'
    ochoa_2 = 'row/row-reduction_problem.R'
    petrovic = 'row/row-reduction_problem.R'
    wiodr13v09 = 'row/row.old.R'
  }
  foreach ($method in $recovered) {
    $configPath = "methods/$method/_method_assumptions.csv"
    $content = Invoke-Issue13OracleEffectGit $repository `
      @('show', "$expectedBase`:$configPath")
    $expectedValue = [string]$expectedAssumptions[$method]
    $occurrences = ([regex]::Matches($content, [regex]::Escape($expectedValue))).Count
    Assert-Issue13OracleEffect ($occurrences -eq 1) `
      "$method assumption route to $expectedValue is not exact at cc2."
  }
  foreach ($method in @('alternative_2', 'petrovic')) {
    $configPath = "methods/$method/_method_solutions.csv"
    $content = Invoke-Issue13OracleEffectGit $repository `
      @('show', "$expectedBase`:$configPath")
    $expectedValue = [string]$nanRoute[0].configuration_values.$method
    $occurrences = ([regex]::Matches($content, [regex]::Escape($expectedValue))).Count
    Assert-Issue13OracleEffect ($occurrences -eq 1) `
      "$method historical-NaN module route is not exact at cc2."
  }
  [pscustomobject]@{
    repository_root = $repository
    patch_path = $patchPath
    patch_sha256 = $expectedPatchSha
    base_commit = $expectedBase
    runtime_commit = $expectedRuntime
    runtime_tree = $expectedRuntimeTree
    changed_file_count = 8
  }
}

function Get-Issue13OracleEffectSummaryRecords {
  param(
    [Parameter(Mandatory = $true)][object]$Summary,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $records = @($Summary.records)
  $map = @{}
  foreach ($record in $records) {
    $method = [string]$record.method
    Assert-Issue13OracleEffect ($method -match '^[a-z0-9_]+$') `
      "$Label has an invalid method id."
    Assert-Issue13OracleEffect (-not $map.ContainsKey($method)) `
      "$Label repeats method $method."
    $map[$method] = $record
  }
  $map
}

function Get-Issue13OracleEffectScenario {
  param(
    [Parameter(Mandatory = $true)][object]$Record,
    [Parameter(Mandatory = $true)][string]$SummaryRoot,
    [Parameter(Mandatory = $true)][string]$ExpectedSha256,
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][bool]$ExpectedPassed,
    [Parameter(Mandatory = $true)][string]$ExpectedCommit,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $expectedScenarioId = "baseline/calculate/$Method/workers1"
  $expectedDirectory = Join-Path $SummaryRoot (
    "attempts/$Method/evidence/scenarios/" +
      "baseline__calculate__${Method}__workers1"
  )
  $expectedProjectRoot = Join-Path $SummaryRoot "worktrees/$Method"
  Assert-Issue13OracleEffect ($Record.scenario_id -ceq $expectedScenarioId -and `
      $Record.status -ceq $(if ($ExpectedPassed) {'passed'} else {'failed'})) `
    "$Label summary record identity differs."
  Assert-Issue13OracleEffect (
    Test-Issue13OracleEffectPathEqual ([string]$Record.evidence_directory) `
      $expectedDirectory
  ) "$Label evidence_directory is not the closed baseline scenario directory."
  Assert-Issue13OracleEffect (
    Test-Issue13OracleEffectPathEqual ([string]$Record.project_root) `
      $expectedProjectRoot
  ) "$Label summary project_root differs."
  if ($ExpectedPassed) {
    Assert-Issue13OracleEffect ($Record.scenario_result_sha256 -ceq $ExpectedSha256) `
      "$Label summary scenario pin differs."
  }
  $path = Join-Path $expectedDirectory 'scenario-result.json'
  $resolved = Resolve-Issue13OracleEffectFile $path "$Label scenario result"
  Assert-Issue13OracleEffect ((Get-Issue13OracleEffectSha256 $resolved) -ceq $ExpectedSha256) `
    "$Label scenario-result hash differs."
  $document = Read-Issue13OracleEffectJson $resolved "$Label scenario result"
  Assert-Issue13OracleEffect ($document.schema -ceq 'wlv-issue13-scenario-result/1') `
    "$Label scenario schema differs."
  Assert-Issue13OracleEffect (
    Test-Issue13OracleEffectExactBoolean $document.passed $ExpectedPassed
  ) `
    "$Label scenario passed flag differs."
  Assert-Issue13OracleEffect ($document.status -ceq $(if ($ExpectedPassed) {'passed'} else {'failed'})) `
    "$Label scenario status differs."
  Assert-Issue13OracleEffect ($document.kind -ceq 'calculate') `
    "$Label scenario is not calculate."
  Assert-Issue13OracleEffect ($document.scenario_id -ceq $expectedScenarioId -and `
      $document.request.method -ceq $Method) `
    "$Label request method differs."
  Assert-Issue13OracleEffectExactSet @($document.request.methods) @($Method) `
    "$Label request methods"
  Assert-Issue13OracleEffect ([int]$document.request.workers -eq 1) `
    "$Label is not workers=1."
  Assert-Issue13OracleEffect ($document.expected_commit -ceq $ExpectedCommit -and `
      $document.observed_commit -ceq $ExpectedCommit) `
    "$Label commit binding differs."
  Assert-Issue13OracleEffect (
    Test-Issue13OracleEffectPathEqual ([string]$document.project_root) `
      $expectedProjectRoot
  ) "$Label scenario project_root differs."
  $expectedSpecPath = Join-Path $SummaryRoot `
    "attempts/$Method/bundle/scenario-spec.json"
  Assert-Issue13OracleEffect (
    Test-Issue13OracleEffectPathEqual `
      ([string]$document.execution_checkpoint.scenario_spec_path) $expectedSpecPath
  ) "$Label scenario spec path differs."
  $specPath = Resolve-Issue13OracleEffectFile $expectedSpecPath "$Label scenario spec"
  $specSha = Get-Issue13OracleEffectSha256 $specPath
  Assert-Issue13OracleEffect ($specSha -ceq `
      [string]$document.execution_checkpoint.scenario_spec_sha256) `
    "$Label scenario spec bytes differ from the scenario pin."
  $scenarioSpec = Read-Issue13OracleEffectJson $specPath "$Label scenario spec"
  Assert-Issue13OracleEffect ($scenarioSpec.schema -ceq 'wlv-issue13-scenario/1' -and `
      $scenarioSpec.scenario_id -ceq $expectedScenarioId -and `
      $scenarioSpec.kind -ceq 'calculate' -and `
      $scenarioSpec.method -ceq $Method -and `
      [int]$scenarioSpec.workers -eq 1 -and `
      $scenarioSpec.expected_commit -ceq $ExpectedCommit) `
    "$Label scenario spec identity differs."
  Assert-Issue13OracleEffect (
    Test-Issue13OracleEffectPathEqual ([string]$scenarioSpec.project_root) `
      $expectedProjectRoot
  ) "$Label scenario spec project_root differs."
  [pscustomobject]@{
    path = $resolved
    sha256 = $ExpectedSha256
    spec_path = $specPath
    spec_sha256 = $specSha
    document = $document
  }
}

function Get-Issue13OracleEffectSafeRelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $normalized = $Path.Replace('\', '/')
  $invalid = [string]::IsNullOrWhiteSpace($normalized) -or `
    $normalized.StartsWith('/') -or $normalized -match '^[A-Za-z]:' -or `
    $normalized -match '(^|/)\.\.(/|$)' -or `
    $normalized -match '(^|/)\.(/|$)' -or `
    $normalized.EndsWith('/') -or $normalized.Contains('//')
  Assert-Issue13OracleEffect (-not $invalid) "$Label is unsafe: $Path"
  $normalized
}

function Get-Issue13OracleEffectRunInventory {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][string]$DeclaredInventorySha256,
    [Parameter(Mandatory = $true)][string]$Label
  )
  Assert-Issue13OracleEffectNoReparseTree $Root "$Label run root"
  $expectedManifest = Join-Path $Root 'run_manifest.json'
  Assert-Issue13OracleEffect (
    Test-Issue13OracleEffectPathEqual $ManifestPath $expectedManifest
  ) "$Label manifest is not the physical run-root manifest."
  Assert-Issue13OracleEffectExactProperties $Manifest @(
    'schema', 'schema_version', 'run_id', 'result_id', 'created_at_utc',
    'parent_run_id', 'method', 'output_contract', 'result', 'execution',
    'artifacts'
  ) "$Label run manifest properties"
  Assert-Issue13OracleEffect ([string]$Manifest.schema_version -ceq '1') `
    "$Label run manifest version differs."
  $artifactRecords = @($Manifest.artifacts)
  Assert-Issue13OracleEffect ($artifactRecords.Count -gt 0) `
    "$Label run manifest has no artifact records."
  $paths = New-Object Collections.Generic.List[string]
  $roles = @{}
  $previous = $null
  foreach ($record in $artifactRecords) {
    Assert-Issue13OracleEffectExactProperties $record @(
      'path', 'role', 'size_bytes', 'sha256'
    ) "$Label run artifact record"
    $relative = Get-Issue13OracleEffectSafeRelativePath `
      ([string]$record.path) "$Label run artifact path"
    Assert-Issue13OracleEffect ($relative -cne 'run_manifest.json') `
      "$Label run manifest inventories itself."
    Assert-Issue13OracleEffect (-not $roles.ContainsKey($relative)) `
      "$Label repeats run artifact $relative."
    if ($null -ne $previous) {
      Assert-Issue13OracleEffect (
        [StringComparer]::Ordinal.Compare([string]$previous, $relative) -lt 0
      ) "$Label run artifact paths are not canonically ordered."
    }
    $previous = $relative
    Assert-Issue13OracleEffect ([string]$record.role -cmatch `
        '^[a-z0-9][a-z0-9._-]*$') `
      "$Label run artifact role is invalid: $relative"
    Assert-Issue13OracleEffect ([int64]$record.size_bytes -ge 0 -and `
        [string]$record.sha256 -cmatch '^[0-9a-f]{64}$') `
      "$Label run artifact size or hash is invalid: $relative"
    $paths.Add($relative)
    $roles[$relative] = [string]$record.role
  }
  $physicalFiles = @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force)
  $physicalRelative = [string[]]@($physicalFiles | ForEach-Object {
    $_.FullName.Substring($Root.Length + 1).Replace('\', '/')
  })
  $expectedRelative = [string[]]@($paths.ToArray() + @('run_manifest.json'))
  Assert-Issue13OracleEffectExactSet $physicalRelative $expectedRelative `
    "$Label physical run files"
  $manifestSha = Get-Issue13OracleEffectSha256 $ManifestPath
  $proofFiles = New-Object Collections.Generic.List[object]
  $artifactLines = New-Object Collections.Generic.List[string]
  foreach ($record in $artifactRecords) {
    $relative = [string]$record.path
    $path = Resolve-Issue13OracleEffectFile (Join-Path $Root $relative) `
      "$Label run artifact $relative"
    $item = Get-Item -LiteralPath $path -Force
    $sha = Get-Issue13OracleEffectSha256 $path
    Assert-Issue13OracleEffect ([int64]$item.Length -eq `
        [int64]$record.size_bytes -and $sha -ceq [string]$record.sha256) `
      "$Label physical run artifact differs from its manifest: $relative"
    $proofFiles.Add([pscustomobject][ordered]@{
      path = $relative
      role = [string]$record.role
      sha256 = $sha
      size_bytes = [int64]$item.Length
    })
    $artifactLines.Add(
      $relative + '|' + [string]$record.role + '|' +
        ([int64]$item.Length).ToString(
          [Globalization.CultureInfo]::InvariantCulture
        ) + '|' + $sha
    )
  }
  $manifestItem = Get-Item -LiteralPath $ManifestPath -Force
  $proofFiles.Add([pscustomobject][ordered]@{
    path = 'run_manifest.json'
    role = 'run-manifest'
    sha256 = $manifestSha
    size_bytes = [int64]$manifestItem.Length
  })
  $orderedFiles = @($proofFiles.ToArray())
  [Array]::Sort($orderedFiles, [Comparison[object]]{
    param($left, $right)
    [StringComparer]::Ordinal.Compare([string]$left.path, [string]$right.path)
  })
  $signature = Get-Issue13OracleEffectUtf8Sha256 (
    'run' + "`n" + $manifestSha + "`n" + ($artifactLines -join "`n")
  )
  Assert-Issue13OracleEffect ($signature -ceq $DeclaredInventorySha256) `
    "$Label physical wlv13_run_inventory/signature differs from the scenario pin."
  [pscustomobject][ordered]@{
    file_count = [int64]$orderedFiles.Count
    total_bytes = [int64](($orderedFiles | Measure-Object size_bytes -Sum).Sum)
    manifest_sha256 = $manifestSha
    inventory_signature_sha256 = $signature
    files = $orderedFiles
  }
}

function Get-Issue13OracleEffectRunOutput {
  param(
    [Parameter(Mandatory = $true)][object]$Scenario,
    [Parameter(Mandatory = $true)][object]$Pin,
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$ExpectedCommit,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $outputs = @($Scenario.document.outputs)
  Assert-Issue13OracleEffect ($outputs.Count -eq 1) `
    "$Label must publish exactly one output."
  $output = $outputs[0]
  Assert-Issue13OracleEffect ($output.kind -ceq 'run' -and $output.method -ceq $Method) `
    "$Label output identity differs."
  Assert-Issue13OracleEffect ($output.manifest_sha256 -ceq $Pin.manifest_sha256) `
    "$Label output manifest pin differs."
  Assert-Issue13OracleEffect ($output.inventory_sha256 -ceq $Pin.inventory_sha256) `
    "$Label output inventory pin differs."
  $root = Resolve-Issue13OracleEffectDirectory ([string]$output.root) "$Label run root"
  $manifestPath = Resolve-Issue13OracleEffectFile ([string]$output.manifest_path) `
    "$Label run manifest"
  Assert-Issue13OracleEffect ((Get-Issue13OracleEffectSha256 $manifestPath) -ceq `
      [string]$output.manifest_sha256) "$Label run manifest bytes differ."
  $manifest = Read-Issue13OracleEffectJson $manifestPath "$Label run manifest"
  Assert-Issue13OracleEffect ($manifest.schema -ceq 'wlv-run-manifest') `
    "$Label run manifest schema differs."
  Assert-Issue13OracleEffect ($manifest.method -ceq $Method) `
    "$Label run manifest method differs."
  Assert-Issue13OracleEffect ($manifest.run_id -ceq $output.run_id -and `
      $manifest.result_id -ceq $output.result_id -and `
      [string]$manifest.parent_run_id -ceq [string]$output.parent_run_id -and `
      $manifest.result.request.method -ceq $Method -and `
      $manifest.result.request.mode -ceq 'calculate' -and `
      [int]$manifest.result.request.workers -eq 1 -and `
      $output.request.method -ceq $Method -and `
      $output.request.mode -ceq 'calculate' -and `
      [int]$output.request.workers -eq 1) `
    "$Label run identity or calculate/workers1 request differs."
  Assert-Issue13OracleEffect ($manifest.output_contract.id -ceq 'wlvpanel-output' -and `
      $manifest.output_contract.version -ceq '1.0.0') `
    "$Label output contract differs."
  Assert-Issue13OracleEffect ((Test-Issue13OracleEffectExactBoolean `
        $manifest.result.provenance.complete $true) -and `
      (Test-Issue13OracleEffectExactBoolean `
        $manifest.result.provenance.git.dirty $false) -and `
      $manifest.result.provenance.git.commit -ceq $ExpectedCommit) `
    "$Label provenance is incomplete, dirty, or bound to another commit."
  $physical = Get-Issue13OracleEffectRunInventory $root $manifestPath $manifest `
    ([string]$output.inventory_sha256) $Label
  [pscustomobject]@{
    root = $root
    output = $output
    manifest_path = $manifestPath
    manifest = $manifest
    physical_inventory = $physical
  }
}

function Get-Issue13OracleEffectArtifact {
  param(
    [Parameter(Mandatory = $true)][object]$Run,
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $entries = @($Run.manifest.artifacts | Where-Object { $_.path -ceq $RelativePath })
  Assert-Issue13OracleEffect ($entries.Count -eq 1) `
    "$Label manifest does not contain exactly one $RelativePath artifact."
  $entry = $entries[0]
  $path = Resolve-Issue13OracleEffectFile (Join-Path $Run.root $RelativePath) `
    "$Label $RelativePath"
  $item = Get-Item -LiteralPath $path
  Assert-Issue13OracleEffect ([int64]$entry.size_bytes -eq [int64]$item.Length) `
    "$Label $RelativePath size differs from the manifest."
  Assert-Issue13OracleEffect ((Get-Issue13OracleEffectSha256 $path) -ceq [string]$entry.sha256) `
    "$Label $RelativePath hash differs from the manifest."
  [pscustomobject]@{
    path = $path
    relative_path = $RelativePath
    sha256 = [string]$entry.sha256
    size_bytes = [int64]$entry.size_bytes
    role = [string]$entry.role
  }
}

function Split-Issue13OracleEffectSimpleCsvLine {
  param(
    [Parameter(Mandatory = $true)][string]$Line,
    [Parameter(Mandatory = $true)][int]$ExpectedFieldCount,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $tokens = @($Line.Split(';'))
  Assert-Issue13OracleEffect ($tokens.Count -eq $ExpectedFieldCount) `
    "$Label has $($tokens.Count) fields; expected $ExpectedFieldCount."
  [string[]]@($tokens | ForEach-Object {
    $token = [string]$_
    if ($token.Length -ge 2 -and $token[0] -eq '"' -and `
        $token[$token.Length - 1] -eq '"') {
      $token.Substring(1, $token.Length - 2).Replace('""', '"')
    } else {
      $token
    }
  })
}

function Get-Issue13OracleEffectAnomalyRows {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$PolicyId,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $expectedHeader = @(
    'artifact', 'indicator', 'checkpoint', 'stage', 'module', 'year',
    'country', 'sector', 'output', 'original_value', 'policy_id', 'action'
  )
  $rows = New-Object Collections.Generic.List[object]
  $lineNumber = 0
  foreach ($line in [IO.File]::ReadLines($Path)) {
    $lineNumber++
    if ($lineNumber -eq 1) {
      $header = Split-Issue13OracleEffectSimpleCsvLine $line 12 "$Label header"
      Assert-Issue13OracleEffect (($header -join "`n") -ceq ($expectedHeader -join "`n")) `
        "$Label header differs."
      continue
    }
    if (-not $line.Contains("`"$PolicyId`"")) {
      continue
    }
    $fields = Split-Issue13OracleEffectSimpleCsvLine $line 12 `
      "$Label line $lineNumber"
    $row = [ordered]@{}
    for ($index = 0; $index -lt $expectedHeader.Count; $index++) {
      $row[$expectedHeader[$index]] = $fields[$index]
    }
    if ($row.policy_id -ceq $PolicyId) {
      $rows.Add([pscustomobject]$row)
    }
  }
  [object[]]$rows.ToArray()
}

function Test-Issue13OracleEffectLeontief {
  param(
    [Parameter(Mandatory = $true)][object]$Run,
    [Parameter(Mandatory = $true)][object]$Spec,
    [Parameter(Mandatory = $true)][string]$Method
  )
  $profileId = if ($Method -ceq 'norow_w13') { 'stable' } else { 'v09' }
  $profile = $Spec.coordinate_contracts.leontief_zero_output.profiles.$profileId
  $signed = $Spec.coordinate_contracts.leontief_signed_diagnostic.$profileId
  $anomalies = Get-Issue13OracleEffectArtifact $Run '_anomalies.csv' "$Method oracle run"
  $diagnostics = Get-Issue13OracleEffectArtifact $Run '_leontief_diagnostics.csv' `
    "$Method oracle run"
  $scientific = Get-Issue13OracleEffectArtifact $Run '_scientific_checks.csv' `
    "$Method oracle run"
  $rows = @(Get-Issue13OracleEffectAnomalyRows $anomalies.path `
    'wiodr13_leontief_zero_output_v1' "$Method anomalies")
  Assert-Issue13OracleEffect ($rows.Count -eq [int]$profile.coordinate_count) `
    "$Method Leontief allowlist count differs."
  $keys = New-Object Collections.Generic.List[string]
  $counts = @{}
  foreach ($row in $rows) {
    Assert-Issue13OracleEffect ($row.artifact -ceq 'm_io' -and `
        $row.indicator -ceq 'leontief_input_ratio' -and `
        $row.checkpoint -ceq 'after_matrices' -and $row.stage -ceq '3' -and `
        $row.module -ceq 'transformation.R' -and $row.country -ceq '' -and `
        $row.original_value -ceq 'Inf' -and `
        $row.action -ceq 'allowlisted_nonzero_over_zero') `
      "$Method has a malformed Leontief anomaly row."
    $key = "$($row.year)|$($row.sector)|$($row.output)"
    $keys.Add($key)
    $group = "$($row.year)|$($row.output)"
    if (-not $counts.ContainsKey($group)) { $counts[$group] = 0 }
    $counts[$group]++
  }
  Assert-Issue13OracleEffect (($keys | Select-Object -Unique).Count -eq $keys.Count) `
    "$Method Leontief coordinates are duplicated."
  Assert-Issue13OracleEffect (
    (Get-Issue13OracleEffectTextHash $keys.ToArray() MD5) -ceq
      [string]$profile.coordinate_md5
  ) "$Method Leontief coordinate MD5 differs."
  Assert-Issue13OracleEffectExactSet @($counts.Keys) `
    @(Get-Issue13OracleEffectPropertyNames $profile.year_output_counts) `
    "$Method Leontief year/output groups"
  foreach ($property in $profile.year_output_counts.PSObject.Properties) {
    Assert-Issue13OracleEffect ([int]$counts[$property.Name] -eq [int]$property.Value) `
      "$Method Leontief count differs for $($property.Name)."
  }

  $diag = @(Import-Csv -Delimiter ';' -LiteralPath $diagnostics.path)
  $years = @($Spec.coordinate_contracts.leontief_signed_diagnostic.years)
  Assert-Issue13OracleEffect ($diag.Count -eq 15) `
    "$Method Leontief diagnostic must have 15 rows."
  Assert-Issue13OracleEffectExactSet @($diag | ForEach-Object year) $years `
    "$Method diagnostic years"
  foreach ($row in $diag) {
    $isSigned = $row.year -ceq [string]$signed.signed_year
    $expectedCount = if ($isSigned) { [int]$signed.signed_coefficient_count } else { 0 }
    $expectedCertificate = if ($isSigned) {
      [string]$Spec.coordinate_contracts.leontief_signed_diagnostic.signed_certificate
    } else {
      [string]$Spec.coordinate_contracts.leontief_signed_diagnostic.other_year_certificate
    }
    Assert-Issue13OracleEffect ($row.method -ceq $Method -and `
        [int]$row.coefficient_negative_count -eq $expectedCount -and `
        $row.certificate_type -ceq $expectedCertificate -and `
        [int]$row.coefficient_nonfinite_count -eq 0 -and `
        [int]$row.gross_output_nonfinite_count -eq 0 -and `
        [int]$row.lambda_nonfinite_count -eq 0) `
      "$Method Leontief diagnostic differs for year $($row.year)."
  }

  $checks = @(Import-Csv -Delimiter ';' -LiteralPath $scientific.path)
  $expectedChecks = @{
    leontief_diagnostics = @('warning', 'global', '15')
    leontief_generation_fingerprint = @('pass', 'global', '15')
    leontief_productivity = @('not_applicable', '2006', '0')
  }
  foreach ($id in $expectedChecks.Keys) {
    $matches = @($checks | Where-Object { $_.check_id -ceq $id })
    Assert-Issue13OracleEffect ($matches.Count -eq 1) `
      "$Method scientific checks do not contain exactly one $id row."
    $expected = $expectedChecks[$id]
    Assert-Issue13OracleEffect ($matches[0].method -ceq $Method -and `
        $matches[0].status -ceq $expected[0] -and `
        $matches[0].scope -ceq $expected[1] -and `
        $matches[0].observations -ceq $expected[2]) `
      "$Method scientific check $id differs."
  }
  [pscustomobject][ordered]@{
    profile_id = $profileId
    coordinate_count = [int]$profile.coordinate_count
    coordinate_md5 = [string]$profile.coordinate_md5
    signed_year = [string]$signed.signed_year
    signed_coefficient_count = [int]$signed.signed_coefficient_count
    signed_certificate = [string]$Spec.coordinate_contracts.leontief_signed_diagnostic.signed_certificate
    anomaly_artifact_sha256 = $anomalies.sha256
    diagnostic_artifact_sha256 = $diagnostics.sha256
    scientific_checks_sha256 = $scientific.sha256
  }
}

function Test-Issue13OracleEffectNanClean {
  param(
    [Parameter(Mandatory = $true)][object]$Run,
    [Parameter(Mandatory = $true)][object]$Spec,
    [Parameter(Mandatory = $true)][string]$Method
  )
  $contract = $Spec.coordinate_contracts.historical_nan_clean
  $methodContract = $contract.methods.$Method
  Assert-Issue13OracleEffect ($null -ne $methodContract) `
    "$Method does not have a historical-NaN contract."
  $anomalies = Get-Issue13OracleEffectArtifact $Run '_anomalies.csv' "$Method oracle run"
  $rows = @(Get-Issue13OracleEffectAnomalyRows $anomalies.path `
    'issue13_cc2_historical_nan_clean_v1' "$Method anomalies")
  Assert-Issue13OracleEffect ($rows.Count -eq 405) `
    "$Method historical-NaN row count differs."
  $keys = New-Object Collections.Generic.List[string]
  $counts = @{}
  foreach ($row in $rows) {
    Assert-Issue13OracleEffect ($row.artifact -ceq 'sea_sectors' -and `
        $row.checkpoint -ceq 'after_stage_2' -and $row.stage -ceq '2' -and `
        $row.module -ceq [string]$methodContract.module -and `
        $row.output -ceq '' -and $row.original_value -ceq 'NaN' -and `
        $row.action -ceq 'replace_historical_nan_with_zero') `
      "$Method has a malformed historical-NaN anomaly row."
    $keys.Add("$($row.indicator)|$($row.year)|$($row.country)|$($row.sector)")
    if (-not $counts.ContainsKey($row.indicator)) { $counts[$row.indicator] = 0 }
    $counts[$row.indicator]++
  }
  Assert-Issue13OracleEffect (($keys | Select-Object -Unique).Count -eq 405) `
    "$Method historical-NaN coordinates are duplicated."
  Assert-Issue13OracleEffect (
    (Get-Issue13OracleEffectTextHash $keys.ToArray() SHA256) -ceq
      [string]$contract.coordinate_sha256
  ) "$Method historical-NaN coordinate SHA-256 differs."
  Assert-Issue13OracleEffectExactSet @($counts.Keys) @($contract.indicators) `
    "$Method historical-NaN indicators"
  foreach ($indicator in @($contract.indicators)) {
    Assert-Issue13OracleEffect ([int]$counts[$indicator] -eq 135) `
      "$Method historical-NaN count differs for $indicator."
  }
  [pscustomobject][ordered]@{
    coordinate_count = 405
    coordinate_sha256 = [string]$contract.coordinate_sha256
    before_value = 'NaN'
    denominator_indicator = [string]$methodContract.denominator_indicator
    denominator_requirement = [string]$contract.denominator_requirement
    after_value = 'finite numeric zero'
    module = [string]$methodContract.module
    policy_id = [string]$contract.policy_id
    action = [string]$contract.action
  }
}

function Test-Issue13OracleEffectUtf8 {
  param(
    [Parameter(Mandatory = $true)][object]$Run,
    [Parameter(Mandatory = $true)][object]$Spec
  )
  $contract = $Spec.coordinate_contracts.norow_utf8
  $artifact = Get-Issue13OracleEffectArtifact $Run '_parameters.csv' 'norow_w13 oracle run'
  $bytes = [IO.File]::ReadAllBytes($artifact.path)
  $encoding = New-Object Text.UTF8Encoding($false, $true)
  try { $text = $encoding.GetString($bytes) } catch {
    throw 'Issue #13 oracle-effect proof rejected: norow _parameters.csv is not valid UTF-8.'
  }
  Assert-Issue13OracleEffect (-not $text.Contains([char]0xFFFD)) `
    'norow _parameters.csv contains U+FFFD.'
  $rows = @(Import-Csv -Delimiter ';' -LiteralPath $artifact.path)
  Assert-Issue13OracleEffect ($rows.Count -eq 1 -and `
      $rows[0].source -ceq 'wiodr13' -and $rows[0].code -ceq 'norow_w13' -and `
      $rows[0].name -ceq [string]$contract.expected_value) `
    'norow UTF-8 parameter row differs.'
  $valueHash = Get-Issue13OracleEffectTextHash @([string]$rows[0].name) SHA256
  Assert-Issue13OracleEffect ($valueHash -ceq [string]$contract.expected_value_utf8_sha256) `
    'norow UTF-8 parameter value hash differs.'
  [pscustomobject][ordered]@{
    artifact_sha256 = $artifact.sha256
    field = 'name'
    value = [string]$rows[0].name
    value_utf8_sha256 = $valueHash
  }
}

function Get-Issue13OracleEffectHarnessInventory {
  param([Parameter(Mandatory = $true)][string]$RuntimeRoot)

  $root = Resolve-Issue13OracleEffectDirectory $RuntimeRoot `
    'materialized comparison runtime root'
  Assert-Issue13OracleEffectNoReparseTree $root `
    'materialized comparison runtime root'
  $harnessRoot = Resolve-Issue13OracleEffectDirectory `
    (Join-Path $root 'issue13-evidence-harness') `
    'materialized comparison harness root'
  $rootDirectories = @(Get-ChildItem -LiteralPath $root -Directory -Force)
  Assert-Issue13OracleEffect ($rootDirectories.Count -eq 1 -and `
      $rootDirectories[0].Name -ceq 'issue13-evidence-harness') `
    'materialized comparison runtime has an unexpected root directory.'
  Assert-Issue13OracleEffect (@(Get-ChildItem -LiteralPath $harnessRoot `
      -Directory -Recurse -Force).Count -eq 0) `
    'materialized comparison harness is not flat.'
  $files = @(
    @(Get-ChildItem -LiteralPath $root -File -Force | Where-Object {
      $_.Name -cne 'v5-harness-manifest.json'
    })
    @(Get-ChildItem -LiteralPath $harnessRoot -File -Force)
  )
  $records = @($files | ForEach-Object {
    [pscustomobject][ordered]@{
      relative_path = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
      size_bytes = [int64]$_.Length
      sha256 = Get-Issue13OracleEffectSha256 $_.FullName
    }
  } | Sort-Object relative_path)
  Assert-Issue13OracleEffect ($records.Count -gt 0) `
    'materialized comparison harness inventory is empty.'
  $lines = [string[]]@($records | ForEach-Object {
    [string]$_.relative_path + '|' + [string]$_.size_bytes + '|' +
      [string]$_.sha256
  })
  $payload = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
  $hasher = [Security.Cryptography.HashAlgorithm]::Create('SHA256')
  try {
    $inventoryHash = (($hasher.ComputeHash($payload) | ForEach-Object {
      $_.ToString('x2')
    }) -join '')
  } finally {
    $hasher.Dispose()
  }
  [pscustomobject][ordered]@{
    root = $root
    harness_root = $harnessRoot
    file_count = [int64]$records.Count
    total_bytes = [int64](($records | Measure-Object size_bytes -Sum).Sum)
    inventory_sha256 = $inventoryHash
    records = $records
  }
}

function Assert-Issue13OracleEffectHarnessManifestEnvelope {
  param([Parameter(Mandatory = $true)][object]$Manifest)
  Assert-Issue13OracleEffectExactProperties $Manifest @(
    'schema', 'generation', 'status', 'materialized_at_utc',
    'baseline_commit', 'baseline_policy', 'baseline_runtime_commit',
    'baseline_runtime_tree', 'baseline_overlay_sha256',
    'baseline_overlay_patch_id', 'strict_negative_evidence_required',
    'final_evidence_eligible', 'reuses_candidate_evidence',
    'source_controller', 'source_tooling', 'output_tooling',
    'sealed_output_tooling', 'overlays'
  ) 'comparison harness manifest properties'
  Assert-Issue13OracleEffectExactProperties $Manifest.source_controller @(
    'commit_sha256', 'file_count', 'records'
  ) 'terminal source_controller properties'
  foreach ($name in @('output_tooling', 'sealed_output_tooling')) {
    Assert-Issue13OracleEffectExactProperties $Manifest.$name @(
      'file_count', 'total_bytes', 'inventory_sha256'
    ) "terminal $name properties"
  }
  $timestamp = [DateTimeOffset]::MinValue
  Assert-Issue13OracleEffect (
    [DateTimeOffset]::TryParseExact(
      [string]$Manifest.materialized_at_utc, 'o',
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::RoundtripKind, [ref]$timestamp
    ) -and $timestamp.Offset -eq [TimeSpan]::Zero -and
    [string]$Manifest.materialized_at_utc -cmatch 'Z$'
  ) 'comparison harness materialized_at_utc is not an exact UTC round-trip timestamp.'
  Assert-Issue13OracleEffect (
    [string]$Manifest.schema -ceq 'wlv-issue13-v5-harness-materialization/1' -and
    [string]$Manifest.status -ceq 'materialized' -and
    [string]$Manifest.generation -ceq 'v5-terminal' -and
    [string]$Manifest.baseline_policy -ceq
      'authenticated-direct-child-compatibility-oracle' -and
    (Test-Issue13OracleEffectExactBoolean `
      $Manifest.strict_negative_evidence_required $true) -and
    (Test-Issue13OracleEffectExactBoolean `
      $Manifest.final_evidence_eligible $true) -and
    (Test-Issue13OracleEffectExactBoolean `
      $Manifest.reuses_candidate_evidence $false)
  ) 'comparison harness manifest identity or policy differs.'
  $expectedOverlays = @(
    'authenticated-compatibility-oracle-cc2',
    'authenticated-candidate-runtime-sidecar',
    'authenticated-arm-specific-source-contracts'
  )
  $observedOverlays = [string[]]@($Manifest.overlays)
  Assert-Issue13OracleEffect (
    $observedOverlays.Count -eq $expectedOverlays.Count -and
    [string]::Join("`n", $observedOverlays) -ceq
      [string]::Join("`n", $expectedOverlays)
  ) 'comparison harness overlays differ in value or order.'
  $true
}

function Test-Issue13OracleEffectHarnessManifest {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][object]$Spec,
    [Parameter(Mandatory = $true)][string]$ExpectedCandidateCommit,
    [Parameter(Mandatory = $true)][string]$RepositoryRoot
  )
  $resolved = Resolve-Issue13OracleEffectFile $Path 'comparison harness manifest'
  $runtimeRoot = Split-Path -Parent $resolved
  Assert-Issue13OracleEffect ((Split-Path -Leaf $resolved) -ceq `
      'v5-harness-manifest.json') `
    'comparison harness manifest must use the terminal manifest filename.'
  $runtimeLeaf = Split-Path -Leaf $runtimeRoot
  Assert-Issue13OracleEffect ($runtimeLeaf -cnotmatch '(?i)v5c[56](?:$|[^0-9])') `
    'pre-terminal v5c5/v5c6 runtime names are forbidden.'
  Assert-Issue13OracleEffect ($ExpectedCandidateCommit -cmatch '^[0-9a-f]{40}$') `
    'ExpectedCandidateCommit is not a lowercase 40-hex Git commit.'
  Assert-Issue13OracleEffect (
    (Invoke-Issue13OracleEffectGit $RepositoryRoot @(
      'rev-parse', "$ExpectedCandidateCommit^{commit}"
    )) -ceq $ExpectedCandidateCommit
  ) 'ExpectedCandidateCommit is not an available Git commit.'
  $manifest = Read-Issue13OracleEffectJson $resolved 'comparison harness manifest'
  $null = Assert-Issue13OracleEffectHarnessManifestEnvelope $manifest
  $expectedController = Get-Issue13OracleEffectExpectedController $Spec `
    $ExpectedCandidateCommit $RepositoryRoot
  $expectedSourceTooling = Get-Issue13OracleEffectExpectedSourceTooling $Spec `
    $ExpectedCandidateCommit $RepositoryRoot
  $null = Assert-Issue13OracleEffectSourceTooling `
    $manifest.source_tooling $expectedSourceTooling `
    'terminal manifest source_tooling'
  Assert-Issue13OracleEffect (
    [string]$manifest.source_controller.commit_sha256 -ceq `
      [string]$expectedController.commit_sha256
  ) 'terminal source_controller.commit_sha256 differs from authenticated controller.'
  $controllerRecords = @($manifest.source_controller.records)
  Assert-Issue13OracleEffect (
    [int64]$manifest.source_controller.file_count -eq `
      [int64]$expectedController.file_count -and
    $controllerRecords.Count -eq [int64]$expectedController.file_count
  ) `
    'terminal source_controller record count differs.'
  foreach ($record in $controllerRecords) {
    Assert-Issue13OracleEffectExactProperties $record @(
      'name', 'relative_path', 'sha256', 'git_blob'
    ) 'terminal source_controller record'
    $null = Get-Issue13OracleEffectSafeRelativePath `
      ([string]$record.relative_path) 'terminal controller relative_path'
  }
  $null = Assert-Issue13OracleEffectControllerRecords $controllerRecords `
    @($expectedController.records) 'terminal source_controller'
  Assert-Issue13OracleEffect ($manifest.baseline_commit -ceq $Spec.oracle.base_commit -and `
      $manifest.baseline_runtime_commit -ceq $Spec.oracle.runtime_commit -and `
      $manifest.baseline_runtime_tree -ceq $Spec.oracle.runtime_tree -and `
      $manifest.baseline_overlay_sha256 -ceq $Spec.oracle.canonical_patch_sha256 -and `
      $manifest.baseline_overlay_patch_id -ceq $Spec.oracle.stable_patch_id) `
    'comparison harness manifest is not bound to the authorized oracle.'
  $inventory = Get-Issue13OracleEffectHarnessInventory $runtimeRoot
  $externalInventory = $Spec.terminal_comparison_runtime.sealed_inventory
  Assert-Issue13OracleEffect (
    [string]$externalInventory.status -ceq 'sealed'
  ) 'terminal harness fixture still requires reseal; proof generation is disabled.'
  Assert-Issue13OracleEffect (
    [int64]$inventory.file_count -eq [int64]$externalInventory.file_count -and
    [int64]$inventory.total_bytes -eq [int64]$externalInventory.total_bytes -and
    [string]$inventory.inventory_sha256 -ceq `
      [string]$externalInventory.inventory_sha256
  ) 'materialized harness differs from the external terminal inventory pin.'
  foreach ($record in @($manifest.output_tooling, $manifest.sealed_output_tooling)) {
    Assert-Issue13OracleEffect ([int64]$record.file_count -eq $inventory.file_count -and `
        [int64]$record.total_bytes -eq $inventory.total_bytes -and `
        [string]$record.inventory_sha256 -ceq $inventory.inventory_sha256) `
      'comparison harness manifest does not authenticate the installed inventory.'
  }
  $harnessRoot = $inventory.harness_root
  $toolNames = @($Spec.terminal_comparison_runtime.required_tool_files)
  $tools = @(
    foreach ($name in $toolNames) {
      $tool = Resolve-Issue13OracleEffectFile (Join-Path $harnessRoot $name) `
        "comparison tool $name"
      [pscustomobject][ordered]@{
        name = $name
        sha256 = Get-Issue13OracleEffectSha256 $tool
        size_bytes = [int64](Get-Item -LiteralPath $tool).Length
      }
    }
  )
  [pscustomobject][ordered]@{
    expected_candidate_commit = $ExpectedCandidateCommit
    manifest_path = $resolved
    manifest_sha256 = Get-Issue13OracleEffectSha256 $resolved
    generation = 'v5-terminal'
    final_evidence_eligible = $true
    reuses_candidate_evidence = $false
    source_controller_commit_sha256 = `
      [string]$manifest.source_controller.commit_sha256
    source_controller = $expectedController
    source_tooling = $expectedSourceTooling
    output_tooling = [pscustomobject][ordered]@{
      file_count = [int64]$manifest.output_tooling.file_count
      total_bytes = [int64]$manifest.output_tooling.total_bytes
      inventory_sha256 = [string]$manifest.output_tooling.inventory_sha256
    }
    sealed_output_tooling = [pscustomobject][ordered]@{
      file_count = [int64]$manifest.sealed_output_tooling.file_count
      total_bytes = [int64]$manifest.sealed_output_tooling.total_bytes
      inventory_sha256 = [string]$manifest.sealed_output_tooling.inventory_sha256
    }
    installed_inventory = $inventory
    tools = $tools
  }
}

function New-Issue13OracleEffectApprovedRunState {
  param(
    [Parameter(Mandatory = $true)][ValidateSet('strict', 'oracle')]
      [string]$Arm,
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$ExpectedCommit,
    [Parameter(Mandatory = $true)][object]$Scenario,
    [Parameter(Mandatory = $true)][object]$Run
  )
  [pscustomobject][ordered]@{
    key = "$Arm|$Method"
    arm = $Arm
    method = $Method
    expected_commit = $ExpectedCommit
    scenario_pin = [pscustomobject][ordered]@{
      path = [string]$Scenario.path
      sha256 = [string]$Scenario.sha256
    }
    scenario_spec_pin = [pscustomobject][ordered]@{
      path = [string]$Scenario.spec_path
      sha256 = [string]$Scenario.spec_sha256
    }
    run_root = [string]$Run.root
    manifest_path = [string]$Run.manifest_path
    declared_inventory_sha256 = [string]$Run.output.inventory_sha256
    snapshot = $Run.physical_inventory
  }
}

function Get-Issue13OracleEffectInputContext {
  param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][string]$ExpectedCandidateCommit,
    [Parameter(Mandatory = $true)][string]$SpecPath,
    [Parameter(Mandatory = $true)][string]$SchemaPath,
    [Parameter(Mandatory = $true)][string]$StrictSmokeSummary,
    [Parameter(Mandatory = $true)][string]$OracleSmokeSummary,
    [Parameter(Mandatory = $true)][string]$OraclePatch,
    [Parameter(Mandatory = $true)][string]$ComparisonHarnessManifest,
    [Parameter(Mandatory = $true)][string]$Rscript,
    [Parameter(Mandatory = $true)][string]$RLibrary
  )
  $specResolved = Resolve-Issue13OracleEffectFile $SpecPath 'oracle-effect spec'
  $schemaResolved = Resolve-Issue13OracleEffectFile $SchemaPath `
    'oracle-effect proof schema'
  $spec = Read-Issue13OracleEffectJson $specResolved 'oracle-effect spec'
  Assert-Issue13OracleEffect ((Get-Issue13OracleEffectSha256 $specResolved) -ceq `
      '12c99503f4abda5b2ebd1c2a3dced1612f5588f36b29ac050fe5c9e9d4a38fe1') `
    'oracle-effect spec bytes differ from the closed terminal manifest.'
  Assert-Issue13OracleEffect ((Get-Issue13OracleEffectSha256 $schemaResolved) -ceq `
      [string]$spec.proof_schema_sha256) `
    'proof schema bytes differ from the spec pin.'
  $oracleIdentity = Test-Issue13OracleEffectSpec $spec $RepositoryRoot $OraclePatch
  $strictPath = Resolve-Issue13OracleEffectFile $StrictSmokeSummary `
    'strict smoke summary'
  $oraclePath = Resolve-Issue13OracleEffectFile $OracleSmokeSummary `
    'oracle smoke summary'
  Assert-Issue13OracleEffect (
    [string]$spec.evidence_pins.strict_smoke.summary_sha256 -ceq
      '973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d' -and
    (Get-Issue13OracleEffectSha256 $strictPath) -ceq
      '973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d'
  ) `
    'strict smoke summary hash differs.'
  Assert-Issue13OracleEffect (
    [string]$spec.evidence_pins.oracle_smoke.summary_sha256 -ceq
      '4ba530a191ef45baaaa08b2aa03ec6dcd0268aa6514caec6520203a0213afdfe' -and
    (Get-Issue13OracleEffectSha256 $oraclePath) -ceq
      '4ba530a191ef45baaaa08b2aa03ec6dcd0268aa6514caec6520203a0213afdfe'
  ) `
    'oracle smoke summary hash differs.'
  $strict = Read-Issue13OracleEffectJson $strictPath 'strict smoke summary'
  $oracle = Read-Issue13OracleEffectJson $oraclePath 'oracle smoke summary'
  Assert-Issue13OracleEffectExactProperties $strict @(
    'schema', 'status', 'passed', 'final_evidence_eligible', 'purpose',
    'baseline_commit', 'started_at_utc', 'finished_at_utc',
    'source_inventory_sha256', 'harness_manifest_path',
    'harness_manifest_sha256', 'method_count', 'passed_count', 'failed_count',
    'records', 'disposition'
  ) 'sealed historical strict smoke summary'
  Assert-Issue13OracleEffectExactProperties $oracle @(
    'schema', 'status', 'passed', 'final_evidence_eligible', 'purpose',
    'baseline_commit', 'baseline_base_commit', 'baseline_runtime_commit',
    'started_at_utc', 'finished_at_utc', 'source_inventory_sha256',
    'harness_manifest_path', 'harness_manifest_sha256',
    'environment_removed', 'method_count', 'passed_count', 'failed_count',
    'records', 'disposition'
  ) 'sealed historical oracle smoke summary'
  Assert-Issue13OracleEffect (@($strict.PSObject.Properties.Name | Where-Object {
        $_ -cmatch '^rscript_'
      }).Count -eq 0 -and
      @($oracle.PSObject.Properties.Name | Where-Object {
        $_ -cmatch '^rscript_'
      }).Count -eq 0) `
    'historical smoke summaries unexpectedly contain Rscript fields.'
  Assert-Issue13OracleEffectExactSet @($oracle.environment_removed) @(
    'LANG', 'LC_ALL', 'LC_CTYPE'
  ) 'sealed historical oracle smoke environment_removed'
  Assert-Issue13OracleEffect ($strict.schema -ceq `
      $spec.evidence_pins.strict_smoke.schema -and `
      $strict.purpose -ceq $spec.evidence_pins.strict_smoke.purpose -and `
      $strict.status -ceq 'failed' -and `
      (Test-Issue13OracleEffectExactBoolean $strict.passed $false) -and `
      (Test-Issue13OracleEffectExactBoolean `
        $strict.final_evidence_eligible $false) -and `
      $strict.baseline_commit -ceq $spec.oracle.base_commit -and `
      $strict.source_inventory_sha256 -ceq `
        $spec.evidence_pins.source_inventory_sha256 -and `
      $strict.harness_manifest_sha256 -ceq `
        $spec.evidence_pins.strict_smoke.harness_manifest_sha256 -and `
      [int]$strict.method_count -eq 12 -and `
      [int]$spec.evidence_pins.strict_smoke.passed_count -eq 5 -and `
      [int]$spec.evidence_pins.strict_smoke.failed_count -eq 7 -and `
      [int]$strict.passed_count -eq `
        [int]$spec.evidence_pins.strict_smoke.passed_count -and `
      [int]$strict.failed_count -eq `
        [int]$spec.evidence_pins.strict_smoke.failed_count) `
    'strict smoke summary envelope differs.'
  Assert-Issue13OracleEffect ($oracle.schema -ceq `
      $spec.evidence_pins.oracle_smoke.schema -and `
      $oracle.purpose -ceq $spec.evidence_pins.oracle_smoke.purpose -and `
      $oracle.status -ceq 'passed' -and `
      (Test-Issue13OracleEffectExactBoolean $oracle.passed $true) -and `
      (Test-Issue13OracleEffectExactBoolean `
        $oracle.final_evidence_eligible $false) -and `
      $oracle.baseline_commit -ceq $spec.oracle.base_commit -and `
      $oracle.baseline_base_commit -ceq $spec.oracle.base_commit -and `
      $oracle.baseline_runtime_commit -ceq $spec.oracle.runtime_commit -and `
      $oracle.source_inventory_sha256 -ceq `
        $spec.evidence_pins.source_inventory_sha256 -and `
      $oracle.harness_manifest_sha256 -ceq `
        $spec.evidence_pins.oracle_smoke.harness_manifest_sha256 -and `
      [int]$oracle.method_count -eq 12 -and `
      [int]$spec.evidence_pins.oracle_smoke.passed_count -eq 12 -and `
      [int]$spec.evidence_pins.oracle_smoke.failed_count -eq 0 -and `
      [int]$oracle.passed_count -eq `
        [int]$spec.evidence_pins.oracle_smoke.passed_count -and `
      [int]$oracle.failed_count -eq `
        [int]$spec.evidence_pins.oracle_smoke.failed_count) `
    'oracle smoke summary envelope differs.'
  $strictMap = Get-Issue13OracleEffectSummaryRecords $strict `
    'strict smoke summary'
  $oracleMap = Get-Issue13OracleEffectSummaryRecords $oracle `
    'oracle smoke summary'
  $allMethods = @($spec.method_partition.strict_common) + `
    @($spec.method_partition.recovered)
  Assert-Issue13OracleEffectExactSet @($strictMap.Keys) $allMethods `
    'strict summary methods'
  Assert-Issue13OracleEffectExactSet @($oracleMap.Keys) $allMethods `
    'oracle summary methods'
  Assert-Issue13OracleEffectExactSet `
    @($strictMap.Keys | Where-Object { $strictMap[$_].status -ceq 'passed' }) `
    @($spec.method_partition.strict_common) 'strict passed methods'
  Assert-Issue13OracleEffectExactSet `
    @($strictMap.Keys | Where-Object { $strictMap[$_].status -ceq 'failed' }) `
    @($spec.method_partition.recovered) 'strict failed methods'
  Assert-Issue13OracleEffect (@($oracleMap.Keys | Where-Object {
      $oracleMap[$_].status -cne 'passed'
    }).Count -eq 0) 'oracle summary contains a non-passed method.'
  $harness = Test-Issue13OracleEffectHarnessManifest `
    $ComparisonHarnessManifest $spec $ExpectedCandidateCommit `
    $oracleIdentity.repository_root
  $rscriptIdentity = Get-Issue13OracleEffectRscriptIdentity $Rscript `
    $spec.terminal_comparison_runtime.rscript
  $rRuntime = Get-Issue13OracleEffectRRuntime `
    $rscriptIdentity.logical_path $RLibrary $oracleIdentity.repository_root
  $strictRoot = Split-Path -Parent $strictPath
  $oracleRoot = Split-Path -Parent $oraclePath
  $strictScenarios = @{}
  $oracleScenarios = @{}
  $strictRuns = @{}
  $oracleRuns = @{}
  $approved = New-Object Collections.Generic.List[object]
  foreach ($pin in @($spec.common_methods)) {
    $method = [string]$pin.method
    $strictScenario = Get-Issue13OracleEffectScenario $strictMap[$method] `
      $strictRoot $pin.strict_scenario_sha256 $method $true `
      $spec.oracle.base_commit "$method strict"
    $oracleScenario = Get-Issue13OracleEffectScenario $oracleMap[$method] `
      $oracleRoot $pin.oracle_scenario_sha256 $method $true `
      $spec.oracle.runtime_commit "$method oracle"
    $strictRun = Get-Issue13OracleEffectRunOutput $strictScenario `
      ([pscustomobject]@{
        manifest_sha256 = $pin.strict_manifest_sha256
        inventory_sha256 = $pin.strict_inventory_sha256
      }) $method $spec.oracle.base_commit "$method strict"
    $oracleRun = Get-Issue13OracleEffectRunOutput $oracleScenario `
      ([pscustomobject]@{
        manifest_sha256 = $pin.oracle_manifest_sha256
        inventory_sha256 = $pin.oracle_inventory_sha256
      }) $method $spec.oracle.runtime_commit "$method oracle"
    $strictScenarios[$method] = $strictScenario
    $oracleScenarios[$method] = $oracleScenario
    $strictRuns[$method] = $strictRun
    $oracleRuns[$method] = $oracleRun
    $approved.Add((New-Issue13OracleEffectApprovedRunState strict $method `
      $spec.oracle.base_commit $strictScenario $strictRun))
  }
  foreach ($pin in @($spec.recovered_methods)) {
    $method = [string]$pin.method
    $strictScenario = Get-Issue13OracleEffectScenario $strictMap[$method] `
      $strictRoot $pin.strict_scenario_sha256 $method $false `
      $spec.oracle.base_commit "$method strict"
    $oracleScenario = Get-Issue13OracleEffectScenario $oracleMap[$method] `
      $oracleRoot $pin.oracle_scenario_sha256 $method $true `
      $spec.oracle.runtime_commit "$method oracle"
    $oracleRun = Get-Issue13OracleEffectRunOutput $oracleScenario `
      ([pscustomobject]@{
        manifest_sha256 = $pin.oracle_manifest_sha256
        inventory_sha256 = $pin.oracle_inventory_sha256
      }) $method $spec.oracle.runtime_commit "$method oracle"
    $strictScenarios[$method] = $strictScenario
    $oracleScenarios[$method] = $oracleScenario
    $oracleRuns[$method] = $oracleRun
  }
  foreach ($method in $allMethods) {
    $approved.Add((New-Issue13OracleEffectApprovedRunState oracle $method `
      $spec.oracle.runtime_commit $oracleScenarios[$method] `
      $oracleRuns[$method]))
  }
  Assert-Issue13OracleEffect ($approved.Count -eq 17) `
    'approved physical run inventory count differs from 17.'
  [pscustomobject]@{
    spec_resolved = $specResolved
    schema_resolved = $schemaResolved
    spec = $spec
    oracle_identity = $oracleIdentity
    strict_path = $strictPath
    oracle_path = $oraclePath
    strict = $strict
    oracle = $oracle
    strict_map = $strictMap
    oracle_map = $oracleMap
    strict_scenarios = $strictScenarios
    oracle_scenarios = $oracleScenarios
    strict_runs = $strictRuns
    oracle_runs = $oracleRuns
    approved_runs = @($approved.ToArray())
    harness = $harness
    rscript = $rscriptIdentity
    r_library = $rRuntime
  }
}

function Assert-Issue13OracleEffectComparisonIsolation {
  param(
    [Parameter(Mandatory = $true)][string]$ComparisonRoot,
    [Parameter(Mandatory = $true)][string]$ReplayRoot,
    [Parameter(Mandatory = $true)][object]$Context,
    [switch]$RequireExisting
  )
  $primary = [IO.Path]::GetFullPath($ComparisonRoot).TrimEnd('\', '/')
  $replay = [IO.Path]::GetFullPath($ReplayRoot).TrimEnd('\', '/')
  Assert-Issue13OracleEffectPathsDisjoint $primary $replay `
    'primary/replay comparison isolation'
  $protected = @(
    [pscustomobject]@{
      label = 'repository root'; path = [string]$Context.oracle_identity.repository_root
    }
    [pscustomobject]@{
      label = 'harness runtime root'; path = [string]$Context.harness.installed_inventory.root
    }
    [pscustomobject]@{
      label = 'R library root'; path = [string]$Context.r_library.path
    }
    [pscustomobject]@{
      label = 'strict smoke root'; path = Split-Path -Parent ([string]$Context.strict_path)
    }
    [pscustomobject]@{
      label = 'oracle smoke root'; path = Split-Path -Parent ([string]$Context.oracle_path)
    }
  )
  foreach ($root in @(
      [pscustomobject]@{ label = 'primary comparison root'; path = $primary },
      [pscustomobject]@{ label = 'replay comparison root'; path = $replay }
    )) {
    Assert-Issue13OracleEffectNoReparseAncestors $root.path $root.label
    if ($RequireExisting) {
      $resolved = Resolve-Issue13OracleEffectDirectory $root.path $root.label
      Assert-Issue13OracleEffectNoReparseTree $resolved $root.label
    } else {
      Assert-Issue13OracleEffect (-not (Test-Path -LiteralPath $root.path)) `
        "$($root.label) existed before generator creation."
    }
    foreach ($protectedRoot in $protected) {
      Assert-Issue13OracleEffectPathsDisjoint $root.path $protectedRoot.path `
        "$($root.label)/$($protectedRoot.label) isolation"
    }
  }
  $true
}

function Get-Issue13OracleEffectComparisonCommands {
  param(
    [Parameter(Mandatory = $true)][object]$Context,
    [Parameter(Mandatory = $true)][string]$ComparisonRoot,
    [Parameter(Mandatory = $true)][string]$ReplayRoot
  )
  $scriptPath = Resolve-Issue13OracleEffectFile (
    Join-Path $Context.harness.installed_inventory.harness_root `
      $Context.spec.terminal_comparison_runtime.comparison_script
  ) 'terminal comparison script'
  $commands = New-Object Collections.Generic.List[object]
  foreach ($phase in @('primary', 'replay')) {
    $root = if ($phase -ceq 'primary') { $ComparisonRoot } else { $ReplayRoot }
    foreach ($method in @($Context.spec.method_partition.strict_common)) {
      $output = [IO.Path]::GetFullPath((Join-Path $root $method))
      $arguments = [string[]]@(
        '--vanilla',
        $scriptPath,
        "--candidate_result=$($Context.oracle_scenarios[$method].path)",
        "--candidate_selector=run:$method",
        "--baseline_result=$($Context.strict_scenarios[$method].path)",
        "--baseline_selector=run:$method",
        "--output=$output",
        "--scenario_id=oracle-effect/common/$method",
        '--comparison_mode=strict'
      )
      $payloadParts = New-Object Collections.Generic.List[string]
      $payloadParts.Add([string]$Context.rscript.logical_path)
      foreach ($argument in $arguments) {
        $payloadParts.Add([string]$argument)
      }
      $payloadParts.Add(
        'CWD=' + [string]$Context.harness.installed_inventory.harness_root
      )
      foreach ($record in @($Context.r_library.environment.set)) {
        $payloadParts.Add(
          'SET=' + [string]$record.name + '=' + [string]$record.value)
      }
      foreach ($name in @($Context.r_library.environment.cleared)) {
        $payloadParts.Add('CLEAR=' + [string]$name)
      }
      $commandPayload = $payloadParts.ToArray() -join [char]0
      $commands.Add([pscustomobject][ordered]@{
        phase = $phase
        method = $method
        executable = [string]$Context.rscript.logical_path
        arguments = $arguments
        working_directory = `
          [string]$Context.harness.installed_inventory.harness_root
        r_library_environment = [pscustomobject][ordered]@{
          name = 'R_LIBS_USER'
          value = [string]$Context.r_library.path
        }
        environment_set = @($Context.r_library.environment.set)
        environment_cleared = `
          [string[]]@($Context.r_library.environment.cleared)
        output_directory = $output
        command_sha256 = Get-Issue13OracleEffectUtf8Sha256 $commandPayload
        exit_code = 0
      })
    }
  }
  Assert-Issue13OracleEffect ($commands.Count -eq 10) `
    'terminal comparison command count differs from ten.'
  @($commands.ToArray())
}

function Invoke-Issue13OracleEffectFreshComparisons {
  param(
    [Parameter(Mandatory = $true)][object]$Context,
    [Parameter(Mandatory = $true)][string]$ComparisonRoot,
    [Parameter(Mandatory = $true)][string]$ReplayRoot
  )
  $primary = Resolve-Issue13OracleEffectNewDirectoryPath $ComparisonRoot `
    'primary comparison root'
  $replay = Resolve-Issue13OracleEffectNewDirectoryPath $ReplayRoot `
    'replay comparison root'
  $null = Assert-Issue13OracleEffectComparisonIsolation $primary $replay $Context
  $commands = Get-Issue13OracleEffectComparisonCommands $Context $primary $replay
  $comparisonEnvironment = New-Issue13V5ClosedREnvironment `
    ([string]$Context.r_library.path)
  $comparisonAction = {
    foreach ($phase in @('primary', 'replay')) {
      $phaseRoot = if ($phase -ceq 'primary') { $primary } else { $replay }
      Assert-Issue13OracleEffect (-not (Test-Path -LiteralPath $phaseRoot)) `
        "$phase comparison root appeared before generator creation."
      $null = New-Item -ItemType Directory -LiteralPath $phaseRoot
      Assert-Issue13OracleEffectNoReparseTree $phaseRoot `
        "$phase comparison root after creation"
      if ($phase -ceq 'replay') {
        $null = Assert-Issue13OracleEffectComparisonIsolation $primary $replay `
          $Context -RequireExisting
      }
      foreach ($command in @($commands | Where-Object { $_.phase -ceq $phase })) {
        Assert-Issue13OracleEffect (-not (Test-Path -LiteralPath `
            $command.output_directory)) `
          "$phase/$($command.method) output appeared before its command."
        $invokeArguments = [string[]]@($command.arguments)
        $invocation = [pscustomobject]@{
          native_output = [object[]]@()
          exit_code = $null
        }
        Assert-Issue13OracleEffect ([string]::Equals(
            [string]$command.executable,
            [string]$Context.rscript.logical_path,
            [StringComparison]::OrdinalIgnoreCase)) `
          'terminal comparison command escaped the sealed Rscript authority.'
        $comparisonResult = Invoke-Issue13V5RscriptBounded `
          -RscriptPath ([string]$command.executable) `
          -Arguments $invokeArguments `
          -Label "$phase comparison for $($command.method)" `
          -TimeoutSeconds 14400 `
          -ExpectedExitCodes $null `
          -WorkingDirectory ([string]$command.working_directory) `
          -Environment $comparisonEnvironment
        $invocation.native_output = `
          [object[]]$comparisonResult.combined_lines
        $invocation.exit_code = [int]$comparisonResult.exit_code
        Assert-Issue13OracleEffect (
          $null -ne $invocation.exit_code -and
          [int]$invocation.exit_code -eq 0
        ) ("$phase comparison failed for $($command.method): " +
          [string]::Join(' ', @($invocation.native_output)))
        Assert-Issue13OracleEffect (Test-Path -LiteralPath `
            $command.output_directory -PathType Container) `
          "$phase comparison did not create $($command.method) output."
      }
      Assert-Issue13OracleEffectNoReparseTree $phaseRoot `
        "$phase comparison root after execution"
    }
  }
  $null = Invoke-Issue13V5WithCleanup -Action $comparisonAction `
    -Label 'Oracle-effect terminal comparisons'
  $null = Assert-Issue13OracleEffectComparisonIsolation $primary $replay `
    $Context -RequireExisting
  $commands
}

function Test-Issue13OracleEffectComparisonRoot {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][object]$Spec,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $resolved = Resolve-Issue13OracleEffectDirectory $Root $Label
  Assert-Issue13OracleEffectNoReparseTree $resolved $Label
  Assert-Issue13OracleEffectExactSet @(
    Get-ChildItem -LiteralPath $resolved -Directory -Force | ForEach-Object Name
  ) @($Spec.method_partition.strict_common) "$Label method directories"
  Assert-Issue13OracleEffect (@(Get-ChildItem -LiteralPath $resolved `
      -File -Force).Count -eq 0) "$Label contains a root file."
  $resolved
}

function Get-Issue13OracleEffectNormalizedComparisonJson {
  param(
    [Parameter(Mandatory = $true)][object]$Document,
    [Parameter(Mandatory = $true)][string]$Label
  )
  Assert-Issue13OracleEffect (@($Document.PSObject.Properties | Where-Object {
      $_.Name -ceq 'compared_at'
    }).Count -eq 1) "$Label lacks exactly one top-level compared_at."
  $copy = ($Document | ConvertTo-Json -Depth 100 -Compress) |
    ConvertFrom-Json -DateKind String
  $comparedAt = [string]$copy.compared_at
  $parsed = [DateTimeOffset]::MinValue
  Assert-Issue13OracleEffect ([DateTimeOffset]::TryParse(
      $comparedAt,
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::AllowWhiteSpaces,
      [ref]$parsed
    )) "$Label compared_at is not a timestamp."
  $copy.PSObject.Properties.Remove('compared_at')
  $json = $copy | ConvertTo-Json -Depth 100 -Compress
  [pscustomobject]@{
    compared_at = $comparedAt
    json = $json
    sha256 = Get-Issue13OracleEffectUtf8Sha256 $json
  }
}

function Test-Issue13OracleEffectSingleComparison {
  param(
    [Parameter(Mandatory = $true)][string]$ComparisonRoot,
    [Parameter(Mandatory = $true)][ValidateSet('primary', 'replay')]
      [string]$Phase,
    [Parameter(Mandatory = $true)][object]$Spec,
    [Parameter(Mandatory = $true)][object]$MethodPin,
    [Parameter(Mandatory = $true)][object]$StrictRun,
    [Parameter(Mandatory = $true)][object]$OracleRun
  )
  $method = [string]$MethodPin.method
  $directory = Resolve-Issue13OracleEffectDirectory `
    (Join-Path $ComparisonRoot $method) "$Phase/$method comparison directory"
  $required = @($Spec.comparison_contract.required_files)
  Assert-Issue13OracleEffectExactSet @(
    Get-ChildItem -LiteralPath $directory -File -Force | ForEach-Object Name
  ) $required "$Phase/$method comparison files"
  Assert-Issue13OracleEffect (@(Get-ChildItem -LiteralPath $directory `
      -Directory -Force).Count -eq 0) `
    "$Phase/$method comparison directory contains a nested directory."
  $comparisonPath = Join-Path $directory 'comparison.json'
  $document = Read-Issue13OracleEffectJson $comparisonPath `
    "$Phase/$method comparison"
  Assert-Issue13OracleEffect ($document.schema -ceq `
      $Spec.comparison_contract.schema -and `
      $document.scenario_id -ceq "oracle-effect/common/$method" -and `
      $document.status -ceq 'passed' -and `
      (Test-Issue13OracleEffectExactBoolean $document.passed $true) -and `
      $document.comparison_mode -ceq 'strict') `
    "$Phase/$method comparison identity or status differs."
  Assert-Issue13OracleEffect ((Test-Issue13OracleEffectExactBoolean `
        $document.identity.passed $true) -and `
      $document.identity.candidate_method -ceq $method -and `
      $document.identity.baseline_method -ceq $method -and `
      $document.identity.candidate_output_contract.id -ceq 'wlvpanel-output' -and `
      $document.identity.candidate_output_contract.version -ceq '1.0.0' -and `
      $document.identity.baseline_output_contract.id -ceq 'wlvpanel-output' -and `
      $document.identity.baseline_output_contract.version -ceq '1.0.0') `
    "$Phase/$method comparison output identity differs."
  Assert-Issue13OracleEffect ($document.candidate.kind -ceq 'run' -and `
      $document.candidate.manifest_sha256 -ceq `
        $MethodPin.oracle_manifest_sha256 -and `
      $document.candidate.inventory_sha256 -ceq `
        $MethodPin.oracle_inventory_sha256 -and `
      $document.baseline.kind -ceq 'run' -and `
      $document.baseline.manifest_sha256 -ceq `
        $MethodPin.strict_manifest_sha256 -and `
      $document.baseline.inventory_sha256 -ceq `
        $MethodPin.strict_inventory_sha256) `
    "$Phase/$method comparison arm hashes differ."
  Assert-Issue13OracleEffect (Test-Issue13OracleEffectPathEqual `
      ([string]$document.candidate.root) $OracleRun.root) `
    "$Phase/$method candidate root differs from its summary scenario."
  Assert-Issue13OracleEffect (Test-Issue13OracleEffectPathEqual `
      ([string]$document.baseline.root) $StrictRun.root) `
    "$Phase/$method baseline root differs from its summary scenario."
  foreach ($field in @(
    'missing_candidate_artifacts', 'extra_candidate_artifacts',
    'allowed_candidate_only_artifacts', 'architecture_differences',
    'policy_exceptions'
  )) {
    Assert-Issue13OracleEffect (@($document.$field).Count -eq 0) `
      "$Phase/$method comparison has non-empty $field."
  }
  $artifacts = @($document.artifacts)
  Assert-Issue13OracleEffect ($artifacts.Count -gt 0 -and `
      [int]$document.artifact_count -eq $artifacts.Count -and `
      (@($artifacts | Where-Object {
        -not (Test-Issue13OracleEffectExactBoolean $_.passed $true)
      }).Count -eq 0)) `
    "$Phase/$method has a failed or inconsistent artifact summary."
  $transitions = @($document.transitions)
  foreach ($transition in $transitions) {
    Assert-Issue13OracleEffect ($transition.candidate_state -ceq `
        $transition.baseline_state -and [double]$transition.count -gt 0 -and `
        -not [string]::IsNullOrWhiteSpace([string]$transition.artifact)) `
      "$Phase/$method reports a non-diagonal state transition."
  }
  Assert-Issue13OracleEffect (@($document.indicator_differences).Count -eq 0) `
    "$Phase/$method reports an indicator difference."
  $artifactRows = @(Import-Csv -LiteralPath `
    (Join-Path $directory 'artifact-summary.csv'))
  Assert-Issue13OracleEffect ($artifactRows.Count -eq $artifacts.Count) `
    "$Phase/$method artifact-summary row count differs."
  foreach ($row in $artifactRows) {
    Assert-Issue13OracleEffect ($row.passed -ceq 'TRUE' -and `
        ($row.mismatch_count -ceq '' -or $row.mismatch_count -ceq '0')) `
      "$Phase/$method artifact-summary contains a mismatch."
  }
  $transitionRows = @(Import-Csv -LiteralPath `
    (Join-Path $directory 'state-transitions.csv'))
  Assert-Issue13OracleEffect ($transitionRows.Count -eq $transitions.Count) `
    "$Phase/$method state-transition row count differs."
  foreach ($transition in $transitionRows) {
    Assert-Issue13OracleEffect ($transition.candidate_state -ceq `
        $transition.baseline_state -and [double]$transition.count -gt 0 -and `
        -not [string]::IsNullOrWhiteSpace([string]$transition.artifact)) `
      "$Phase/$method state-transitions.csv is malformed."
  }
  Assert-Issue13OracleEffect (@(Import-Csv -LiteralPath `
      (Join-Path $directory 'indicator-differences.csv')).Count -eq 0) `
    "$Phase/$method indicator-differences.csv is non-empty."
  $fileRecords = @(
    foreach ($name in $required) {
      $path = Join-Path $directory $name
      [pscustomobject][ordered]@{
        name = $name
        sha256 = Get-Issue13OracleEffectSha256 $path
        size_bytes = [int64](Get-Item -LiteralPath $path).Length
      }
    }
  )
  [pscustomobject]@{
    directory = $directory
    document = $document
    artifact_count = $artifacts.Count
    normalized = Get-Issue13OracleEffectNormalizedComparisonJson $document `
      "$Phase/$method comparison"
    files = $fileRecords
  }
}

function Test-Issue13OracleEffectComparisonPair {
  param(
    [Parameter(Mandatory = $true)][string]$ComparisonRoot,
    [Parameter(Mandatory = $true)][string]$ReplayRoot,
    [Parameter(Mandatory = $true)][object]$Spec,
    [Parameter(Mandatory = $true)][object]$MethodPin,
    [Parameter(Mandatory = $true)][object]$StrictRun,
    [Parameter(Mandatory = $true)][object]$OracleRun,
    [Parameter(Mandatory = $true)][object[]]$Commands
  )
  $method = [string]$MethodPin.method
  $primary = Test-Issue13OracleEffectSingleComparison $ComparisonRoot primary `
    $Spec $MethodPin $StrictRun $OracleRun
  $replay = Test-Issue13OracleEffectSingleComparison $ReplayRoot replay `
    $Spec $MethodPin $StrictRun $OracleRun
  Assert-Issue13OracleEffect ($primary.normalized.json -ceq `
      $replay.normalized.json -and $primary.normalized.sha256 -ceq `
      $replay.normalized.sha256) `
    "$method primary/replay comparison JSON differs beyond compared_at."
  $normalizedFiles = @(
    foreach ($name in @($Spec.comparison_contract.required_files)) {
      $left = @($primary.files | Where-Object { $_.name -ceq $name })[0]
      $right = @($replay.files | Where-Object { $_.name -ceq $name })[0]
      if ($name -ceq 'comparison.json') {
        $normalization = 'remove-top-level-compared_at'
        $normalizedSha = [string]$primary.normalized.sha256
      } else {
        Assert-Issue13OracleEffect ($left.sha256 -ceq $right.sha256 -and `
            [int64]$left.size_bytes -eq [int64]$right.size_bytes) `
          "$method primary/replay $name is not byte-identical."
        $normalization = 'identity'
        $normalizedSha = [string]$left.sha256
      }
      [pscustomobject][ordered]@{
        name = $name
        primary_sha256 = [string]$left.sha256
        primary_size_bytes = [int64]$left.size_bytes
        replay_sha256 = [string]$right.sha256
        replay_size_bytes = [int64]$right.size_bytes
        normalization = $normalization
        normalized_sha256 = $normalizedSha
        normalized_identical = $true
        raw_byte_identical = ($left.sha256 -ceq $right.sha256 -and `
          [int64]$left.size_bytes -eq [int64]$right.size_bytes)
      }
    }
  )
  $primaryCommand = @($Commands | Where-Object {
    $_.phase -ceq 'primary' -and $_.method -ceq $method
  })
  $replayCommand = @($Commands | Where-Object {
    $_.phase -ceq 'replay' -and $_.method -ceq $method
  })
  Assert-Issue13OracleEffect ($primaryCommand.Count -eq 1 -and `
      $replayCommand.Count -eq 1) "$method command binding is ambiguous."
  [pscustomobject][ordered]@{
    method = $method
    primary_directory = [string]$primary.directory
    replay_directory = [string]$replay.directory
    comparison_mode = 'strict'
    artifact_count = [int]$primary.artifact_count
    candidate_manifest_sha256 = `
      [string]$primary.document.candidate.manifest_sha256
    candidate_inventory_sha256 = `
      [string]$primary.document.candidate.inventory_sha256
    baseline_manifest_sha256 = `
      [string]$primary.document.baseline.manifest_sha256
    baseline_inventory_sha256 = `
      [string]$primary.document.baseline.inventory_sha256
    primary_compared_at = [string]$primary.normalized.compared_at
    replay_compared_at = [string]$replay.normalized.compared_at
    primary_command_sha256 = [string]$primaryCommand[0].command_sha256
    replay_command_sha256 = [string]$replayCommand[0].command_sha256
    files = $normalizedFiles
  }
}

function Get-Issue13OracleEffectEvidence {
  param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][string]$ExpectedCandidateCommit,
    [Parameter(Mandatory = $true)][string]$SpecPath,
    [Parameter(Mandatory = $true)][string]$SchemaPath,
    [Parameter(Mandatory = $true)][string]$StrictSmokeSummary,
    [Parameter(Mandatory = $true)][string]$OracleSmokeSummary,
    [Parameter(Mandatory = $true)][string]$OraclePatch,
    [Parameter(Mandatory = $true)][string]$ComparisonRoot,
    [Parameter(Mandatory = $true)][string]$ReplayRoot,
    [Parameter(Mandatory = $true)][string]$ComparisonHarnessManifest,
    [Parameter(Mandatory = $true)][string]$Rscript,
    [Parameter(Mandatory = $true)][string]$RLibrary,
    [object]$PreparedContext,
    [AllowNull()][object[]]$RunInventoriesBefore,
    [AllowNull()][object]$RuntimeBefore
  )
  $context = $PreparedContext
  if ($null -eq $context) {
    $context = Get-Issue13OracleEffectInputContext `
      -RepositoryRoot $RepositoryRoot `
      -ExpectedCandidateCommit $ExpectedCandidateCommit `
      -SpecPath $SpecPath `
      -SchemaPath $SchemaPath `
      -StrictSmokeSummary $StrictSmokeSummary `
      -OracleSmokeSummary $OracleSmokeSummary `
      -OraclePatch $OraclePatch `
      -ComparisonHarnessManifest $ComparisonHarnessManifest `
      -Rscript $Rscript `
      -RLibrary $RLibrary
  }
  $spec = $context.spec
  $null = Assert-Issue13OracleEffectComparisonIsolation $ComparisonRoot `
    $ReplayRoot $context -RequireExisting
  $comparisonRootResolved = Test-Issue13OracleEffectComparisonRoot `
    $ComparisonRoot $spec 'primary comparison root'
  $replayRootResolved = Test-Issue13OracleEffectComparisonRoot `
    $ReplayRoot $spec 'replay comparison root'
  Assert-Issue13OracleEffect (-not (Test-Issue13OracleEffectPathEqual `
      $comparisonRootResolved $replayRootResolved)) `
    'primary and replay comparison roots are identical.'
  $commands = Get-Issue13OracleEffectComparisonCommands $context `
    $comparisonRootResolved $replayRootResolved
  $commonEvidence = @(
    foreach ($pin in @($spec.common_methods)) {
      $method = [string]$pin.method
      Test-Issue13OracleEffectComparisonPair $comparisonRootResolved `
        $replayRootResolved $spec $pin $context.strict_runs[$method] `
        $context.oracle_runs[$method] $commands
    }
  )
  $beforeStates = if ($null -eq $RunInventoriesBefore -or `
      @($RunInventoriesBefore).Count -eq 0) {
    @($context.approved_runs)
  } else { @($RunInventoriesBefore) }
  Assert-Issue13OracleEffect ($beforeStates.Count -eq 17) `
    'before-comparison approved run inventory count differs from 17.'
  Assert-Issue13OracleEffectExactSet @($beforeStates | ForEach-Object key) `
    @($context.approved_runs | ForEach-Object key) `
    'before/after approved run inventory keys'
  $approvedEvidence = @(
    foreach ($after in @($context.approved_runs)) {
      $before = @($beforeStates | Where-Object { $_.key -ceq $after.key })
      Assert-Issue13OracleEffect ($before.Count -eq 1) `
        "approved run before-state is ambiguous: $($after.key)"
      $beforeComparable = [pscustomobject][ordered]@{
        arm = $before[0].arm
        method = $before[0].method
        expected_commit = $before[0].expected_commit
        scenario_pin = $before[0].scenario_pin
        scenario_spec_pin = $before[0].scenario_spec_pin
        run_root = $before[0].run_root
        manifest_path = $before[0].manifest_path
        declared_inventory_sha256 = $before[0].declared_inventory_sha256
        snapshot = $before[0].snapshot
      }
      $afterComparable = [pscustomobject][ordered]@{
        arm = $after.arm
        method = $after.method
        expected_commit = $after.expected_commit
        scenario_pin = $after.scenario_pin
        scenario_spec_pin = $after.scenario_spec_pin
        run_root = $after.run_root
        manifest_path = $after.manifest_path
        declared_inventory_sha256 = $after.declared_inventory_sha256
        snapshot = $after.snapshot
      }
      Assert-Issue13OracleEffect (
        ($beforeComparable | ConvertTo-Json -Depth 30 -Compress) -ceq `
          ($afterComparable | ConvertTo-Json -Depth 30 -Compress)
      ) "approved run or its scenario/spec pin changed: $($after.key)"
      [pscustomobject][ordered]@{
        arm = [string]$after.arm
        method = [string]$after.method
        expected_commit = [string]$after.expected_commit
        run_root = [string]$after.run_root
        manifest_path = [string]$after.manifest_path
        declared_inventory_sha256 = `
          [string]$after.declared_inventory_sha256
        before = [pscustomobject][ordered]@{
          scenario_pin = $before[0].scenario_pin
          scenario_spec_pin = $before[0].scenario_spec_pin
          run_inventory = $before[0].snapshot
        }
        after = [pscustomobject][ordered]@{
          scenario_pin = $after.scenario_pin
          scenario_spec_pin = $after.scenario_spec_pin
          run_inventory = $after.snapshot
        }
        immutable = $true
      }
    }
  )

  $recoveredEvidence = @(
    foreach ($pin in @($spec.recovered_methods)) {
      $method = [string]$pin.method
      $strictScenario = $context.strict_scenarios[$method]
      $expectedError = [string]$spec.strict_failure_messages.([string]$pin.strict_failure_id)
      Assert-Issue13OracleEffect ($strictScenario.document.error -ceq $expectedError) `
        "$method strict failure message differs."
      $oracleScenario = $context.oracle_scenarios[$method]
      $oracleRun = $context.oracle_runs[$method]
      Assert-Issue13OracleEffect ($oracleRun.output.result_id -ceq $pin.oracle_result_id) `
        "$method oracle result_id differs."
      $leontief = Test-Issue13OracleEffectLeontief $oracleRun $spec $method
      $nan = if ($method -in @('alternative_2', 'petrovic')) {
        Test-Issue13OracleEffectNanClean $oracleRun $spec $method
      } else { $null }
      $utf8 = if ($method -ceq 'norow_w13') {
        Test-Issue13OracleEffectUtf8 $oracleRun $spec
      } else { $null }
      $goPrice = if ($method -in @(
        'alternative_1', 'alternative_2', 'norow_w13', 'ochoa_1',
        'ochoa_2', 'petrovic'
      )) {
        [pscustomobject][ordered]@{
          coordinate_count = 525
          coordinate_sha256 = [string]$spec.coordinate_contracts.go_price_row_from_usa.coordinate_sha256
          checkpoint = 'after_assumptions'
          strict_failure_observed = $true
          oracle_checkpoint_passed = $true
          value_rule = 'ROW is finite and bitwise equal to USA at the same year/indicator/sector'
        }
      } else { $null }
      [pscustomobject][ordered]@{
        method = $method
        strict_scenario_path = $strictScenario.path
        strict_scenario_sha256 = $strictScenario.sha256
        strict_failure_id = [string]$pin.strict_failure_id
        strict_failure_message = $expectedError
        oracle_scenario_path = $oracleScenario.path
        oracle_scenario_sha256 = $oracleScenario.sha256
        oracle_manifest_sha256 = [string]$oracleRun.output.manifest_sha256
        oracle_inventory_sha256 = [string]$oracleRun.output.inventory_sha256
        oracle_result_id = [string]$oracleRun.output.result_id
        change_ids = @($pin.change_ids)
        go_price = $goPrice
        historical_nan_clean = $nan
        leontief = $leontief
        utf8 = $utf8
      }
    }
  )
  $currentSourceTooling = Get-Issue13OracleEffectExpectedSourceTooling $spec `
    $ExpectedCandidateCommit $RepositoryRoot
  $null = Assert-Issue13OracleEffectSourceTooling `
    $context.harness.source_tooling $currentSourceTooling `
    'terminal proof source_tooling'
  $currentRscript = Get-Issue13OracleEffectRscriptIdentity $Rscript `
    $spec.terminal_comparison_runtime.rscript
  $null = Assert-Issue13OracleEffectRscriptIdentity $context.rscript `
    $currentRscript 'terminal proof Rscript identity'
  $currentRLibrary = Get-Issue13OracleEffectRRuntime `
    $currentRscript.logical_path $RLibrary $RepositoryRoot
  $contextRuntimeSnapshot = [pscustomobject][ordered]@{
    rscript = $context.rscript
    r_library = $context.r_library
  }
  $currentRuntimeSnapshot = [pscustomobject][ordered]@{
    rscript = $currentRscript
    r_library = $currentRLibrary
  }
  $beforeRuntimeSnapshot = if ($null -eq $RuntimeBefore) {
    $contextRuntimeSnapshot
  } else {
    [pscustomobject][ordered]@{
      rscript = $RuntimeBefore.rscript
      r_library = $RuntimeBefore.r_library
    }
  }
  Assert-Issue13OracleEffect (
    ($beforeRuntimeSnapshot | ConvertTo-Json -Depth 100 -Compress) -ceq
      ($currentRuntimeSnapshot | ConvertTo-Json -Depth 100 -Compress)
  ) 'Rscript/R library runtime inventory changed between before and after probes.'
  [pscustomobject][ordered]@{
    spec = [pscustomobject][ordered]@{
      path = $context.spec_resolved
      sha256 = Get-Issue13OracleEffectSha256 $context.spec_resolved
      schema = [string]$spec.schema
    }
    proof_schema = [pscustomobject][ordered]@{
      path = $context.schema_resolved
      sha256 = Get-Issue13OracleEffectSha256 $context.schema_resolved
    }
    oracle = $context.oracle_identity
    terminal_runtime = [pscustomobject][ordered]@{
      comparison_harness = $context.harness
      rscript = $currentRscript
      r_library = $currentRLibrary
      runtime_immutability = [pscustomobject][ordered]@{
        before = $beforeRuntimeSnapshot
        after = $currentRuntimeSnapshot
        immutable = $true
      }
    }
    source_evidence = [pscustomobject][ordered]@{
      strict_smoke_summary_path = $context.strict_path
      strict_smoke_summary_sha256 = `
        Get-Issue13OracleEffectSha256 $context.strict_path
      oracle_smoke_summary_path = $context.oracle_path
      oracle_smoke_summary_sha256 = `
        Get-Issue13OracleEffectSha256 $context.oracle_path
    }
    approved_run_immutability = $approvedEvidence
    comparison_workflow = [pscustomobject][ordered]@{
      primary_root = $comparisonRootResolved
      replay_root = $replayRootResolved
      generator_created_both_roots = $true
      methods = @($spec.method_partition.strict_common)
      commands = $commands
      comparisons = $commonEvidence
    }
    recovered_methods = $recoveredEvidence
  }
}

function New-Issue13OracleEffectProofObject {
  param([Parameter(Mandatory = $true)][object]$Evidence)
  [pscustomobject][ordered]@{
    schema = 'wlv-issue13-v5-oracle-effect-proof/2'
    status = 'passed'
    passed = $true
    final_evidence_eligible = $false
    purpose = 'closed-authorized-oracle-effect-cc2-to-e2f'
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
    evidence = $Evidence
    conclusion = [pscustomobject][ordered]@{
      authorized_patch_authenticated = $true
      terminal_harness_authenticated = $true
      strict_common_method_count = 5
      strict_common_primary_and_replay_passed = $true
      approved_run_count = 17
      approved_runs_immutable = $true
      recovered_method_count = 7
      recovered_methods_passed = $true
      recovered_coordinate_and_diagnostic_contracts_passed = $true
      oracle_effect_closed = $true
      final_v5_gate_substituted = $false
    }
  }
}

function Write-Issue13OracleEffectJsonOnce {
  param(
    [Parameter(Mandatory = $true)][object]$Value,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$SchemaPath,
    [Parameter(Mandatory = $true)][string[]]$ProtectedRoots
  )
  $full = Assert-Issue13OracleEffectProofPathIsolation `
    $Path $ProtectedRoots
  $parent = Split-Path -Parent $full
  Assert-Issue13OracleEffect (Test-Path -LiteralPath $parent -PathType Container) `
    "proof output parent does not exist: $parent"
  Assert-Issue13OracleEffect (-not (Test-Path -LiteralPath $full)) `
    "refusing to overwrite proof output: $full"
  $json = $Value | ConvertTo-Json -Depth 100
  $encoding = New-Object Text.UTF8Encoding($false, $true)
  $temporary = Join-Path $parent ('.' + [IO.Path]::GetFileName($full) + `
    '.' + [Guid]::NewGuid().ToString('N') + '.tmp')
  try {
    [IO.File]::WriteAllText($temporary, $json + "`n", $encoding)
    $null = Read-Issue13OracleEffectJson $temporary 'staged oracle-effect proof'
    $null = Test-Issue13OracleEffectJsonSchemaFile $temporary $SchemaPath `
      'staged oracle-effect proof'
    $null = Assert-Issue13OracleEffectProofPathIsolation `
      $full $ProtectedRoots
    Assert-Issue13OracleEffect (-not (Test-Path -LiteralPath $full)) `
      "proof output appeared during staging: $full"
    [IO.File]::Move($temporary, $full)
  } finally {
    if (Test-Path -LiteralPath $temporary -PathType Leaf) {
      [IO.File]::Delete($temporary)
    }
  }
  Resolve-Issue13OracleEffectFile $full 'oracle-effect proof output'
}

function Test-Issue13OracleEffectProofObject {
  param(
    [Parameter(Mandatory = $true)][object]$Proof,
    [Parameter(Mandatory = $true)][object]$ExpectedEvidence
  )
  Assert-Issue13OracleEffectExactProperties $Proof @(
    'schema', 'status', 'passed', 'final_evidence_eligible', 'purpose',
    'generated_at_utc', 'evidence', 'conclusion'
  ) 'proof top-level properties'
  Assert-Issue13OracleEffect ($Proof.schema -ceq 'wlv-issue13-v5-oracle-effect-proof/2' -and `
      $Proof.status -ceq 'passed' -and `
      (Test-Issue13OracleEffectExactBoolean $Proof.passed $true) -and `
      (Test-Issue13OracleEffectExactBoolean `
        $Proof.final_evidence_eligible $false) -and `
      $Proof.purpose -ceq 'closed-authorized-oracle-effect-cc2-to-e2f') `
    'proof envelope differs.'
  $timestamp = [DateTime]::MinValue
  Assert-Issue13OracleEffect ([DateTime]::TryParse(
      [string]$Proof.generated_at_utc,
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::RoundtripKind,
      [ref]$timestamp
    ) -and $timestamp.Kind -eq [DateTimeKind]::Utc) 'proof timestamp is not UTC ISO-8601.'
  $observedEvidenceJson = $Proof.evidence | ConvertTo-Json -Depth 100 -Compress
  $expectedEvidenceJson = $ExpectedEvidence | ConvertTo-Json -Depth 100 -Compress
  Assert-Issue13OracleEffect ($observedEvidenceJson -ceq $expectedEvidenceJson) `
    'proof evidence differs from independently revalidated inputs.'
  $conclusion = $Proof.conclusion
  Assert-Issue13OracleEffectExactProperties $conclusion @(
    'authorized_patch_authenticated', 'terminal_harness_authenticated',
    'strict_common_method_count', 'strict_common_primary_and_replay_passed',
    'approved_run_count', 'approved_runs_immutable', 'recovered_method_count',
    'recovered_methods_passed',
    'recovered_coordinate_and_diagnostic_contracts_passed',
    'oracle_effect_closed', 'final_v5_gate_substituted'
  ) 'proof conclusion properties'
  Assert-Issue13OracleEffect ((Test-Issue13OracleEffectExactBoolean `
        $conclusion.authorized_patch_authenticated $true) -and `
      (Test-Issue13OracleEffectExactBoolean `
        $conclusion.terminal_harness_authenticated $true) -and `
      [int]$conclusion.strict_common_method_count -eq 5 -and `
      (Test-Issue13OracleEffectExactBoolean `
        $conclusion.strict_common_primary_and_replay_passed $true) -and `
      [int]$conclusion.approved_run_count -eq 17 -and `
      (Test-Issue13OracleEffectExactBoolean `
        $conclusion.approved_runs_immutable $true) -and `
      [int]$conclusion.recovered_method_count -eq 7 -and `
      (Test-Issue13OracleEffectExactBoolean `
        $conclusion.recovered_methods_passed $true) -and `
      (Test-Issue13OracleEffectExactBoolean `
        $conclusion.recovered_coordinate_and_diagnostic_contracts_passed `
        $true) -and `
      (Test-Issue13OracleEffectExactBoolean `
        $conclusion.oracle_effect_closed $true) -and `
      (Test-Issue13OracleEffectExactBoolean `
        $conclusion.final_v5_gate_substituted $false)) `
    'proof conclusion differs.'
  $true
}
