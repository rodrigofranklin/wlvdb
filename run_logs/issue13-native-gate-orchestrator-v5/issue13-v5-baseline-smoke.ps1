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
    'cc2c86189a06676bcb9f0e05e08033d710a92509',
  [ValidateSet(
    'strict-cc2-executability-preflight',
    'compatibility-oracle-executability-preflight'
  )]
  [string]$Purpose = 'strict-cc2-executability-preflight',
  [switch]$ConfirmCreateWorktrees,
  [switch]$ConfirmExecuteR
)

. (Join-Path $PSScriptRoot 'issue13-v5-coordinator-lib.ps1')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ConfirmCreateWorktrees -or -not $ConfirmExecuteR) {
  throw 'Baseline smoke requires -ConfirmCreateWorktrees and -ConfirmExecuteR.'
}

$baselineBaseCommit = 'cc2c86189a06676bcb9f0e05e08033d710a92509'
$baselineCommit = $BaselineRuntimeCommit
$sourceInventorySha256 =
  'c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26'
$sourceDirectorySha256 =
  '8b3a622a748f2489fe8cfd2a8273ec98ad4c372b2378d587a5ee2e3c5c916640'
$expectedHarnessFileCount = 39L
$expectedHarnessTotalBytes = 592426L
$expectedHarnessInventorySha256 =
  'b38a6e60fd7b300b4da5ebbce9bc492cbf7e170e57b3b24c7d1f1e8503ecc90f'
$methods = @(
  'wiodr13', 'wiodr16', 'alternative_1', 'alternative_2', 'norow_w13',
  'ochoa_1', 'ochoa_2', 'petrovic', 'wiodr13v09', 'wiodr16v09',
  'zerodep_1', 'zerodep_2'
)
$localeEnvironmentNames = @('LANG', 'LC_ALL', 'LC_CTYPE')
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function Get-Issue13V5Sha256([string]$Path) {
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Issue13V5TextSha256([string]$Value) {
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
        sha256 = Get-Issue13V5Sha256 $_.FullName
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
    inventory_sha256 = Get-Issue13V5TextSha256 (
      [string]::Join("`n", $fileLines))
    directory_list_sha256 = Get-Issue13V5TextSha256 (
      [string]::Join("`n", $directories))
    records = $files
  }
}

function Assert-Issue13V5SourceInventory([object]$Inventory, [string]$Label) {
  if ([long]$Inventory.file_count -ne 84 -or
      [long]$Inventory.directory_count -ne 5 -or
      [long]$Inventory.total_bytes -ne 2946498269L -or
      [string]$Inventory.inventory_sha256 -cne $sourceInventorySha256 -or
      [string]$Inventory.directory_list_sha256 -cne $sourceDirectorySha256) {
    throw "$Label does not match the authenticated official source inventory."
  }
}

function Assert-Issue13V5NoConcurrentR {
  $processes = @(Get-CimInstance Win32_Process -ErrorAction Stop |
    Where-Object { $_.Name -in @(
      'R.exe', 'Rscript.exe', 'Rterm.exe', 'Rgui.exe', 'Rcmd.exe', 'Rfe.exe'
    ) })
  foreach ($process in $processes) {
    if ([int]$process.ProcessId -ne 30272 -or
        [string]$process.Name -cne 'Rscript.exe' -or
        [string]$process.CommandLine -cne
          '"C:\Users\rodri\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe" --vanilla run-local-panel.R') {
      throw "Unexpected R process before baseline smoke: PID $($process.ProcessId)."
    }
  }
}

function Write-Issue13V5Json([object]$Value, [string]$Path) {
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
  $candidateCommit = [string]$manifest.source_controller.candidate_commit
  if ($candidateCommit -cnotmatch '^[0-9a-f]{40}$') {
    throw 'Baseline smoke harness lacks its candidate controller commit.'
  }
  $bindingConfig = [pscustomobject]@{
    repository_root = $Repository
    candidate_commit = $candidateCommit
    harness_runtime_root = $RuntimeRoot
    harness_root = (Join-Path $RuntimeRoot 'issue13-evidence-harness')
    harness_manifest_path = $ManifestPath
    harness_manifest_sha256 = Get-Issue13V5Sha256 $ManifestPath
  }
  $binding = Assert-Issue13V5HarnessBinding $bindingConfig
  if ((-not [string]::IsNullOrWhiteSpace($ExpectedManifestSha256) -and
        (Get-Issue13V5Sha256 $ManifestPath) -cne $ExpectedManifestSha256) -or
      [long]$binding.inventory.file_count -ne $expectedHarnessFileCount -or
      [long]$binding.inventory.total_bytes -ne $expectedHarnessTotalBytes -or
      [string]$binding.inventory.inventory_sha256 -cne
        $expectedHarnessInventorySha256) {
    throw 'Baseline smoke harness changed after its sealed authentication.'
  }
  $binding
}

