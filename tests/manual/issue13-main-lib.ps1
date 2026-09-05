Set-StrictMode -Version Latest

$script:Issue13MainMethods = [string[]]@('wiodr13', 'wiodr16')
$script:Issue13MainArms = [string[]]@('baseline', 'candidate')
$script:Issue13MainFaults = [string[]]@(
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
$script:Issue13MainClearedREnvironment = [string[]]@(
  'LANG', 'LC_ALL', 'LC_CTYPE',
  'R_ARCH', 'R_DEFAULT_PACKAGES', 'R_ENVIRON', 'R_ENVIRON_USER', 'R_HOME',
  'R_LIBS', 'R_LIBS_SITE', 'R_PROFILE', 'R_PROFILE_USER', 'R_STARTUP_DEBUG',
  'RENV_ACTIVATE_PROJECT', 'RENV_AUTOLOAD_ENABLED',
  'RENV_AUTOLOADER_ENABLED', 'RENV_CONFIG_AUTOLOADER_ENABLED',
  'RENV_CONFIG_EXTERNAL_LIBRARIES', 'RENV_CONFIG_STARTUP_QUIET',
  'RENV_CONFIG_SYNCHRONIZED_CHECK', 'RENV_CONFIG_USER_PROFILE',
  'RENV_PATHS_LIBRARY_ROOT', 'RENV_PATHS_LIBRARY_ROOT_ASIS',
  'RENV_PATHS_LOCKFILE', 'RENV_PATHS_PREFIX', 'RENV_PATHS_PREFIX_AUTO',
  'RENV_PATHS_RENV', 'RENV_PATHS_ROOT', 'RENV_PATHS_SANDBOX',
  'RENV_PATHS_VERSION', 'RENV_PROCESS_TYPE', 'RENV_PROFILE', 'RENV_PROJECT',
  'RENV_SANDBOX_LOCKING_ENABLED', 'RENV_STARTUP_DIAGNOSTICS'
)

function Get-Issue13MainClosedREnvironment([Parameter(Mandatory)][object]$Config) {
  $library = ConvertTo-Issue13MainFullPath ([string]$Config.r_library) `
    -RequireExistingDirectory
  $architecture = [IO.DirectoryInfo]::new($library)
  $version = $architecture.Parent
  $platform = if ($null -eq $version) { $null } else { $version.Parent }
  $root = if ($null -eq $platform) { $null } else { $platform.Parent }
  if ($null -eq $root -or $root.Name -cne 'library') {
    throw 'R library does not have the expected renv layout.'
  }
  $environment = [ordered]@{}
  foreach ($name in $script:Issue13MainClearedREnvironment) {
    $environment[$name] = $null
  }
  $environment['R_LIBS_USER'] = $library
  $environment['RENV_PATHS_LIBRARY'] = $root.FullName
  $environment['RENV_CONFIG_AUTO_SNAPSHOT'] = 'FALSE'
  $environment['RENV_CONFIG_CACHE_ENABLED'] = 'FALSE'
  $environment['RENV_CONFIG_LOCKING_ENABLED'] = 'FALSE'
  $environment['RENV_CONFIG_SANDBOX_ENABLED'] = 'FALSE'
  $environment['RENV_CONFIG_UPDATES_CHECK'] = 'FALSE'
  $environment['RENV_CONFIG_USER_ENVIRON'] = 'FALSE'
  $environment['RENV_CONFIG_USER_LIBRARY'] = 'FALSE'
  $environment['TZ'] = 'UTC'
  $environment['ISSUE13_V5_RSCRIPT_EXECUTABLE'] = [string]$Config.rscript
  $environment['ISSUE13_V5_GIT_EXECUTABLE'] = [string]$Config.git
  $environment
}

function Set-Issue13MainChildEnvironment(
  [Parameter(Mandatory)][Diagnostics.ProcessStartInfo]$StartInfo,
  [Parameter(Mandatory)][object]$Config
) {
  $environment = Get-Issue13MainClosedREnvironment $Config
  foreach ($name in $environment.Keys) {
    if ($null -eq $environment[$name]) {
      $null = $StartInfo.Environment.Remove([string]$name)
    } else {
      $StartInfo.Environment[[string]$name] = [string]$environment[$name]
    }
  }
}

function Enter-Issue13MainClosedREnvironment([Parameter(Mandatory)][object]$Config) {
  $environment = Get-Issue13MainClosedREnvironment $Config
  $prior = [Collections.Generic.List[object]]::new()
  foreach ($name in $environment.Keys) {
    $prior.Add([pscustomobject]@{
      name = [string]$name
      value = [Environment]::GetEnvironmentVariable([string]$name, 'Process')
    })
    [Environment]::SetEnvironmentVariable(
      [string]$name, $environment[$name], 'Process')
  }
  [object[]]$prior.ToArray()
}

function Exit-Issue13MainClosedREnvironment([Parameter(Mandatory)][object[]]$Prior) {
  foreach ($record in $Prior) {
    [Environment]::SetEnvironmentVariable(
      [string]$record.name, $record.value, 'Process')
  }
}

function Get-Issue13MainSha256([Parameter(Mandatory)][string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "File is missing: $Path"
  }
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-Issue13MainExactBoolean([object]$Value, [bool]$Expected) {
  $Value -is [bool] -and $Value -eq $Expected
}

function Test-Issue13MainSamePath(
  [Parameter(Mandatory)][string]$Left,
  [Parameter(Mandatory)][string]$Right
) {
  [string]::Equals(
    [IO.Path]::GetFullPath($Left).TrimEnd('\', '/'),
    [IO.Path]::GetFullPath($Right).TrimEnd('\', '/'),
    [StringComparison]::OrdinalIgnoreCase)
}

function New-Issue13MainFileRecord(
  [Parameter(Mandatory)][string]$Role,
  [Parameter(Mandatory)][string]$Path
) {
  $full = ConvertTo-Issue13MainFullPath $Path -RequireExistingFile
  [ordered]@{
    role = $Role
    path = $full
    sha256 = Get-Issue13MainSha256 $full
  }
}

function Assert-Issue13MainFileRecords(
  [Parameter(Mandatory)][object[]]$Records
) {
  if ($Records.Count -eq 0) { throw 'No local controller files were bound.' }
  $roles = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal)
  foreach ($record in $Records) {
    if ([string]::IsNullOrWhiteSpace([string]$record.role) -or
        -not $roles.Add([string]$record.role) -or
        (Get-Issue13MainSha256 ([string]$record.path)) -cne
          [string]$record.sha256) {
      throw 'A local controller file binding is invalid or changed.'
    }
  }
  $true
}

function New-Issue13MainControllerSnapshots(
  [Parameter(Mandatory)][string]$AttemptRoot,
  [Parameter(Mandatory)][object[]]$Files
) {
  $snapshotRoot = Join-Path $AttemptRoot 'controller-snapshot'
  if (Test-Path -LiteralPath $snapshotRoot) {
    throw "Controller snapshot already exists: $snapshotRoot"
  }
  $null = New-Item -ItemType Directory -Path $snapshotRoot
  $records = [Collections.Generic.List[object]]::new()
  foreach ($file in $Files) {
    $source = ConvertTo-Issue13MainFullPath ([string]$file.path) `
      -RequireExistingFile
    $before = Get-Issue13MainSha256 $source
    $extension = [IO.Path]::GetExtension($source)
    $snapshot = Join-Path $snapshotRoot (([string]$file.role) + $extension)
    [IO.File]::Copy($source, $snapshot, $false)
    $after = Get-Issue13MainSha256 $source
    $snapshotHash = Get-Issue13MainSha256 $snapshot
    if ($before -cne $after -or $before -cne $snapshotHash) {
      throw "Controller changed while it was snapshotted: $source"
    }
    $records.Add([ordered]@{
      role = [string]$file.role
      execution_path = $source
      sha256 = $before
      snapshot_path = $snapshot
      snapshot_sha256 = $snapshotHash
    })
  }
  [object[]]$records.ToArray()
}

