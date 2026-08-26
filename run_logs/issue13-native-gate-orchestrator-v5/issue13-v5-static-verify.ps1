param(
  [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')]
  [string]$CandidateCommit,
  [string]$HarnessRuntimeRoot =
    'D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5',
  [string]$RepositoryRoot = 'D:\Trabalho\Code\wlvdb'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $PSScriptRoot).Path
. (Join-Path $root 'issue13-v5-coordinator-lib.ps1')

$scripts = @(
  'issue13-v5-baseline-smoke.ps1',
  'issue13-v5-materialize-harness.ps1',
  'issue13-v5-new-config.ps1',
  'issue13-v5-coordinator-lib.ps1',
  'issue13-v5-coordinator.ps1',
  'issue13-v5-render-report.ps1',
  'issue13-v5-static-verify.ps1'
)
$legacyGeneration = 'v' + '4'
$legacyPathNeedles = @(
  'issue13-native-gate-orchestrator-' + $legacyGeneration,
  'final-evidence-' + $legacyGeneration,
  'final-control-' + $legacyGeneration
)
$records = [Collections.Generic.List[object]]::new()
foreach ($name in $scripts) {
  $path = Join-Path $root $name
  $tokens = $null
  $errors = $null
  $ast = [Management.Automation.Language.Parser]::ParseFile(
    $path, [ref]$tokens, [ref]$errors)
  if ($errors.Count -ne 0) {
    throw "PowerShell parser rejected $name`: $($errors[0].Message)"
  }
  $commands = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst]
  }, $true))
  $dangerous = @($commands | Where-Object {
    [string]$_.GetCommandName() -cin @(
      'Invoke-Expression', 'iex', 'Remove-Item', 'Stop-Process',
      'Start-Job', 'Start-ThreadJob'
    )
  })
  if ($dangerous.Count -ne 0) {
    throw "Forbidden coordinator command appears in $name."
  }
  $text = [IO.File]::ReadAllText($path,
    [Text.UTF8Encoding]::new($false, $true))
  $legacyMatches = @($legacyPathNeedles | Where-Object {
    $text.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0
  })
  if ($legacyMatches.Count -ne 0) {
    throw "Coordinator depends on a legacy V4 path: $name"
  }
  $records.Add([ordered]@{
    name = $name
    sha256 = Get-Issue13V5Sha256 $path
    command_ast_count = [long]$commands.Count
  })
}

$coordinatorText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-coordinator.ps1'),
  [Text.UTF8Encoding]::new($false, $true))
foreach ($required in @(
    "'ValidateConfig'", "'PrepareWorktrees'", "'RunNext'", "'RunAll'",
    "'Aggregate'", "'Report'", 'Get-Issue13V5WorktreeBindings',
    'issue13-build-calculate-bundle.R', 'issue13-build-recalc-bundle.R',
    'issue13-build-paper-bundle.R', 'issue13-build-prep-fault-specs.R',
    'issue13-aggregate-prep-fault.R', 'issue13-aggregate.R',
    'issue13-v5-render-report.ps1', '162', '202',
    'Planned comparison output already exists:',
    'Planned prep/fault aggregate output already exists.',
    'Planned final aggregate output already exists.'
  )) {
  if (-not $coordinatorText.Contains($required)) {
    throw "Coordinator lacks required closed-gate binding: $required"
  }
}

$smokeText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-baseline-smoke.ps1'),
  [Text.UTF8Encoding]::new($false, $true))
foreach ($required in @(
    "'R.exe'", "'Rscript.exe'", "'Rterm.exe'", "'Rgui.exe'",
    "'Rcmd.exe'", "'Rfe.exe'",
    '$localeEnvironmentNames = @(''LANG'', ''LC_ALL'', ''LC_CTYPE'')',
    'Set-Item -LiteralPath (''Env:'' + $name) -Value $null',
    'environment_removed = [object[]]$localeEnvironmentNames'
  )) {
  if (-not $smokeText.Contains($required)) {
    throw "Baseline smoke lacks required R-process guard: $required"
  }
}

$libraryText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-coordinator-lib.ps1'),
  [Text.UTF8Encoding]::new($false, $true))
foreach ($required in @(
    "'R.exe'", "'Rscript.exe'", "'Rterm.exe'", "'Rgui.exe'",
    "'Rcmd.exe'", "'Rfe.exe'", 'Assert-Issue13V5ReportBinding',
    'roots must not be nested', '$process.Kill($true)',
    '$environmentRemoved = @(''LANG'', ''LC_ALL'', ''LC_CTYPE'')',
    '$info.Environment.Remove($name)',
    'environment_removed = [object[]]$environmentRemoved',
    'V5 commands cannot override sanitized locale variable',
    'Get-Issue13V5ConfiguredPaths', 'Test-Issue13V5LegacyPath'
  )) {
  if (-not $libraryText.Contains($required)) {
    throw "Coordinator library lacks required safety guard: $required"
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
  if ((Test-Issue13V5LegacyPath ([string]$case.path)) -ne
      [bool]$case.expected) {
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
if ($projectedPaths.Count -ne 19 -or
    $projectedLegacyPaths.Count -ne 3) {
  throw 'Configured path projection failed its static cases.'
}

$compareText = [IO.File]::ReadAllText(
  (Join-Path $root 'issue13-v5-compare-override.R'),
  [Text.UTF8Encoding]::new($false, $true))
foreach ($required in @(
    'results_root <- dirname(runs_root)',
    'project_root <- dirname(results_root)',
    'identical(basename(results_root), "results")',
    'identical(basename(runs_root), "runs")',
    'file.exists(file.path(project_root, "R", "bootstrap.R"))',
    'results/runs/<method>/<run_id>'
  )) {
  if (-not $compareText.Contains($required)) {
    throw "V5 compare override lacks structural runtime binding: $required"
  }
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
$expectedHarnessTotalBytes = 588671L
$expectedHarnessInventorySha256 =
  '0d5b7cfd4a9085afd9b9d196d4ac487853b41948981e3436e9d87811ef473ced'
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

[pscustomobject][ordered]@{
  status = 'passed'
  r_started = $false
  generation = 'v5'
  baseline_commit = $script:Issue13V5BaselineCommit
  baseline_runtime_commit = $script:Issue13V5BaselineRuntimeCommit
  baseline_policy = [string]$manifest.baseline_policy
  controller_files = [object[]]$records.ToArray()
  harness_file_count = [long]$inventory.file_count
  harness_inventory_sha256 = [string]$inventory.inventory_sha256
  expected_worktrees = 29
  expected_pairs = 76
  expected_scenarios = 162
  expected_comparisons = 202
  expected_faults = 10
}
