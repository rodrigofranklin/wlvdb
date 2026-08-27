param(
  [Parameter(Mandatory = $true)][string]$ConfigPath,
  [Parameter(Mandatory = $true)][string]$StatePath,
  [Parameter(Mandatory = $true)][string]$Output,
  [switch]$ConfirmWriteAttestation
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
$script:Issue13V5DeliveryAttesterInvocationPath =
  (Resolve-Path -LiteralPath $PSCommandPath).Path
$scriptRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path

$script:Issue13V5DeliveryReportPath = 'docs/validation/issue-13.md'
$script:Issue13V5DeliveryAttesterPath =
  'run_logs/issue13-native-gate-orchestrator-v5/' +
    'issue13-v5-attest-delivery.ps1'

function Invoke-Issue13V5DeliveryGit(
  [string]$Repository,
  [string[]]$Arguments
) {
  $output = @(Invoke-Issue13V5SealedGit `
    -C $Repository @Arguments 2>$null)
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw ('Git command failed (' + $exitCode + '): git -C ' +
      $Repository + ' ' + ($Arguments -join ' '))
  }
  [string[]]@($output | ForEach-Object { [string]$_ })
}

function Get-Issue13V5DeliveryGitScalar(
  [string]$Repository,
  [string[]]$Arguments,
  [string]$Label
) {
  $lines = @(Invoke-Issue13V5DeliveryGit $Repository $Arguments)
  if ($lines.Count -ne 1 -or [string]::IsNullOrWhiteSpace($lines[0])) {
    throw "Git did not return exactly one $Label."
  }
  $lines[0].Trim()
}

function Get-Issue13V5DeliveryBlobBytes(
  [string]$Repository,
  [string]$Blob
) {
  if ($Blob -cnotmatch '^[0-9a-f]{40}$') {
    throw "Invalid Git blob identifier: $Blob"
  }
  $raw = Invoke-Issue13V5GitRaw $Repository @(
    'cat-file', 'blob', $Blob)
  [byte[]]$raw.stdout
}

function Get-Issue13V5DeliveryByteSha256([byte[]]$Bytes) {
  [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($Bytes)
  ).ToLowerInvariant()
}

function Resolve-Issue13V5DeliveryOutput(
  [string]$Path,
  [string[]]$ProtectedRoots
) {
  $full = ConvertTo-Issue13V5Path $Path
  if ([IO.Path]::GetExtension($full) -cne '.json') {
    throw 'Delivery attestation output must be a JSON file.'
  }
  if (Test-Path -LiteralPath $full) {
    throw "Refusing to overwrite immutable delivery attestation: $full"
  }
  $parent = Split-Path -Parent $full
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    throw 'Delivery attestation parent directory must already exist.'
  }
  $resolvedParent = (Resolve-Path -LiteralPath $parent).Path
  Assert-Issue13V5NoReparseAncestors `
    $resolvedParent 'Delivery attestation parent'
  $null = ConvertTo-Issue13V5PhysicalPath `
    $resolvedParent 'Delivery attestation parent'
  $resolved = Join-Path $resolvedParent ([IO.Path]::GetFileName($full))
  if ($ProtectedRoots.Count -eq 0) {
    throw 'Delivery attestation protected roots are empty.'
  }
  foreach ($protectedRoot in $ProtectedRoots) {
    if ([string]::IsNullOrWhiteSpace($protectedRoot)) {
      throw 'Delivery attestation contains an empty protected root.'
    }
    Assert-Issue13V5NoReparseAncestors `
      $protectedRoot 'Delivery attestation protected root'
    $null = ConvertTo-Issue13V5PhysicalPath `
      $protectedRoot 'Delivery attestation protected root'
    Assert-Issue13V5PathsDisjoint $resolved $protectedRoot `
      'Delivery attestation/protected-root isolation'
  }
  $resolved
}

function Get-Issue13V5DeliverySnapshot(
  [string]$Repository,
  [string]$CandidateCommit,
  [string]$ReportRelativePath,
  [string]$ExpectedReportSha256
) {
  $repositoryPath = (Resolve-Path -LiteralPath $Repository).Path
  $topLevel = Get-Issue13V5DeliveryGitScalar $repositoryPath `
    @('rev-parse', '--show-toplevel') 'repository root'
  if (-not [string]::Equals(
      (ConvertTo-Issue13V5Path $topLevel),
      (ConvertTo-Issue13V5Path $repositoryPath),
      [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Configured repository root is not the Git top level.'
  }
  if ($CandidateCommit -cnotmatch '^[0-9a-f]{40}$') {
    throw 'Validated candidate commit is not a full lowercase Git SHA-1.'
  }
  if ($ReportRelativePath -cne $script:Issue13V5DeliveryReportPath) {
    throw 'Delivery report path is not the required issue #13 path.'
  }
  if ($ExpectedReportSha256 -cnotmatch '^[0-9a-f]{64}$') {
    throw 'Validated report SHA-256 is invalid.'
  }

  $head = Get-Issue13V5DeliveryGitScalar $repositoryPath `
    @('rev-parse', 'HEAD') 'delivery HEAD'
  if ($head -cnotmatch '^[0-9a-f]{40}$' -or
      $head -ceq $CandidateCommit) {
    throw 'Delivery HEAD is invalid or still equals the candidate commit.'
  }
  $parentLine = Get-Issue13V5DeliveryGitScalar $repositoryPath `
    @('rev-list', '--parents', '-n', '1', $head) 'delivery ancestry record'
  $parentFields = @($parentLine.Split(
      [char]' ', [StringSplitOptions]::RemoveEmptyEntries))
  if ($parentFields.Count -ne 2 -or $parentFields[0] -cne $head -or
      $parentFields[1] -cne $CandidateCommit) {
    throw 'Delivery HEAD must have exactly one parent: the validated candidate.'
  }

  $diff = @(Invoke-Issue13V5DeliveryGit $repositoryPath @(
      'diff', '--name-status', '--no-renames',
      $CandidateCommit, $head, '--'))
  $expectedDiff = "A`t$ReportRelativePath"
  if ($diff.Count -ne 1 -or $diff[0] -cne $expectedDiff) {
    throw ('Delivery diff must add exactly ' + $ReportRelativePath + '.')
  }

  $trackedStatus = @(Invoke-Issue13V5DeliveryGit $repositoryPath @(
      'status', '--porcelain=v1', '--untracked-files=no',
      '--ignore-submodules=none'))
  if ($trackedStatus.Count -ne 0) {
    throw 'Delivery repository has tracked changes.'
  }

  $reportPath = ConvertTo-Issue13V5Path (
    Join-Path $repositoryPath $ReportRelativePath)
  if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
    throw 'Committed delivery report is absent from the working tree.'
  }
  $utf8 = [Text.UTF8Encoding]::new($false, $true)
  $reportText = [IO.File]::ReadAllText($reportPath, $utf8)
  if ($reportText.Contains([char]0xFFFD)) {
    throw 'Delivery report contains a UTF-8 replacement character.'
  }
  $workingSha256 = Get-Issue13V5Sha256 $reportPath
  if ($workingSha256 -cne $ExpectedReportSha256) {
    throw 'Working report SHA-256 differs from the validated state.'
  }

  $objectSpec = $head + ':' + $ReportRelativePath
  $blob = Get-Issue13V5DeliveryGitScalar $repositoryPath `
    @('rev-parse', $objectSpec) 'report blob'
  $blobType = Get-Issue13V5DeliveryGitScalar $repositoryPath `
    @('cat-file', '-t', $blob) 'report object type'
  $workingBlob = Get-Issue13V5DeliveryGitScalar $repositoryPath `
    @('hash-object', '--no-filters', '--', $reportPath) `
    'working report blob'
  if ($blob -cnotmatch '^[0-9a-f]{40}$' -or $blobType -cne 'blob' -or
      $workingBlob -cne $blob) {
    throw 'Committed report blob is not byte-identical to the working report.'
  }
  $blobBytes = Get-Issue13V5DeliveryBlobBytes $repositoryPath $blob
  $blobSha256 = Get-Issue13V5DeliveryByteSha256 $blobBytes
  if ($blobSha256 -cne $ExpectedReportSha256) {
    throw 'Committed report blob SHA-256 differs from the validated state.'
  }
  $fileSize = (Get-Item -LiteralPath $reportPath).Length
  if ([long]$blobBytes.LongLength -ne [long]$fileSize) {
    throw 'Committed report blob size differs from the working report.'
  }

  [pscustomobject][ordered]@{
    validated_code_commit = $CandidateCommit
    delivery_commit = $head
    delivery_parent = $parentFields[1]
    delivery_parent_count = 1L
    validated_code_tree = Get-Issue13V5DeliveryGitScalar $repositoryPath `
      @('rev-parse', ($CandidateCommit + '^{tree}')) 'candidate tree'
    delivery_tree = Get-Issue13V5DeliveryGitScalar $repositoryPath `
      @('rev-parse', ($head + '^{tree}')) 'delivery tree'
    diff_status = 'A'
    diff_path = $ReportRelativePath
    diff_path_count = 1L
    tracked_tree_clean = $true
    report_path = $reportPath
    report_sha256 = $workingSha256
    report_git_blob = $blob
    report_git_blob_sha256 = $blobSha256
    report_size_bytes = [long]$fileSize
  }
}