function Assert-Issue13MainControllerSnapshots(
  [Parameter(Mandatory)][object[]]$Records,
  [switch]$RequireExecutionFiles
) {
  if ($Records.Count -eq 0) { throw 'No controller snapshots were bound.' }
  $roles = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal)
  foreach ($record in $Records) {
    if ([string]::IsNullOrWhiteSpace([string]$record.role) -or
        -not $roles.Add([string]$record.role) -or
        (Get-Issue13MainSha256 ([string]$record.snapshot_path)) -cne
          [string]$record.snapshot_sha256 -or
        [string]$record.snapshot_sha256 -cne [string]$record.sha256) {
      throw 'A controller snapshot binding is invalid or changed.'
    }
    if ($RequireExecutionFiles -and
        (Get-Issue13MainSha256 ([string]$record.execution_path)) -cne
          [string]$record.sha256) {
      throw 'A controller execution file changed after planning.'
    }
  }
  $true
}

function Test-Issue13MainControllerRecordEquality(
  [Parameter(Mandatory)][object[]]$Left,
  [Parameter(Mandatory)][object[]]$Right
) {
  if ($Left.Count -ne $Right.Count) { return $false }
  for ($index = 0; $index -lt $Left.Count; $index++) {
    foreach ($name in @(
        'role', 'execution_path', 'sha256', 'snapshot_path',
        'snapshot_sha256')) {
      if ([string]$Left[$index].$name -cne [string]$Right[$index].$name) {
        return $false
      }
    }
  }
  $true
}

function ConvertTo-Issue13MainFullPath(
  [Parameter(Mandatory)][string]$Path,
  [switch]$RequireExistingDirectory,
  [switch]$RequireExistingFile
) {
  if (-not [IO.Path]::IsPathFullyQualified($Path)) {
    throw "Path must be absolute: $Path"
  }
  $full = [IO.Path]::GetFullPath($Path)
  if ($RequireExistingDirectory -and
      -not (Test-Path -LiteralPath $full -PathType Container)) {
    throw "Directory is missing: $full"
  }
  if ($RequireExistingFile -and
      -not (Test-Path -LiteralPath $full -PathType Leaf)) {
    throw "File is missing: $full"
  }
  $full
}

