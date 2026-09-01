param(
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')]
  [string]$CandidateCommit,
  [Parameter(Mandatory = $true)][string]$HarnessRuntimeRoot,
  [Parameter(Mandatory = $true)][string]$BaselineRuntimeIndex,
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')]
  [string]$BaselineRuntimeCommit,
  [Parameter(Mandatory = $true)][string]$BaselineOverlayPatch,
  [Parameter(Mandatory = $true)][string]$StrictBaselineSmokeSummary,
  [Parameter(Mandatory = $true)][string]$CompatibilityBaselineSmokeSummary,
  [Parameter(Mandatory = $true)][string]$OracleEffectSmokeSummary,
  [Parameter(Mandatory = $true)][string]$ProofPath,
  [Parameter(Mandatory = $true)][string]$ComparisonRoot,
  [Parameter(Mandatory = $true)][string]$ReplayRoot,
  [Parameter(Mandatory = $true)][string]$WorktreeRoot,
  [Parameter(Mandatory = $true)][string]$EvidenceRoot,
  [Parameter(Mandatory = $true)][string]$ControlRoot,
  [Parameter(Mandatory = $true)][string]$Output,
  [string]$RepositoryRoot = 'D:\Trabalho\Code\wlvdb',
  [string]$SourceOrigin =
    'D:\Trabalho\Code\wlvdb-issue13-baseline\source_data',
  [Parameter(Mandatory = $true)][string]$CandidateSourceOrigin,
  [string]$Rscript =
    'C:\Users\rodri\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe',
  [string]$RLibrary =
    'D:\Trabalho\Code\wlvdb\renv\library\windows\R-4.6\x86_64-w64-mingw32'
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

$baselineCommit = 'cc2c86189a06676bcb9f0e05e08033d710a92509'
$baselineProfile = 'compatibility-oracle-cc2'
$expectedBaselineRuntimeCommit =
  'e2f4d6dae9a6d35c966b305fabac52e489faa3e7'
$expectedBaselineTree = '7da19c4f2913e857040ba228280f404b0e54eaab'
$expectedOverlaySha256 =
  '9f9b878f8e557973127e6260a0f224c868a0c4e8dc2db52dd6aa3f7131f28cd9'
$expectedOverlayPatchId = '253ca5f1397132f94e3432264084a37395c60ec3'
$strictSmokeSha256 =
  '973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d'
$strictSmokeHarnessSha256 =
  'a17a187621cdd4aff6f24efd6bf43ffbf9336de0a19189dfc7f5a82758a92c23'
$expectedHarnessFileCount = 47L
$expectedHarnessTotalBytes = 2634087L
$expectedHarnessInventorySha256 =
  'a9fa44706264cd6b8392790ff1f032cc9314a8a73e18243d65e7f6ccbea02c71'
$methods = @(
  'wiodr13', 'wiodr16', 'alternative_1', 'alternative_2', 'norow_w13',
  'ochoa_1', 'ochoa_2', 'petrovic', 'wiodr13v09', 'wiodr16v09',
  'zerodep_1', 'zerodep_2'
)
$recalculations = @(
  [ordered]@{ stage = 1; variant = 'full'; sea_vars = @() },
  [ordered]@{ stage = 4; variant = 'full'; sea_vars = @() },
  [ordered]@{ stage = 5; variant = 'full'; sea_vars = @() },
  [ordered]@{
    stage = 4
    variant = 'select-gross-output-mv'
    sea_vars = @('gross_output.s.mv')
  },
  [ordered]@{
    stage = 5
    variant = 'select-gross-output-du'
    sea_vars = @('gross_output.s.du')
  }
)
$faults = @(
  'module-execution',
  'preparation-promotion',
  'publication-run-staging',
  'publication-semantic-validation',
  'publication-run-manifest',
  'publication-run-promotion',
  'publication-release-staging',
  'publication-release-manifest',
  'publication-release-promotion',
  'publication-channel-marker'
)
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function ConvertTo-Issue13V5FullPath([string]$Path, [bool]$MustExist) {
  $full = [IO.Path]::GetFullPath($Path)
  if ($MustExist -and -not (Test-Path -LiteralPath $full)) {
    throw "Required V5 path does not exist: $full"
  }
  $full
}

function Assert-Issue13V5FreshRoot([string]$Path, [string]$Label) {
  $full = ConvertTo-Issue13V5FullPath $Path $false
  $null = ConvertTo-Issue13V5PhysicalPath $full $Label
  Assert-Issue13V5NoReparseAncestors $full $Label
  if ($full -match '(?i)(^|[\\/])[^\\/]*v4(?:r[0-9]+)?[^\\/]*($|[\\/])') {
    throw "$Label must not be a V4/V4R2 root: $full"
  }
  if (Test-Path -LiteralPath $full) {
    throw "$Label already exists; V5 never reuses evidence or worktrees: $full"
  }
  $full
}

function Get-Issue13V5NewConfigSha256([string]$Path) {
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$repository = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $RepositoryRoot $true)).Path
$harnessRuntime = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $HarnessRuntimeRoot $true)).Path
$harness = Join-Path $harnessRuntime 'issue13-evidence-harness'
$harnessManifestPath = Join-Path $harnessRuntime 'v5-harness-manifest.json'
if (-not (Test-Path -LiteralPath $harness -PathType Container) -or
    -not (Test-Path -LiteralPath $harnessManifestPath -PathType Leaf)) {
  throw 'The materialized V5 harness is incomplete.'
}
$runtimeIndex = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $BaselineRuntimeIndex $true)).Path
$overlayPatch = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $BaselineOverlayPatch $true)).Path
$strictSmokePath = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $StrictBaselineSmokeSummary $true)).Path
$compatibilitySmokePath = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $CompatibilityBaselineSmokeSummary $true)).Path
$oracleEffectSmokePath = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $OracleEffectSmokeSummary $true)).Path
$rscriptFull = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $Rscript $true)).Path
$library = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $RLibrary $true)).Path
$rscriptIdentity = Get-Issue13V5PhysicalItemIdentity `
  $rscriptFull 'V5 config Rscript executable'
$rscriptSha256 = Get-Issue13V5NewConfigSha256 $rscriptFull
if ([IO.Path]::GetFileName($rscriptFull) -cne 'Rscript.exe' -or
    [long]$rscriptIdentity.link_count -ne 1L -or
    [long](Get-Item -LiteralPath $rscriptFull).Length -ne 94720L -or
    $rscriptSha256 -cne $script:Issue13V5RscriptSha256) {
  throw 'The current Rscript executable differs from its physical pin.'
}
$strictSmokeBinding = [pscustomobject][ordered]@{
  path = $strictSmokePath
  sha256 = Get-Issue13V5NewConfigSha256 $strictSmokePath
  passed_count = 5L
  failed_count = 7L
  final_evidence_eligible = $false
  rscript_path = $rscriptFull
  rscript_physical_path = [string]$rscriptIdentity.physical_path
  rscript_item_id = [string]$rscriptIdentity.item_id
  rscript_link_count = [long]$rscriptIdentity.link_count
  rscript_sha256 = $rscriptSha256
}
$pinConfig = [pscustomobject][ordered]@{
  repository_root = $repository
  candidate_commit = $CandidateCommit
  harness_runtime_root = $harnessRuntime
  harness_root = $harness
  harness_manifest_path = $harnessManifestPath
  harness_manifest_sha256 =
    Get-Issue13V5NewConfigSha256 $harnessManifestPath
  rscript = $rscriptFull
  r_library = $library
  strict_baseline_smoke = $strictSmokeBinding
}
$harnessBinding = Assert-Issue13V5HarnessBinding $pinConfig
$harnessManifest = $harnessBinding.manifest
$harnessInventory = $harnessBinding.inventory
$sourceTooling = $harnessBinding.source_tooling
if ([string]$harnessManifest.schema -cne
      'wlv-issue13-v5-harness-materialization/1' -or
    [string]$harnessManifest.generation -cne 'v5-terminal' -or
    -not (Test-Issue13V5ExactBoolean `
      $harnessManifest.final_evidence_eligible $true) -or
    -not (Test-Issue13V5ExactBoolean `
      $harnessManifest.reuses_candidate_evidence $false) -or
    [string]$harnessManifest.baseline_commit -cne $baselineCommit -or
    [string]$harnessManifest.baseline_policy -cne
      'authenticated-direct-child-compatibility-oracle' -or
    [string]$harnessManifest.baseline_runtime_commit -cne
      $expectedBaselineRuntimeCommit -or
    [string]$harnessManifest.baseline_runtime_tree -cne
      $expectedBaselineTree -or
    [string]$harnessManifest.baseline_overlay_sha256 -cne
      $expectedOverlaySha256 -or
    [string]$harnessManifest.baseline_overlay_patch_id -cne
      $expectedOverlayPatchId -or
    -not (Test-Issue13V5ExactBoolean `
      $harnessManifest.strict_negative_evidence_required $true)) {
  throw 'The V5 harness manifest is not final-evidence eligible.'
}
if ([long]$harnessInventory.file_count -ne $expectedHarnessFileCount -or
    [long]$harnessInventory.total_bytes -ne $expectedHarnessTotalBytes -or
    [string]$harnessInventory.inventory_sha256 -cne
      $expectedHarnessInventorySha256 -or
    [long]$harnessManifest.output_tooling.file_count -ne
      $expectedHarnessFileCount -or
    [long]$harnessManifest.output_tooling.total_bytes -ne
      $expectedHarnessTotalBytes -or
    [string]$harnessManifest.output_tooling.inventory_sha256 -cne
      $expectedHarnessInventorySha256 -or
    [long]$harnessManifest.sealed_output_tooling.file_count -ne
      $expectedHarnessFileCount -or
    [long]$harnessManifest.sealed_output_tooling.total_bytes -ne
      $expectedHarnessTotalBytes -or
    [string]$harnessManifest.sealed_output_tooling.inventory_sha256 -cne
      $expectedHarnessInventorySha256) {
  throw 'The materialized V5 harness changed after authentication.'
}
$preparationEquivalencePath = Join-Path $harness `
  'issue13-v5-preparation-equivalence.json'
if (-not (Test-Path -LiteralPath $preparationEquivalencePath -PathType Leaf)) {
  throw 'The exhaustive preparation-equivalence profile is missing.'
}
$preparationEquivalence = Read-Issue13V5Json $preparationEquivalencePath
if ([string]$preparationEquivalence.schema -cne
      'wlv-issue13-preparation-equivalence/1' -or
    [string]::Join("`n", @($preparationEquivalence.sources)) -cne
      "wiodr13`nwiodr16" -or
    [string]::Join("`n", @($preparationEquivalence.artifacts)) -cne
      "_unit_contract.csv`n_source_manifest.csv" -or
    @($preparationEquivalence.profiles).Count -ne 2 -or
    [string]::Join("`n", @($preparationEquivalence.profiles.source)) -cne
      "wiodr13`nwiodr16") {
  throw 'The exhaustive preparation-equivalence profile changed.'
}
$preparationEquivalenceBinding = [ordered]@{
  schema = 'wlv-issue13-preparation-equivalence/1'
  path = $preparationEquivalencePath
  sha256 = Get-Issue13V5NewConfigSha256 $preparationEquivalencePath
  sources = @('wiodr13', 'wiodr16')
  artifacts = @('_unit_contract.csv', '_source_manifest.csv')
  profile_count = 2
  all_rows_fields_and_order_exact = $true
  architecture_projection = @()
  source_unit_contract_bridge = 'exhaustive-source-unit-contract-bridge'
}