function Assert-Issue13V5DeliverySnapshotEqual(
  [object]$Expected,
  [object]$Actual
) {
  foreach ($field in @(
      'validated_code_commit', 'delivery_commit', 'delivery_parent',
      'delivery_parent_count', 'validated_code_tree', 'delivery_tree',
      'diff_status', 'diff_path', 'diff_path_count', 'tracked_tree_clean',
      'report_path', 'report_sha256', 'report_git_blob',
      'report_git_blob_sha256', 'report_size_bytes')) {
    if ([string]$Expected.$field -cne [string]$Actual.$field) {
      throw "Delivery snapshot changed before attestation: $field"
    }
  }
  $true
}

function Assert-Issue13V5DeliveryAttesterBinding(
  [string]$Repository,
  [string]$CandidateCommit,
  [string]$DeliveryCommit
) {
  $expectedPath = ConvertTo-Issue13V5Path (
    Join-Path $Repository $script:Issue13V5DeliveryAttesterPath)
  $actualPath = ConvertTo-Issue13V5Path (
    $script:Issue13V5DeliveryAttesterInvocationPath)
  if (-not [string]::Equals($actualPath, $expectedPath,
      [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Delivery attester is not running from its canonical repository path.'
  }
  $workingBlob = Get-Issue13V5DeliveryGitScalar $Repository `
    @('hash-object', '--no-filters', '--', $actualPath) 'attester blob'
  $candidateBlob = Get-Issue13V5DeliveryGitScalar $Repository `
    @('rev-parse', ($CandidateCommit + ':' +
        $script:Issue13V5DeliveryAttesterPath)) 'candidate attester blob'
  $deliveryBlob = Get-Issue13V5DeliveryGitScalar $Repository `
    @('rev-parse', ($DeliveryCommit + ':' +
        $script:Issue13V5DeliveryAttesterPath)) 'delivery attester blob'
  if ($workingBlob -cne $candidateBlob -or $deliveryBlob -cne $candidateBlob) {
    throw 'Delivery attester differs from the validated candidate version.'
  }
  [pscustomobject][ordered]@{
    relative_path = $script:Issue13V5DeliveryAttesterPath
    sha256 = Get-Issue13V5Sha256 $actualPath
    git_blob = $candidateBlob
  }
}

function Invoke-Issue13V5DeliveryAttestation(
  [string]$ConfigPath,
  [string]$StatePath,
  [string]$Output,
  [switch]$ConfirmWriteAttestation
) {
  if (-not $ConfirmWriteAttestation) {
    throw 'Delivery attestation requires -ConfirmWriteAttestation.'
  }
  $binding = Assert-Issue13V5Config $ConfigPath
  $config = $binding.config
  if ([string]$config.report.required_path -cne
      $script:Issue13V5DeliveryReportPath) {
    throw 'Configured report path is not the required issue #13 path.'
  }
  $expectedStatePath = ConvertTo-Issue13V5Path (
    Get-Issue13V5StatePath $config)
  $providedStatePath = ConvertTo-Issue13V5Path (
    (Resolve-Path -LiteralPath $StatePath).Path)
  if (-not [string]::Equals($providedStatePath, $expectedStatePath,
      [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Delivery state path is not the canonical control-root gate-state.json.'
  }
  $state = Read-Issue13V5State $config $binding.sha256
  if ([string]$state.status -cne 'complete' -or
      [string]$state.final_aggregate.status -cne 'passed' -or
      [string]$state.prep_fault.aggregate_status -cne 'passed' -or
      @($state.phases | Where-Object comparison_status -cne 'completed').Count `
        -ne 0 -or
      @($state.prep_fault.faults | Where-Object status -cne 'executed').Count `
        -ne 0 -or
      [string]$state.report.status -cne 'written') {
    throw 'Delivery attestation requires the complete passed V5 state.'
  }
  $null = Assert-Issue13V5FinalBindings $config $state

  $repository = (Resolve-Path -LiteralPath $config.repository_root).Path
  $deliveryProtectedRoots = @(
    [string]$config.repository_root,
    [string]$config.worktree_root,
    [string]$config.evidence_root,
    [string]$config.control_root,
    [string]$config.harness_runtime_root,
    [string]$config.source_origin,
    [string]$config.candidate_source_origin,
    [string]$config.r_library,
    [string]$config.rscript,
    [string]$config.oracle_effect.comparisons.primary.root,
    [string]$config.oracle_effect.comparisons.replay.root
  )
  $outputPath = Resolve-Issue13V5DeliveryOutput `
    $Output $deliveryProtectedRoots
  $stateSha256 = Get-Issue13V5Sha256 $providedStatePath
  $reportSha256 = [string]$state.report.sha256
  $snapshot = Get-Issue13V5DeliverySnapshot $repository `
    ([string]$state.candidate_commit) `
    ([string]$config.report.required_path) $reportSha256
  $attester = Assert-Issue13V5DeliveryAttesterBinding $repository `
    ([string]$state.candidate_commit) ([string]$snapshot.delivery_commit)

  $attestation = [ordered]@{
    schema = 'wlv-issue13-v5-delivery-attestation/1'
    generation = 'v5'
    status = 'passed'
    immutable_write_once = $true
    attested_at_utc = [DateTime]::UtcNow.ToString('o')
    validated_code_commit = [string]$snapshot.validated_code_commit
    delivery_commit = [string]$snapshot.delivery_commit
    delivery_parent = [string]$snapshot.delivery_parent
    delivery_parent_count = [long]$snapshot.delivery_parent_count
    repository = [ordered]@{
      root = $repository
      validated_code_tree = [string]$snapshot.validated_code_tree
      delivery_tree = [string]$snapshot.delivery_tree
      tracked_tree_clean = $snapshot.tracked_tree_clean
    }
    config = [ordered]@{
      path = [string]$binding.path
      sha256 = [string]$binding.sha256
    }
    state = [ordered]@{
      path = $providedStatePath
      sha256 = $stateSha256
      revision = [long]$state.revision
      final_aggregate_sha256 = [string]$state.final_aggregate.sha256
    }
    report = [ordered]@{
      required_path = [string]$snapshot.diff_path
      path = [string]$snapshot.report_path
      sha256 = [string]$snapshot.report_sha256
      git_blob = [string]$snapshot.report_git_blob
      git_blob_sha256 = [string]$snapshot.report_git_blob_sha256
      size_bytes = [long]$snapshot.report_size_bytes
    }
    delivery_diff = [ordered]@{
      base = [string]$snapshot.validated_code_commit
      head = [string]$snapshot.delivery_commit
      changed_path_count = [long]$snapshot.diff_path_count
      status = [string]$snapshot.diff_status
      path = [string]$snapshot.diff_path
    }
    attester = $attester
    attestation_path = $outputPath
  }

  $secondSnapshot = Get-Issue13V5DeliverySnapshot $repository `
    ([string]$state.candidate_commit) `
    ([string]$config.report.required_path) $reportSha256
  $null = Assert-Issue13V5DeliverySnapshotEqual $snapshot $secondSnapshot
  if ((Get-Issue13V5Sha256 $binding.path) -cne [string]$binding.sha256 -or
      (Get-Issue13V5Sha256 $providedStatePath) -cne $stateSha256) {
    throw 'Config or state changed before delivery attestation was written.'
  }

  $attestationSha256 = Write-Issue13V5Json $attestation `
    (Resolve-Issue13V5DeliveryOutput `
      $outputPath $deliveryProtectedRoots)
  $roundtrip = Read-Issue13V5Json $outputPath
  if ([string]$roundtrip.schema -cne
        'wlv-issue13-v5-delivery-attestation/1' -or
      [string]$roundtrip.status -cne 'passed' -or
      -not (Test-Issue13V5ExactBoolean `
        $roundtrip.immutable_write_once $true) -or
      [string]$roundtrip.validated_code_commit -cne
        [string]$snapshot.validated_code_commit -or
      [string]$roundtrip.delivery_commit -cne
        [string]$snapshot.delivery_commit -or
      [string]$roundtrip.report.required_path -cne
        $script:Issue13V5DeliveryReportPath -or
      [string]$roundtrip.report.sha256 -cne
        [string]$state.report.sha256 -or
      [string]$roundtrip.report.git_blob_sha256 -cne
        [string]$state.report.sha256 -or
      (Get-Issue13V5Sha256 $outputPath) -cne $attestationSha256) {
    throw 'Installed delivery attestation failed its JSON round trip.'
  }

  $finalSnapshot = Get-Issue13V5DeliverySnapshot $repository `
    ([string]$state.candidate_commit) `
    ([string]$config.report.required_path) $reportSha256
  $null = Assert-Issue13V5DeliverySnapshotEqual $snapshot $finalSnapshot
  if ((Get-Issue13V5Sha256 $binding.path) -cne [string]$binding.sha256 -or
      (Get-Issue13V5Sha256 $providedStatePath) -cne $stateSha256) {
    throw 'Config or state changed after delivery attestation was written.'
  }

  [pscustomobject][ordered]@{
    status = 'passed'
    validated_code_commit = [string]$snapshot.validated_code_commit
    delivery_commit = [string]$snapshot.delivery_commit
    attestation_path = $outputPath
    attestation_sha256 = $attestationSha256
  }
}

if ($MyInvocation.InvocationName -cne '.') {
  Invoke-Issue13V5DeliveryAttestation -ConfigPath $ConfigPath `
    -StatePath $StatePath -Output $Output `
    -ConfirmWriteAttestation:$ConfirmWriteAttestation
}