$repository = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$source = (Resolve-Path -LiteralPath $SourceOrigin).Path
$runtimeRoot = (Resolve-Path -LiteralPath $HarnessRuntimeRoot).Path
$harness = Join-Path $runtimeRoot 'issue13-evidence-harness'
$harnessManifestPath = Join-Path $runtimeRoot 'v5-harness-manifest.json'
$rscriptFull = (Resolve-Path -LiteralPath $Rscript).Path
$library = (Resolve-Path -LiteralPath $RLibrary).Path
$smoke = [IO.Path]::GetFullPath($SmokeRoot)
if (($Purpose -ceq 'strict-cc2-executability-preflight' -and
      $baselineCommit -cne $baselineBaseCommit) -or
    ($Purpose -ceq 'compatibility-oracle-executability-preflight' -and
      $baselineCommit -ceq $baselineBaseCommit)) {
  throw 'Baseline smoke purpose and runtime commit disagree.'
}
$null = & git -C $repository cat-file -e ($baselineCommit + '^{commit}')
if ($LASTEXITCODE -ne 0) {
  throw "Baseline smoke runtime commit is unavailable: $baselineCommit"
}
$expectedRuntimeTree = (& git -C $repository rev-parse `
  ($baselineCommit + '^{tree}') 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $expectedRuntimeTree -cnotmatch '^[0-9a-f]{40}$') {
  throw 'Cannot authenticate the baseline smoke runtime tree.'
}
if ($Purpose -ceq 'compatibility-oracle-executability-preflight') {
  if ($baselineCommit -cne
      'e2f4d6dae9a6d35c966b305fabac52e489faa3e7') {
    throw 'The compatibility smoke must use the sealed V5 oracle commit.'
  }
  $parentCommit = (& git -C $repository rev-parse ($baselineCommit + '^')).Trim()
  $runtimeTree = (& git -C $repository rev-parse `
    ($baselineCommit + '^{tree}')).Trim()
  if ($LASTEXITCODE -ne 0 -or $parentCommit -cne $baselineBaseCommit -or
      $runtimeTree -cne $expectedRuntimeTree -or
      $runtimeTree -cne '7da19c4f2913e857040ba228280f404b0e54eaab') {
    throw 'The compatibility oracle must be a direct child of cc2.'
  }
}
if ($smoke -match '(?i)(^|[\\/])[^\\/]*v4(?:r[0-9]+)?[^\\/]*($|[\\/])' -or
    $smoke.StartsWith($repository + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase)) {
  throw 'The disposable V5 smoke root must be outside the repository and V4 roots.'
}
if (Test-Path -LiteralPath $smoke) {
  throw 'The disposable V5 smoke root already exists; reuse is forbidden.'
}
if (-not (Test-Path -LiteralPath $harness -PathType Container) -or
    -not (Test-Path -LiteralPath $harnessManifestPath -PathType Leaf)) {
  throw 'The materialized V5 harness is incomplete.'
}
$harnessBinding = Assert-Issue13V5SmokeHarness $runtimeRoot `
  $harnessManifestPath $repository
$harnessManifest = $harnessBinding.manifest
$harnessManifestSha256 = Get-Issue13V5Sha256 $harnessManifestPath

$sourceInventory = Get-Issue13V5SourceInventory $source
Assert-Issue13V5SourceInventory $sourceInventory 'Source origin'
Assert-Issue13V5NoConcurrentR

$null = New-Item -ItemType Directory -Path $smoke
$worktreeRoot = Join-Path $smoke 'worktrees'
$attemptRoot = Join-Path $smoke 'attempts'
$null = New-Item -ItemType Directory -Path $worktreeRoot
$null = New-Item -ItemType Directory -Path $attemptRoot

$started = [DateTime]::UtcNow
$records = [Collections.Generic.List[object]]::new()
$previousLibrary = [Environment]::GetEnvironmentVariable('R_LIBS_USER', 'Process')
$previousLocaleEnvironment = [ordered]@{}
foreach ($name in $localeEnvironmentNames) {
  $previousLocaleEnvironment[$name] =
    [Environment]::GetEnvironmentVariable($name, 'Process')
}
try {
  foreach ($name in $localeEnvironmentNames) {
    Set-Item -LiteralPath ('Env:' + $name) -Value $null
    if ($null -ne [Environment]::GetEnvironmentVariable($name, 'Process')) {
      throw "Cannot sanitize inherited locale variable for smoke: $name"
    }
  }
  [Environment]::SetEnvironmentVariable('R_LIBS_USER', $library, 'Process')
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
      Assert-Issue13V5NoConcurrentR
      $null = Assert-Issue13V5SmokeHarness $runtimeRoot `
        $harnessManifestPath $repository $harnessManifestSha256
      $null = & git -C $repository worktree add --detach $project $baselineCommit
      if ($LASTEXITCODE -ne 0) {
        throw "Cannot create baseline runtime worktree for $method."
      }
      $head = (& git -C $project rev-parse HEAD).Trim()
      if ($LASTEXITCODE -ne 0 -or $head -cne $baselineCommit) {
        throw "Baseline worktree commit differs for $method."
      }
      $tracked = @(& git -C $project status '--porcelain=v1' `
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
            (Get-Issue13V5Sha256 $to) -cne [string]$sourceRecord.sha256) {
          throw "Copied source file differs for $method/$relativeNative."
        }
      }
      $copiedInventory = Get-Issue13V5SourceInventory $targetSource
      Assert-Issue13V5SourceInventory $copiedInventory `
        "Copied source for $method"

      $null = New-Item -ItemType Directory -Path $methodEvidence
      $null = New-Item -ItemType Directory -Path $methodSpecs
      $channel = 'issue13-v5-smoke-b-' + $method.Replace('_', '-')
      $builder = Join-Path $harness 'issue13-build-calculate-bundle.R'
      & $rscriptFull --vanilla $builder `
        --arm baseline `
        --method $method `
        --workers 1 `
        --project-root $project `
        --runtime-commit $baselineCommit `
        --channel $channel `
        --output $methodSpecs `
        --evidence-root $methodEvidence `
        --rscript $rscriptFull `
        --r-library $library `
        --timeout-seconds 14400 | Out-Null
      if ($LASTEXITCODE -ne 0) {
        throw "Cannot build baseline smoke bundle for $method."
      }
      $null = Assert-Issue13V5SmokeHarness $runtimeRoot `
        $harnessManifestPath $repository $harnessManifestSha256
      $bundle = Get-Content -LiteralPath (
        Join-Path $methodSpecs 'bundle.json') -Raw |
        ConvertFrom-Json -DateKind String
      $monitor = Join-Path $harness 'issue13-monitor.ps1'
      & $monitor -SpecPath ([string]$bundle.process_spec) `
        -EvidenceDir ([string]$bundle.scenario_evidence) | Out-Null
      $monitorExitCode = $LASTEXITCODE
      $null = Assert-Issue13V5SmokeHarness $runtimeRoot `
        $harnessManifestPath $repository $harnessManifestSha256
      if ($monitorExitCode -ne 0) {
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
          -not [bool]$result.passed -or
          [string]$result.status -cne 'passed' -or
          [string]$result.expected_commit -cne $baselineCommit -or
          [string]$result.observed_commit -cne $baselineCommit -or
          [string]$result.kind -cne 'calculate' -or
          [string]$result.request.method -cne $method -or
          [long]$result.request.workers -ne 1L -or
          [string]$metrics.schema -cne 'wlv-issue13-process-metrics/2' -or
          [string]$metrics.scenario_id -cne $scenarioId -or
          -not [bool]$metrics.passed -or
          [string]$metrics.status -cne 'passed' -or
          -not [bool]$metrics.cluster_closed -or
          -not [bool]$metrics.worker_count_matched -or
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
            (Get-Issue13V5Sha256 $expectedPath) -cne
              [string]$telemetry[1]) {
          throw "Baseline smoke telemetry binding differs for $method."
        }
      }
      $finalHead = (& git -C $project rev-parse HEAD 2>$null).Trim()
      $finalTree = (& git -C $project rev-parse 'HEAD^{tree}' 2>$null).Trim()
      $finalTracked = @(& git -C $project status '--porcelain=v1' `
        '--untracked-files=no' 2>$null)
      if ($LASTEXITCODE -ne 0 -or $finalHead -cne $baselineCommit -or
          $finalTree -cne $expectedRuntimeTree -or $finalTracked.Count -ne 0) {
        throw "Baseline smoke worktree changed during execution for $method."
      }
      $afterInventory = Get-Issue13V5SourceInventory $targetSource
      Assert-Issue13V5SourceInventory $afterInventory `
        "Post-execution source for $method"
      if ([string]$afterInventory.inventory_sha256 -cne
          [string]$copiedInventory.inventory_sha256) {
        throw "Baseline smoke changed source_data for $method."
      }
      $status = 'passed'
      $resultSha = Get-Issue13V5Sha256 $resultPath
      $metricsSha = Get-Issue13V5Sha256 $metricsPath
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
} finally {
  [Environment]::SetEnvironmentVariable(
    'R_LIBS_USER', $previousLibrary, 'Process')
  foreach ($name in $localeEnvironmentNames) {
    Set-Item -LiteralPath ('Env:' + $name) `
      -Value $previousLocaleEnvironment[$name]
    if (-not [object]::Equals(
        [Environment]::GetEnvironmentVariable($name, 'Process'),
        $previousLocaleEnvironment[$name])) {
      throw "Cannot restore inherited locale variable after smoke: $name"
    }
  }
  $null = Assert-Issue13V5SmokeHarness $runtimeRoot `
    $harnessManifestPath $repository $harnessManifestSha256
}

Assert-Issue13V5NoConcurrentR
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
Write-Issue13V5Json $summary $summaryPath

[pscustomobject][ordered]@{
  status = [string]$summary.status
  summary_path = (Resolve-Path -LiteralPath $summaryPath).Path
  summary_sha256 = Get-Issue13V5Sha256 $summaryPath
  passed_count = $passedCount
  failed_count = 12 - $passedCount
}
if ($passedCount -ne 12) {
  throw "Baseline smoke failed for $([int](12 - $passedCount)) method(s)."
}