$index = Get-Content -LiteralPath $runtimeIndex -Raw |
  ConvertFrom-Json -DateKind String
$strictSmoke = Get-Content -LiteralPath $strictSmokePath -Raw |
  ConvertFrom-Json -DateKind String
$compatibilitySmoke = Get-Content -LiteralPath $compatibilitySmokePath -Raw |
  ConvertFrom-Json -DateKind String
if ($BaselineRuntimeCommit -cne $expectedBaselineRuntimeCommit -or
    (Get-Issue13V5NewConfigSha256 $overlayPatch) -cne
      $expectedOverlaySha256) {
  throw 'The requested baseline runtime or patch differs from the sealed oracle.'
}
$expectedBaselineScenarios = [Collections.Generic.List[string]]::new()
foreach ($method in $methods) {
  $expectedBaselineScenarios.Add("baseline/calculate/$method/workers1")
  foreach ($recalculation in $recalculations) {
    $expectedBaselineScenarios.Add(
      "baseline/recalculate/$method/stage$($recalculation.stage)/" +
        [string]$recalculation.variant
    )
  }
}
foreach ($method in @('wiodr13', 'wiodr16')) {
  $expectedBaselineScenarios.Add("baseline/calculate/$method/workers2")
}
$expectedBaselineScenarios.Add('baseline/prepare/all')
$expectedBaselineScenarios.Add('baseline/paper/0')
$expectedBaselineIds = @($expectedBaselineScenarios.ToArray() | Sort-Object)
$actualBaselineIds = @($index.scenarios.scenario_id | Sort-Object)
if ([string]$index.schema -cne 'wlv-issue13-baseline-runtime-index/1' -or
    [string]$index.baseline_base_commit -cne $baselineCommit -or
    @($index.profiles).Count -ne 1 -or
    [string]$index.profiles[0].id -cne $baselineProfile -or
    [string]$index.profiles[0].inventory_value -cne $baselineProfile -or
    [string]$index.profiles[0].source_commit -cne $BaselineRuntimeCommit -or
    [string]$index.profiles[0].runtime_commit -cne $BaselineRuntimeCommit -or
    -not (Test-Issue13V5ExactBoolean `
      $index.profiles[0].run_dirty $false) -or
    -not [string]::Equals(
      (ConvertTo-Issue13V5FullPath `
        ([string]$index.profiles[0].overlay_patch_path) $true),
      $overlayPatch, [StringComparison]::OrdinalIgnoreCase) -or
    [string]$index.profiles[0].overlay_patch_sha256 -cne
      (Get-Issue13V5NewConfigSha256 $overlayPatch) -or
    [string]$index.profiles[0].overlay_patch_id -cne
      $expectedOverlayPatchId -or
    @($index.scenarios).Count -ne 76 -or
    @($index.scenarios.scenario_id | Sort-Object -Unique).Count -ne 76 -or
    [string]::Join("`n", $actualBaselineIds) -cne
      [string]::Join("`n", $expectedBaselineIds) -or
    @($index.scenarios | Where-Object {
      [string]$_.runtime_commit -cne $BaselineRuntimeCommit -or
      [string]$_.profile_id -cne $baselineProfile
    }).Count -ne 0) {
  throw 'The V5 baseline index is not the authenticated compatibility oracle.'
}
if ([string]$strictSmoke.schema -cne 'wlv-issue13-v5-baseline-smoke/1' -or
    (Get-Issue13V5NewConfigSha256 $strictSmokePath) -cne
      $strictSmokeSha256 -or
    -not (Test-Issue13V5ExactBoolean `
      $strictSmoke.final_evidence_eligible $false) -or
    [string]$strictSmoke.purpose -cne
      'strict-cc2-executability-preflight' -or
    [string]$strictSmoke.baseline_commit -cne $baselineCommit -or
    -not (Test-Issue13V5ExactBoolean $strictSmoke.passed $false) -or
    [string]$strictSmoke.status -cne 'failed' -or
    [long]$strictSmoke.passed_count -ne 5 -or
    [long]$strictSmoke.failed_count -ne 7 -or
    @($strictSmoke.records).Count -ne 12 -or
    [string]$strictSmoke.source_inventory_sha256 -cne
      'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26' -or
    [string]$strictSmoke.harness_manifest_sha256 -cne
      $strictSmokeHarnessSha256 -or
    [string]::Join("`n", @($strictSmoke.records.method)) -cne
      [string]::Join("`n", $methods) -or
    [string]::Join("`n", @($strictSmoke.records |
        Where-Object status -ceq 'failed' | ForEach-Object method)) -cne
      "alternative_1`nalternative_2`nnorow_w13`nochoa_1`nochoa_2`npetrovic`nwiodr13v09") {
  throw 'The authenticated strict cc2 smoke is not the expected 5/7 evidence.'
}
if ([string]$compatibilitySmoke.schema -cne
      'wlv-issue13-v5-baseline-smoke/1' -or
    -not (Test-Issue13V5ExactBoolean `
      $compatibilitySmoke.final_evidence_eligible $false) -or
    [string]$compatibilitySmoke.purpose -cne
      'compatibility-oracle-executability-preflight' -or
    [string]$compatibilitySmoke.baseline_base_commit -cne $baselineCommit -or
    [string]$compatibilitySmoke.baseline_runtime_commit -cne
      $BaselineRuntimeCommit -or
    -not (Test-Issue13V5ExactBoolean $compatibilitySmoke.passed $true) -or
    [string]$compatibilitySmoke.status -cne 'passed' -or
    [long]$compatibilitySmoke.passed_count -ne 12 -or
    [long]$compatibilitySmoke.failed_count -ne 0 -or
    @($compatibilitySmoke.records).Count -ne 12 -or
    [string]$compatibilitySmoke.source_inventory_sha256 -cne
      'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26' -or
    [string]$compatibilitySmoke.harness_manifest_sha256 -cne
      (Get-Issue13V5NewConfigSha256 $harnessManifestPath) -or
    [string]::Join("`n", @($compatibilitySmoke.records.method)) -cne
      [string]::Join("`n", $methods) -or
    @($compatibilitySmoke.records | Where-Object status -cne 'passed').Count `
      -ne 0) {
  throw 'The compatibility-oracle smoke did not pass all 12 methods.'
}
$strictFailedMethods = @(
  'alternative_1', 'alternative_2', 'norow_w13', 'ochoa_1', 'ochoa_2',
  'petrovic', 'wiodr13v09'
)
$null = Assert-Issue13V5BaselineSmokeEvidence $pinConfig $strictSmokePath `
  'strict-cc2-executability-preflight' $baselineCommit `
  $strictSmokeHarnessSha256 $false $strictFailedMethods $strictSmokeSha256
$null = Assert-Issue13V5BaselineSmokeEvidence $pinConfig `
  $compatibilitySmokePath 'compatibility-oracle-executability-preflight' `
  $BaselineRuntimeCommit `
  (Get-Issue13V5NewConfigSha256 $harnessManifestPath) `
  $true @() (Get-Issue13V5NewConfigSha256 $compatibilitySmokePath)

$null = Invoke-Issue13V5SealedGit `
  -C $repository cat-file -e ($BaselineRuntimeCommit + '^{commit}')
if ($LASTEXITCODE -ne 0) {
  throw "Compatibility runtime commit is unavailable: $BaselineRuntimeCommit"
}
$baselineParent = (Invoke-Issue13V5SealedGit -C $repository rev-parse `
  ($BaselineRuntimeCommit + '^') 2>$null).Trim()
$baselineTree = (Invoke-Issue13V5SealedGit -C $repository rev-parse `
  ($BaselineRuntimeCommit + '^{tree}') 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $baselineParent -cne $baselineCommit -or
    $baselineTree -cne $expectedBaselineTree) {
  throw 'The compatibility runtime must be one direct child of cc2.'
}
$null = Invoke-Issue13V5SealedGit `
  -C $repository cat-file -e ($CandidateCommit + '^{commit}')
if ($LASTEXITCODE -ne 0) {
  throw "Candidate commit is unavailable: $CandidateCommit"
}
$null = Invoke-Issue13V5SealedGit -C $repository merge-base --is-ancestor `
  $baselineCommit $CandidateCommit
if ($LASTEXITCODE -ne 0 -or $CandidateCommit -ceq $baselineCommit -or
    $CandidateCommit -ceq $BaselineRuntimeCommit) {
  throw 'The candidate must be a strict descendant of the Issue #12 merge.'
}
$null = Invoke-Issue13V5SealedGit -C $repository merge-base --is-ancestor `
  $BaselineRuntimeCommit $CandidateCommit 2>$null
$oracleAncestorExit = $LASTEXITCODE
if ($oracleAncestorExit -eq 0) {
  throw 'The compatibility oracle must remain outside the candidate history.'
}
if ($oracleAncestorExit -ne 1) {
  throw 'Cannot prove that the compatibility oracle is outside the candidate history.'
}

$source = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $SourceOrigin $true)).Path
$candidateSource = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $CandidateSourceOrigin $true)).Path
$oracleProofPath = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $ProofPath $true)).Path
$oracleProof = Read-Issue13V5Json $oracleProofPath
if ([string]$oracleProof.schema -cne
      'wlv-issue13-v5-oracle-effect-proof/2' -or
    [string]$oracleProof.status -cne 'passed' -or
    -not (Test-Issue13V5ExactBoolean $oracleProof.passed $true)) {
  throw 'Oracle-effect proof is not the required passed terminal proof.'
}
$oraclePrimaryRoot = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $ComparisonRoot $true)).Path
$oracleReplayRoot = (Resolve-Path -LiteralPath (
  ConvertTo-Issue13V5FullPath $ReplayRoot $true)).Path
if (-not (Test-Path -LiteralPath $oraclePrimaryRoot -PathType Container) -or
    -not (Test-Path -LiteralPath $oracleReplayRoot -PathType Container)) {
  throw 'Oracle-effect ComparisonRoot and ReplayRoot must be existing directories.'
}
Assert-Issue13V5PathsDisjoint $oraclePrimaryRoot $oracleReplayRoot 'Oracle-effect primary/replay isolation'
foreach ($outputRoot in @($oraclePrimaryRoot, $oracleReplayRoot)) {
  Assert-Issue13V5NoReparse $outputRoot
  foreach ($protectedRoot in @(
      $repository, $harnessRuntime, $library,
      (Split-Path -Parent $strictSmokePath),
      (Split-Path -Parent $oracleEffectSmokePath))) {
    Assert-Issue13V5NoReparseAncestors $protectedRoot `
      'Oracle-effect protected root'
    Assert-Issue13V5PathsDisjoint $outputRoot $protectedRoot `
      'Oracle-effect output/protected-root isolation'
  }
}
$oraclePrimaryInventory = Get-Issue13V5TreeInventory $oraclePrimaryRoot
$oracleReplayInventory = Get-Issue13V5TreeInventory $oracleReplayRoot
$oracleComparisonPairPayload = [string]::Join("`n", @(
  'wlv-issue13-v5-oracle-effect-comparison-pair-inventory/1',
  'primary|' + (ConvertTo-Issue13V5Path $oraclePrimaryRoot) + '|' +
    [string]$oraclePrimaryInventory.inventory_sha256,
  'replay|' + (ConvertTo-Issue13V5Path $oracleReplayRoot) + '|' +
    [string]$oracleReplayInventory.inventory_sha256
))
$oracleComparisonPairInventory = [ordered]@{
  schema = 'wlv-issue13-v5-oracle-effect-comparison-pair-inventory/1'
  primary_inventory_sha256 =
    [string]$oraclePrimaryInventory.inventory_sha256
  replay_inventory_sha256 =
    [string]$oracleReplayInventory.inventory_sha256
  inventory_sha256 = Get-Issue13V5TextSha256 $oracleComparisonPairPayload
}
$oracleTooling = @(Get-Issue13V5OracleEffectToolRecords)
$oracleEffect = [ordered]@{
  schema = 'wlv-issue13-v5-oracle-effect-binding/2'
  status = 'passed'
  passed = $true
  final_evidence_eligible = $false
  required_by_final_gate = $true
  strict_common_method_count = 5
  comparison_execution_count = 10
  approved_run_inventory_count = 17
  recovered_method_count = 7
  oracle_effect_closed = $true
  final_v5_gate_substituted = $false
  authorized_patch_sha256 = $expectedOverlaySha256
  authorized_patch_id = $expectedOverlayPatchId
  oracle_smoke = [ordered]@{
    path = $oracleEffectSmokePath
    sha256 = Get-Issue13V5NewConfigSha256 $oracleEffectSmokePath
    final_evidence_eligible = $false
  }
  proof = [ordered]@{
    path = $oracleProofPath
    sha256 = Get-Issue13V5NewConfigSha256 $oracleProofPath
    schema = 'wlv-issue13-v5-oracle-effect-proof/2'
  }
  comparisons = [ordered]@{
    primary = [ordered]@{
      root = $oraclePrimaryRoot
      inventory = $oraclePrimaryInventory
    }
    replay = [ordered]@{
      root = $oracleReplayRoot
      inventory = $oracleReplayInventory
    }
    inventory = $oracleComparisonPairInventory
  }
  comparison_harness = [ordered]@{
    expected_candidate_commit = $CandidateCommit
    manifest_path = $harnessManifestPath
    manifest_sha256 = Get-Issue13V5NewConfigSha256 $harnessManifestPath
    generation = 'v5-terminal'
    final_evidence_eligible = $true
    reuses_candidate_evidence = $false
    source_controller_commit_sha256 =
      [string]$harnessManifest.source_controller.commit_sha256
    source_controller = $oracleProof.evidence.terminal_runtime.
      comparison_harness.source_controller
    source_tooling = $sourceTooling
    output_tooling = [ordered]@{
      file_count = [long]$harnessManifest.output_tooling.file_count
      total_bytes = [long]$harnessManifest.output_tooling.total_bytes
      inventory_sha256 = [string]$harnessManifest.output_tooling.inventory_sha256
    }
    sealed_output_tooling = [ordered]@{
      file_count = [long]$harnessManifest.sealed_output_tooling.file_count
      total_bytes = [long]$harnessManifest.sealed_output_tooling.total_bytes
      inventory_sha256 =
        [string]$harnessManifest.sealed_output_tooling.inventory_sha256
    }
    installed_inventory = [ordered]@{
      root = $harnessRuntime
      harness_root = $harness
      file_count = [long]$harnessInventory.file_count
      total_bytes = [long]$harnessInventory.total_bytes
      inventory_sha256 = [string]$harnessInventory.inventory_sha256
    }
  }
  r_library = $oracleProof.evidence.terminal_runtime.r_library
  tooling = [object[]]$oracleTooling
}
$oracleValidationConfig = [pscustomobject]@{
  repository_root = $repository
  candidate_commit = $CandidateCommit
  baseline_commit = $baselineCommit
  baseline_runtime_commit = $BaselineRuntimeCommit
  harness_runtime_root = $harnessRuntime
  harness_manifest_path = $harnessManifestPath
  harness_manifest_sha256 =
    Get-Issue13V5NewConfigSha256 $harnessManifestPath
  rscript = $rscriptFull
  r_library = $library
  strict_baseline_smoke = $strictSmokeBinding
  compatibility_baseline_smoke = [pscustomobject]@{
    path = $compatibilitySmokePath
  }
  baseline_overlay = [pscustomobject]@{
    path = $overlayPatch
    sha256 = Get-Issue13V5NewConfigSha256 $overlayPatch
  }
  oracle_effect = [pscustomobject]$oracleEffect
}
$oracleInitialValidation = Invoke-Issue13V5OracleEffectValidation `
  $oracleValidationConfig
$oracleEffect['initial_validation'] = $oracleInitialValidation
$outputFull = ConvertTo-Issue13V5FullPath $Output $false
$null = ConvertTo-Issue13V5PhysicalPath $outputFull 'V5 config output'
Assert-Issue13V5NoReparseAncestors $outputFull 'V5 config output'
if (Test-Path -LiteralPath $outputFull) {
  throw "Refusing to overwrite the V5 gate config: $outputFull"
}
$configImmutableRoots = @(
  $repository, $harnessRuntime, $source, $candidateSource, $library,
  $rscriptFull, $oraclePrimaryRoot, $oracleReplayRoot
)
$null = Assert-Issue13V5ConfigPathIsolation `
  $outputFull $configImmutableRoots
$worktrees = Assert-Issue13V5FreshRoot $WorktreeRoot 'Worktree root'
$evidence = Assert-Issue13V5FreshRoot $EvidenceRoot 'Evidence root'
$control = Assert-Issue13V5FreshRoot $ControlRoot 'Control root'
$outputRoots = @($worktrees, $evidence, $control)
for ($left = 0; $left -lt $outputRoots.Count; $left++) {
  for ($right = $left + 1; $right -lt $outputRoots.Count; $right++) {
    Assert-Issue13V5PathsDisjoint $outputRoots[$left] $outputRoots[$right] 'Worktree/evidence/control isolation'
  }
}
foreach ($rootPath in $outputRoots) {
  Assert-Issue13V5PathsDisjoint $outputFull $rootPath 'V5 config/output-root isolation'
  foreach ($oracleRoot in @($oraclePrimaryRoot, $oracleReplayRoot)) {
    Assert-Issue13V5PathsDisjoint $rootPath $oracleRoot 'V5 output/oracle-comparison isolation'
  }
  foreach ($protectedRoot in @(
      $repository, $harnessRuntime, $source, $candidateSource, $library,
      $rscriptFull)) {
    Assert-Issue13V5PathsDisjoint $rootPath $protectedRoot 'V5 output/immutable-root isolation'
  }
}
foreach ($oracleRoot in @($oraclePrimaryRoot, $oracleReplayRoot)) {
  Assert-Issue13V5PathsDisjoint $outputFull $oracleRoot 'V5 config/oracle-comparison isolation'
}

$sciencePhases = [Collections.Generic.List[object]]::new()
foreach ($method in $methods) {
  $sciencePhases.Add([ordered]@{
    phase = "calculate/$method/workers1"
    kind = 'calculate'
    method = $method
    workers = 1
    stage = $null
    variant = $null
    sea_vars = @()
  })
  foreach ($recalculation in $recalculations) {
    $sciencePhases.Add([ordered]@{
      phase = "recalculate/$method/stage$($recalculation.stage)/" +
        [string]$recalculation.variant
      kind = 'recalculate'
      method = $method
      workers = 1
      stage = [int]$recalculation.stage
      variant = [string]$recalculation.variant
      sea_vars = @($recalculation.sea_vars)
    })
  }
}
foreach ($method in @('wiodr13', 'wiodr16')) {
  $sciencePhases.Add([ordered]@{
    phase = "calculate/$method/workers2"
    kind = 'calculate'
    method = $method
    workers = 2
    stage = $null
    variant = $null
    sea_vars = @()
  })
}
if ($sciencePhases.Count -ne 74) {
  throw 'The internal V5 science matrix is not exactly 74 phases.'
}

$methodRoots = @($methods | ForEach-Object {
  [ordered]@{
    method = $_
    baseline = Join-Path $worktrees ('baseline-' + $_)
    candidate = Join-Path $worktrees ('candidate-' + $_)
    baseline_runtime_commit = $BaselineRuntimeCommit
    candidate_runtime_commit = $CandidateCommit
    baseline_seed_commit = $BaselineRuntimeCommit
    candidate_seed_commit = $CandidateCommit
  }
})

$sourceContractBindings = @(
  [ordered]@{
    arm = 'baseline'; source = 'wiodr13'
    runtime_commit = $BaselineRuntimeCommit
    manifest_relative_path = 'wiodr13/normalized/_source_manifest.csv'
    manifest_sha256 =
      'cd3ee98c7b823b1efa9b1272dca660a3977cc4a185b033263c2bef09cc1f73a8'
    source_generation_id =
      '65691585592c9cb6dc628c46606f004113f808e5b74c511c89678fae32032e2d'
    contract_id = 'wiodr13_units_v2'; contract_version = '2'
    contract_sha256 =
      'f7e04664e357d6a334685e48eced6428dfdd410f5b9811785a0ad0f696cc65eb'
    units_relative_path = 'contracts/units/wiodr13_v2-units.csv'
    units_sha256 =
      'ff1ab869e72d18879dc2e69c61c911425d73b612870c06317047accf9520ff11'
    units_git_blob = 'c89f1ca1e463d05a0b0ec683bee16084d39f4ac3'
    aggregations_relative_path =
      'contracts/units/wiodr13_v2-aggregations.csv'
    aggregations_sha256 =
      'e830708911f5b6674f44e51e8625de9a072ccf5cd91395954e1040f81372004a'
    aggregations_git_blob = '4d98444799af4c715f07a3b8a0ea4c1c1570a87c'
  },
  [ordered]@{
    arm = 'baseline'; source = 'wiodr16'
    runtime_commit = $BaselineRuntimeCommit
    manifest_relative_path = 'wiodr16/normalized/_source_manifest.csv'
    manifest_sha256 =
      '091183d74d97f5bc22209e57be0314c5ea5e510ae3573eaf2b342237de903aa9'
    source_generation_id =
      'f135fddb4723ba3cdf29164cf1b7ec006693cc201feaf2063f91fa104e942a7a'
    contract_id = 'wiodr16_units_v2'; contract_version = '2'
    contract_sha256 =
      '94b9f78e8977001fab92e8fa8528aea5b97a3f22809bec58a16a56f413a6acf7'
    units_relative_path = 'contracts/units/wiodr16_v2-units.csv'
    units_sha256 =
      'dfd73aa1e7721a139b04345c1e9fc48dc0a0a875659b8385a73292b2fba90143'
    units_git_blob = 'fcf432fd4ddc6fd54acf88ef809e241b5e3f0cf7'
    aggregations_relative_path =
      'contracts/units/wiodr16_v2-aggregations.csv'
    aggregations_sha256 =
      'bbee477efe375ffee47dc69ad86d9176d3e57d4292461d86423bbe68a9cbc642'
    aggregations_git_blob = '339de049570be34158a5599de05d1eea4175cacd'
  },
  [ordered]@{
    arm = 'candidate'; source = 'wiodr13'
    runtime_commit = $CandidateCommit
    manifest_relative_path = 'wiodr13/normalized/_source_manifest.csv'
    manifest_sha256 =
      'b454f0f05890374cebde8b1b3222da4b4b63b887f67283fe12c97a351adc0bb8'
    source_generation_id =
      'b16a64edd8f3cdf117002fda011e1ba19f17e3fa72936671bb98dffeb0207856'
    contract_id = 'wiodr13_units_v2'; contract_version = '2'
    contract_sha256 =
      '1f2462835e70d5681d7a5b9b29be5f0598cdb35a9abd72d3d147a6636ae5c905'
    units_relative_path = 'contracts/units/wiodr13_v2-units.csv'
    units_sha256 =
      'ff1ab869e72d18879dc2e69c61c911425d73b612870c06317047accf9520ff11'
    units_git_blob = 'c89f1ca1e463d05a0b0ec683bee16084d39f4ac3'
    aggregations_relative_path =
      'contracts/units/wiodr13_v2-aggregations.csv'
    aggregations_sha256 =
      'c5c9779772101380514b6dbb937de48036280e66df382f2eb84f122ec91384d3'
    aggregations_git_blob = '20fbc53bb31261b0a698ae6ac56b0344772e1e6a'
  },
  [ordered]@{
    arm = 'candidate'; source = 'wiodr16'
    runtime_commit = $CandidateCommit
    manifest_relative_path = 'wiodr16/normalized/_source_manifest.csv'
    manifest_sha256 =
      '28dc13d3abb9856fb984b01eb60379e213e6e0cfae58e8fb08c3b882c19c1a35'
    source_generation_id =
      '1f747ab8d53abe8cc674b0842796a5c9b936b036a79b48715b9e04734f949976'
    contract_id = 'wiodr16_units_v2'; contract_version = '2'
    contract_sha256 =
      '3b23ab671df4905dee50b35efd8dff8d4897f65f2b74a2677d7614d9137e801a'
    units_relative_path = 'contracts/units/wiodr16_v2-units.csv'
    units_sha256 =
      'dfd73aa1e7721a139b04345c1e9fc48dc0a0a875659b8385a73292b2fba90143'
    units_git_blob = 'fcf432fd4ddc6fd54acf88ef809e241b5e3f0cf7'
    aggregations_relative_path =
      'contracts/units/wiodr16_v2-aggregations.csv'
    aggregations_sha256 =
      '227c32c390e019a8ccb231db1bca898667bc31d75b599beda083799fa9d27278'
    aggregations_git_blob = '516f2dc29ed594df42605811a18af49bc9328d71'
  }
)

$config = [ordered]@{
  schema = 'wlv-issue13-native-gate-config/3'
  generation = 'v5'
  created_at_utc = [DateTime]::UtcNow.ToString('o')
  final_evidence_eligible = $true
  reuse_policy = [ordered]@{
    v4_evidence_allowed = $false
    candidate_evidence_reuse_allowed = $false
    imported_scenario_evidence_allowed = $false
    fresh_roots_required = $true
  }
  repository_root = $repository
  harness_runtime_root = $harnessRuntime
  harness_root = $harness
  harness_manifest_path = $harnessManifestPath
  harness_manifest_sha256 =
    Get-Issue13V5NewConfigSha256 $harnessManifestPath
  worktree_root = $worktrees
  evidence_root = $evidence
  control_root = $control
  source_origin = $source
  source_inventory = [ordered]@{
    file_count = 84
    directory_count = 5
    total_bytes = 2946498269L
    inventory_sha256 =
      'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26'
    directory_list_sha256 =
      '8b3a622a748f2489fe8cfd2a8273ec98ad4c372b2378d587a5ee2e3c5c916640'
  }
  candidate_source_origin = $candidateSource
  candidate_source_inventory = [ordered]@{
    file_count = 76
    directory_count = 6
    total_bytes = 2035522216L
    inventory_sha256 =
      '22e90e9485d7cee19d1de786c3464106d9a857ad3d85d0c9f2b3d912a0f38026'
    directory_list_sha256 =
      'c75aa417f14cded3c3bb6028effc8acadd64a32e86fddc0f1278079acdb6f114'
  }
  source_contract_bindings = [object[]]$sourceContractBindings
  rscript = $rscriptFull
  r_library = $library
  baseline_commit = $baselineCommit
  baseline_base_commit = $baselineCommit
  baseline_runtime_commit = $BaselineRuntimeCommit
  baseline_profile = $baselineProfile
  baseline_overlay = [ordered]@{
    path = $overlayPatch
    sha256 = Get-Issue13V5NewConfigSha256 $overlayPatch
    patch_id = [string]$index.profiles[0].overlay_patch_id
  }
  strict_baseline_smoke = $strictSmokeBinding
  compatibility_baseline_smoke = [ordered]@{
    path = $compatibilitySmokePath
    sha256 = Get-Issue13V5NewConfigSha256 $compatibilitySmokePath
    passed_count = 12
    failed_count = 0
    final_evidence_eligible = $false
  }
  oracle_effect = $oracleEffect
  candidate_commit = $CandidateCommit
  candidate_seed_commit = $CandidateCommit
  baseline_runtime_index = $runtimeIndex
  baseline_runtime_index_sha256 = Get-Issue13V5NewConfigSha256 $runtimeIndex
  methods = $methodRoots
  supplemental_roots = [ordered]@{
    baseline_preparation = Join-Path $worktrees 'baseline-preparation'
    candidate_preparation = Join-Path $worktrees 'candidate-preparation'
    baseline_paper0 = Join-Path $worktrees 'baseline-paper0'
    candidate_paper0 = Join-Path $worktrees 'candidate-paper0'
    candidate_fault = Join-Path $worktrees 'candidate-fault'
  }
  matrix = [ordered]@{
    method_count = 12
    science_phase_count = 74
    paired_phase_count = 76
    monitored_scenario_count = 162
    authenticated_comparison_count = 202
    fault_count = 10
    science_phases = $sciencePhases.ToArray()
    supplemental_phases = @('prepare/all', 'paper/0')
    faults = $faults
  }
  comparison = [ordered]@{
    numerical_tolerance = 'contract-only-no-new-tolerance'
    compare_dimensions = $true
    compare_dimnames = $true
    compare_finite_values = $true
    distinguish_na_nan_posinf_neginf = $true
    compare_semantic_states = $true
    compare_metadata_and_contracts = $true
    compare_method_matrices = $true
    compare_diagnostics_as_duplicate_preserving_multisets = $true
    compare_unselected_cells = $true
    ignore_only = @('timestamps', 'paths', 'run_id', 'result_id',
      'provenance-dependent-container-bytes')
    candidate_only_artifacts = @(
      '_nonfinite_resolution_diagnostics.csv',
      '_runtime_resources.rds'
    )
    preparation_equivalence_profile = $preparationEquivalenceBinding
  }
  performance = [ordered]@{
    candidate_time_ratio_maximum = 1.2
    candidate_rss_baseline_ratio_allowance = 0.1
    candidate_rss_minimum_allowance_bytes = 536870912L
    workers2_methods = @('wiodr13', 'wiodr16')
    require_cluster_closed = $true
    rss_worker_lifecycle_scope = 'authenticated-root-and-observed-descendants'
    elapsed_scope =
      'monitor-wall-clock-from-prelaunch-through-observed-tree-quiescence'
    allow_unrelated_r_processes = $true
    external_load_policy = 'minimum-free-physical-memory-no-cpu-exclusivity'
  }
  preparation = [ordered]@{
    sources = @('wiodr13', 'wiodr16', 'euklems')
    same_official_cache_inventory = $true
    bitwise_arrays = $true
    require_atomic_promotion = $true
  }
  paper0 = [ordered]@{
    methods = @('ochoa_1', 'ochoa_2')
    workbook_semantic_comparison = $true
    unsupported_papers = @(3, 4)
  }
  report = [ordered]@{
    required_path = 'docs/validation/issue-13.md'
    required_fields = @(
      'baseline_commit', 'baseline_base_commit', 'baseline_runtime_commit',
      'strict_baseline_smoke', 'compatibility_baseline_smoke',
      'baseline_overlay_patch', 'oracle_effect_proof', 'candidate_commit',
      'source_ids', 'commands',
      'hashes', 'times', 'peak_rss', 'differences', 'fault_results',
      'preparation_results', 'paper0_results'
    )
  }
}

$outputParent = Split-Path -Parent $outputFull
if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
  $null = New-Item -ItemType Directory -Path $outputParent
}
$outputParent = (Resolve-Path -LiteralPath $outputParent).Path
$finalOutputFull = Join-Path $outputParent ([IO.Path]::GetFileName($outputFull))
if (-not [string]::Equals(
    $finalOutputFull, $outputFull, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Resolved V5 config output changed its canonical path.'
}
$null = ConvertTo-Issue13V5PhysicalPath `
  $finalOutputFull 'Resolved V5 config output'
Assert-Issue13V5NoReparseAncestors `
  $finalOutputFull 'Resolved V5 config output'
$null = Assert-Issue13V5ConfigPathIsolation `
  $finalOutputFull $configImmutableRoots
$temporary = Join-Path $outputParent (
  '.' + [IO.Path]::GetFileName($finalOutputFull) + '-' +
    [Guid]::NewGuid().ToString('N') + '.tmp'
)
$payload = ($config | ConvertTo-Json -Depth 100) + "`n"
[IO.File]::WriteAllText($temporary, $payload, $utf8)
$roundtripText = [IO.File]::ReadAllText($temporary, $utf8)
if (-not [string]::Equals($roundtripText, $payload,
    [StringComparison]::Ordinal)) {
  throw 'V5 config UTF-8 round trip failed.'
}
$roundtrip = $roundtripText | ConvertFrom-Json -DateKind String
if ([string]$roundtrip.generation -cne 'v5' -or
    [string]$roundtrip.baseline_commit -cne $baselineCommit -or
    [string]$roundtrip.baseline_runtime_commit -cne $BaselineRuntimeCommit -or
    @($roundtrip.matrix.science_phases).Count -ne 74 -or
    [string]$roundtrip.oracle_effect.proof.sha256 -cne
      (Get-Issue13V5NewConfigSha256 $oracleProofPath) -or
    [string]$roundtrip.oracle_effect.comparisons.primary.inventory.
      inventory_sha256 -cne
      [string]$oraclePrimaryInventory.inventory_sha256 -or
    [string]$roundtrip.oracle_effect.comparisons.replay.inventory.
      inventory_sha256 -cne
      [string]$oracleReplayInventory.inventory_sha256 -or
    [string]$roundtrip.oracle_effect.comparisons.inventory.inventory_sha256 `
      -cne [string]$oracleComparisonPairInventory.inventory_sha256 -or
    [string]$roundtrip.oracle_effect.comparison_harness.source_controller.
      inventory_sha256 -cne
      [string]$oracleEffect.comparison_harness.source_controller.
        inventory_sha256 -or
    ($roundtrip.oracle_effect.comparison_harness.source_tooling |
      ConvertTo-Json -Depth 30 -Compress) -cne
      ($sourceTooling | ConvertTo-Json -Depth 30 -Compress) -or
    [string]$roundtrip.oracle_effect.r_library.inventory_sha256 -cne
      [string]$oracleEffect.r_library.inventory_sha256 -or
    [long]$roundtrip.oracle_effect.comparison_execution_count -ne 10L -or
    [long]$roundtrip.oracle_effect.approved_run_inventory_count -ne 17L -or
    -not (Test-Issue13V5ExactBoolean `
      $roundtrip.oracle_effect.final_evidence_eligible $false) -or
    -not (Test-Issue13V5ExactBoolean `
      $roundtrip.oracle_effect.required_by_final_gate $true)) {
  throw 'V5 config JSON round trip changed the contract.'
}
$null = ConvertTo-Issue13V5PhysicalPath `
  $finalOutputFull 'Final V5 config output'
Assert-Issue13V5NoReparseAncestors `
  $finalOutputFull 'Final V5 config output'
$null = Assert-Issue13V5ConfigPathIsolation `
  $finalOutputFull $configImmutableRoots
if (Test-Path -LiteralPath $finalOutputFull) {
  throw 'The V5 config target appeared during generation.'
}
Move-Item -LiteralPath $temporary -Destination $finalOutputFull
$installed = [IO.File]::ReadAllText($finalOutputFull, $utf8)
if (-not [string]::Equals($installed, $payload, [StringComparison]::Ordinal)) {
  throw 'Installed V5 config differs from its verified UTF-8 payload.'
}

[pscustomobject][ordered]@{
  status = 'created'
  config_path = (Resolve-Path -LiteralPath $finalOutputFull).Path
  config_sha256 = Get-Issue13V5NewConfigSha256 $finalOutputFull
  baseline_commit = $baselineCommit
  baseline_runtime_commit = $BaselineRuntimeCommit
  candidate_commit = $CandidateCommit
  paired_phases = 76
  scenarios = 162
  comparisons = 202
  faults = 10
  oracle_effect_proof_sha256 = Get-Issue13V5NewConfigSha256 $oracleProofPath
  oracle_effect_smoke_sha256 =
    Get-Issue13V5NewConfigSha256 $oracleEffectSmokePath
  oracle_effect_primary_inventory_sha256 =
    [string]$oraclePrimaryInventory.inventory_sha256
  oracle_effect_replay_inventory_sha256 =
    [string]$oracleReplayInventory.inventory_sha256
  oracle_effect_comparison_pair_inventory_sha256 =
    [string]$oracleComparisonPairInventory.inventory_sha256
  oracle_effect_strict_common_methods = 5
  oracle_effect_comparison_executions = 10
  oracle_effect_approved_run_inventories = 17
  oracle_effect_recovered_methods = 7
}