function Read-Issue13MainJson([Parameter(Mandatory)][string]$Path) {
  $resolved = ConvertTo-Issue13MainFullPath $Path -RequireExistingFile
  Get-Content -LiteralPath $resolved -Raw -Encoding UTF8 |
    ConvertFrom-Json -DateKind String
}

function Write-Issue13MainJson(
  [Parameter(Mandatory)][object]$Value,
  [Parameter(Mandatory)][string]$Path
) {
  $full = ConvertTo-Issue13MainFullPath $Path
  $parent = Split-Path -Parent $full
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    $null = New-Item -ItemType Directory -Path $parent
  }
  $temporary = $full + '.tmp-' + [Guid]::NewGuid().ToString('N')
  $json = $Value | ConvertTo-Json -Depth 30
  [IO.File]::WriteAllText(
    $temporary, $json + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false))
  if (Test-Path -LiteralPath $full) {
    [IO.File]::Replace($temporary, $full, [NullString]::Value)
  } else {
    [IO.File]::Move($temporary, $full)
  }
  Get-Issue13MainSha256 $full
}

function Get-Issue13MainSafeId([Parameter(Mandatory)][string]$Id) {
  if ($Id -cnotmatch '^[a-z0-9][a-z0-9._/-]*$') {
    throw "Unsafe scenario id: $Id"
  }
  $Id.Replace('/', '__')
}

function New-Issue13MainArmState {
  [ordered]@{
    status = 'planned'
    attempt_count = 0
    active_attempt = $null
    attempts = [object[]]@()
    evidence_directory = $null
    scenario_result_sha256 = $null
    process_metrics_sha256 = $null
    failure = $null
  }
}

function New-Issue13MainPhases {
  $phases = [Collections.Generic.List[object]]::new()
  $ordinal = 0
  foreach ($method in $script:Issue13MainMethods) {
    $specifications = [object[]]@(
      [ordered]@{ kind = 'calculate'; workers = 1; stage = $null;
        variant = $null; sea_vars = [string[]]@() },
      [ordered]@{ kind = 'recalculate'; workers = 1; stage = 1;
        variant = 'full'; sea_vars = [string[]]@() },
      [ordered]@{ kind = 'recalculate'; workers = 1; stage = 4;
        variant = 'full'; sea_vars = [string[]]@() },
      [ordered]@{ kind = 'recalculate'; workers = 1; stage = 5;
        variant = 'full'; sea_vars = [string[]]@() },
      [ordered]@{ kind = 'recalculate'; workers = 1; stage = 4;
        variant = 'select-gross-output-mv';
        sea_vars = [string[]]@('gross_output.s.mv') },
      [ordered]@{ kind = 'recalculate'; workers = 1; stage = 5;
        variant = 'select-gross-output-du';
        sea_vars = [string[]]@('gross_output.s.du') }
    )
    foreach ($specification in $specifications) {
      $ordinal++
      $phase = if ($specification.kind -ceq 'calculate') {
        "calculate/$method/workers1"
      } else {
        "recalculate/$method/stage$($specification.stage)/$($specification.variant)"
      }
      $phases.Add([ordered]@{
        ordinal = $ordinal
        phase = $phase
        kind = [string]$specification.kind
        method = $method
        workers = [long]$specification.workers
        stage = $specification.stage
        variant = $specification.variant
        sea_vars = [string[]]$specification.sea_vars
        baseline = New-Issue13MainArmState
        candidate = New-Issue13MainArmState
        comparison_status = 'planned'
        performance = $null
        comparisons = [object[]]@()
      })
    }
  }
  foreach ($method in $script:Issue13MainMethods) {
    $ordinal++
    $phases.Add([ordered]@{
      ordinal = $ordinal
      phase = "calculate/$method/workers2"
      kind = 'calculate'
      method = $method
      workers = 2
      stage = $null
      variant = $null
      sea_vars = [string[]]@()
      baseline = New-Issue13MainArmState
      candidate = New-Issue13MainArmState
      comparison_status = 'planned'
      performance = $null
      comparisons = [object[]]@()
    })
  }
  if ($phases.Count -ne 14) {
    throw 'The reduced scientific matrix is not exactly 14 paired phases.'
  }
  [object[]]$phases.ToArray()
}

function New-Issue13MainPlan {
  [ordered]@{
    schema = 'wlv-issue13-main-plan/1'
    methods = [string[]]$script:Issue13MainMethods
    arms = [string[]]$script:Issue13MainArms
    scientific_pair_count = 14
    scientific_scenario_count = 28
    preparation_pair_count = 1
    fault_count = 10
    monitored_scenario_count = 40
    authenticated_comparison_count = 41
    paper_scenarios = 0
    scheduling = [ordered]@{
      maximum_isolated_jobs = 4
      science_measurements = 'observational-under-parallel-load'
      one_active_scenario_per_results_root = $true
      comparison_pool_maximum = 2
      controlled_performance_maximum_jobs = 1
    }
    phases = New-Issue13MainPhases
    preparation = [ordered]@{
      phase = 'prepare/all'
      sources = [string[]]@('wiodr13', 'wiodr16', 'euklems')
    }
    faults = [string[]]$script:Issue13MainFaults
  }
}

