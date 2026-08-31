param(
  [Parameter(Mandatory = $true)][string]$Destination,
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')]
  [string]$CandidateCommit,
  [string]$SourceRuntimeRoot = '',
  [switch]$ConfirmMaterialize
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

if (-not $IsWindows) {
  throw 'The sealed V5 real-evidence materializer is Windows-only.'
}

if (-not $ConfirmMaterialize) {
  throw 'V5 harness materialization requires -ConfirmMaterialize.'
}

$baselineCommit = 'cc2c86189a06676bcb9f0e05e08033d710a92509'
$sourceToolingRelativeRoot = 'run_logs/issue13-evidence-source-v5'
$expectedSourcePathListSha256 =
  '7bf2e27807e9bc36d3d3766789439d0d9afdd7b2cc5127145ce0e0f6819db00d'
$sourceToolingFiles = @(
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
$expectedOutputFileCount = 47L
$expectedOutputTotalBytes = 2616118L
$expectedOutputInventory =
  'b74d70b6a3dd263756ddd2fe70f5e9ac16a4d2f3f88c9c3d842e3bd7b75eb1c2'
$controllerFiles = @(
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
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function ConvertTo-Issue13V5FullPath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) {
    throw 'A V5 path is empty.'
  }
  [IO.Path]::GetFullPath($Path)
}

if ($IsWindows) {
  $materializerNativePathAssembliesBefore =
    [Reflection.Assembly[]]@([AppDomain]::CurrentDomain.GetAssemblies())
  $preexistingMaterializerNativePathTypes = [type[]]@(
    [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
      $_.GetType('Issue13V5.NativePath', $false, $true)
    } | Where-Object { $null -ne $_ })
  if ($preexistingMaterializerNativePathTypes.Count -ne 0) {
    throw 'The materializer native path type was preloaded.'
  }
  $materializerNativePathTypes = [object[]]@(
    Add-Type -PassThru -ErrorAction Stop -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace Issue13V5 {
  public static class NativePath {
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
      string deviceName, StringBuilder targetPath, int maxLength);

    public static string DriveTarget(string drive) {
      int capacity = 512;
      while (true) {
        StringBuilder buffer = new StringBuilder(capacity);
        uint length = QueryDosDevice(drive, buffer, capacity);
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
  }
}
'@)
  $materializerNativePathType = 'Issue13V5.NativePath' -as [type]
  $materializerNativePathNonTypes = [object[]]@(
    $materializerNativePathTypes | Where-Object { $_ -isnot [type] })
  $materializerNativePathReturnedAssemblies = [Reflection.Assembly[]]@(
    $materializerNativePathTypes | ForEach-Object { $_.Assembly } |
      Select-Object -Unique)
  $materializerNativePathAssemblyWasPreexisting = [object[]]@(
    $materializerNativePathAssembliesBefore | Where-Object {
      [object]::ReferenceEquals(
        $_, $materializerNativePathReturnedAssemblies[0])
    })
  $loadedMaterializerNativePathTypes = [type[]]@(
    [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
      $_.GetType('Issue13V5.NativePath', $false, $true)
    } | Where-Object { $null -ne $_ })
  $materializerNativePathMethods = [string[]]@(
    $materializerNativePathTypes[0].GetMethods(
      [Reflection.BindingFlags]'Public, Static, DeclaredOnly') |
      ForEach-Object { $_.ToString() } | Sort-Object)
  if ($materializerNativePathTypes.Count -ne 1 -or
      $materializerNativePathTypes[0] -isnot [type] -or
      $materializerNativePathNonTypes.Count -ne 0 -or
      $materializerNativePathReturnedAssemblies.Count -ne 1 -or
      $materializerNativePathAssemblyWasPreexisting.Count -ne 0 -or
      [string]$materializerNativePathTypes[0].FullName -cne
        'Issue13V5.NativePath' -or
      $loadedMaterializerNativePathTypes.Count -ne 1 -or
      $null -eq $materializerNativePathType -or
      -not [object]::ReferenceEquals(
        $materializerNativePathTypes[0], $materializerNativePathType) -or
      -not [object]::ReferenceEquals(
        $materializerNativePathTypes[0],
        $loadedMaterializerNativePathTypes[0]) -or
      [string]::Join('|', $materializerNativePathMethods) -cne
        'System.String DriveTarget(System.String)|System.String Resolve(System.String)') {
    throw 'The materializer native path type compilation was not singular.'
  }
  New-Variable -Name Issue13V5MaterializerNativePathType `
    -Scope Script -Option Constant -Value $materializerNativePathTypes[0]
}

function Assert-Issue13V5AliasFreeLocalPath(
  [string]$Path,
  [string]$Label
) {
  $full = ConvertTo-Issue13V5FullPath $Path
  $root = [IO.Path]::GetPathRoot($full)
  if ($root -cnotmatch '^[A-Za-z]:\\$') {
    throw "$Label must use a local drive-letter path."
  }
  $drive = [IO.DriveInfo]::new($root)
  if ($drive.DriveType -ne [IO.DriveType]::Fixed) {
    throw "$Label must use a fixed local drive."
  }
  $target = $script:Issue13V5MaterializerNativePathType::DriveTarget(
    $root.Substring(0, 2))
  if ($target.StartsWith('\??\', [StringComparison]::OrdinalIgnoreCase) -or
      $target.StartsWith('\Device\Mup\',
        [StringComparison]::OrdinalIgnoreCase) -or
      $target.StartsWith('\Device\LanmanRedirector\',
        [StringComparison]::OrdinalIgnoreCase) -or
      $target.StartsWith('\Device\WebDavRedirector\',
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "$Label uses a substituted or mapped drive."
  }
  $full
}

function ConvertTo-Issue13V5CanonicalPath([string]$Path) {
  $full = Assert-Issue13V5AliasFreeLocalPath $Path 'V5 canonical path'
  if (-not $IsWindows) { return $full.TrimEnd([IO.Path]::DirectorySeparatorChar) }
  $missing = [Collections.Generic.List[string]]::new()
  $cursor = $full
  while (-not (Test-Path -LiteralPath $cursor)) {
    $leaf = [IO.Path]::GetFileName($cursor)
    if ([string]::IsNullOrWhiteSpace($leaf)) {
      throw "Cannot canonicalize V5 path: $full"
    }
    $missing.Add($leaf)
    $parent = [IO.Directory]::GetParent($cursor)
    if ($null -eq $parent) {
      throw "Cannot find an existing ancestor for V5 path: $full"
    }
    $cursor = $parent.FullName
  }
  $canonical =
    $script:Issue13V5MaterializerNativePathType::Resolve($cursor).TrimEnd('\')
  for ($index = $missing.Count - 1; $index -ge 0; $index--) {
    $canonical = $canonical + '\' + $missing[$index]
  }
  $canonical.TrimEnd('\')
}

function Test-Issue13V5PathOverlap([string]$Left, [string]$Right) {
  $leftFull = $Left.TrimEnd('\')
  $rightFull = $Right.TrimEnd('\')
  [string]::Equals($leftFull, $rightFull,
    [StringComparison]::OrdinalIgnoreCase) -or
    $leftFull.StartsWith($rightFull + '\',
      [StringComparison]::OrdinalIgnoreCase) -or
    $rightFull.StartsWith($leftFull + '\',
      [StringComparison]::OrdinalIgnoreCase)
}

function Assert-Issue13V5MaterializerNoReparseAncestors(
  [string]$Path,
  [string]$Label
) {
  $full = ConvertTo-Issue13V5FullPath $Path
  $cursor = $full
  while (-not (Test-Path -LiteralPath $cursor)) {
    $parent = [IO.Directory]::GetParent($cursor)
    if ($null -eq $parent) { break }
    $cursor = $parent.FullName
  }
  while (-not [string]::IsNullOrWhiteSpace($cursor)) {
    if (Test-Path -LiteralPath $cursor) {
      $item = Get-Item -LiteralPath $cursor -Force
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "$Label traverses a reparse point: $($item.FullName)"
      }
    }
    $parent = [IO.Directory]::GetParent($cursor)
    if ($null -eq $parent) { break }
    $cursor = $parent.FullName
  }
  $full
}

function Assert-Issue13V5TreeHasNoReparsePoints(
  [string]$Root,
  [string]$Label
) {
  $rootFull = Assert-Issue13V5MaterializerNoReparseAncestors $Root $Label
  if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) {
    throw "$Label is not an existing directory: $rootFull"
  }
  $reparse = @(
    Get-ChildItem -LiteralPath $rootFull -Force -Recurse |
      Where-Object {
        ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
      }
  )
  if ($reparse.Count -ne 0) {
    throw "$Label contains a reparse point: $($reparse[0].FullName)"
  }
  $rootFull
}

function Get-Issue13V5MaterializerSha256([string]$Path) {
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Issue13V5MaterializerBytesSha256([byte[]]$Bytes) {
  [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($Bytes)
  ).ToLowerInvariant()
}

function Get-Issue13V5GitBlobSha1([byte[]]$Bytes) {
  $header = [Text.Encoding]::ASCII.GetBytes(
    'blob ' + [string]$Bytes.LongLength + [char]0)
  $payload = [byte[]]::new($header.Length + $Bytes.Length)
  [Array]::Copy($header, 0, $payload, 0, $header.Length)
  [Array]::Copy($Bytes, 0, $payload, $header.Length, $Bytes.Length)
  [Convert]::ToHexString(
    [Security.Cryptography.SHA1]::HashData($payload)
  ).ToLowerInvariant()
}

function Invoke-Issue13V5GitBytes(
  [string]$Repository,
  [string[]]$Arguments
) {
  Invoke-Issue13V5GitRaw $Repository $Arguments
}

function Get-Issue13V5MaterializerGitLine(
  [string]$Repository,
  [string[]]$Arguments,
  [string]$Label
) {
  $result = Invoke-Issue13V5GitBytes $Repository $Arguments
  $value = $utf8.GetString([byte[]]$result.stdout).TrimEnd("`r", "`n")
  if ([string]::IsNullOrWhiteSpace($value) -or $value.Contains("`n") -or
      $value.Contains("`r")) {
    throw "$Label did not produce exactly one nonempty line."
  }
  $value
}

function ConvertFrom-Issue13V5MaterializerGitTreeBytes(
  [byte[]]$Bytes,
  [string]$Label
) {
  if ($Bytes.Length -eq 0 -or $Bytes[$Bytes.Length - 1] -ne 0) {
    throw "$Label is not a nonempty NUL-terminated Git tree listing."
  }
  $records = [Collections.Generic.List[object]]::new()
  $start = 0
  for ($index = 0; $index -lt $Bytes.Length; $index++) {
    if ($Bytes[$index] -ne 0) { continue }
    if ($index -eq $start) { throw "$Label contains an empty tree record." }
    $length = $index - $start
    $segment = [byte[]]::new($length)
    [Array]::Copy($Bytes, $start, $segment, 0, $length)
    $text = $utf8.GetString($segment)
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

function Get-Issue13V5SourceToolingFiles([string]$Root) {
  $harness = Join-Path $Root 'issue13-evidence-harness'
  if (-not (Test-Path -LiteralPath $harness -PathType Container)) {
    throw "The canonical V5 source harness directory is absent: $harness"
  }
  $rootDirectories = @(Get-ChildItem -LiteralPath $Root -Directory -Force)
  $harnessDirectories = @(
    Get-ChildItem -LiteralPath $harness -Directory -Recurse -Force)
  if ($rootDirectories.Count -ne 1 -or
      $rootDirectories[0].Name -cne 'issue13-evidence-harness' -or
      $harnessDirectories.Count -ne 0) {
    throw 'The canonical V5 source requires one flat harness directory.'
  }
  $actual = @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force |
      ForEach-Object {
        $_.FullName.Substring($Root.Length + 1).Replace('\', '/')
      } | Sort-Object -CaseSensitive)
  $expected = @($sourceToolingFiles | Sort-Object -CaseSensitive)
  if ([string]::Join("`n", $actual) -cne
      [string]::Join("`n", $expected)) {
    throw 'The canonical V5 source topology differs from its closed allowlist.'
  }
  @($sourceToolingFiles | ForEach-Object {
      Get-Item -LiteralPath (Join-Path $Root $_.Replace('/', '\')) -Force
    })
}

function Get-Issue13V5TrackedSourceTooling(
  [string]$Root,
  [string]$Repository,
  [string]$Commit
) {
  $rootFull = (Resolve-Path -LiteralPath $Root).Path
  $expectedRoot = (Resolve-Path -LiteralPath (
      Join-Path $Repository $sourceToolingRelativeRoot.Replace('/', '\'))).Path
  if (-not [string]::Equals($rootFull, $expectedRoot,
      [StringComparison]::OrdinalIgnoreCase)) {
    throw 'V5 materialization accepts only the tracked canonical source root.'
  }
  $files = @(Get-Issue13V5SourceToolingFiles $rootFull)
  if ($files.Count -ne 37) {
    throw 'The canonical V5 source must contain exactly 37 files.'
  }
  $pathPayload = [Text.Encoding]::UTF8.GetBytes(
    [string]::Join("`n", $sourceToolingFiles))
  $pathListSha256 = Get-Issue13V5MaterializerBytesSha256 $pathPayload
  if ($pathListSha256 -cne $expectedSourcePathListSha256) {
    throw 'The canonical V5 source path allowlist changed.'
  }
  $head = Get-Issue13V5MaterializerGitLine $Repository @('rev-parse', 'HEAD') `
    'V5 repository HEAD'
  if ($head -cne $Commit) {
    throw 'The canonical V5 source is not evaluated at the candidate commit.'
  }
  $status = Invoke-Issue13V5GitBytes $Repository @(
    'status', '--porcelain=v1', '-z', '--untracked-files=no')
  if ($status.stdout -isnot [byte[]] -or
      $status.stdout.Length -ne 0) {
    throw 'The candidate repository has tracked working-tree changes.'
  }

  $rootListing = ConvertFrom-Issue13V5MaterializerGitTreeBytes (
    (Invoke-Issue13V5GitBytes $Repository @(
        'ls-tree', '-z', $Commit, '--', $sourceToolingRelativeRoot)).stdout) `
    'Canonical source root tree'
  if ($rootListing.Count -ne 1 -or
      $rootListing[0].path -cne $sourceToolingRelativeRoot -or
      $rootListing[0].mode -cne '040000' -or
      $rootListing[0].type -cne 'tree') {
    throw 'The candidate commit lacks the exact canonical source root tree.'
  }
  $rootEntries = ConvertFrom-Issue13V5MaterializerGitTreeBytes (
    (Invoke-Issue13V5GitBytes $Repository @(
        'ls-tree', '-z', ($Commit + ':' + $sourceToolingRelativeRoot))).stdout) `
    'Canonical source top-level tree'
  $harnessEntry = @($rootEntries | Where-Object {
      $_.path -ceq 'issue13-evidence-harness'
    })
  if ($harnessEntry.Count -ne 1 -or
      $harnessEntry[0].mode -cne '040000' -or
      $harnessEntry[0].type -cne 'tree') {
    throw 'The candidate commit lacks the canonical source harness tree.'
  }
  $harnessEntries = ConvertFrom-Issue13V5MaterializerGitTreeBytes (
    (Invoke-Issue13V5GitBytes $Repository @(
        'ls-tree', '-z', ($Commit + ':' + $sourceToolingRelativeRoot +
          '/issue13-evidence-harness'))).stdout) `
    'Canonical source harness tree'
  $gitFiles = [Collections.Generic.Dictionary[string, object]]::new(
    [StringComparer]::Ordinal)
  foreach ($entry in $rootEntries) {
    if ($entry.type -ceq 'tree') { continue }
    $gitFiles.Add([string]$entry.path, $entry)
  }
  foreach ($entry in $harnessEntries) {
    if ($entry.type -cne 'blob') {
      throw 'The canonical source harness tree contains a nested tree.'
    }
    $gitFiles.Add('issue13-evidence-harness/' + [string]$entry.path, $entry)
  }
  $gitPaths = @($gitFiles.Keys | Sort-Object -CaseSensitive)
  $expectedPaths = @($sourceToolingFiles | Sort-Object -CaseSensitive)
  if ($rootEntries.Count -ne 6 -or $harnessEntries.Count -ne 32 -or
      $gitFiles.Count -ne 37 -or
      [string]::Join("`n", $gitPaths) -cne
        [string]::Join("`n", $expectedPaths)) {
    throw 'The candidate commit source topology differs from the allowlist.'
  }

  foreach ($treeObject in @(
      [string]$rootListing[0].object,
      [string]$harnessEntry[0].object)) {
    $type = Get-Issue13V5MaterializerGitLine $Repository @(
      'cat-file', '-t', $treeObject) 'Canonical source tree type'
    if ($type -cne 'tree') {
      throw 'A canonical source tree object is not a Git tree.'
    }
  }
  $records = [Collections.Generic.List[object]]::new()
  foreach ($relative in $sourceToolingFiles) {
    $entry = $gitFiles[$relative]
    if ($null -eq $entry -or $entry.mode -cne '100644' -or
        $entry.type -cne 'blob') {
      throw "Canonical source file has an invalid Git mode: $relative"
    }
    $repositoryPath = $sourceToolingRelativeRoot + '/' + $relative
    $path = Join-Path $rootFull $relative.Replace('/', '\')
    $localBytes = [IO.File]::ReadAllBytes($path)
    $blobBytes = [byte[]](Invoke-Issue13V5GitBytes $Repository @(
        'cat-file', 'blob', ($Commit + ':' + $repositoryPath))).stdout
    if (-not [Collections.StructuralComparisons]::StructuralEqualityComparer.
        Equals($localBytes, $blobBytes)) {
      throw "Canonical source bytes differ from the candidate: $relative"
    }
    $hashObject = Get-Issue13V5MaterializerGitLine $Repository @(
      'hash-object', '--no-filters', '--', $repositoryPath) `
      "Canonical source hash-object $relative"
    if ($hashObject -cne [string]$entry.object -or
        (Get-Issue13V5GitBlobSha1 $localBytes) -cne [string]$entry.object) {
      throw "Canonical source Git blob differs from the candidate: $relative"
    }
    $records.Add([pscustomobject][ordered]@{
        relative_path = $relative
        repository_path = $repositoryPath
        size_bytes = [long]$localBytes.LongLength
        sha256 = Get-Issue13V5MaterializerBytesSha256 $localBytes
        mode = [string]$entry.mode
        type = [string]$entry.type
        blob = [string]$entry.object
      })
  }
  $inventoryLines = @($records | ForEach-Object {
      [string]$_.relative_path + '|' + [string]$_.size_bytes + '|' +
        [string]$_.sha256
    })
  $inventoryPayload = [Text.Encoding]::UTF8.GetBytes(
    [string]::Join("`n", $inventoryLines))
  [pscustomobject][ordered]@{
    candidate_commit = $Commit
    repository_relative_root = $sourceToolingRelativeRoot
    root = $rootFull
    physical_root = ConvertTo-Issue13V5CanonicalPath $rootFull
    file_count = [long]$records.Count
    directory_count = 1L
    total_bytes = [long](($records | Measure-Object size_bytes -Sum).Sum)
    path_list_sha256 = $pathListSha256
    inventory_sha256 = Get-Issue13V5MaterializerBytesSha256 $inventoryPayload
    trees = [object[]]@(
      [pscustomobject][ordered]@{
        relative_path = '.'
        repository_path = $sourceToolingRelativeRoot
        mode = [string]$rootListing[0].mode
        type = [string]$rootListing[0].type
        tree = [string]$rootListing[0].object
      },
      [pscustomobject][ordered]@{
        relative_path = 'issue13-evidence-harness'
        repository_path = $sourceToolingRelativeRoot +
          '/issue13-evidence-harness'
        mode = [string]$harnessEntry[0].mode
        type = [string]$harnessEntry[0].type
        tree = [string]$harnessEntry[0].object
      }
    )
    records = [object[]]$records.ToArray()
  }
}

function Get-Issue13V5OutputRuntimeFiles([string]$Root) {
  $harness = Join-Path $Root 'issue13-evidence-harness'
  if (-not (Test-Path -LiteralPath $harness -PathType Container)) {
    throw "The materialized V5 harness directory is absent: $harness"
  }
  $rootDirectories = @(Get-ChildItem -LiteralPath $Root -Directory -Force)
  $harnessDirectories = @(
    Get-ChildItem -LiteralPath $harness -Directory -Recurse -Force)
  if ($rootDirectories.Count -ne 1 -or
      $rootDirectories[0].Name -cne 'issue13-evidence-harness' -or
      $harnessDirectories.Count -ne 0) {
    throw 'V5 output requires one flat issue13-evidence-harness directory.'
  }
  @(
    @(Get-ChildItem -LiteralPath $Root -File -Force | Where-Object {
      $_.Name -cne 'v5-harness-manifest.json'
    }),
    @(Get-ChildItem -LiteralPath $harness -File -Force)
  ) | ForEach-Object { $_ }
}

function Get-Issue13V5Inventory(
  [string]$Root,
  [ValidateSet('source', 'output')][string]$Mode
) {
  $rootFull = (Resolve-Path -LiteralPath $Root).Path
  $files = if ($Mode -ceq 'source') {
    Get-Issue13V5SourceToolingFiles $rootFull
  } else {
    Get-Issue13V5OutputRuntimeFiles $rootFull
  }
  $records = @($files | ForEach-Object {
    $relative = $_.FullName.Substring($rootFull.Length + 1).Replace('\', '/')
    [pscustomobject][ordered]@{
      relative_path = $relative
      size_bytes = [long]$_.Length
      sha256 = Get-Issue13V5MaterializerSha256 $_.FullName
    }
  } | Sort-Object relative_path)
  $lines = @($records | ForEach-Object {
    [string]$_.relative_path + '|' + [string]$_.size_bytes + '|' +
      [string]$_.sha256
  })
  $payload = [Text.Encoding]::UTF8.GetBytes([string]::Join("`n", $lines))
  [pscustomobject][ordered]@{
    file_count = [long]$records.Count
    total_bytes = [long](($records | Measure-Object size_bytes -Sum).Sum)
    inventory_sha256 = [Convert]::ToHexString(
      [Security.Cryptography.SHA256]::HashData($payload)
    ).ToLowerInvariant()
    records = $records
  }
}

function Set-Issue13V5Utf8Text([string]$Path, [string]$Value) {
  [IO.File]::WriteAllText($Path, $Value, $utf8)
  $observed = [IO.File]::ReadAllText($Path, $utf8)
  if (-not [string]::Equals($observed, $Value, [StringComparison]::Ordinal)) {
    throw "UTF-8 round trip failed: $Path"
  }
}

function Copy-Issue13V5AuthenticatedFile(
  [string]$Source,
  [string]$Destination,
  [long]$ExpectedSize,
  [string]$ExpectedSha256
) {
  $sourceStream = [IO.FileStream]::new(
    $Source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
  try {
    if ($sourceStream.Length -ne $ExpectedSize -or
        $sourceStream.Length -gt [int]::MaxValue) {
      throw "Authenticated V5 source size changed: $Source"
    }
    $bytes = [byte[]]::new([int]$sourceStream.Length)
    $offset = 0
    while ($offset -lt $bytes.Length) {
      $read = $sourceStream.Read($bytes, $offset, $bytes.Length - $offset)
      if ($read -eq 0) {
        throw "Authenticated V5 source ended early: $Source"
      }
      $offset += $read
    }
    if ((Get-Issue13V5MaterializerBytesSha256 $bytes) -cne
        $ExpectedSha256) {
      throw "Authenticated V5 source content changed: $Source"
    }
    $destinationStream = [IO.FileStream]::new(
      $Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write,
      [IO.FileShare]::None)
    try {
      $destinationStream.Write($bytes, 0, $bytes.Length)
      $destinationStream.Flush($true)
    } finally {
      $destinationStream.Dispose()
    }
  } finally {
    $sourceStream.Dispose()
  }
}

function Get-Issue13V5ControllerPins(
  [string]$Repository,
  [string]$Commit
) {
  $relativeRoot = $PSScriptRoot.Substring($Repository.Length).
    TrimStart('\').Replace('\', '/')
  @($controllerFiles | ForEach-Object {
    $candidatePath = Join-Path $PSScriptRoot $_
    $null = Assert-Issue13V5MaterializerNoReparseAncestors $candidatePath `
      "V5 controller source $_"
    $path = (Resolve-Path -LiteralPath $candidatePath).Path
    $relative = $relativeRoot + '/' + $_
    $controllerBytes = [IO.File]::ReadAllBytes($path)
    $currentBlob = Get-Issue13V5GitBlobSha1 $controllerBytes
    $committedBlob = (Invoke-Issue13V5SealedGit -C $Repository rev-parse `
      ($Commit + ':' + $relative) 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $currentBlob -cnotmatch '^[0-9a-f]{40}$' -or
        $currentBlob -cne $committedBlob) {
      throw "V5 controller source is not pinned to candidate: $relative"
    }
    [ordered]@{
      name = $_
      relative_path = $relative
      sha256 = Get-Issue13V5MaterializerBytesSha256 $controllerBytes
      git_blob = $currentBlob
    }
  })
}

function Add-Issue13V5ExactSource(
  [string]$Path,
  [string]$Needle,
  [string]$Replacement
) {
  $value = [IO.File]::ReadAllText($Path, $utf8)
  $first = $value.IndexOf($Needle, [StringComparison]::Ordinal)
  if ($first -lt 0 -or
      $value.IndexOf($Needle, $first + $Needle.Length,
        [StringComparison]::Ordinal) -ge 0) {
    throw "V5 patch anchor is absent or ambiguous: $Path"
  }
  $patched = $value.Substring(0, $first) + $Replacement +
    $value.Substring($first + $Needle.Length)
  Set-Issue13V5Utf8Text $Path $patched
}

$repository = (Invoke-Issue13V5SealedGit `
  -C $PSScriptRoot rev-parse --show-toplevel 2>$null).Trim()
$repository = Assert-Issue13V5AliasFreeLocalPath $repository 'V5 repository'
$repository = Assert-Issue13V5MaterializerNoReparseAncestors `
  $repository 'V5 repository'
$head = (Invoke-Issue13V5SealedGit `
  -C $repository rev-parse HEAD 2>$null).Trim()
$trackedStatus = @(Invoke-Issue13V5SealedGit `
  -C $repository status '--porcelain=v1' `
  '--untracked-files=no' 2>$null)
if ($LASTEXITCODE -ne 0 -or $head -cne $CandidateCommit -or
    $trackedStatus.Count -ne 0) {
  throw 'V5 materialization requires the pinned candidate HEAD and tracked-clean tree.'
}
$metadataPath = Join-Path $PSScriptRoot 'issue13-v5-metadata-equivalence.json'
$metadata = [IO.File]::ReadAllText($metadataPath, $utf8) |
  ConvertFrom-Json -DateKind String
$metadataDerivationCommit =
  [string]$metadata.candidate_commit_at_derivation
$metadataRuntimeGeneration =
  [string]$metadata.candidate_runtime_generation_sha256
if ([string]$metadata.schema -cne 'wlv-issue13-metadata-equivalence/1' -or
    [string]$metadata.baseline_commit -cne $baselineCommit -or
    -not [regex]::IsMatch($metadataDerivationCommit, '^[0-9a-f]{40}$') -or
    -not [regex]::IsMatch($metadataRuntimeGeneration, '^[0-9a-f]{64}$')) {
  throw 'V5 metadata equivalence has an invalid derivation binding.'
}
$resolvedMetadataCommit = (Invoke-Issue13V5SealedGit `
  -C $repository rev-parse ($metadataDerivationCommit + '^{commit}') `
  2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or
    $resolvedMetadataCommit -cne $metadataDerivationCommit) {
  throw 'V5 metadata derivation commit is not available as a Git commit.'
}
$null = Invoke-Issue13V5SealedGit -C $repository merge-base `
  '--is-ancestor' $metadataDerivationCommit $CandidateCommit 2>$null
if ($LASTEXITCODE -ne 0) {
  throw 'V5 metadata derivation is not an ancestor of the candidate.'
}
$metadataInputChanges = @(Invoke-Issue13V5SealedGit -C $repository diff `
  '--name-only' $metadataDerivationCommit $CandidateCommit '--' `
  'R' 'catalog' 'config' 'contracts/units' 'methods' 'parameters' 2>$null)
if ($LASTEXITCODE -ne 0 -or $metadataInputChanges.Count -ne 0) {
  throw 'V5 metadata derivation is stale for the candidate runtime inputs.'
}
$controllerPins = @(Get-Issue13V5ControllerPins $repository $CandidateCommit)
if ($controllerPins.Count -ne $controllerFiles.Count) {
  throw 'V5 controller pin coverage differs from its closed inventory.'
}
if ([string]::IsNullOrWhiteSpace($SourceRuntimeRoot)) {
  $SourceRuntimeRoot = Join-Path $repository `
    $sourceToolingRelativeRoot.Replace('/', '\')
}
$SourceRuntimeRoot = Assert-Issue13V5AliasFreeLocalPath `
  $SourceRuntimeRoot 'Canonical V5 tooling source'
$null = Assert-Issue13V5MaterializerNoReparseAncestors $SourceRuntimeRoot `
  'Canonical V5 tooling source'
$source = Assert-Issue13V5TreeHasNoReparsePoints `
  (Resolve-Path -LiteralPath $SourceRuntimeRoot).Path `
  'Canonical V5 tooling source'
$Destination = Assert-Issue13V5AliasFreeLocalPath $Destination 'V5 destination'
$destinationFull = Assert-Issue13V5MaterializerNoReparseAncestors $Destination `
  'V5 destination'
$sourceFull = ConvertTo-Issue13V5FullPath $source
$repositoryCanonical = ConvertTo-Issue13V5CanonicalPath $repository
$sourceCanonical = ConvertTo-Issue13V5CanonicalPath $sourceFull
$destinationCanonical = ConvertTo-Issue13V5CanonicalPath $destinationFull
if ((Test-Issue13V5PathOverlap $destinationCanonical $sourceCanonical) -or
    (Test-Issue13V5PathOverlap $destinationCanonical $repositoryCanonical) -or
    $destinationFull -match '(?i)(^|[\\/])[^\\/]*v4(?:r[0-9]+)?[^\\/]*($|[\\/])') {
  throw 'The V5 destination must be new, external to the repository, and not V4.'
}
if (Test-Path -LiteralPath $destinationFull) {
  throw "The V5 harness destination already exists: $destinationFull"
}

$sourceInventory = Get-Issue13V5TrackedSourceTooling `
  $source $repository $CandidateCommit
if ([long]$sourceInventory.file_count -ne 37 -or
    [long]$sourceInventory.directory_count -ne 1 -or
    @($sourceInventory.trees).Count -ne 2 -or
    @($sourceInventory.records).Count -ne 37 -or
    [string]$sourceInventory.path_list_sha256 -cne
      $expectedSourcePathListSha256) {
  throw 'The canonical V5 tooling binding differs from its closed contract.'
}

$parent = Split-Path -Parent $destinationFull
if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $parent
}
$parent = Assert-Issue13V5MaterializerNoReparseAncestors `
  (Resolve-Path -LiteralPath $parent).Path 'V5 destination parent'
$parentCanonical = ConvertTo-Issue13V5CanonicalPath $parent
if ((ConvertTo-Issue13V5CanonicalPath $destinationFull) -cne
    $destinationCanonical) {
  throw 'The V5 destination identity changed while creating its parent.'
}
$staging = Join-Path $parent (
  '.' + [IO.Path]::GetFileName($destinationFull) + '.staging-' +
    [Guid]::NewGuid().ToString('N')
)
$null = New-Item -ItemType Directory -Path $staging
$harnessStaging = Join-Path $staging 'issue13-evidence-harness'
$null = New-Item -ItemType Directory -Path $harnessStaging
$stagingCanonical = ConvertTo-Issue13V5CanonicalPath $staging
$null = Assert-Issue13V5TreeHasNoReparsePoints $staging `
  'V5 materialization staging tree'

foreach ($record in @($sourceInventory.records)) {
  $from = Join-Path $source ([string]$record.relative_path).Replace('/', '\')
  $to = Join-Path $staging ([string]$record.relative_path).Replace('/', '\')
  $null = Assert-Issue13V5MaterializerNoReparseAncestors $from `
    "V5 tracked tooling source $($record.relative_path)"
  $toParent = Split-Path -Parent $to
  if (-not (Test-Path -LiteralPath $toParent -PathType Container)) {
    $null = New-Item -ItemType Directory -Path $toParent
  }
  Copy-Issue13V5AuthenticatedFile $from $to `
    ([long]$record.size_bytes) ([string]$record.sha256)
  $null = Assert-Issue13V5MaterializerNoReparseAncestors $to `
    "V5 copied runtime file $($record.relative_path)"
  if ((Get-Issue13V5MaterializerSha256 $to) -cne
      [string]$record.sha256) {
    throw "V5 harness copy failed authentication: $($record.relative_path)"
  }
}

foreach ($name in @(
    'issue13-v5-aggregate-hardening.R',
    'issue13-v5-compatibility-baseline-override.R',
    'issue13-v5-compare-override.R',
    'issue13-v5-diagnostic-module-bridges.csv',
    'issue13-v5-diagnostics-override.R',
    'issue13-v5-difference-fingerprint.R',
    'issue13-v5-metadata-equivalence.json',
    'issue13-v5-preparation-equivalence.R',
    'issue13-v5-preparation-equivalence.json',
    'issue13-v5-stage5-multiplicity-profiles.csv'
  )) {
  $from = Join-Path $PSScriptRoot $name
  $to = Join-Path $harnessStaging $name
  Copy-Item -LiteralPath $from -Destination $to
  if ((Get-Issue13V5MaterializerSha256 $to) -cne
      (Get-Issue13V5MaterializerSha256 $from)) {
    throw "V5 overlay copy failed authentication: $name"
  }
}

$aggregate = Join-Path $harnessStaging 'issue13-aggregate.R'
$baselineSource = @'
sys.source(file.path(script_dir, "issue13-baseline-runtime-index-lib.R"),
  envir = environment()
)
'@
$baselineReplacement = $baselineSource + "`n" + @'
sys.source(file.path(script_dir, "issue13-v5-compatibility-baseline-override.R"),
  envir = environment()
)
sys.source(file.path(script_dir, "issue13-v5-aggregate-hardening.R"),
  envir = environment()
)
'@
Add-Issue13V5ExactSource $aggregate $baselineSource $baselineReplacement

Add-Issue13V5ExactSource $aggregate `
  '    is.numeric(metrics$peak_rss_bytes) && metrics$peak_rss_bytes >= 0 &&' `
  '    is.numeric(metrics$peak_rss_bytes) && metrics$peak_rss_bytes > 0 &&'

$rssMapSource = @'
wlv13_validate_scenario <- function(id) {
'@.TrimEnd("`r", "`n")
$rssMapReplacement = @'
rss_evidence_by_id <- list()
wlv13_validate_scenario <- function(id) {
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $aggregate $rssMapSource $rssMapReplacement

$rssValidationSource = @'
  process_spec_ok <- tryCatch({
'@.TrimEnd("`r", "`n")
$rssValidationReplacement = @'
  rss_evidence <- tryCatch(
    wlv13_v5_recompute_peak_rss(
      metrics,
      file.path(dirname(metrics_docs$paths[[id]]), "process-samples.csv")
    ),
    error = function(error) list(
      passed = FALSE,
      peak_rss_bytes = NA_real_,
      reported_peak_rss_bytes = suppressWarnings(
        as.numeric(metrics$peak_rss_bytes)
      ),
      sample_count = NA_integer_,
      row_count = NA_integer_,
      samples_sha256 = if (is.character(metrics$samples_sha256) &&
          length(metrics$samples_sha256) == 1L) {
        metrics$samples_sha256
      } else {
        ""
      },
      error = conditionMessage(error)
    )
  )
  rss_evidence_by_id[[id]] <<- rss_evidence
  metrics_ok <- metrics_ok && isTRUE(rss_evidence$passed)
  process_spec_ok <- tryCatch({
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $aggregate `
  $rssValidationSource $rssValidationReplacement

$oracleOutcomeSource = @'
      same_outcome <- all(oracle_valid) &&
        identical(oracle$baseline$passed, oracle$candidate$passed)
      classification <- if (!same_outcome) {
'@.TrimEnd("`r", "`n")
$oracleOutcomeReplacement = @'
      delta <- tryCatch(
        wlv13_v5_compare_oracle_deltas(
          oracle$baseline,
          oracle$candidate,
          list(
            child = comparison_docs$values[[paste0("parity/", phase)]],
            full = comparison_docs$values[[paste0(
              "parity/", full_phase
            )]]
          )
        ),
        error = function(error) list(
          passed = FALSE,
          baseline_sha256 = NULL,
          candidate_sha256 = NULL,
          baseline_passed = FALSE,
          candidate_passed = FALSE,
          schema = "wlv-issue13-complete-recalculation-delta/1",
          error = conditionMessage(error)
        )
      )
      same_outcome <- all(oracle_valid) && isTRUE(delta$passed)
      classification <- if (!same_outcome) {
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $aggregate `
  $oracleOutcomeSource $oracleOutcomeReplacement
Add-Issue13V5ExactSource $aggregate `
  '      } else if (isTRUE(oracle$baseline$passed)) {' `
  '      } else if (isTRUE(delta$baseline_passed)) {'

$oracleCheckSource = @'
      add_check("oracle", phase, same_outcome,
        paste0("classification=", classification)
      )
'@.TrimEnd("`r", "`n")
$oracleCheckReplacement = @'
      add_check("oracle", phase, same_outcome,
        paste0(
          "classification=", classification,
          " delta_schema=", delta$schema,
          " baseline_delta_sha256=",
          if (is.null(delta$baseline_sha256)) "" else delta$baseline_sha256,
          " candidate_delta_sha256=",
          if (is.null(delta$candidate_sha256)) "" else delta$candidate_sha256
        )
      )
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $aggregate `
  $oracleCheckSource $oracleCheckReplacement

$oracleRowSource = @'
        baseline_exact = isTRUE(oracle$baseline$passed),
        candidate_exact = isTRUE(oracle$candidate$passed),
        baseline_mismatch_artifacts = paste(mismatch_artifacts, collapse = "|"),
'@.TrimEnd("`r", "`n")
$oracleRowReplacement = @'
        baseline_exact = isTRUE(delta$baseline_passed),
        candidate_exact = isTRUE(delta$candidate_passed),
        delta_schema = delta$schema,
        baseline_delta_sha256 = if (is.null(delta$baseline_sha256)) "" else
          delta$baseline_sha256,
        candidate_delta_sha256 = if (is.null(delta$candidate_sha256)) "" else
          delta$candidate_sha256,
        complete_delta_equal = isTRUE(delta$passed),
        baseline_mismatch_artifacts = paste(mismatch_artifacts, collapse = "|"),
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $aggregate $oracleRowSource $oracleRowReplacement

$performanceRssSource = @'
    baseline_rss <- as.numeric(baseline$peak_rss_bytes)
    candidate_rss <- as.numeric(candidate$peak_rss_bytes)
'@.TrimEnd("`r", "`n")
$performanceRssReplacement = @'
    baseline_rss_evidence <- rss_evidence_by_id[[paste0("baseline/", suffix)]]
    candidate_rss_evidence <- rss_evidence_by_id[[paste0("candidate/", suffix)]]
    baseline_rss <- if (is.list(baseline_rss_evidence) &&
        isTRUE(baseline_rss_evidence$passed)) {
      as.numeric(baseline_rss_evidence$peak_rss_bytes)
    } else {
      NA_real_
    }
    candidate_rss <- if (is.list(candidate_rss_evidence) &&
        isTRUE(candidate_rss_evidence$passed)) {
      as.numeric(candidate_rss_evidence$peak_rss_bytes)
    } else {
      NA_real_
    }
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $aggregate `
  $performanceRssSource $performanceRssReplacement

Add-Issue13V5ExactSource $aggregate `
  '    rss_ok <- is.finite(baseline_rss) && baseline_rss >= 0 &&' `
  '    rss_ok <- is.finite(baseline_rss) && baseline_rss > 0 &&'

$performanceRssEvidenceSource = @'
      baseline_peak_rss_bytes = baseline_rss,
      candidate_peak_rss_bytes = candidate_rss,
      rss_limit_bytes = rss_limit,
'@.TrimEnd("`r", "`n")
$performanceRssEvidenceReplacement = @'
      baseline_peak_rss_bytes = baseline_rss,
      candidate_peak_rss_bytes = candidate_rss,
      rss_recomputed_from_authenticated_samples =
        isTRUE(baseline_rss_evidence$passed) &&
          isTRUE(candidate_rss_evidence$passed),
      baseline_rss_sample_count = baseline_rss_evidence$sample_count,
      candidate_rss_sample_count = candidate_rss_evidence$sample_count,
      baseline_samples_sha256 = baseline_rss_evidence$samples_sha256,
      candidate_samples_sha256 = candidate_rss_evidence$samples_sha256,
      rss_limit_bytes = rss_limit,
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $aggregate `
  $performanceRssEvidenceSource $performanceRssEvidenceReplacement

$compareSource =
  'sys.source(file.path(script_dir, "issue13-compare-lib.R"), envir = environment())'
$compareReplacement = $compareSource + "`n" +
  'sys.source(file.path(script_dir, "issue13-v5-difference-fingerprint.R"), ' +
  'envir = environment())' + "`n" +
  'sys.source(file.path(script_dir, "issue13-v5-compare-override.R"), ' +
  'envir = environment())' + "`n" +
  'sys.source(file.path(script_dir, "issue13-v5-diagnostics-override.R"), ' +
  'envir = environment())'
foreach ($name in @('issue13-compare.R', 'issue13-compare-results.R')) {
  Add-Issue13V5ExactSource (Join-Path $harnessStaging $name) `
    $compareSource $compareReplacement
}

$roleSource =
  '      validation$role_match <- identical(descriptor$role, "diagnostic")'
$roleReplacement = @'
      validation$role_match <- if (
        identical(key, "file:_runtime_resources.rds")
      ) {
        identical(descriptor$role, "metadata")
      } else {
        identical(descriptor$role, "diagnostic")
      }
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource `
  (Join-Path $harnessStaging 'issue13-compare-lib.R') `
  $roleSource $roleReplacement

$inventoryModeSource = @'
                                      comparison_mode = c(
                                        "strict", "cross_engine_run_v3"
                                      )) {
'@.TrimEnd("`r", "`n")
$inventoryModeReplacement = @'
                                      comparison_mode = c(
                                        "strict", "cross_engine_run_v3",
                                        "cross_engine_source_v1"
                                      )) {
'@.TrimEnd("`r", "`n")
$compareLibrary = Join-Path $harnessStaging 'issue13-compare-lib.R'
Add-Issue13V5ExactSource $compareLibrary `
  $inventoryModeSource $inventoryModeReplacement

$crossEngineSource = @'
  cross_engine <- identical(comparison_mode, "cross_engine_run_v3")
  if (cross_engine && (!identical(candidate$kind, "run") ||
      !identical(baseline$kind, "run"))) {
    stop("cross_engine_run_v3 accepts only authenticated run inventories.",
      call. = FALSE
    )
  }
'@.TrimEnd("`r", "`n")
$crossEngineReplacement = @'
  cross_engine_run <- identical(comparison_mode, "cross_engine_run_v3")
  cross_engine_source <- identical(
    comparison_mode, "cross_engine_source_v1"
  )
  cross_engine <- cross_engine_run || cross_engine_source
  if (cross_engine_run && (!identical(candidate$kind, "run") ||
      !identical(baseline$kind, "run"))) {
    stop("cross_engine_run_v3 accepts only authenticated run inventories.",
      call. = FALSE
    )
  }
  if (cross_engine_source && (!identical(candidate$kind, "source") ||
      !identical(baseline$kind, "source"))) {
    stop("cross_engine_source_v1 accepts only authenticated source inventories.",
      call. = FALSE
    )
  }
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $crossEngineSource $crossEngineReplacement

$crossEngineRulesSource = @'
  rules <- if (cross_engine) wlv13_cross_engine_run_rules() else NULL
'@.TrimEnd("`r", "`n")
$crossEngineRulesReplacement = @'
  rules <- if (cross_engine_run) {
    wlv13_cross_engine_run_rules()
  } else if (cross_engine_source) {
    list(
      normalized = "file:_unit_contract.csv",
      candidate_only = character()
    )
  } else {
    NULL
  }
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $crossEngineRulesSource $crossEngineRulesReplacement
Add-Issue13V5ExactSource $compareLibrary `
  '    } else if (cross_engine && identical(key, "file:_anomalies.csv")) {' `
  '    } else if (cross_engine_run && identical(key, "file:_anomalies.csv")) {'

$arrayShapeSource = @'
  same_dimnames <- identical(left_sidecar$dimnames, right_sidecar$dimnames)
  if (!same_dimensions) {
    return(list(
      summary = list(
        passed = FALSE,
        same_dimensions = FALSE,
        same_dimnames = same_dimnames,
        mismatch_count = NULL,
        maximum_absolute_difference = NULL,
        first_mismatch_coordinate = "dimension-mismatch"
      ),
'@.TrimEnd("`r", "`n")
$arrayShapeReplacement = @'
  same_dimnames <- identical(left_sidecar$dimnames, right_sidecar$dimnames)
  left_schema <- left$fst_metadata[c(
    "nrOfRows", "columnNames", "columnTypes", "columnBaseTypes"
  )]
  right_schema <- right$fst_metadata[c(
    "nrOfRows", "columnNames", "columnTypes", "columnBaseTypes"
  )]
  same_payload_schema <- identical(left_schema, right_schema)
  if (!same_dimensions || !same_payload_schema) {
    return(list(
      summary = list(
        passed = FALSE,
        same_dimensions = same_dimensions,
        same_dimnames = same_dimnames,
        same_payload_schema = same_payload_schema,
        mismatch_count = NULL,
        difference_sha256 = wlv13_v5_fst_array_pair_sha256(
          left, right, chunk_rows
        ),
        maximum_absolute_difference = NULL,
        first_mismatch_coordinate = if (!same_dimensions) {
          "dimension-mismatch"
        } else {
          "array-schema-mismatch"
        }
      ),
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $arrayShapeSource $arrayShapeReplacement

$arrayFingerprintStateSource = @'
  first_right_value <- ""
  axis2_labels <- if (length(left_sidecar$dimensions) >= 2L) {
'@.TrimEnd("`r", "`n")
$arrayFingerprintStateReplacement = @'
  first_right_value <- ""
  difference_chunks <- character()
  axis2_labels <- if (length(left_sidecar$dimensions) >= 2L) {
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $arrayFingerprintStateSource $arrayFingerprintStateReplacement

$arrayFingerprintChunkSource = @'
    mismatch <- left_state != right_state
    mismatch[finite] <- left_value[finite] != right_value[finite]
    mismatch_count <- mismatch_count + sum(mismatch)
'@.TrimEnd("`r", "`n")
$arrayFingerprintChunkReplacement = @'
    mismatch <- left_state != right_state
    mismatch[finite] <- wlv13_v5_exact_numeric_mismatch(
      left_value[finite], right_value[finite]
    )
    mismatch_index <- which(mismatch)
    difference_records <- vapply(mismatch_index, function(local) {
      paste(
        format(from + local - 1, scientific = FALSE),
        wlv13_v5_difference_scalar_token(left_value[[local]]),
        wlv13_v5_difference_scalar_token(right_value[[local]]),
        sep = "|"
      )
    }, character(1L))
    difference_chunks <- c(
      difference_chunks,
      wlv13_v5_difference_chunk_sha256(
        "fst_array", from, to, difference_records
      )
    )
    mismatch_count <- mismatch_count + sum(mismatch)
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $arrayFingerprintChunkSource $arrayFingerprintChunkReplacement

$arrayFingerprintFinalSource = @'
  transition_table <- as.data.frame(as.table(transitions),
'@.TrimEnd("`r", "`n")
$arrayFingerprintFinalReplacement = @'
  difference_sha256 <- wlv13_v5_difference_final_sha256(
    "fst_array",
    list(
      candidate_dimensions = left_sidecar$dimensions,
      candidate_dimnames = left_sidecar$dimnames,
      candidate_fst_metadata = left_schema,
      baseline_dimensions = right_sidecar$dimensions,
      baseline_dimnames = right_sidecar$dimnames,
      baseline_fst_metadata = right_schema
    ),
    difference_chunks
  )
  transition_table <- as.data.frame(as.table(transitions),
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $arrayFingerprintFinalSource $arrayFingerprintFinalReplacement

$arrayFingerprintSummarySource = @'
      mismatch_count = mismatch_count,
      maximum_absolute_difference = wlv13_format_value(maximum_difference),
'@.TrimEnd("`r", "`n")
$arrayFingerprintSummaryReplacement = @'
      mismatch_count = mismatch_count,
      difference_sha256 = difference_sha256,
      maximum_absolute_difference = wlv13_format_value(maximum_difference),
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $arrayFingerprintSummarySource $arrayFingerprintSummaryReplacement
Add-Issue13V5ExactSource $compareLibrary `
  '  passed <- same_dimensions && same_dimnames && mismatch_count == 0' `
  @'
  passed <- same_dimensions && same_dimnames && same_payload_schema &&
    mismatch_count == 0
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  @'
      passed = passed,
      same_dimensions = same_dimensions,
      same_dimnames = same_dimnames,
      dimensions = as.list(left_sidecar$dimensions),
'@.TrimEnd("`r", "`n") `
  @'
      passed = passed,
      same_dimensions = same_dimensions,
      same_dimnames = same_dimnames,
      same_payload_schema = same_payload_schema,
      dimensions = as.list(left_sidecar$dimensions),
'@.TrimEnd("`r", "`n")

$tableShapeSource = @'
        mismatch_count = NULL,
        first_mismatch_coordinate = "table-schema-mismatch"
'@.TrimEnd("`r", "`n")
$tableShapeReplacement = @'
        mismatch_count = NULL,
        difference_sha256 = wlv13_v5_fst_table_pair_sha256(
          left, right, chunk_rows
        ),
        first_mismatch_coordinate = "table-schema-mismatch"
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $tableShapeSource $tableShapeReplacement

$tableFingerprintStateSource = @'
  first_mismatch <- ""
  starts <- if (rows) seq.int(1, rows, by = chunk_rows) else numeric()
'@.TrimEnd("`r", "`n")
$tableFingerprintStateReplacement = @'
  first_mismatch <- ""
  difference_chunks <- character()
  starts <- if (rows) seq.int(1, rows, by = chunk_rows) else numeric()
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $tableFingerprintStateSource $tableFingerprintStateReplacement

$tableFingerprintChunkSource = @'
      if (length(mismatch) != nrow(left_table)) {
        stop("FST table columns changed length during comparison.", call. = FALSE)
      }
      counts[[column]] <- counts[[column]] + sum(mismatch)
'@.TrimEnd("`r", "`n")
$tableFingerprintChunkReplacement = @'
      if (length(mismatch) != nrow(left_table)) {
        stop("FST table columns changed length during comparison.", call. = FALSE)
      }
      mismatch_index <- which(mismatch)
      difference_records <- vapply(mismatch_index, function(local) {
        paste(
          format(from + local - 1, scientific = FALSE),
          paste0(nchar(column, type = "bytes"), ":", enc2utf8(column)),
          wlv13_v5_difference_scalar_token(left_table[[column]][[local]]),
          wlv13_v5_difference_scalar_token(right_table[[column]][[local]]),
          sep = "|"
        )
      }, character(1L))
      difference_chunks <- c(
        difference_chunks,
        wlv13_v5_difference_chunk_sha256(
          paste0("fst_table:", column), from, to, difference_records
        )
      )
      counts[[column]] <- counts[[column]] + sum(mismatch)
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $tableFingerprintChunkSource $tableFingerprintChunkReplacement

$tableFingerprintFinalSource = @'
  differences <- data.frame(
'@.TrimEnd("`r", "`n")
$tableFingerprintFinalReplacement = @'
  difference_sha256 <- wlv13_v5_difference_final_sha256(
    "fst_table",
    list(
      candidate = list(
        rows = rows,
        columns = columns,
        types = left_meta$columnTypes,
        base_types = left_meta$columnBaseTypes
      ),
      baseline = list(
        rows = as.numeric(right_meta$nrOfRows),
        columns = right_meta$columnNames,
        types = right_meta$columnTypes,
        base_types = right_meta$columnBaseTypes
      )
    ),
    difference_chunks
  )
  differences <- data.frame(
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $tableFingerprintFinalSource $tableFingerprintFinalReplacement

$tableFingerprintSummarySource = @'
      mismatch_count = sum(counts),
      first_mismatch_coordinate = first_mismatch
'@.TrimEnd("`r", "`n")
$tableFingerprintSummaryReplacement = @'
      mismatch_count = sum(counts),
      difference_sha256 = difference_sha256,
      first_mismatch_coordinate = first_mismatch
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareLibrary `
  $tableFingerprintSummarySource $tableFingerprintSummaryReplacement

$modeChoicesSource =
  '  match.arg(options$comparison_mode, c("strict", "cross_engine_run_v3"))'
$modeChoicesReplacement = @'
  match.arg(options$comparison_mode, c(
    "strict", "cross_engine_run_v3", "cross_engine_source_v1"
  ))
'@.TrimEnd("`r", "`n")
foreach ($name in @('issue13-compare.R', 'issue13-compare-results.R')) {
  Add-Issue13V5ExactSource (Join-Path $harnessStaging $name) `
    $modeChoicesSource $modeChoicesReplacement
}

$compareResults = Join-Path $harnessStaging 'issue13-compare-results.R'
$contextHelperSource = @'
select_output <- function(path, selector) {
'@.TrimEnd("`r", "`n")
$contextHelperReplacement = @'
wlv13_v5_validate_run_context <- function(report, output, inventory) {
  project_root <- normalizePath(
    wlv13_scalar_text(report$project_root, "scenario project_root"),
    winslash = "/", mustWork = TRUE
  )
  expected_commit <- wlv13_scalar_text(
    report$expected_commit, "scenario expected_commit", "^[0-9a-f]{40}$"
  )
  observed_commit <- wlv13_scalar_text(
    report$observed_commit, "scenario observed_commit", "^[0-9a-f]{40}$"
  )
  method <- wlv13_scalar_text(output$method, "scenario output method")
  run_id <- basename(inventory$root)
  expected_root <- normalizePath(file.path(
    project_root, "results", "runs", method, run_id
  ), winslash = "/", mustWork = TRUE)
  manifest <- wlv13_json_read(inventory$manifest_path, simplify = FALSE)
  provenance <- manifest$result$provenance
  inputs <- provenance$inputs
  valid <- identical(expected_commit, observed_commit) &&
    identical(wlv13_git_commit(project_root), expected_commit) &&
    isTRUE(wlv13_git_runtime_clean(project_root)) &&
    identical(expected_root, inventory$root) &&
    identical(manifest$method, method) &&
    is.list(provenance) && isTRUE(provenance$complete) &&
    is.list(provenance$git) &&
    identical(provenance$git$commit, expected_commit) &&
    identical(provenance$git$dirty, FALSE) &&
    is.list(inputs) && length(inputs) > 0L
  if (!valid) {
    stop("Selected run is not bound to its exact clean engine worktree.",
      call. = FALSE
    )
  }
  relative_paths <- character()
  records <- lapply(inputs, function(input) {
    relative <- wlv13_scalar_text(input$path, "provenance input path")
    expected_sha <- wlv13_scalar_text(
      input$sha256, "provenance input sha256", "^[0-9a-f]{64}$"
    )
    if (grepl("^([A-Za-z]:|[/\\\\])", relative) ||
        grepl("(^|[/\\\\])[.][.]($|[/\\\\])", relative)) {
      stop("Run provenance contains an unsafe input path.", call. = FALSE)
    }
    path <- normalizePath(file.path(project_root, relative),
      winslash = "/", mustWork = TRUE
    )
    if (!wlv13_is_within(path, project_root) ||
        !identical(wlv13_sha256_file(path), expected_sha)) {
      stop(sprintf("Run provenance input differs: %s.", relative),
        call. = FALSE
      )
    }
    relative_paths <<- c(relative_paths, relative)
    paste(relative, expected_sha, sep = "|")
  })
  records <- unlist(records, use.names = FALSE)
  if (anyDuplicated(relative_paths) || anyDuplicated(records)) {
    stop("Run provenance input paths are duplicated.", call. = FALSE)
  }
  list(
    arm = if (file.exists(file.path(project_root, "R", "bootstrap.R"))) {
      "candidate"
    } else {
      "baseline"
    },
    project_root = project_root,
    expected_commit = expected_commit,
    observed_commit = observed_commit,
    method = method,
    run_root = inventory$root,
    input_count = length(records),
    input_binding_sha256 = wlv13_sha256_text(paste(records, collapse = "\n")),
    inputs = inputs
  )
}

select_output <- function(path, selector) {
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareResults `
  $contextHelperSource $contextHelperReplacement

$contextReturnSource = @'
  if (!identical(wlv13_inventory_signature(inventory),
      output$inventory_sha256) ||
      !identical(inventory$manifest_sha256, output$manifest_sha256)) {
    stop("Selected output differs from its scenario evidence.", call. = FALSE)
  }
  inventory
}
'@.TrimEnd("`r", "`n")
$contextReturnReplacement = @'
  if (!identical(wlv13_inventory_signature(inventory),
      output$inventory_sha256) ||
      !identical(inventory$manifest_sha256, output$manifest_sha256)) {
    stop("Selected output differs from its scenario evidence.", call. = FALSE)
  }
  if (identical(kind, "run")) {
    inventory$v5_engine_context <- wlv13_v5_validate_run_context(
      report, output, inventory
    )
  }
  inventory
}
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareResults `
  $contextReturnSource $contextReturnReplacement

$contextInstallSource = @'
candidate <- select_output(options$candidate_result, options$candidate_selector)
baseline <- select_output(options$baseline_result, options$baseline_selector)
output <- wlv13_ensure_dir(options$output, "comparison output")
'@.TrimEnd("`r", "`n")
$contextInstallReplacement = @'
candidate <- select_output(options$candidate_result, options$candidate_selector)
baseline <- select_output(options$baseline_result, options$baseline_selector)
wlv13_v5_comparison_context <- list(
  candidate = candidate$v5_engine_context,
  baseline = baseline$v5_engine_context
)
if (identical(comparison_mode, "cross_engine_run_v3") &&
    (!is.list(wlv13_v5_comparison_context$candidate) ||
      !is.list(wlv13_v5_comparison_context$baseline))) {
  stop("Cross-engine run comparison lacks sealed engine contexts.",
    call. = FALSE
  )
}
output <- wlv13_ensure_dir(options$output, "comparison output")
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $compareResults `
  $contextInstallSource $contextInstallReplacement

$selftest = Join-Path $harnessStaging 'issue13-selftest.R'
$selftestCompareSource =
  'sys.source(file.path(script_dir, "issue13-compare-lib.R"), envir = environment())'
$selftestCompareReplacement = $selftestCompareSource + "`n" +
  'sys.source(file.path(script_dir, "issue13-v5-difference-fingerprint.R"), ' +
  'envir = environment())'
Add-Issue13V5ExactSource $selftest `
  $selftestCompareSource $selftestCompareReplacement

$selftestFstExactSource = @'
assert(nrow(bad_comparison$transitions) >= 1L,
  "Numeric-state failure did not emit transition evidence."
)
'@.TrimEnd("`r", "`n")
$selftestFstExactReplacement = $selftestFstExactSource + "`n" + @'

# Array payload schema is scientific evidence, even when the sidecar shape and
# every value are unchanged.
schema_root <- file.path(comparison_root, "candidate-schema-bad")
dir.create(schema_root)
invisible(file.copy(
  file.path(candidate_root, "_anomalies.csv"), schema_root
))
fst::write_fst(
  data.frame(Renamed = baseline_values),
  file.path(schema_root, "array.fst")
)
saveRDS(c(list(dimensions), axes), file.path(schema_root, "array.fst.meta"))
schema_snapshot_path <- file.path(manifest_root, "candidate-schema-bad.json")
wlv13_create_snapshot(
  schema_root, paths, roles, "selftest/candidate-schema-bad",
  schema_snapshot_path
)
schema_comparison <- wlv13_compare_inventories(
  wlv13_snapshot_inventory(schema_snapshot_path),
  wlv13_snapshot_inventory(baseline_snapshot_path),
  chunk_rows = 2L,
  scenario_id = "selftest/comparison-schema-fail"
)
assert(!schema_comparison$passed,
  "FST array payload schema mutation was accepted."
)
schema_artifact <- schema_comparison$artifacts[[which(vapply(
  schema_comparison$artifacts,
  function(value) identical(value$type, "fst_array"),
  logical(1L)
))]]
assert(!isTRUE(schema_artifact$same_payload_schema) &&
    grepl("^[0-9a-f]{64}$", schema_artifact$difference_sha256),
  "FST array schema failure lacks a complete semantic fingerprint."
)

# FST tables compare exact double bits.  The second value differs by one ULP.
next_raw <- writeBin(1, raw(), size = 8L, endian = "little")
next_raw[[1L]] <- as.raw(as.integer(next_raw[[1L]]) + 1L)
next_double <- readBin(
  next_raw, what = "double", n = 1L, size = 8L, endian = "little"
)
table_baseline_root <- file.path(comparison_root, "table-baseline")
table_candidate_root <- file.path(comparison_root, "table-candidate")
dir.create(table_baseline_root)
dir.create(table_candidate_root)
fst::write_fst(
  data.frame(value = c(1, 2)),
  file.path(table_baseline_root, "table.fst")
)
fst::write_fst(
  data.frame(value = c(next_double, 2)),
  file.path(table_candidate_root, "table.fst")
)
table_baseline_snapshot <- file.path(manifest_root, "table-baseline.json")
table_candidate_snapshot <- file.path(manifest_root, "table-candidate.json")
wlv13_create_snapshot(
  table_baseline_root, "table.fst", "diagnostic",
  "selftest/table-baseline", table_baseline_snapshot
)
wlv13_create_snapshot(
  table_candidate_root, "table.fst", "diagnostic",
  "selftest/table-candidate", table_candidate_snapshot
)
table_comparison <- wlv13_compare_inventories(
  wlv13_snapshot_inventory(table_candidate_snapshot),
  wlv13_snapshot_inventory(table_baseline_snapshot),
  chunk_rows = 2L,
  scenario_id = "selftest/table-ulp-fail"
)
table_artifact <- table_comparison$artifacts[[1L]]
assert(!table_comparison$passed && table_artifact$mismatch_count == 1 &&
    grepl("^[0-9a-f]{64}$", table_artifact$difference_sha256),
  "FST table one-ULP mutation was not rejected exactly."
)
'@
Add-Issue13V5ExactSource $selftest `
  $selftestFstExactSource $selftestFstExactReplacement

$selftestSamplesSource = @'
  samples <- write_text(
    "sample_at_utc,pid,parent_pid,name,created_at_utc,working_set_bytes,private_bytes,cpu_seconds",
    file.path(directory, "process-samples.csv")
  )
'@.TrimEnd("`r", "`n")
$selftestSamplesReplacement = @'
  samples <- write_text(
    c(
      "sample_at_utc,pid,parent_pid,name,created_at_utc,working_set_bytes,private_bytes,cpu_seconds",
      paste(
        "2026-01-01T00:00:01.000Z", "100", "1", "Rscript.exe",
        "2026-01-01T00:00:00.000Z", as.character(100 * 1024^2),
        as.character(110 * 1024^2), "1", sep = ","
      )
    ),
    file.path(directory, "process-samples.csv")
  )
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $selftest `
  $selftestSamplesSource $selftestSamplesReplacement

$selftestPaperArtifactSource = @'
      type = "xlsx",
      passed = passed,
'@.TrimEnd("`r", "`n")
$selftestPaperArtifactReplacement = @'
      type = "xlsx",
      passed = passed,
      role_match = TRUE,
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $selftest `
  $selftestPaperArtifactSource $selftestPaperArtifactReplacement

$selftestPayloadArtifactSource = @'
    list(list(
      key = "file:payload.txt", passed = passed,
      mismatch_count = if (passed) 0L else 1L
    ))
'@.TrimEnd("`r", "`n")
$selftestPayloadArtifactReplacement = @'
    list(list(
      key = "file:payload.txt",
      type = if (passed) "text" else "fst_array",
      passed = passed,
      role_match = TRUE,
      mismatch_count = if (passed) 0L else 1L,
      difference_sha256 = if (passed) NULL else
        wlv13_sha256_text("synthetic-complete-recalculation-delta")
    ))
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $selftest `
  $selftestPayloadArtifactSource $selftestPayloadArtifactReplacement

$selftestComparisonEnvelopeSource = @'
    compared_at = "2026-01-01T00:00:00.000Z",
    candidate = list(inventory_sha256 = left$inventory_sha256),
    baseline = list(inventory_sha256 = right$inventory_sha256),
    artifacts = artifacts,
    policy_exceptions = list()
'@.TrimEnd("`r", "`n")
$selftestComparisonEnvelopeReplacement = @'
    compared_at = "2026-01-01T00:00:00.000Z",
    chunk_rows = 1000L,
    comparison_mode = if (parity_run) "cross_engine_run_v3" else "strict",
    candidate = list(
      kind = left$kind,
      root = left$root,
      manifest_path = left$manifest_path,
      manifest_sha256 = left$manifest_sha256,
      inventory_sha256 = left$inventory_sha256,
      identity = list(
        method = left$method,
        output_contract = list(id = "wlvpanel-output", version = "1.0.0")
      )
    ),
    baseline = list(
      kind = right$kind,
      root = right$root,
      manifest_path = right$manifest_path,
      manifest_sha256 = right$manifest_sha256,
      inventory_sha256 = right$inventory_sha256,
      identity = list(
        method = right$method,
        output_contract = list(id = "wlvpanel-output", version = "1.0.0")
      )
    ),
    identity = list(
      passed = TRUE,
      candidate_method = left$method,
      baseline_method = right$method,
      candidate_output_contract = list(
        id = "wlvpanel-output", version = "1.0.0"
      ),
      baseline_output_contract = list(
        id = "wlvpanel-output", version = "1.0.0"
      )
    ),
    missing_candidate_artifacts = list(),
    extra_candidate_artifacts = list(),
    allowed_candidate_only_artifacts = if (parity_run) {
      as.list(c(
        "file:_nonfinite_resolution_diagnostics.csv",
        "file:_runtime_resources.rds"
      ))
    } else {
      list()
    },
    architecture_differences = if (parity_run) {
      as.list(c(
        "file:_scientific_checks.csv",
        "file:_source_provenance.csv",
        "file:_nonfinite_resolution_diagnostics.csv",
        "file:_runtime_resources.rds"
      ))
    } else {
      list()
    },
    artifact_count = length(artifacts),
    artifacts = artifacts,
    transitions = data.frame(),
    indicator_differences = data.frame(),
    policy_exceptions = list()
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $selftest `
  $selftestComparisonEnvelopeSource $selftestComparisonEnvelopeReplacement

$selftestArchitectureAnchor = @'
  }
  report <- list(
'@.TrimEnd("`r", "`n")
$selftestArchitectureReplacement = @'
  }
  parity_run <- grepl("^parity/(calculate|recalculate)/", id)
  if (startsWith(id, "oracle/candidate/") || parity_run) {
    artifacts <- c(artifacts, list(
      list(
        key = "file:_nonfinite_resolution_diagnostics.csv",
        type = "csv",
        passed = TRUE,
        role_match = TRUE,
        candidate_path = "_nonfinite_resolution_diagnostics.csv",
        baseline_path = if (parity_run) "" else
          "_nonfinite_resolution_diagnostics.csv",
        comparison_mode = "unordered-row-multiset",
        same_columns = TRUE,
        same_dimensions = TRUE,
        architecture_difference = parity_run
      ),
      list(
        key = "file:_runtime_resources.rds",
        type = "rds",
        passed = !startsWith(id, "oracle/candidate/"),
        role_match = TRUE,
        candidate_path = "_runtime_resources.rds",
        baseline_path = if (parity_run) "" else "_runtime_resources.rds",
        architecture_difference = parity_run,
        difference_sha256 = if (startsWith(id, "oracle/candidate/")) {
          wlv13_sha256_text("authenticated-distinct-runtime-sidecar")
        } else {
          NULL
        }
      )
    ))
    if (parity_run) {
      artifacts <- c(artifacts, list(
        list(
          key = "file:_scientific_checks.csv",
          type = "csv",
          passed = TRUE,
          role_match = TRUE,
          candidate_path = "_scientific_checks.csv",
          baseline_path = "_scientific_checks.csv",
          architecture_difference = TRUE
        ),
        list(
          key = "file:_source_provenance.csv",
          type = "csv",
          passed = TRUE,
          role_match = TRUE,
          candidate_path = "_source_provenance.csv",
          baseline_path = "_source_provenance.csv",
          comparison_mode = "sealed-source-provenance-by-arm",
          method = left$method,
          source = if (left$method %in% c(
              "wiodr16", "wiodr16v09", "zerodep_2"
            )) "wiodr16" else "wiodr13",
          candidate_schema_valid = TRUE,
          baseline_schema_valid = TRUE,
          candidate_exact = TRUE,
          baseline_exact = TRUE,
          candidate_run_manifest_sha256 = left$manifest_sha256,
          baseline_run_manifest_sha256 = right$manifest_sha256,
          candidate_source_manifest_sha256 = wlv13_sha256_text(paste0(
            "candidate-source-manifest|", left$method
          )),
          baseline_source_manifest_sha256 = wlv13_sha256_text(paste0(
            "baseline-source-manifest|", right$method
          )),
          preparation_profile_sha256 = wlv13_sha256_text(
            "sealed-preparation-equivalence-profile"
          ),
          preparation_profile_exact = TRUE,
          candidate_additional_inputs_sha256 = wlv13_sha256_text(
            "shared-additional-source-inputs"
          ),
          baseline_additional_inputs_sha256 = wlv13_sha256_text(
            "shared-additional-source-inputs"
          ),
          additional_inputs_exact = TRUE,
          candidate_additional_input_count = 30L,
          baseline_additional_input_count = 30L,
          raw_semantic_equal = FALSE,
          architecture_difference = TRUE
        )
      ))
    }
  }
  projected_failure <- id %in% c(
    "oracle/baseline/recalculate/alternative_2/stage1/full",
    "oracle/candidate/recalculate/alternative_2/stage1/full"
  )
  if (startsWith(id, "oracle/")) {
    artifacts <- c(artifacts, list(
      list(
        key = "file:_scientific_checks.csv",
        type = "csv",
        passed = !projected_failure,
        role_match = TRUE,
        candidate_path = "_scientific_checks.csv",
        baseline_path = "_scientific_checks.csv",
        architecture_difference = FALSE,
        difference_sha256 = if (projected_failure) {
          wlv13_sha256_text(paste0(
            "authenticated-projected-strict-delta|", id
          ))
        } else {
          NULL
        }
      ),
      list(
        key = "file:_source_provenance.csv",
        type = "csv",
        passed = TRUE,
        role_match = TRUE,
        candidate_path = "_source_provenance.csv",
        baseline_path = "_source_provenance.csv",
        architecture_difference = FALSE
      )
    ))
  }
  raw_passed <- passed && all(vapply(artifacts, function(artifact) {
    isTRUE(artifact$passed)
  }, logical(1L)))
  report <- list(
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $selftest `
  $selftestArchitectureAnchor $selftestArchitectureReplacement
Add-Issue13V5ExactSource $selftest `
  @'
    status = if (passed) "passed" else "failed",
    passed = passed,
    compared_at = "2026-01-01T00:00:00.000Z",
'@.TrimEnd("`r", "`n") `
  @'
    status = if (raw_passed) "passed" else "failed",
    passed = raw_passed,
    compared_at = "2026-01-01T00:00:00.000Z",
'@.TrimEnd("`r", "`n")

$selftestNegativeHardeningSource = @'
# Completeness is fail-closed: remove one exact comparison in the temporary
'@.TrimEnd("`r", "`n")
$selftestNegativeHardeningReplacement = @'
# Peak RSS is accepted only when it is independently recomputed from the
# authenticated per-process samples.
rss_metrics_restore <- NULL
run_negative_aggregate(
  "forged-peak-rss",
  mutate = function() {
    rss_metrics_restore <<- replace_scenario(metrics_path, function(value) {
      value$peak_rss_bytes <- value$peak_rss_bytes + 1
      value
    })
  },
  restore = function() rss_metrics_restore(),
  category = "process"
)

rss_path_restore <- NULL
run_negative_aggregate(
  "forged-process-samples-path",
  mutate = function() {
    rss_path_restore <<- replace_scenario(metrics_path, function(value) {
      value$samples_path <- value$stdout_path
      value$samples_sha256 <- value$stdout_sha256
      value
    })
  },
  restore = function() rss_path_restore(),
  category = "process"
)

rss_count_restore <- NULL
run_negative_aggregate(
  "fractional-process-sample-count",
  mutate = function() {
    rss_count_restore <<- replace_scenario(metrics_path, function(value) {
      value$samples <- 1.5
      value
    })
  },
  restore = function() rss_count_restore(),
  category = "process"
)

samples_path <- file.path(baseline_directory, "process-samples.csv")
samples_original <- readBin(
  samples_path, what = "raw", n = file.info(samples_path)$size
)
duplicate_metrics_restore <- NULL
run_negative_aggregate(
  "duplicate-process-generation",
  mutate = function() {
    lines <- readLines(samples_path, encoding = "UTF-8", warn = FALSE)
    writeLines(c(lines, lines[[2L]]), samples_path, useBytes = TRUE)
    duplicate_metrics_restore <<- replace_scenario(
      metrics_path,
      function(value) {
        value$samples_sha256 <- wlv13_sha256_file(samples_path)
        value
      }
    )
  },
  restore = function() {
    duplicate_metrics_restore()
    connection <- file(samples_path, open = "wb")
    tryCatch(
      writeBin(samples_original, connection),
      finally = close(connection)
    )
  },
  category = "process"
)

# Equal pass/fail booleans are insufficient: every recalculation mismatch is
# bound by its complete streaming difference fingerprint.
oracle_id <- paste0(
  "oracle/candidate/",
  "recalculate/alternative_2/stage1/full"
)
oracle_path <- file.path(
  evidence_root, "comparisons", safe_id(oracle_id), "comparison.json"
)
oracle_restore <- NULL
run_negative_aggregate(
  "forged-oracle-delta",
  mutate = function() {
    oracle_restore <<- replace_scenario(oracle_path, function(value) {
      value$artifacts[[1L]]$difference_sha256 <-
        wlv13_sha256_text("different-complete-recalculation-delta")
      value
    })
  },
  restore = function() oracle_restore(),
  category = "oracle"
)

architecture_id <- paste0(
  "parity/",
  "recalculate/alternative_2/stage1/full"
)
architecture_path <- file.path(
  evidence_root, "comparisons", safe_id(architecture_id), "comparison.json"
)
architecture_restore <- NULL
run_negative_aggregate(
  "forged-runtime-sidecar-proof",
  mutate = function() {
    architecture_restore <<- replace_scenario(
      architecture_path,
      function(value) {
        keys <- vapply(value$artifacts, `[[`, character(1L), "key")
        index <- match("file:_runtime_resources.rds", keys)
        value$artifacts[[index]]$architecture_difference <- FALSE
        value
      }
    )
  },
  restore = function() architecture_restore(),
  category = "oracle"
)

source_provenance_restore <- NULL
run_negative_aggregate(
  "omitted-source-provenance-proof",
  mutate = function() {
    source_provenance_restore <<- replace_scenario(
      architecture_path,
      function(value) {
        key <- "file:_source_provenance.csv"
        keys <- vapply(value$artifacts, `[[`, character(1L), "key")
        value$artifacts <- value$artifacts[keys != key]
        value$artifact_count <- length(value$artifacts)
        value$architecture_differences <- Filter(
          function(item) !identical(item, key),
          value$architecture_differences
        )
        value
      }
    )
  },
  restore = function() source_provenance_restore(),
  category = "oracle"
)

source_inputs_restore <- NULL
run_negative_aggregate(
  "forged-source-provenance-additional-inputs",
  mutate = function() {
    source_inputs_restore <<- replace_scenario(
      architecture_path,
      function(value) {
        keys <- vapply(value$artifacts, `[[`, character(1L), "key")
        index <- match("file:_source_provenance.csv", keys)
        value$artifacts[[index]]$candidate_additional_inputs_sha256 <-
          wlv13_sha256_text("mutated-additional-source-inputs")
        value
      }
    )
  },
  restore = function() source_inputs_restore(),
  category = "oracle"
)

strict_source_restore <- NULL
run_negative_aggregate(
  "omitted-strict-source-provenance",
  mutate = function() {
    strict_source_restore <<- replace_scenario(
      oracle_path,
      function(value) {
        key <- "file:_source_provenance.csv"
        keys <- vapply(value$artifacts, `[[`, character(1L), "key")
        value$artifacts <- value$artifacts[keys != key]
        value$artifact_count <- length(value$artifacts)
        value
      }
    )
  },
  restore = function() strict_source_restore(),
  category = "oracle"
)

failed_strict_source_restore <- NULL
run_negative_aggregate(
  "failed-strict-source-provenance",
  mutate = function() {
    failed_strict_source_restore <<- replace_scenario(
      oracle_path,
      function(value) {
        keys <- vapply(value$artifacts, `[[`, character(1L), "key")
        index <- match("file:_source_provenance.csv", keys)
        value$artifacts[[index]]$passed <- FALSE
        value$artifacts[[index]]$difference_sha256 <-
          wlv13_sha256_text("mutated-strict-source-provenance")
        value$passed <- FALSE
        value$status <- "failed"
        value
      }
    )
  },
  restore = function() failed_strict_source_restore(),
  category = "oracle"
)

unknown_architecture_restore <- NULL
run_negative_aggregate(
  "unregistered-architecture-projection",
  mutate = function() {
    unknown_architecture_restore <<- replace_scenario(
      architecture_path,
      function(value) {
        value$artifacts[[1L]]$architecture_difference <- TRUE
        value$architecture_differences <- c(
          value$architecture_differences,
          list(value$artifacts[[1L]]$key)
        )
        value
      }
    )
  },
  restore = function() unknown_architecture_restore(),
  category = "oracle"
)

# Completeness is fail-closed: remove one exact comparison in the temporary
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $selftest `
  $selftestNegativeHardeningSource $selftestNegativeHardeningReplacement

$selftestAggregateSource = @'
aggregate_output <- file.path(aggregate_root, "output-pass")
command <- file.path(R.home("bin"), "Rscript.exe")
'@.TrimEnd("`r", "`n")
$selftestAggregateReplacement = @'
aggregate_output <- file.path(aggregate_root, "output-pass")
aggregate_production_script <- file.path(script_dir, "issue13-aggregate.R")
aggregate_template <- readLines(
  aggregate_production_script, encoding = "UTF-8", warn = FALSE
)
script_dir_line <- which(aggregate_template ==
  "script_dir <- dirname(script_path)"
)
override_start <- grep(
  "issue13-v5-compatibility-baseline-override.R",
  aggregate_template, fixed = TRUE
)
if (length(script_dir_line) != 1L || length(override_start) != 1L ||
    override_start + 2L > length(aggregate_template) ||
    !identical(aggregate_template[[override_start]],
      "sys.source(file.path(script_dir, \"issue13-v5-compatibility-baseline-override.R\"),") ||
    !identical(aggregate_template[[override_start + 1L]],
      "  envir = environment()") ||
    !identical(aggregate_template[[override_start + 2L]], ")")) {
  stop("V5 aggregate self-test overlay anchor changed.", call. = FALSE)
}
aggregate_template[[script_dir_line]] <- sprintf(
  "script_dir <- %s", deparse(script_dir)
)
aggregate_template <- aggregate_template[-seq.int(
  override_start, override_start + 2L
)]
aggregate_selftest_script <- file.path(
  temporary_root, "issue13-aggregate-core-selftest.R"
)
writeLines(
  aggregate_template, aggregate_selftest_script,
  useBytes = TRUE
)
command <- file.path(R.home("bin"), "Rscript.exe")
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $selftest `
  $selftestAggregateSource $selftestAggregateReplacement
Add-Issue13V5ExactSource $selftest `
  '  "--vanilla", file.path(script_dir, "issue13-aggregate.R"),' `
  '  "--vanilla", aggregate_selftest_script,'
$selftestStatusSource = @'
status <- system2(command, shQuote(arguments), stdout = TRUE, stderr = TRUE)
'@.TrimEnd("`r", "`n")
$selftestStatusReplacement = @'
policy_output <- file.path(aggregate_root, "output-v5-policy-reject")
production_arguments <- arguments
production_arguments[[which(
  production_arguments == aggregate_selftest_script
)]] <- aggregate_production_script
production_arguments[[which(
  production_arguments == aggregate_output
)]] <- policy_output
policy_status <- suppressWarnings(system2(
  command, shQuote(production_arguments), stdout = TRUE, stderr = TRUE
))
policy_exit <- attr(policy_status, "status", exact = TRUE)
if (is.null(policy_exit)) policy_exit <- 0L
assert(!identical(policy_exit, 0L) && any(grepl(
  "V5 requires the exact Issue #12 baseline origin.",
  policy_status, fixed = TRUE
)), "V5 aggregate accepted a synthetic unbound baseline profile.")

status <- system2(command, shQuote(arguments), stdout = TRUE, stderr = TRUE)
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $selftest `
  $selftestStatusSource $selftestStatusReplacement

$selftestMetadataSource = @'
}

aggregate_root <- file.path(temporary_root, "aggregate")
'@.TrimEnd("`r", "`n")
$selftestMetadataReplacement = @'
}

sys.source(file.path(script_dir, "issue13-v5-compare-override.R"),
  envir = environment()
)
sys.source(file.path(script_dir, "issue13-v5-diagnostics-override.R"),
  envir = environment()
)
sys.source(file.path(script_dir, "issue13-v5-preparation-equivalence.R"),
  envir = environment()
)
metadata_assertions <- wlv13_v5_metadata_selftest()
assert(identical(metadata_assertions, 645L),
  "V5 exhaustive metadata mutation coverage is incomplete."
)
diagnostic_assertions <- wlv13_v5d_selftest()
assert(identical(diagnostic_assertions, 226L),
  "V5 exhaustive diagnostic mutation coverage is incomplete."
)
preparation_assertions <- wlv13_v5p_selftest(file.path(
  script_dir, "issue13-v5-preparation-equivalence.json"
))
assert(identical(preparation_assertions, 173L),
  "V5 exhaustive preparation mutation coverage is incomplete."
)

aggregate_root <- file.path(temporary_root, "aggregate")
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $selftest `
  $selftestMetadataSource $selftestMetadataReplacement

$preparationCompare = Join-Path $staging 'issue13-preparation-compare.R'
$preparationLibrary = Join-Path $staging 'issue13-prep-paper-lib.R'
$preparationAuthSource = @'
sys.source(
  file.path(dirname(script_path), "issue13-preparation-auth-lib.R"),
  envir = environment(),
  chdir = FALSE
)
'@.TrimEnd("`r", "`n")
$preparationAuthReplacement = $preparationAuthSource + "`n" + @'
sys.source(
  file.path(
    dirname(script_path), "issue13-evidence-harness",
    "issue13-v5-preparation-equivalence.R"
  ),
  envir = environment(),
  chdir = FALSE
)
preparation_equivalence_path <- file.path(
  dirname(script_path), "issue13-evidence-harness",
  "issue13-v5-preparation-equivalence.json"
)
script_dir <- file.path(dirname(script_path), "issue13-evidence-harness")
sys.source(file.path(script_dir, "issue13-compare-lib.R"),
  envir = environment(), chdir = FALSE
)
sys.source(file.path(script_dir, "issue13-v5-difference-fingerprint.R"),
  envir = environment(), chdir = FALSE
)
sys.source(file.path(script_dir, "issue13-v5-compare-override.R"),
  envir = environment(), chdir = FALSE
)
sys.source(file.path(script_dir, "issue13-v5-diagnostics-override.R"),
  envir = environment(), chdir = FALSE
)
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $preparationCompare `
  $preparationAuthSource $preparationAuthReplacement
$sidecarPassSource = @'
  passed <- shape_passed && values_passed && left_internal_hash_ok &&
    right_internal_hash_ok
'@.TrimEnd("`r", "`n")
$sidecarPassReplacement = @'
  sidecar_architecture_valid <- isTRUE(left_contract$legacy) &&
    !isTRUE(right_contract$legacy) &&
    is.null(left_contract$schema_version) &&
    identical(right_contract$schema_version, "1") &&
    is.null(left_contract$fst_sha256) &&
    identical(right_contract$fst_sha256, right_sha)
  passed <- shape_passed && values_passed && left_internal_hash_ok &&
    right_internal_hash_ok && sidecar_architecture_valid
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $preparationLibrary `
  $sidecarPassSource $sidecarPassReplacement
$sidecarReportSource = @'
    baseline_internal_hash_ok = left_internal_hash_ok,
    candidate_internal_hash_ok = right_internal_hash_ok,
    sidecars_semantically_identical = identical(
'@.TrimEnd("`r", "`n")
$sidecarReportReplacement = @'
    baseline_internal_hash_ok = left_internal_hash_ok,
    candidate_internal_hash_ok = right_internal_hash_ok,
    baseline_sidecar_format = "legacy-positional",
    candidate_sidecar_format = "versioned-v1",
    sidecar_architecture_valid = sidecar_architecture_valid,
    sidecars_semantically_identical = identical(
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $preparationLibrary `
  $sidecarReportSource $sidecarReportReplacement

$preparationCsvSource = @'
  csv_names <- c(
    "_normalization_contract.csv",
    "_source_manifest.csv",
    "_unit_contract.csv",
    "countries.csv",
    "demand.csv",
    "sectors.csv"
  )
  csv <- lapply(csv_names, function(name) {
    wlv_gate_compare_csv(
      file.path(baseline, name),
      file.path(candidate, name),
      paste0(source, "/normalized/", name)
    )
  })
  names(csv) <- csv_names
'@.TrimEnd("`r", "`n")
$preparationCsvReplacement = @'
  csv_names <- c(
    "_normalization_contract.csv", "countries.csv", "demand.csv",
    "sectors.csv"
  )
  csv <- lapply(csv_names, function(name) {
    wlv_gate_compare_csv(
      file.path(baseline, name),
      file.path(candidate, name),
      paste0(source, "/normalized/", name)
    )
  })
  names(csv) <- csv_names
  source_equivalence <- wlv13_v5p_compare_source(
    baseline, candidate, source,
    baseline_manifest_table, candidate_manifest_table,
    preparation_equivalence_path
  )
  source_unit_contract_bridge <- wlv13_v5d_compare_source_unit_contract(
    wlv_gate_read_character_csv(file.path(
      baseline, "_unit_contract.csv"
    )),
    wlv_gate_read_character_csv(file.path(
      candidate, "_unit_contract.csv"
    )),
    source
  )
  source_equivalence$unit_contract$cross_engine_bridge <-
    source_unit_contract_bridge
  source_equivalence$unit_contract$passed <-
    isTRUE(source_equivalence$unit_contract$passed) &&
    isTRUE(source_unit_contract_bridge$passed)
  source_equivalence$passed <- isTRUE(source_equivalence$passed) &&
    isTRUE(source_unit_contract_bridge$passed)
  csv[["_unit_contract.csv"]] <- source_equivalence$unit_contract
  csv[["_source_manifest.csv"]] <- source_equivalence$source_manifest
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $preparationCompare `
  $preparationCsvSource $preparationCsvReplacement

$preparationManifestSource = @'
  manifest_tables_identical <- identical(
    baseline_manifest_table,
    candidate_manifest_table
  )
  passed <- isTRUE(baseline_manifest$passed) &&
    isTRUE(candidate_manifest$passed) && manifest_tables_identical &&
'@.TrimEnd("`r", "`n")
$preparationManifestReplacement = @'
  manifest_tables_identical <- identical(
    baseline_manifest_table,
    candidate_manifest_table
  )
  manifest_tables_equivalence_profile_exact <-
    isTRUE(source_equivalence$source_manifest$passed)
  passed <- isTRUE(baseline_manifest$passed) &&
    isTRUE(candidate_manifest$passed) &&
    isTRUE(source_equivalence$passed) &&
'@.TrimEnd("`r", "`n")
Add-Issue13V5ExactSource $preparationCompare `
  $preparationManifestSource $preparationManifestReplacement
Add-Issue13V5ExactSource $preparationCompare `
  '    manifest_tables_identical = manifest_tables_identical,' `
  @'
    manifest_tables_identical = manifest_tables_identical,
    manifest_tables_equivalence_profile_exact =
      manifest_tables_equivalence_profile_exact,
'@.TrimEnd("`r", "`n")

Add-Issue13V5ExactSource $preparationCompare `
  '      "wlv-issue13-preparation-rule-matrix/1") ||' `
  '      "wlv-issue13-preparation-rule-matrix/2") ||'

$ruleMatrixPath = Join-Path $staging 'issue13-preparation-rule-matrix.json'
$ruleMatrix = [IO.File]::ReadAllText($ruleMatrixPath, $utf8) |
  ConvertFrom-Json -DateKind String
if ([string]$ruleMatrix.schema -cne
      'wlv-issue13-preparation-rule-matrix/1' -or
    @($ruleMatrix.comparison_modes.preparation_cross_engine.rules).Count -ne
      10 -or
    @($ruleMatrix.comparison_modes.fault_within_engine.rules).Count -ne 5) {
  throw 'Canonical preparation rule matrix differs before V5 projection.'
}
$ruleMatrix.schema = 'wlv-issue13-preparation-rule-matrix/2'
$ruleMatrix.comparison_modes.preparation_cross_engine.candidate =
  'candidate-runtime-pinned-by-v5-config'
$ruleMatrix.comparison_modes.fault_within_engine.candidate =
  'candidate-runtime-pinned-by-v5-config'
$manifestRule = @(
  $ruleMatrix.comparison_modes.preparation_cross_engine.rules |
    Where-Object { [string]$_.id -ceq 'source-manifests' }
)
$contractRule = @(
  $ruleMatrix.comparison_modes.preparation_cross_engine.rules |
    Where-Object { [string]$_.id -ceq 'contracts-and-labels' }
)
if ($manifestRule.Count -ne 1 -or $contractRule.Count -ne 1) {
  throw 'Preparation architecture rules are absent or ambiguous.'
}
$manifestRule[0].comparison =
  'each arm must match its complete controller-pinned source manifest table, authenticated artifact inventory, schema, row order, identities, sizes and hashes'
$contractRule[0].comparison =
  'each arm must match every cell and row of its complete controller-pinned _unit_contract.csv table; no field or row is projected'
$arrayRule = @(
  $ruleMatrix.comparison_modes.preparation_cross_engine.rules |
    Where-Object { [string]$_.id -ceq 'normalized-arrays' }
)
if ($arrayRule.Count -ne 1) {
  throw 'Preparation normalized-array rule is absent or ambiguous.'
}
$arrayRule[0].comparison =
  'exact dimensions, dimnames, FST schema/types/rows, bitwise double values, and internal hashes; baseline legacy sidecars must correspond to authenticated candidate versioned-v1 sidecars'
$ruleMatrixPayload = ($ruleMatrix | ConvertTo-Json -Depth 20) + "`n"
Set-Issue13V5Utf8Text $ruleMatrixPath $ruleMatrixPayload

$readme = Join-Path $harnessStaging 'README.md'
$readmeValue = [IO.File]::ReadAllText($readme, $utf8) + @'

## V5 compatibility-oracle cut

This materialized copy is V5 tooling, not V4 evidence. The immutable origin is
`cc2c86189a06676bcb9f0e05e08033d710a92509`. Every final baseline scenario is
bound to one clean direct child authenticated by its complete binary diff. The
strict cc2 smoke is retained separately as negative evidence and is never
imported as final scenario evidence. The candidate-only
`_runtime_resources.rds` is accepted only after the candidate runtime validates
its complete cryptographic and semantic binding.

Baseline and candidate normalized sources are authenticated independently.
Their scientific arrays remain bitwise comparable. Source-generation and
aggregation-routing metadata must match exhaustive arm-specific tables sealed
in the controller; no source-contract field is dropped. FST-sidecar format
differences are accepted only after their payloads and internal hashes pass.
The shared `_source_provenance.csv` is authenticated independently in each arm;
its additional-input inventory must remain exactly identical across engines and
must remain unchanged in every recalculation.
'@
Set-Issue13V5Utf8Text $readme $readmeValue

$null = Assert-Issue13V5TreeHasNoReparsePoints $source `
  'Canonical V5 tooling source after projection'
if ((ConvertTo-Issue13V5CanonicalPath $source) -cne $sourceCanonical -or
    (ConvertTo-Issue13V5CanonicalPath $repository) -cne
      $repositoryCanonical) {
  throw 'The V5 source or repository physical identity changed.'
}
$sourceInventoryAfter = Get-Issue13V5TrackedSourceTooling `
  $source $repository $CandidateCommit
if (($sourceInventoryAfter | ConvertTo-Json -Depth 20 -Compress) -cne
    ($sourceInventory | ConvertTo-Json -Depth 20 -Compress)) {
  throw 'The canonical V5 tooling source changed during materialization.'
}
$controllerPinsAfter = @(Get-Issue13V5ControllerPins $repository $CandidateCommit)
if (($controllerPinsAfter | ConvertTo-Json -Depth 10 -Compress) -cne
    ($controllerPins | ConvertTo-Json -Depth 10 -Compress)) {
  throw 'The candidate-pinned controller changed during materialization.'
}
if ((ConvertTo-Issue13V5CanonicalPath $parent) -cne $parentCanonical -or
    (ConvertTo-Issue13V5CanonicalPath $staging) -cne $stagingCanonical) {
  throw 'The V5 parent or staging identity changed during materialization.'
}
$outputInventory = Get-Issue13V5Inventory $staging 'output'
$null = Assert-Issue13V5TreeHasNoReparsePoints $staging `
  'V5 completed staging tree'
if ([long]$outputInventory.file_count -ne $expectedOutputFileCount -or
    [long]$outputInventory.total_bytes -ne $expectedOutputTotalBytes -or
    [string]$outputInventory.inventory_sha256 -cne $expectedOutputInventory) {
  throw 'Materialized V5 tooling differs from the sealed output inventory.'
}
$manifest = [ordered]@{
  schema = 'wlv-issue13-v5-harness-materialization/1'
  generation = 'v5-terminal'
  status = 'materialized'
  materialized_at_utc = [DateTime]::UtcNow.ToString('o')
  baseline_commit = $baselineCommit
  baseline_policy = 'authenticated-direct-child-compatibility-oracle'
  baseline_runtime_commit = 'e2f4d6dae9a6d35c966b305fabac52e489faa3e7'
  baseline_runtime_tree = '7da19c4f2913e857040ba228280f404b0e54eaab'
  baseline_overlay_sha256 =
    '9f9b878f8e557973127e6260a0f224c868a0c4e8dc2db52dd6aa3f7131f28cd9'
  baseline_overlay_patch_id = '253ca5f1397132f94e3432264084a37395c60ec3'
  strict_negative_evidence_required = $true
  final_evidence_eligible = $true
  reuses_candidate_evidence = $false
  source_controller = [ordered]@{
    commit_sha256 = $CandidateCommit
    file_count = $controllerPins.Count
    records = [object[]]$controllerPins
  }
  source_tooling = $sourceInventory
  output_tooling = [ordered]@{
    file_count = $outputInventory.file_count
    total_bytes = $outputInventory.total_bytes
    inventory_sha256 = $outputInventory.inventory_sha256
  }
  sealed_output_tooling = [ordered]@{
    file_count = $expectedOutputFileCount
    total_bytes = $expectedOutputTotalBytes
    inventory_sha256 = $expectedOutputInventory
  }
  overlays = @(
    'authenticated-compatibility-oracle-cc2',
    'authenticated-candidate-runtime-sidecar',
    'authenticated-arm-specific-source-contracts'
  )
}
$manifestPath = Join-Path $staging 'v5-harness-manifest.json'
$manifestJson = $manifest | ConvertTo-Json -Depth 20
Set-Issue13V5Utf8Text $manifestPath ($manifestJson + "`n")
$manifestSha256 = Get-Issue13V5MaterializerSha256 $manifestPath

if (Test-Path -LiteralPath $destinationFull) {
  throw 'The V5 destination appeared during materialization.'
}
$null = Assert-Issue13V5MaterializerNoReparseAncestors $destinationFull `
  'V5 destination before promotion'
if ((ConvertTo-Issue13V5CanonicalPath $destinationFull) -cne
      $destinationCanonical -or
    (ConvertTo-Issue13V5CanonicalPath $parent) -cne $parentCanonical -or
    (ConvertTo-Issue13V5CanonicalPath $staging) -cne $stagingCanonical -or
    (Test-Issue13V5PathOverlap $destinationCanonical `
      (ConvertTo-Issue13V5CanonicalPath $repository)) -or
    (Test-Issue13V5PathOverlap $destinationCanonical `
      (ConvertTo-Issue13V5CanonicalPath $source))) {
  throw 'The V5 destination identity changed before promotion.'
}
[IO.Directory]::Move($staging, $destinationFull)
$null = Assert-Issue13V5TreeHasNoReparsePoints $destinationFull `
  'Installed V5 harness'
if ((ConvertTo-Issue13V5CanonicalPath $destinationFull) -cne
    $destinationCanonical) {
  throw 'The installed V5 harness has an unexpected physical identity.'
}
$installedManifest = Join-Path $destinationFull 'v5-harness-manifest.json'
if (-not (Test-Path -LiteralPath $installedManifest -PathType Leaf)) {
  throw 'The V5 harness was not installed atomically.'
}
if ((Get-Issue13V5MaterializerSha256 $installedManifest) -cne
    $manifestSha256) {
  throw 'The V5 harness manifest changed during atomic installation.'
}
$installedInventory = Get-Issue13V5Inventory $destinationFull 'output'
if ([long]$installedInventory.file_count -ne $expectedOutputFileCount -or
    [long]$installedInventory.total_bytes -ne $expectedOutputTotalBytes -or
    [string]$installedInventory.inventory_sha256 -cne
      $expectedOutputInventory) {
  throw 'Installed V5 tooling differs from the sealed output inventory.'
}
$sourceInventoryInstalled = Get-Issue13V5TrackedSourceTooling `
  $source $repository $CandidateCommit
if (($sourceInventoryInstalled | ConvertTo-Json -Depth 20 -Compress) -cne
    ($sourceInventory | ConvertTo-Json -Depth 20 -Compress)) {
  throw 'The canonical V5 tooling source changed across promotion.'
}
$controllerPinsInstalled = @(
  Get-Issue13V5ControllerPins $repository $CandidateCommit)
if (($controllerPinsInstalled | ConvertTo-Json -Depth 10 -Compress) -cne
    ($controllerPins | ConvertTo-Json -Depth 10 -Compress)) {
  throw 'The candidate-pinned controller changed across promotion.'
}

[pscustomobject][ordered]@{
  status = 'materialized'
  destination = (Resolve-Path -LiteralPath $destinationFull).Path
  manifest_path = (Resolve-Path -LiteralPath $installedManifest).Path
  manifest_sha256 = Get-Issue13V5MaterializerSha256 $installedManifest
  baseline_commit = $baselineCommit
  source_inventory_sha256 = $sourceInventory.inventory_sha256
  output_inventory_sha256 = $outputInventory.inventory_sha256
}