function New-Issue13MainComparisons {
  $records = [Collections.Generic.List[object]]::new()
  $ordinal = 0L
  foreach ($phase in New-Issue13MainPhases) {
    $ordinal++
    $records.Add([ordered]@{
      ordinal = $ordinal; id = 'parity/' + [string]$phase.phase
      kind = 'parity'; phase = [string]$phase.phase; arm = $null
      mode = 'cross_engine_run_v3'; allow_difference = $false
      status = 'planned'; attempt_count = 0L; attempts = [object[]]@()
      output_directory = $null; comparison_sha256 = $null; passed = $null
      failure = $null
    })
    if ([string]$phase.kind -ceq 'recalculate') {
      foreach ($arm in $script:Issue13MainArms) {
        $ordinal++
        $records.Add([ordered]@{
          ordinal = $ordinal; id = "oracle/$arm/$($phase.phase)"
          kind = 'oracle'; phase = [string]$phase.phase; arm = $arm
          mode = 'strict'; allow_difference = $true
          status = 'planned'; attempt_count = 0L; attempts = [object[]]@()
          output_directory = $null; comparison_sha256 = $null; passed = $null
          failure = $null
        })
      }
    }
    if ([string]$phase.kind -ceq 'calculate' -and
        [long]$phase.workers -eq 2L) {
      foreach ($arm in $script:Issue13MainArms) {
        $ordinal++
        $records.Add([ordered]@{
          ordinal = $ordinal
          id = "equivalence/$arm/calculate/$($phase.method)/workers2-vs-workers1"
          kind = 'worker-equivalence'; phase = [string]$phase.phase; arm = $arm
          mode = 'strict'; allow_difference = $false
          status = 'planned'; attempt_count = 0L; attempts = [object[]]@()
          output_directory = $null; comparison_sha256 = $null; passed = $null
          failure = $null
        })
      }
    }
  }
  if ($records.Count -ne 38) {
    throw 'The reduced scientific comparison matrix is not exactly 38.'
  }
  [object[]]$records.ToArray()
}

function Assert-Issue13MainDerivedHarness(
  [Parameter(Mandatory)][object]$Config,
  [Parameter(Mandatory)][object]$Source
) {
  $manifestPath = ConvertTo-Issue13MainFullPath `
    ([string]$Config.harness_manifest) -RequireExistingFile
  $manifest = Read-Issue13MainJson $manifestPath
  $sourceManifest = ConvertTo-Issue13MainFullPath `
    ([string]$Source.harness_manifest_path) -RequireExistingFile
  $toolsRoot = Split-Path -Parent ([string]$Config.harness_root)
  if ($manifest.schema -cne
        'wlv-issue13-main-derived-harness-manifest/1' -or
      [string]$manifest.status -cne 'materialized' -or
      -not (Test-Issue13MainExactBoolean `
        $manifest.scientific_r_files_unchanged $true) -or
      [long]$manifest.exact_changed_file_count -ne 7L -or
      [long]$manifest.source_output_tooling.file_count -ne 47L -or
      [long]$manifest.derived_output_tooling.file_count -ne 47L -or
      -not (Test-Issue13MainSamePath `
        ([string]$manifest.source_harness_root) `
        ([string]$Source.harness_root)) -or
      -not (Test-Issue13MainSamePath `
        ([string]$manifest.source_harness_manifest) $sourceManifest) -or
      [string]$manifest.source_harness_manifest_sha256 -cne
        (Get-Issue13MainSha256 $sourceManifest) -or
      -not (Test-Issue13MainSamePath `
        ([string]$manifest.derived_harness_root) `
        ([string]$Config.harness_root)) -or
      -not (Test-Issue13MainSamePath `
        ([string]$manifest.derived_powershell_executable) `
        ([string]$Config.sealed_pwsh)) -or
      -not (Test-Issue13MainSamePath `
        ([string]$manifest.derived_powershell_root) `
        (Split-Path -Parent ([string]$Config.sealed_pwsh)))) {
    throw 'The derived V5 harness declaration is invalid.'
  }
  $sourceManifestDocument = Read-Issue13MainJson $sourceManifest
  foreach ($name in @('file_count', 'total_bytes', 'inventory_sha256')) {
    if ([string]$manifest.source_output_tooling.$name -cne
        [string]$sourceManifestDocument.output_tooling.$name) {
      throw 'The derived harness does not bind the V5 source inventory.'
    }
  }
  $expectedChanged = [string[]]@(
    'issue13-monitor-selftest.ps1',
    'issue13-monitor.ps1',
    'issue13-run-fault-seed-record.ps1',
    'issue13-run-fault-seeds.ps1',
    'issue13-run-plan.ps1',
    'issue13-run-prep-fault-record.ps1',
    'issue13-run-recalc-bundle.ps1'
  )
  $changed = [string[]]@($manifest.changed_files | ForEach-Object {
    if ([string]$_.classification -cne 'powershell-runtime-binding-only' -or
        [string]$_.derived_sha256 -cne
          [string]$_.deterministic_transform_sha256) {
      throw 'A derived harness change is not an authenticated runtime binding.'
    }
    [string]$_.relative_path
  })
  [Array]::Sort($changed, [StringComparer]::Ordinal)
  if ([string]::Join("`n", $changed) -cne
      [string]::Join("`n", $expectedChanged)) {
    throw 'The derived harness changed files outside the exact guard allowlist.'
  }
  $sourceRecords = @{}
  foreach ($record in @($manifest.source_output_tooling.records)) {
    $sourceRecords[[string]$record.relative_path] = $record
  }
  $seen = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  foreach ($record in @($manifest.derived_output_tooling.records)) {
    $relative = [string]$record.relative_path
    $path = [IO.Path]::GetFullPath((Join-Path $toolsRoot $relative))
    if (-not $path.StartsWith(
        $toolsRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase) -or
        -not $seen.Add($path) -or
        -not (Test-Path -LiteralPath $path -PathType Leaf) -or
        [long](Get-Item -LiteralPath $path).Length -ne
          [long]$record.size_bytes -or
        (Get-Issue13MainSha256 $path) -cne [string]$record.sha256) {
      throw 'A derived tooling record is missing, escaped, duplicated, or changed.'
    }
    $sourceRecord = $sourceRecords[$relative]
    $leaf = [IO.Path]::GetFileName($relative)
    if ($null -eq $sourceRecord -or
        ($expectedChanged -cnotcontains $leaf -and
         [string]$record.sha256 -cne [string]$sourceRecord.sha256)) {
      throw "A non-guard tooling file changed: $relative"
    }
  }
  if ($seen.Count -ne 47) { throw 'Derived tooling coverage is not exact.' }
  if (@($manifest.trusted_runtime_records).Count -ne 11) {
    throw 'Private PowerShell trusted-runtime coverage is not exact.'
  }
  $runtimeRoot = Split-Path -Parent ([string]$Config.sealed_pwsh)
  foreach ($record in @($manifest.trusted_runtime_records)) {
    $path = [IO.Path]::GetFullPath(
      (Join-Path $runtimeRoot ([string]$record.relative_path)))
    if (-not $path.StartsWith(
        $runtimeRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase) -or
        [long](Get-Item -LiteralPath $path -Force).Length -ne
          [long]$record.size_bytes -or
        (Get-Issue13MainSha256 $path) -cne
          ([string]$record.sha256).ToLowerInvariant()) {
      throw 'A private PowerShell trusted-runtime file changed.'
    }
  }
  $true
}

function Assert-Issue13MainConfig([Parameter(Mandatory)][object]$Config) {
  if ($Config.schema -cne 'wlv-issue13-main-gate-config/1') {
    throw 'Unsupported reduced gate config schema.'
  }
  foreach ($name in @(
      'campaign_id', 'source_v5_config', 'control_root', 'evidence_root',
      'harness_root', 'harness_manifest', 'rscript', 'r_library',
      'sealed_pwsh', 'git', 'arms', 'scheduling', 'performance')) {
    if ($Config.PSObject.Properties.Name -cnotcontains $name) {
      throw "Reduced gate config is missing: $name"
    }
  }
  if ([string]$Config.campaign_id -cnotmatch '^[a-z0-9][a-z0-9._-]*$') {
    throw 'campaign_id is not filesystem-safe.'
  }
  foreach ($pathName in @(
      'source_v5_config', 'harness_manifest', 'rscript', 'sealed_pwsh', 'git')) {
    $null = ConvertTo-Issue13MainFullPath ([string]$Config.$pathName) `
      -RequireExistingFile
  }
  foreach ($pathName in @('harness_root', 'r_library')) {
    $null = ConvertTo-Issue13MainFullPath ([string]$Config.$pathName) `
      -RequireExistingDirectory
  }
  $control = ConvertTo-Issue13MainFullPath ([string]$Config.control_root)
  $evidence = ConvertTo-Issue13MainFullPath ([string]$Config.evidence_root)
  if ([string]::Equals($control, $evidence,
      [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Control and evidence roots must differ.'
  }
  if ([long]$Config.scheduling.maximum_isolated_jobs -lt 1 -or
      [long]$Config.scheduling.maximum_isolated_jobs -gt 4) {
    throw 'maximum_isolated_jobs must be between 1 and 4.'
  }
  if ([long]$Config.scheduling.comparison_jobs -lt 1 -or
      [long]$Config.scheduling.comparison_jobs -gt 2) {
    throw 'comparison_jobs must be between 1 and 2.'
  }
  if ([long]$Config.scheduling.memory_budget_bytes -ne 85899345920L -or
      [long]$Config.scheduling.minimum_free_physical_bytes -lt 17179869184L) {
    throw 'Memory admission requires an 80 GiB budget and a 16 GiB free floor.'
  }
  if ([long]$Config.scheduling.minimum_free_worktree_volume_bytes -lt
      10737418240L) {
    throw 'minimum_free_worktree_volume_bytes must be at least 10 GiB.'
  }
  $reserves = $Config.scheduling.job_reserve_bytes
  if ([long]$reserves.wiodr13_workers1 -lt 8589934592L -or
      [long]$reserves.wiodr16_workers1 -lt 23622320128L -or
      [long]$reserves.workers2 -lt 42949672960L) {
    throw 'Per-job memory reserves are below the audited safety values.'
  }
  if ([double]$Config.performance.candidate_time_ratio_maximum -ne 1.2 -or
      [double]$Config.performance.candidate_time_absolute_allowance_seconds `
        -ne 600.0 -or
      [double]$Config.performance.candidate_rss_baseline_ratio_allowance `
        -ne 0.1 -or
      [long]$Config.performance.candidate_rss_minimum_allowance_bytes `
        -ne 536870912L -or
      [string]$Config.performance.science_measurements -cne 'observational' -or
      [long]$Config.performance.controlled_maximum_jobs -ne 1) {
    throw 'Performance policy differs from the reduced normative policy.'
  }
  $roots = [Collections.Generic.List[string]]::new()
  $rootSet = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase)
  $bindings = @{}
  foreach ($arm in $script:Issue13MainArms) {
    $declaration = $Config.arms.$arm
    if ($null -eq $declaration -or
        [string]::IsNullOrWhiteSpace([string]$declaration.binding_path) -or
        -not [IO.Path]::IsPathFullyQualified([string]$declaration.binding_path)) {
      throw "Invalid arm binding declaration: $arm"
    }
    if (Test-Path -LiteralPath ([string]$declaration.binding_path) -PathType Leaf) {
      $binding = Get-Issue13MainArmBinding $Config $arm
      $bindings[$arm] = $binding
      foreach ($method in $script:Issue13MainMethods) {
        $root = ConvertTo-Issue13MainFullPath `
          ([string]$binding.roots.$method) -RequireExistingDirectory
        if (-not $rootSet.Add($root)) {
          throw "Scientific worktree root is reused: $root"
        }
        foreach ($otherRoot in $roots) {
          if ($root.StartsWith(
              $otherRoot + [IO.Path]::DirectorySeparatorChar,
              [StringComparison]::OrdinalIgnoreCase) -or
              $otherRoot.StartsWith(
                $root + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Scientific worktree roots overlap: $root / $otherRoot"
          }
        }
        $roots.Add($root)
        foreach ($outside in @($control, $evidence)) {
          if ($outside.StartsWith(
              $root + [IO.Path]::DirectorySeparatorChar,
              [StringComparison]::OrdinalIgnoreCase) -or
              $root.StartsWith(
                $outside + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Campaign output is inside a scientific worktree: $outside"
          }
        }
      }
    }
  }
  if ($bindings.ContainsKey('baseline') -and
      $bindings.ContainsKey('candidate')) {
    foreach ($method in $script:Issue13MainMethods) {
    $baselineDrive = [IO.Path]::GetPathRoot(
        [string]$bindings.baseline.roots.$method)
    $candidateDrive = [IO.Path]::GetPathRoot(
        [string]$bindings.candidate.roots.$method)
    if (-not [string]::Equals($baselineDrive, $candidateDrive,
        [StringComparison]::OrdinalIgnoreCase)) {
      throw "Baseline and candidate must share a volume for $method timing."
    }
  }
  }
  $source = Read-Issue13MainJson ([string]$Config.source_v5_config)
  $sourceManifest = ConvertTo-Issue13MainFullPath `
    ([string]$source.harness_manifest_path) -RequireExistingFile
  $originalHarness = Test-Issue13MainSamePath `
    ([string]$source.harness_root) ([string]$Config.harness_root)
  if ($originalHarness) {
    if (-not (Test-Issue13MainSamePath $sourceManifest `
        ([string]$Config.harness_manifest))) {
      throw 'The original V5 harness must use its original manifest.'
    }
  } else {
    $null = Assert-Issue13MainDerivedHarness $Config $source
  }
  if ($source.schema -cne 'wlv-issue13-native-gate-config/4' -or
      -not (Test-Issue13MainExactBoolean `
        $source.final_evidence_eligible $true) -or
      -not (Test-Issue13MainExactBoolean `
        $source.reuse_policy.fresh_roots_required $true) -or
      -not (Test-Issue13MainSamePath ([string]$source.rscript) `
        ([string]$Config.rscript)) -or
      -not (Test-Issue13MainSamePath ([string]$source.r_library) `
        ([string]$Config.r_library)) -or
      [string]$source.harness_manifest_sha256 -cne
        (Get-Issue13MainSha256 $sourceManifest)) {
    throw 'The referenced V5 runtime/config/manifest binding is invalid.'
  }
  $true
}

function Get-Issue13MainArmBinding(
  [Parameter(Mandatory)][object]$Config,
  [Parameter(Mandatory)][ValidateSet('baseline', 'candidate')][string]$Arm
) {
  $declaration = $Config.arms.$Arm
  $path = ConvertTo-Issue13MainFullPath ([string]$declaration.binding_path) `
    -RequireExistingFile
  $binding = Read-Issue13MainJson $path
  if ($binding.schema -cne 'wlv-issue13-main-arm-binding/1' -or
      [string]$binding.arm -cne $Arm -or
      [string]$binding.commit -cnotmatch '^[0-9a-f]{40}$' -or
      [string]$binding.seed_commit -cnotmatch '^[0-9a-f]{40}$') {
    throw "Invalid reduced gate arm binding: $Arm"
  }
  foreach ($method in $script:Issue13MainMethods) {
    $null = ConvertTo-Issue13MainFullPath ([string]$binding.roots.$method) `
      -RequireExistingDirectory
  }
  $binding | Add-Member -NotePropertyName binding_path -NotePropertyValue $path `
    -Force
  $binding | Add-Member -NotePropertyName binding_sha256 `
    -NotePropertyValue (Get-Issue13MainSha256 $path) -Force
  $binding
}

function Get-Issue13MainRoot(
  [Parameter(Mandatory)][object]$Config,
  [Parameter(Mandatory)][ValidateSet('baseline', 'candidate')][string]$Arm,
  [Parameter(Mandatory)][ValidateSet('wiodr13', 'wiodr16')][string]$Method
) {
  $binding = Get-Issue13MainArmBinding $Config $Arm
  ConvertTo-Issue13MainFullPath ([string]$binding.roots.$Method) `
    -RequireExistingDirectory
}

function Get-Issue13MainScenarioResult([Parameter(Mandatory)][object]$ArmState) {
  if ([string]$ArmState.status -cne 'passed' -or
      [string]::IsNullOrWhiteSpace([string]$ArmState.evidence_directory)) {
    throw 'Scenario has no passed evidence.'
  }
  ConvertTo-Issue13MainFullPath `
    (Join-Path ([string]$ArmState.evidence_directory) 'scenario-result.json') `
    -RequireExistingFile
}

function Test-Issue13MainScenarioEvidence(
  [Parameter(Mandatory)][string]$Directory,
  [Parameter(Mandatory)][string]$ScenarioId,
  [Parameter(Mandatory)][string]$ExpectedCommit,
  [Parameter(Mandatory)][long]$ExpectedWorkers
) {
  $resultPath = ConvertTo-Issue13MainFullPath `
    (Join-Path $Directory 'scenario-result.json') -RequireExistingFile
  $metricsPath = ConvertTo-Issue13MainFullPath `
    (Join-Path $Directory 'process-metrics.json') -RequireExistingFile
  $result = Read-Issue13MainJson $resultPath
  $metrics = Read-Issue13MainJson $metricsPath
  if ($result.schema -cne 'wlv-issue13-scenario-result/1' -or
      [string]$result.scenario_id -cne $ScenarioId -or
      -not (Test-Issue13MainExactBoolean $result.passed $true) -or
      [string]$result.status -cne 'passed' -or
      [string]$result.expected_commit -cne $ExpectedCommit -or
      [string]$result.observed_commit -cne $ExpectedCommit -or
      $metrics.schema -cne 'wlv-issue13-process-metrics/2' -or
      [string]$metrics.scenario_id -cne $ScenarioId -or
      -not (Test-Issue13MainExactBoolean $metrics.passed $true) -or
      [string]$metrics.status -cne 'passed' -or
      -not (Test-Issue13MainExactBoolean $metrics.cluster_closed $true) -or
      @($metrics.lingering_pids).Count -ne 0 -or
      [long]$metrics.expected_worker_processes -ne $ExpectedWorkers -or
      [long]$metrics.max_concurrent_worker_processes -ne $ExpectedWorkers -or
      -not (Test-Issue13MainExactBoolean `
        $metrics.worker_count_matched $true)) {
    throw "Scenario evidence failed its reduced binding: $ScenarioId"
  }
  foreach ($binding in @(
      @($metrics.stdout_path, $metrics.stdout_sha256),
      @($metrics.stderr_path, $metrics.stderr_sha256),
      @($metrics.samples_path, $metrics.samples_sha256),
      @($metrics.process_spec_path, $metrics.process_spec_sha256))) {
    if ((Get-Issue13MainSha256 ([string]$binding[0])) -cne
        [string]$binding[1]) {
      throw "Scenario telemetry hash differs: $ScenarioId"
    }
  }
  [pscustomobject]@{
    result_path = $resultPath
    result_sha256 = Get-Issue13MainSha256 $resultPath
    metrics_path = $metricsPath
    metrics_sha256 = Get-Issue13MainSha256 $metricsPath
    elapsed_seconds = [double]$metrics.elapsed_seconds
    peak_rss_bytes = [long]$metrics.peak_rss_bytes
  }
}

function Get-Issue13MainPerformance(
  [Parameter(Mandatory)][object]$Config,
  [Parameter(Mandatory)][object]$Baseline,
  [Parameter(Mandatory)][object]$Candidate
) {
  $ratioLimit = [double]$Baseline.elapsed_seconds *
    [double]$Config.performance.candidate_time_ratio_maximum
  $absoluteLimit = [double]$Baseline.elapsed_seconds +
    [double]$Config.performance.candidate_time_absolute_allowance_seconds
  $rssAllowance = [Math]::Max(
    [double]$Baseline.peak_rss_bytes *
      [double]$Config.performance.candidate_rss_baseline_ratio_allowance,
    [double]$Config.performance.candidate_rss_minimum_allowance_bytes)
  $rssLimit = [double]$Baseline.peak_rss_bytes + $rssAllowance
  [ordered]@{
    baseline_seconds = [double]$Baseline.elapsed_seconds
    candidate_seconds = [double]$Candidate.elapsed_seconds
    time_ratio_limit_seconds = $ratioLimit
    time_absolute_limit_seconds = $absoluteLimit
    time_limit_seconds = [Math]::Max($ratioLimit, $absoluteLimit)
    time_passed = [double]$Candidate.elapsed_seconds -le
      [Math]::Max($ratioLimit, $absoluteLimit)
    baseline_peak_rss_bytes = [long]$Baseline.peak_rss_bytes
    candidate_peak_rss_bytes = [long]$Candidate.peak_rss_bytes
    rss_limit_bytes = [long][Math]::Floor($rssLimit)
    rss_passed = [double]$Candidate.peak_rss_bytes -le $rssLimit
  }
}

function Get-Issue13MainToolingBinding(
  [Parameter(Mandatory)][object]$Config
) {
  $required = [string[]]@(
    'issue13-build-calculate-bundle.R',
    'issue13-build-recalc-bundle.R',
    'issue13-run-recalc-bundle.ps1',
    'issue13-monitor.ps1',
    'issue13-scenario.R',
    'issue13-seed-channel.R',
    'issue13-seed-runtime-lib.R',
    'issue13-lib.R',
    'issue13-matrix.R',
    'issue13-compare-results.R',
    'issue13-compare-lib.R',
    'issue13-v5-difference-fingerprint.R',
    'issue13-v5-compare-override.R',
    'issue13-v5-diagnostics-override.R',
    'issue13-v5-aggregate-hardening.R'
  )
  $records = [Collections.Generic.List[object]]::new()
  foreach ($name in $required) {
    $path = ConvertTo-Issue13MainFullPath `
      (Join-Path ([string]$Config.harness_root) $name) -RequireExistingFile
    $records.Add([ordered]@{
      name = $name
      path = $path
      sha256 = Get-Issue13MainSha256 $path
    })
  }
  $preparationLibrary = ConvertTo-Issue13MainFullPath `
    (Join-Path (Split-Path -Parent ([string]$Config.harness_root)) `
      'issue13-prep-paper-lib.R') -RequireExistingFile
  $records.Add([ordered]@{
    name = 'issue13-prep-paper-lib.R'
    path = $preparationLibrary
    sha256 = Get-Issue13MainSha256 $preparationLibrary
  })
  [ordered]@{
    schema = 'wlv-issue13-main-tooling-binding/1'
    eligibility = 'tooling-only-no-historical-evidence-adoption'
    source_v5_config = ConvertTo-Issue13MainFullPath `
      ([string]$Config.source_v5_config) -RequireExistingFile
    source_v5_config_sha256 = Get-Issue13MainSha256 `
      ([string]$Config.source_v5_config)
    harness_manifest = ConvertTo-Issue13MainFullPath `
      ([string]$Config.harness_manifest) -RequireExistingFile
    harness_manifest_sha256 = Get-Issue13MainSha256 `
      ([string]$Config.harness_manifest)
    harness_records = [object[]]$records.ToArray()
    executables = [object[]]@(
      [ordered]@{ role = 'Rscript'; path = [string]$Config.rscript;
        sha256 = Get-Issue13MainSha256 ([string]$Config.rscript) },
      [ordered]@{ role = 'sealed-pwsh'; path = [string]$Config.sealed_pwsh;
        sha256 = Get-Issue13MainSha256 ([string]$Config.sealed_pwsh) },
      [ordered]@{ role = 'git'; path = [string]$Config.git;
        sha256 = Get-Issue13MainSha256 ([string]$Config.git) }
    )
  }
}

function Assert-Issue13MainToolingBinding(
  [Parameter(Mandatory)][object]$Binding
) {
  if ($Binding.schema -cne 'wlv-issue13-main-tooling-binding/1' -or
      [string]$Binding.eligibility -cne
        'tooling-only-no-historical-evidence-adoption') {
    throw 'Invalid reduced tooling binding.'
  }
  foreach ($record in @($Binding.harness_records) + @($Binding.executables)) {
    if ((Get-Issue13MainSha256 ([string]$record.path)) -cne
        [string]$record.sha256) {
      throw "Bound tooling changed: $($record.path)"
    }
  }
  if ((Get-Issue13MainSha256 ([string]$Binding.harness_manifest)) -cne
      [string]$Binding.harness_manifest_sha256 -or
      (Get-Issue13MainSha256 ([string]$Binding.source_v5_config)) -cne
      [string]$Binding.source_v5_config_sha256) {
    throw 'The V5 tooling reference changed.'
  }
  $true
}
