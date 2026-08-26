param(
  [Parameter(Mandatory = $true)]
  [ValidateSet(
    'ValidateConfig', 'Initialize', 'PrepareWorktrees', 'RunNext',
    'RunAll', 'Aggregate', 'Report', 'Status'
  )]
  [string]$Action,
  [Parameter(Mandatory = $true)][string]$ConfigPath,
  [switch]$ConfirmCreateWorktrees,
  [switch]$ConfirmExecuteR,
  [switch]$ConfirmWriteReport,
  [int]$CoolingSeconds = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
. (Join-Path $scriptRoot 'issue13-v5-coordinator-lib.ps1')

$canonicalActions = @(
  'ValidateConfig', 'Initialize', 'PrepareWorktrees', 'RunNext',
  'RunAll', 'Aggregate', 'Report', 'Status'
)
if ($Action -cnotin $canonicalActions) {
  throw 'Action must use canonical casing.'
}
if ($CoolingSeconds -lt 0 -or $CoolingSeconds -gt 300) {
  throw 'CoolingSeconds must be between zero and 300.'
}

function New-Issue13V5State(
  [object]$Binding,
  [object]$OracleControlBinding
) {
  $config = $Binding.config
  $phases = [Collections.Generic.List[object]]::new()
  $ordinal = 0L
  foreach ($phase in @($config.matrix.science_phases)) {
    $ordinal++
    $phases.Add([ordered]@{
      ordinal = $ordinal
      phase = [string]$phase.phase
      kind = [string]$phase.kind
      method = [string]$phase.method
      workers = [long]$phase.workers
      stage = $phase.stage
      variant = $phase.variant
      sea_vars = [object[]]@($phase.sea_vars)
      baseline_status = 'planned'
      baseline_evidence = $null
      baseline_result_sha256 = $null
      baseline_metrics_sha256 = $null
      candidate_status = 'planned'
      candidate_evidence = $null
      candidate_result_sha256 = $null
      candidate_metrics_sha256 = $null
      comparison_status = 'planned'
      comparisons = [object[]]@()
      pair_result_path = $null
      pair_result_sha256 = $null
      performance = $null
      completed_at_utc = $null
    })
  }
  foreach ($supplemental in @(
      [pscustomobject]@{ phase = 'prepare/all'; kind = 'prepare' },
      [pscustomobject]@{ phase = 'paper/0'; kind = 'paper0' }
    )) {
    $ordinal++
    $phases.Add([ordered]@{
      ordinal = $ordinal
      phase = [string]$supplemental.phase
      kind = [string]$supplemental.kind
      method = $null
      workers = 1L
      stage = $null
      variant = $null
      sea_vars = [object[]]@()
      baseline_status = 'planned'
      baseline_evidence = $null
      baseline_result_sha256 = $null
      baseline_metrics_sha256 = $null
      candidate_status = 'planned'
      candidate_evidence = $null
      candidate_result_sha256 = $null
      candidate_metrics_sha256 = $null
      comparison_status = 'planned'
      comparisons = [object[]]@()
      pair_result_path = $null
      pair_result_sha256 = $null
      performance = $null
      completed_at_utc = $null
    })
  }
  $worktrees = @(Get-Issue13V5WorktreeBindings $config | ForEach-Object {
    [ordered]@{
      id = [string]$_.id
      arm = [string]$_.arm
      kind = [string]$_.kind
      label = [string]$_.label
      root = ConvertTo-Issue13V5Path ([string]$_.root)
      commit = [string]$_.commit
      status = 'planned'
      setup_manifest_path = $null
      setup_manifest_sha256 = $null
    }
  })
  [pscustomobject][ordered]@{
    schema = 'wlv-issue13-v5-coordinator-state/1'
    generation = 'v5'
    status = 'initialized'
    revision = 0L
    config_path = [string]$Binding.path
    config_sha256 = [string]$Binding.sha256
    baseline_commit = $script:Issue13V5BaselineCommit
    baseline_runtime_commit = [string]$config.baseline_runtime_commit
    candidate_commit = [string]$config.candidate_commit
    coordinator_pins = [object[]](Get-Issue13V5CoordinatorPins $config)
    oracle_effect = [ordered]@{
      status = 'authenticated'
      control_record_path = [string]$OracleControlBinding.path
      control_record_sha256 = [string]$OracleControlBinding.sha256
      proof_sha256 = [string]$config.oracle_effect.proof.sha256
      comparison_inventory_sha256 =
        [string]$config.oracle_effect.comparisons.inventory.inventory_sha256
      strict_common_method_count = 5L
      recovered_method_count = 7L
      final_evidence_eligible = $false
      required_by_final_gate = $true
    }
    initialized_at_utc = [DateTime]::UtcNow.ToString('o')
    updated_at_utc = [DateTime]::UtcNow.ToString('o')
    worktrees = [object[]]$worktrees
    phases = [object[]]$phases.ToArray()
    prep_fault = [ordered]@{
      plan_status = 'planned'
      plan_directory = $null
      plan_path = $null
      plan_sha256 = $null
      plan_audit_path = $null
      plan_audit_sha256 = $null
      preparation_comparison_status = 'planned'
      preparation_comparison_path = $null
      preparation_comparison_sha256 = $null
      import_status = 'planned'
      import_report_path = $null
      import_report_sha256 = $null
      seed_plan_status = 'planned'
      seed_plan_path = $null
      seed_plan_sha256 = $null
      seeds_status = 'planned'
      seed_evidence = [object[]]@()
      faults = [object[]]@($config.matrix.faults | ForEach-Object {
        [ordered]@{
          fault_id = [string]$_
          scenario_id = 'candidate/fault/' + [string]$_
          status = 'planned'
          evidence = $null
          result_sha256 = $null
          metrics_sha256 = $null
        }
      })
      aggregate_status = 'planned'
      aggregate_path = $null
      aggregate_sha256 = $null
    }
    final_aggregate = [ordered]@{
      status = 'planned'
      path = $null
      sha256 = $null
      files = [object[]]@()
      evidence_inventory = $null
      command_inventory = $null
      prep_fault_aggregate_sha256 = $null
      preparation_comparison_sha256 = $null
      paper0_comparison_sha256 = $null
    }
    report = [ordered]@{
      status = 'planned'; path = $null; sha256 = $null
    }
  }
}

function Initialize-Issue13V5([object]$Binding) {
  $config = $Binding.config
  foreach ($rootName in @('worktree_root', 'evidence_root', 'control_root')) {
    $root = ConvertTo-Issue13V5Path ([string]$config.$rootName)
    if (Test-Path -LiteralPath $root) {
      throw "Initialize requires a fresh root: $root"
    }
  }
  $null = New-Item -ItemType Directory -Path ([string]$config.worktree_root)
  $null = New-Item -ItemType Directory -Path ([string]$config.evidence_root)
  $null = New-Item -ItemType Directory -Path ([string]$config.control_root)
  foreach ($path in @(
      (Join-Path ([string]$config.evidence_root) 'scenarios'),
      (Join-Path ([string]$config.evidence_root) 'comparisons'),
      (Join-Path ([string]$config.control_root) 'commands'),
      (Join-Path ([string]$config.control_root) 'setup'),
      (Join-Path ([string]$config.control_root) 'attempts'),
      (Join-Path ([string]$config.control_root) 'pair-results')
    )) {
    $null = New-Item -ItemType Directory -Path $path
  }
  $oracleControlPath = Join-Path ([string]$config.control_root) `
    'oracle-effect-validation.json'
  $oracleControlRecord = New-Issue13V5OracleEffectControlRecord $config `
    ([string]$Binding.sha256) $Binding.oracle_effect_validation
  $oracleControlSha256 = Write-Issue13V5Json $oracleControlRecord `
    $oracleControlPath
  $oracleControlBinding = [pscustomobject]@{
    path = (Resolve-Path -LiteralPath $oracleControlPath).Path
    sha256 = $oracleControlSha256
  }
  $state = New-Issue13V5State $Binding $oracleControlBinding
  $null = Write-Issue13V5Json $state (Get-Issue13V5StatePath $config)
  Read-Issue13V5State $config $Binding.sha256
}

function Copy-Issue13V5PreparationCaches(
  [object]$Config,
  [string]$ProjectRoot
) {
  $target = Join-Path $ProjectRoot 'source_data'
  if (Test-Path -LiteralPath $target) {
    throw "Preparation source_data already exists: $target"
  }
  $staging = Join-Path $ProjectRoot (
    '.issue13-v5-preparation-staging-' + [Guid]::NewGuid().ToString('N'))
  $null = New-Item -ItemType Directory -Path $staging
  foreach ($cache in @($script:Issue13V5PreparationCaches)) {
    $source = Join-Path ([string]$Config.source_origin) $cache.relative_path
    $destination = Join-Path $staging $cache.relative_path
    $parent = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
      $null = New-Item -ItemType Directory -Path $parent
    }
    if ((Get-Item -LiteralPath $source).Length -ne $cache.size_bytes -or
        (Get-Issue13V5Sha256 $source) -cne $cache.sha256) {
      throw "Official preparation cache changed: $($cache.relative_path)"
    }
    Copy-Item -LiteralPath $source -Destination $destination
    if ((Get-Issue13V5Sha256 $destination) -cne $cache.sha256) {
      throw "Copied preparation cache differs: $($cache.relative_path)"
    }
  }
  $null = Assert-Issue13V5SourceInventory $Config $staging -PreparationOnly
  [IO.Directory]::Move($staging, $target)
  Assert-Issue13V5SourceInventory $Config $target -PreparationOnly
}

function Assert-Issue13V5WorktreeSetup(
  [object]$Config,
  [object]$Record,
  [switch]$Deep,
  [switch]$Fresh
) {
  $git = Assert-Issue13V5GitWorktree $Record.root $Record.commit
  if ($Fresh) {
    foreach ($forbidden in @('results')) {
      if (Test-Path -LiteralPath (Join-Path $Record.root $forbidden)) {
        throw "Fresh V5 worktree contains transaction/output state: $($Record.id)"
      }
    }
    $null = Assert-Issue13V5NoTransactionResidue $Record.root
  }
  $source = $null
  if ([string]$Record.kind -ceq 'fault') {
    if ($Fresh -and
        (Test-Path -LiteralPath (Join-Path $Record.root 'source_data'))) {
      throw 'Fresh fault worktree must not contain source_data.'
    }
  } elseif ($Deep -and ([string]$Record.kind -ceq 'full' -or $Fresh)) {
    $source = Assert-Issue13V5SourceInventory $Config `
      (Join-Path $Record.root 'source_data') `
      -Arm ([string]$Record.arm) `
      -PreparationOnly:([string]$Record.kind -ceq 'preparation')
  }
  [pscustomobject]@{ git = $git; source = $source }
}

function Prepare-Issue13V5Worktrees(
  [object]$Binding,
  [object]$State
) {
  if (-not $ConfirmCreateWorktrees) {
    throw 'PrepareWorktrees requires -ConfirmCreateWorktrees.'
  }
  $config = $Binding.config
  $scientificStarted = @($State.phases | Where-Object {
    [string]$_.baseline_status -cne 'planned' -or
      [string]$_.candidate_status -cne 'planned' -or
      [string]$_.comparison_status -cne 'planned'
  }).Count -ne 0
  if ([string]$State.status -cnotin @('initialized', 'worktrees-prepared') -or
      $scientificStarted) {
    throw 'PrepareWorktrees is not valid after scientific execution.'
  }
  $null = Assert-Issue13V5NoConcurrentR $config
  foreach ($record in @($State.worktrees)) {
    if ([string]$record.status -ceq 'completed') {
      $null = Assert-Issue13V5WorktreeSetup $config $record -Deep -Fresh
      continue
    }
    if ([string]$record.status -cne 'planned') {
      throw "Unknown worktree setup status: $($record.id)"
    }
    if (Test-Path -LiteralPath $record.root) {
      throw "Unrecorded V5 worktree path already exists: $($record.root)"
    }
    $null = Invoke-Issue13V5External $config `
      (Get-Command git.exe -ErrorAction Stop).Source `
      @('-C', [string]$config.repository_root, 'worktree', 'add', '--detach',
        [string]$record.root, [string]$record.commit) `
      ('setup/worktree/' + [string]$record.id) 600 @(0) `
      ([string]$config.repository_root)
    $null = Assert-Issue13V5GitWorktree $record.root $record.commit
    $sourceInventory = $null
    if ([string]$record.kind -ceq 'full') {
      $sourceBinding = Get-Issue13V5SourceBinding $config `
        ([string]$record.arm)
      $sourceInventory = Copy-Issue13V5WriteOnceTree `
        ([string]$sourceBinding.origin) (Join-Path $record.root 'source_data')
      $null = Assert-Issue13V5SourceInventory $config `
        (Join-Path $record.root 'source_data') -Arm ([string]$record.arm)
    } elseif ([string]$record.kind -ceq 'preparation') {
      $sourceInventory = Copy-Issue13V5PreparationCaches $config $record.root
    }
    $verified = Assert-Issue13V5WorktreeSetup $config $record -Deep -Fresh
    if ([string]$record.kind -cne 'fault') {
      $physicalSource = if ([string]$record.kind -ceq 'preparation') {
        [string]$config.source_origin
      } else {
        [string](Get-Issue13V5SourceBinding $config `
          ([string]$record.arm)).origin
      }
      $null = Assert-Issue13V5PhysicalCopy `
        $physicalSource (Join-Path $record.root 'source_data') `
        $verified.source
    }
    $manifest = [ordered]@{
      schema = 'wlv-issue13-v5-worktree-setup/1'
      id = [string]$record.id
      arm = [string]$record.arm
      kind = [string]$record.kind
      root = (Resolve-Path -LiteralPath $record.root).Path
      commit = [string]$record.commit
      tree = [string]$verified.git.tree
      source_origin = if ([string]$record.kind -ceq 'full') {
        [string](Get-Issue13V5SourceBinding $config `
          ([string]$record.arm)).origin
      } else {
        [string]$config.source_origin
      }
      source_inventory = $verified.source
      physical_copy_distinct = [string]$record.kind -cne 'fault'
      prepared_at_utc = [DateTime]::UtcNow.ToString('o')
    }
    $manifestPath = Join-Path (Join-Path ([string]$config.control_root) `
      'setup') ((Get-Issue13V5SafeId $record.id) + '.json')
    $null = Write-Issue13V5Json $manifest $manifestPath
    $record.setup_manifest_path = (Resolve-Path -LiteralPath $manifestPath).Path
    $record.setup_manifest_sha256 = Get-Issue13V5Sha256 $manifestPath
    $record.status = 'completed'
    Save-Issue13V5State $config $State
    $null = Assert-Issue13V5NoConcurrentR $config
  }
  $expectedRoots = @($State.worktrees.root | ForEach-Object {
    [IO.Path]::GetFileName([string]$_)
  } | Sort-Object)
  $actualRoots = @(Get-ChildItem -LiteralPath $config.worktree_root `
    -Directory -Force | ForEach-Object Name | Sort-Object)
  if ($actualRoots.Count -ne 29 -or
      [string]::Join("`n", $actualRoots) -cne
        [string]::Join("`n", $expectedRoots)) {
    throw 'Worktree root does not contain exactly the 29 configured roots.'
  }
  $State.status = 'worktrees-prepared'
  Save-Issue13V5State $config $State
  $State
}

function Assert-Issue13V5AllWorktrees(
  [object]$Config,
  [object]$State,
  [switch]$Deep
) {
  if (@($State.worktrees | Where-Object status -cne 'completed').Count -ne 0) {
    throw 'All 29 worktrees must be prepared first.'
  }
  foreach ($record in @($State.worktrees)) {
    $null = Assert-Issue13V5WorktreeSetup $Config $record -Deep:$Deep
    if ((Get-Issue13V5Sha256 $record.setup_manifest_path) -cne
        [string]$record.setup_manifest_sha256) {
      throw "Worktree setup manifest changed: $($record.id)"
    }
  }
  $true
}

function Get-Issue13V5PhaseBinding(
  [object]$Config,
  [object]$Phase,
  [string]$Arm
) {
  $commit = if ($Arm -ceq 'baseline') {
    [string]$Config.baseline_runtime_commit
  } else { [string]$Config.candidate_commit }
  $root = switch ([string]$Phase.kind) {
    'prepare' {
      [string]$Config.supplemental_roots.($Arm + '_preparation')
    }
    'paper0' {
      [string]$Config.supplemental_roots.($Arm + '_paper0')
    }
    default {
      $method = @($Config.methods | Where-Object {
        [string]$_.method -ceq [string]$Phase.method
      })
      if ($method.Count -ne 1) {
        throw "Method binding is missing: $($Phase.method)"
      }
      [string]$method[0].$Arm
    }
  }
  [pscustomobject]@{ root = $root; commit = $commit }
}

function Get-Issue13V5Channel([object]$Config, [string]$ScenarioId) {
  $digest = Get-Issue13V5TextSha256 (
    [string]$Config.candidate_commit + '|' + $ScenarioId)
  'issue13-v5-' + $digest.Substring(0, 24)
}

function Get-Issue13V5RequiredFreeMemory(
  [object]$Phase,
  [string]$Arm
) {
  $floor = if ([long]$Phase.workers -eq 2L) { 64GB } else { 40GB }
  if ($Arm -ceq 'baseline' -or
      [string]::IsNullOrWhiteSpace([string]$Phase.baseline_evidence)) {
    return [int64]$floor
  }
  $metrics = Read-Issue13V5Json (Join-Path `
    ([string]$Phase.baseline_evidence) 'process-metrics.json')
  $baselineRss = [double]$metrics.peak_rss_bytes
  $rssLimit = $baselineRss + [Math]::Max($baselineRss * 0.10, 512MB)
  [int64][Math]::Ceiling([Math]::Max([double]$floor, $rssLimit + 20GB))
}

function Ensure-Issue13V5PrepFaultPlan(
  [object]$Config,
  [object]$State
) {
  $workflow = $State.prep_fault
  $root = Join-Path ([string]$Config.control_root) 'prep-fault-plan'
  $planPath = Join-Path $root 'plan.json'
  $auditPath = Join-Path $root 'plan-audit.json'
  if ([string]$workflow.plan_status -ceq 'planned') {
    if (Test-Path -LiteralPath $root) {
      throw 'Unrecorded prep/fault plan directory already exists.'
    }
    $null = Invoke-Issue13V5R $Config @(
      '--vanilla', (Join-Path ([string]$Config.harness_root) `
        'issue13-build-prep-fault-specs.R'),
      '--output-root', $root,
      '--baseline-root', [string]$Config.supplemental_roots.baseline_preparation,
      '--baseline-commit', [string]$Config.baseline_runtime_commit,
      '--candidate-root', [string]$Config.supplemental_roots.candidate_preparation,
      '--candidate-commit', [string]$Config.candidate_commit,
      '--fault-root', [string]$Config.supplemental_roots.candidate_fault,
      '--r-library', [string]$Config.r_library,
      '--channel-prefix', ('issue13-v5-pf-' +
        ([string]$Config.candidate_commit).Substring(0, 8) + '-')
    ) 'prep-fault/build-plan' 900 -ConfirmExecuteR:$ConfirmExecuteR
    $null = Invoke-Issue13V5R $Config @(
      '--vanilla', (Join-Path ([string]$Config.harness_root) `
        'issue13-audit-prep-fault-plan.R'), $planPath
    ) 'prep-fault/audit-plan' 900 -ConfirmExecuteR:$ConfirmExecuteR
    $plan = Read-Issue13V5Json $planPath
    $audit = Read-Issue13V5Json $auditPath
    if ([string]$plan.schema -cne 'wlv-issue13-prep-fault-plan/2' -or
        @($plan.records).Count -ne 12 -or
        [string]$audit.schema -cne
          'wlv-issue13-prep-fault-plan-audit/2' -or
        -not (Test-Issue13V5ExactBoolean $audit.passed $true) -or
        [string]$audit.status -cne 'passed' -or
        [string]$audit.plan_sha256 -cne (Get-Issue13V5Sha256 $planPath)) {
      throw 'Preparation/fault plan or independent audit failed.'
    }
    $workflow.plan_directory = (Resolve-Path -LiteralPath $root).Path
    $workflow.plan_path = (Resolve-Path -LiteralPath $planPath).Path
    $workflow.plan_sha256 = Get-Issue13V5Sha256 $planPath
    $workflow.plan_audit_path = (Resolve-Path -LiteralPath $auditPath).Path
    $workflow.plan_audit_sha256 = Get-Issue13V5Sha256 $auditPath
    $workflow.plan_status = 'built'
    Save-Issue13V5State $Config $State
  }
  $plan = Read-Issue13V5Json $planPath
  $audit = Read-Issue13V5Json $auditPath
  if ((Get-Issue13V5Sha256 $planPath) -cne [string]$audit.plan_sha256 -or
      (Get-Issue13V5Sha256 $planPath) -cne [string]$workflow.plan_sha256 -or
      (Get-Issue13V5Sha256 $auditPath) -cne
        [string]$workflow.plan_audit_sha256) {
    throw 'Preparation/fault plan changed after audit.'
  }
  [pscustomobject]@{
    root = $root; plan_path = $planPath; audit_path = $auditPath; plan = $plan
  }
}

function Invoke-Issue13V5PreparationArm(
  [object]$Config,
  [object]$State,
  [object]$Phase,
  [string]$Arm
) {
  $plan = Ensure-Issue13V5PrepFaultPlan $Config $State
  $scenarioId = "$Arm/prepare/all"
  $record = @($plan.plan.records | Where-Object {
    [string]$_.scenario_id -ceq $scenarioId
  })
  if ($record.Count -ne 1) {
    throw "Prep/fault plan lacks scenario: $scenarioId"
  }
  $source = [string]$record[0].evidence_directory
  $destination = Get-Issue13V5ScenarioDirectory $Config $scenarioId
  if ((Test-Path -LiteralPath $source) -or
      (Test-Path -LiteralPath $destination)) {
    throw "Planned preparation output already exists: $scenarioId"
  }
  $requiredMemory = Get-Issue13V5RequiredFreeMemory $Phase $Arm
  $null = Wait-Issue13V5CoolState $Config $CoolingSeconds $requiredMemory
  $null = Invoke-Issue13V5Pwsh $Config @(
    '-NoLogo', '-NoProfile', '-File',
    (Join-Path ([string]$Config.harness_root) `
      'issue13-run-prep-fault-record.ps1'),
    '-PlanPath', [string]$plan.plan_path,
    '-ScenarioId', $scenarioId
  ) ("prepare/$Arm") 30000 -ConfirmExecuteR:$ConfirmExecuteR
  $binding = Get-Issue13V5PhaseBinding $Config $Phase $Arm
  $validated = Assert-Issue13V5ScenarioEvidence $source $scenarioId `
    $binding.commit 0
  $null = Copy-Issue13V5WriteOnceTree $source $destination
  $final = Assert-Issue13V5ScenarioEvidence $destination $scenarioId `
    $binding.commit 0
  $null = Assert-Issue13V5NoTransactionResidue $binding.root
  [pscustomobject]@{
    source = $destination
    validation = $final
  }
}

function Invoke-Issue13V5OrdinaryArm(
  [object]$Config,
  [object]$State,
  [object]$Phase,
  [string]$Arm
) {
  $scenarioId = "$Arm/$($Phase.phase)"
  $binding = Get-Issue13V5PhaseBinding $Config $Phase $Arm
  $null = Assert-Issue13V5GitWorktree $binding.root $binding.commit
  $sourceBefore = Assert-Issue13V5SourceInventory $Config `
    (Join-Path $binding.root 'source_data') -Arm $Arm
  $attemptRoot = Join-Path (Join-Path ([string]$Config.control_root) `
    'attempts') (Get-Issue13V5SafeId $scenarioId)
  $specRoot = Join-Path $attemptRoot 'specs'
  $attemptEvidence = Join-Path $attemptRoot 'evidence'
  $scenarioSource = Join-Path (Join-Path $attemptEvidence 'scenarios') `
    (Get-Issue13V5SafeId $scenarioId)
  $scenarioDirectory = Get-Issue13V5ScenarioDirectory $Config $scenarioId
  $specExists = Test-Path -LiteralPath $specRoot -PathType Container
  $evidenceExists = Test-Path -LiteralPath $scenarioSource `
    -PathType Container
  if ((Test-Path -LiteralPath $attemptRoot) -or
      (Test-Path -LiteralPath $specRoot) -or
      (Test-Path -LiteralPath $scenarioSource) -or
      (Test-Path -LiteralPath $scenarioDirectory)) {
    throw "Planned scenario output already exists: $scenarioId"
  }
  if ((Test-Path -LiteralPath $specRoot) -and -not $specExists) {
    throw "Scenario specs path is not a directory: $scenarioId"
  }
  if ((Test-Path -LiteralPath $scenarioSource) -and -not $evidenceExists) {
    throw "Scenario evidence path is not a directory: $scenarioId"
  }
  if ($evidenceExists -and -not $specExists) {
    throw "Scenario evidence exists without its specs: $scenarioId"
  }
  $builder = switch ([string]$Phase.kind) {
    'calculate' { 'issue13-build-calculate-bundle.R' }
    'paper0' { 'issue13-build-paper-bundle.R' }
    'recalculate' { 'issue13-build-recalc-bundle.R' }
    default { throw "Unknown ordinary phase kind: $($Phase.kind)" }
  }
  $channel = Get-Issue13V5Channel $Config $scenarioId
  $arguments = @(
    '--vanilla', (Join-Path ([string]$Config.harness_root) $builder),
    '--arm', $Arm,
    '--project-root', [string]$binding.root,
    '--runtime-commit', [string]$binding.commit,
    '--channel', $channel,
    '--output', $specRoot,
    '--evidence-root', $attemptEvidence,
    '--rscript', [string]$Config.rscript,
    '--r-library', [string]$Config.r_library,
    '--timeout-seconds', $(if ([string]$Phase.kind -ceq 'paper0') {
      '21600'
    } else { '14400' })
  )
  if ([string]$Phase.kind -ceq 'calculate') {
    $arguments += @('--method', [string]$Phase.method,
      '--workers', [string]$Phase.workers)
  } elseif ([string]$Phase.kind -ceq 'recalculate') {
    $seedId = "$Arm/calculate/$($Phase.method)/workers1"
    $seedResult = Join-Path (
      Get-Issue13V5ScenarioDirectory $Config $seedId) 'scenario-result.json'
    if (-not (Test-Path -LiteralPath $seedResult -PathType Leaf)) {
      throw "Recalculation seed scenario is missing: $seedId"
    }
    $arguments += @(
      '--method', [string]$Phase.method,
      '--stage', [string]$Phase.stage,
      '--variant', [string]$Phase.variant,
      '--seed-commit', [string]$binding.commit,
      '--seed-result', $seedResult
    )
  }
  if (-not $specExists) {
    $null = Invoke-Issue13V5R $Config $arguments `
      ("build/$scenarioId") 900 -ConfirmExecuteR:$ConfirmExecuteR
    $specExists = $true
  }
  $bundlePath = Join-Path $specRoot 'bundle.json'
  $bundle = Read-Issue13V5Json $bundlePath
  if ([string]$bundle.scenario_id -cne $scenarioId -or
      [string]$bundle.runtime_commit -cne [string]$binding.commit -or
      [string]$bundle.channel -cne $channel -or
      -not [string]::Equals(
        (ConvertTo-Issue13V5Path ([string]$bundle.scenario_evidence)),
        (ConvertTo-Issue13V5Path $scenarioSource),
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Scenario bundle identity differs: $scenarioId"
  }
  if (-not $evidenceExists) {
    $requiredMemory = Get-Issue13V5RequiredFreeMemory $Phase $Arm
    $null = Wait-Issue13V5CoolState $Config $CoolingSeconds $requiredMemory
    if ([string]$Phase.kind -ceq 'recalculate') {
      $null = Invoke-Issue13V5Pwsh $Config @(
        '-NoLogo', '-NoProfile', '-File',
        (Join-Path ([string]$Config.harness_root) `
          'issue13-run-recalc-bundle.ps1'),
        '-BundlePath', $bundlePath
      ) ("execute/$scenarioId") 15000 -ConfirmExecuteR:$ConfirmExecuteR
    } else {
      $outerTimeout = if ([string]$Phase.kind -ceq 'paper0') {
        22500
      } else { 15000 }
      $null = Invoke-Issue13V5Pwsh $Config @(
        '-NoLogo', '-NoProfile', '-File',
        (Join-Path ([string]$Config.harness_root) 'issue13-monitor.ps1'),
        '-SpecPath', [string]$bundle.process_spec,
        '-EvidenceDir', [string]$bundle.scenario_evidence
      ) ("execute/$scenarioId") $outerTimeout `
        -ConfirmExecuteR:$ConfirmExecuteR
    }
  }
  $expectedWorkers = if ([string]$Phase.kind -ceq 'calculate' -and
      [long]$Phase.workers -eq 2L) { 2 } else { 0 }
  $validated = Assert-Issue13V5ScenarioEvidence $scenarioSource `
    $scenarioId $binding.commit $expectedWorkers
  if (-not (Test-Path -LiteralPath $scenarioDirectory -PathType Container)) {
    if (Test-Path -LiteralPath $scenarioDirectory) {
      throw "Final scenario evidence is not a directory: $scenarioId"
    }
    $null = Copy-Issue13V5WriteOnceTree $scenarioSource $scenarioDirectory
  }
  $finalValidation = Assert-Issue13V5ScenarioEvidence $scenarioDirectory `
    $scenarioId $binding.commit $expectedWorkers
  $null = Assert-Issue13V5NoTransactionResidue $binding.root
  $sourceAfter = Assert-Issue13V5SourceInventory $Config `
    (Join-Path $binding.root 'source_data') -Arm $Arm
  if ($sourceBefore.inventory_sha256 -cne $sourceAfter.inventory_sha256 -or
      $sourceBefore.directory_list_sha256 -cne
        $sourceAfter.directory_list_sha256) {
    throw "Scientific scenario changed official inputs: $scenarioId"
  }
  [pscustomobject]@{
    source = $scenarioDirectory
    validation = $finalValidation
  }
}

function Invoke-Issue13V5Arm(
  [object]$Config,
  [object]$State,
  [object]$Phase,
  [string]$Arm
) {
  if ([string]$Phase.kind -ceq 'prepare') {
    Invoke-Issue13V5PreparationArm $Config $State $Phase $Arm
  } else {
    Invoke-Issue13V5OrdinaryArm $Config $State $Phase $Arm
  }
}

function Invoke-Issue13V5Comparison(
  [object]$Config,
  [string]$Id,
  [string]$CandidateResult,
  [string]$CandidateSelector,
  [string]$BaselineResult,
  [string]$BaselineSelector,
  [string]$Mode,
  [switch]$AllowDifference
) {
  $output = Get-Issue13V5ComparisonDirectory $Config $Id
  if (Test-Path -LiteralPath $output) {
    throw "Planned comparison output already exists: $Id"
  }
  $expectedCodes = if ($AllowDifference) { @(0, 1) } else { @(0) }
  $null = Invoke-Issue13V5R $Config @(
    '--vanilla', (Join-Path ([string]$Config.harness_root) `
      'issue13-compare-results.R'),
    '--candidate-result', $CandidateResult,
    '--candidate-selector', $CandidateSelector,
    '--baseline-result', $BaselineResult,
    '--baseline-selector', $BaselineSelector,
    '--output', $output,
    '--scenario-id', $Id,
    '--comparison-mode', $Mode,
    '--chunk-rows', '1000000'
  ) ("compare/$Id") 21600 $expectedCodes `
    -ConfirmExecuteR:$ConfirmExecuteR
  $documentPath = Join-Path $output 'comparison.json'
  $document = Read-Issue13V5Json $documentPath
  $selectOutput = {
    param([object]$Scenario, [string]$Selector)
    $pieces = $Selector.Split(':')
    $kind = [string]$pieces[0]
    $qualifier = if ($pieces.Count -eq 2) { [string]$pieces[1] } else { $null }
    $matches = @($Scenario.outputs | Where-Object {
      [string]$_.kind -ceq $kind -and
        ($null -eq $qualifier -or [string]$_.method -ceq $qualifier -or
          [string]$_.source -ceq $qualifier)
    })
    if ($matches.Count -ne 1) {
      throw "Comparison selector is not unique: $Selector"
    }
    $matches[0]
  }
  $expectedCandidate = & $selectOutput (Read-Issue13V5Json $CandidateResult) `
    $CandidateSelector
  $expectedBaseline = & $selectOutput (Read-Issue13V5Json $BaselineResult) `
    $BaselineSelector
  if ([string]$document.scenario_id -cne $Id -or
      [string]$document.comparison_mode -cne $Mode -or
      [string]$document.candidate.manifest_sha256 -cne
        [string]$expectedCandidate.manifest_sha256 -or
      [string]$document.baseline.manifest_sha256 -cne
        [string]$expectedBaseline.manifest_sha256 -or
      -not ((Test-Issue13V5ExactBoolean $document.passed $true) -or
        (Test-Issue13V5ExactBoolean $document.passed $false)) -or
      (-not $AllowDifference -and
        -not (Test-Issue13V5ExactBoolean $document.passed $true))) {
    throw "Comparison result is invalid: $Id"
  }
  [pscustomobject][ordered]@{
    id = $Id
    directory = (Resolve-Path -LiteralPath $output).Path
    comparison_sha256 = Get-Issue13V5Sha256 $documentPath
    passed = $document.passed
    allow_difference = $AllowDifference.IsPresent
  }
}

function Ensure-Issue13V5PreparationSemanticComparison(
  [object]$Config,
  [object]$State,
  [object]$Phase
) {
  $workflow = $State.prep_fault
  if ([string]$workflow.preparation_comparison_status -ceq 'passed') {
    if ((Get-Issue13V5Sha256 $workflow.preparation_comparison_path) -cne
        [string]$workflow.preparation_comparison_sha256) {
      throw 'Preparation semantic comparison changed.'
    }
    return
  }
  $plan = Ensure-Issue13V5PrepFaultPlan $Config $State
  $output = Join-Path ([string]$Config.control_root) 'preparation-comparison'
  $baseline = [string]$Phase.baseline_evidence
  $candidate = [string]$Phase.candidate_evidence
  if (Test-Path -LiteralPath $output) {
    throw 'Planned preparation comparison output already exists.'
  }
  $null = Invoke-Issue13V5R $Config @(
    '--vanilla', (Join-Path (Split-Path -Parent ([string]$Config.harness_root)) `
      'issue13-preparation-compare.R'),
    [string]$Config.supplemental_roots.baseline_preparation,
    [string]$Config.supplemental_roots.candidate_preparation,
    $output,
    [string]$Config.baseline_runtime_commit,
    [string]$Config.candidate_commit,
    '1000000',
    (Join-Path $baseline 'process-metrics.json'),
    (Join-Path $candidate 'process-metrics.json'),
    (Join-Path $baseline 'scenario-result.json'),
    (Join-Path $candidate 'scenario-result.json'),
    [string]$Config.r_library,
    [string]$plan.plan_path
  ) 'prepare/semantic-comparison' 21600 `
    -ConfirmExecuteR:$ConfirmExecuteR
  $reportPath = Join-Path $output 'issue13-preparation-comparison.json'
  $report = Read-Issue13V5Json $reportPath
  if ([string]$report.status -cne 'passed') {
    throw 'Bitwise preparation comparison failed.'
  }
  $workflow.preparation_comparison_status = 'passed'
  $workflow.preparation_comparison_path =
    (Resolve-Path -LiteralPath $reportPath).Path
  $workflow.preparation_comparison_sha256 = Get-Issue13V5Sha256 $reportPath
  Save-Issue13V5State $Config $State
}

function Complete-Issue13V5Pair(
  [object]$Config,
  [object]$State,
  [object]$Phase
) {
  $null = Assert-Issue13V5PhaseEvidenceState $Config $Phase
  $pairRequiredMemory = if ([long]$Phase.workers -eq 2L) { 64GB } else { 40GB }
  $null = Wait-Issue13V5CoolState $Config $CoolingSeconds `
    ([int64]$pairRequiredMemory)
  $baselineResult = Join-Path $Phase.baseline_evidence 'scenario-result.json'
  $candidateResult = Join-Path $Phase.candidate_evidence 'scenario-result.json'
  $baselineMetrics = Assert-Issue13V5ScenarioEvidence `
    $Phase.baseline_evidence ("baseline/$($Phase.phase)") `
    ([string]$Config.baseline_runtime_commit) `
    $(if ([string]$Phase.kind -ceq 'calculate' -and
        [long]$Phase.workers -eq 2) { 2 } else { 0 })
  $candidateMetrics = Assert-Issue13V5ScenarioEvidence `
    $Phase.candidate_evidence ("candidate/$($Phase.phase)") `
    ([string]$Config.candidate_commit) `
    $(if ([string]$Phase.kind -ceq 'calculate' -and
        [long]$Phase.workers -eq 2) { 2 } else { 0 })
  $performance = Assert-Issue13V5Performance $Config $baselineMetrics `
    $candidateMetrics ([string]$Phase.phase)
  $records = [Collections.Generic.List[object]]::new()
  if ([string]$Phase.kind -ceq 'prepare') {
    Ensure-Issue13V5PreparationSemanticComparison $Config $State $Phase
    foreach ($selector in @(
        @('wiodr13', 'source:wiodr13'),
        @('wiodr16', 'source:wiodr16'),
        @('euklems', 'snapshot:euklems')
      )) {
      $records.Add((Invoke-Issue13V5Comparison $Config `
        ('parity/prepare/' + $selector[0]) $candidateResult $selector[1] `
        $baselineResult $selector[1] `
        $(if ($selector[0] -ceq 'euklems') {
          'strict'
        } else {
          'cross_engine_source_v1'
        })))
    }
  } elseif ([string]$Phase.kind -ceq 'paper0') {
    $records.Add((Invoke-Issue13V5Comparison $Config 'parity/paper/0' `
      $candidateResult 'release' $baselineResult 'release' 'strict'))
  } else {
    $selector = 'run:' + [string]$Phase.method
    $records.Add((Invoke-Issue13V5Comparison $Config `
      ('parity/' + [string]$Phase.phase) $candidateResult $selector `
      $baselineResult $selector 'cross_engine_run_v3'))
  }
  if ([string]$Phase.kind -ceq 'recalculate') {
    foreach ($arm in @('baseline', 'candidate')) {
      $child = if ($arm -ceq 'baseline') { $baselineResult } else {
        $candidateResult
      }
      $fullId = "$arm/calculate/$($Phase.method)/workers1"
      $full = Join-Path (Get-Issue13V5ScenarioDirectory $Config $fullId) `
        'scenario-result.json'
      $selector = 'run:' + [string]$Phase.method
      $records.Add((Invoke-Issue13V5Comparison $Config `
        ("oracle/$arm/$($Phase.phase)") $child $selector $full $selector `
        'strict' -AllowDifference))
    }
  }
  if ([string]$Phase.kind -ceq 'calculate' -and
      [long]$Phase.workers -eq 2) {
    foreach ($arm in @('baseline', 'candidate')) {
      $worker2 = if ($arm -ceq 'baseline') { $baselineResult } else {
        $candidateResult
      }
      $worker1Id = "$arm/calculate/$($Phase.method)/workers1"
      $worker1 = Join-Path (Get-Issue13V5ScenarioDirectory $Config `
        $worker1Id) 'scenario-result.json'
      $selector = 'run:' + [string]$Phase.method
      $id = "equivalence/$arm/calculate/$($Phase.method)/workers2-vs-workers1"
      $records.Add((Invoke-Issue13V5Comparison $Config $id $worker2 `
        $selector $worker1 $selector 'strict'))
    }
  }
  $pair = [ordered]@{
    schema = 'wlv-issue13-v5-pair/1'
    ordinal = [long]$Phase.ordinal
    phase = [string]$Phase.phase
    status = 'passed'
    performance = $performance
    comparisons = [object[]]$records.ToArray()
    completed_at_utc = [DateTime]::UtcNow.ToString('o')
  }
  $pairPath = Join-Path (Join-Path ([string]$Config.control_root) `
    'pair-results') ('p' + ([long]$Phase.ordinal).ToString('000') + '.json')
  if (Test-Path -LiteralPath $pairPath) {
    throw "Planned pair result already exists: $($Phase.phase)"
  }
  $pairSha256 = Write-Issue13V5Json $pair $pairPath
  $Phase.performance = $performance
  $Phase.comparisons = [object[]]$records.ToArray()
  $Phase.pair_result_path = (Resolve-Path -LiteralPath $pairPath).Path
  $Phase.pair_result_sha256 = $pairSha256
  $Phase.comparison_status = 'completed'
  $Phase.completed_at_utc = [DateTime]::UtcNow.ToString('o')
  $null = Assert-Issue13V5PhaseEvidenceState $Config $Phase `
    -RequireCompletedComparison
  Save-Issue13V5State $Config $State
  $pair
}

function Invoke-Issue13V5NextPhase(
  [object]$Config,
  [object]$State
) {
  $phase = @($State.phases | Sort-Object ordinal | Where-Object {
    [string]$_.comparison_status -cne 'completed'
  } | Select-Object -First 1)
  if ($phase.Count -eq 0) { return $null }
  $phase = $phase[0]
  foreach ($arm in @('baseline', 'candidate')) {
    $statusName = $arm + '_status'
    $evidenceName = $arm + '_evidence'
    $resultHashName = $arm + '_result_sha256'
    $metricsHashName = $arm + '_metrics_sha256'
    if ([string]$phase.$statusName -ceq 'planned') {
      $execution = Invoke-Issue13V5Arm $Config $State $phase $arm
      $phase.$evidenceName = (Resolve-Path -LiteralPath $execution.source).Path
      $phase.$resultHashName = [string]$execution.validation.result_sha256
      $phase.$metricsHashName = [string]$execution.validation.metrics_sha256
      $phase.$statusName = 'executed'
      Save-Issue13V5State $Config $State
      return [pscustomobject]@{
        status = "$arm-executed"
        phase = [string]$phase.phase
        evidence = [string]$phase.$evidenceName
      }
    }
    if ([string]$phase.$statusName -cne 'executed') {
      throw "Unknown phase arm status: $($phase.phase)/$arm"
    }
  }
  $pair = Complete-Issue13V5Pair $Config $State $phase
  [pscustomobject]@{
    status = 'pair-completed'; phase = [string]$phase.phase; pair = $pair
  }
}

function Copy-Issue13V5PlannedScenario(
  [object]$Config,
  [object]$Plan,
  [string]$ScenarioId,
  [string]$Commit,
  [int]$ExpectedWorkers
) {
  $record = @($Plan.records | Where-Object {
    [string]$_.scenario_id -ceq $ScenarioId
  })
  if ($record.Count -ne 1) {
    throw "Plan lacks scenario: $ScenarioId"
  }
  $source = [string]$record[0].evidence_directory
  $null = Assert-Issue13V5ScenarioEvidence $source $ScenarioId $Commit `
    $ExpectedWorkers
  $destination = Get-Issue13V5ScenarioDirectory $Config $ScenarioId
  $null = Copy-Issue13V5WriteOnceTree $source $destination
  Assert-Issue13V5ScenarioEvidence $destination $ScenarioId $Commit `
    $ExpectedWorkers
}

function Invoke-Issue13V5FaultWorkflowNext(
  [object]$Config,
  [object]$State
) {
  $workflow = $State.prep_fault
  $planBinding = Ensure-Issue13V5PrepFaultPlan $Config $State
  if ([string]$workflow.preparation_comparison_status -cne 'passed') {
    throw 'Fault workflow requires passed preparation comparison.'
  }
  if ([string]$workflow.import_status -ceq 'planned') {
    $output = Join-Path ([string]$Config.control_root) 'fault-inputs'
    $seedResult = Join-Path (Get-Issue13V5ScenarioDirectory $Config `
      'candidate/calculate/wiodr13/workers1') 'scenario-result.json'
    $candidateMethod = @($Config.methods | Where-Object method -ceq 'wiodr13')[0]
    if (Test-Path -LiteralPath $output) {
      throw 'Planned fault-input output already exists.'
    }
    $null = Invoke-Issue13V5R $Config @(
      '--vanilla', (Join-Path ([string]$Config.harness_root) `
        'issue13-import-fault-inputs.R'),
      '--prepared-root', [string]$Config.supplemental_roots.candidate_preparation,
      '--preparation-comparison', [string]$workflow.preparation_comparison_path,
      '--seed-project-root', [string]$candidateMethod.candidate,
      '--seed-result', $seedResult,
      '--seed-commit', [string]$Config.candidate_commit,
      '--fault-root', [string]$Config.supplemental_roots.candidate_fault,
      '--candidate-commit', [string]$Config.candidate_commit,
      '--method', 'wiodr13',
      '--output', $output
    ) 'fault/import-inputs' 10800 -ConfirmExecuteR:$ConfirmExecuteR
    $reportPath = Join-Path $output 'fault-input-import.json'
    $report = Read-Issue13V5Json $reportPath
    if ([string]$report.status -cne 'passed' -or
        -not (Test-Issue13V5ExactBoolean $report.passed $true) -or
        -not (Test-Issue13V5ExactBoolean `
          $report.source_stores_unchanged $true)) {
      throw 'Fault-input import failed authentication.'
    }
    $workflow.import_status = 'passed'
    $workflow.import_report_path = (Resolve-Path -LiteralPath $reportPath).Path
    $workflow.import_report_sha256 = Get-Issue13V5Sha256 $reportPath
    Save-Issue13V5State $Config $State
    return [pscustomobject]@{ status = 'fault-inputs-imported' }
  }
  if ([string]$workflow.seed_plan_status -ceq 'planned') {
    $output = Join-Path ([string]$Config.control_root) 'fault-seeds'
    if (Test-Path -LiteralPath $output) {
      throw 'Planned fault seed-plan output already exists.'
    }
    $null = Invoke-Issue13V5R $Config @(
      '--vanilla', (Join-Path ([string]$Config.harness_root) `
        'issue13-build-fault-seed-specs.R'),
      '--plan', [string]$planBinding.plan_path,
      '--import-report', [string]$workflow.import_report_path,
      '--output', $output
    ) 'fault/build-seed-plan' 900 -ConfirmExecuteR:$ConfirmExecuteR
    $seedPlan = Join-Path $output 'seed-plan.json'
    $document = Read-Issue13V5Json $seedPlan
    if ([string]$document.schema -cne 'wlv-issue13-fault-seed-plan/1' -or
        [long]$document.record_count -ne 10 -or
        @($document.records).Count -ne 10) {
      throw 'Fault seed plan is invalid.'
    }
    $workflow.seed_plan_status = 'built'
    $workflow.seed_plan_path = (Resolve-Path -LiteralPath $seedPlan).Path
    $workflow.seed_plan_sha256 = Get-Issue13V5Sha256 $seedPlan
    Save-Issue13V5State $Config $State
    return [pscustomobject]@{ status = 'fault-seed-plan-built' }
  }
  if ([string]$workflow.seeds_status -ceq 'planned') {
    $seedPlan = Read-Issue13V5Json $workflow.seed_plan_path
    $existingSeeds = @($seedPlan.records | Where-Object {
      Test-Path -LiteralPath ([string]$_.evidence_directory)
    })
    if ($existingSeeds.Count -ne 0) {
      throw 'Planned fault seed evidence already exists and is terminal.'
    }
    $null = Wait-Issue13V5CoolState $Config $CoolingSeconds 40GB
    $null = Invoke-Issue13V5Pwsh $Config @(
      '-NoLogo', '-NoProfile', '-File',
      (Join-Path ([string]$Config.harness_root) 'issue13-run-fault-seeds.ps1'),
      '-SeedPlanPath', [string]$workflow.seed_plan_path
    ) 'fault/seed-channels' 30000 -ConfirmExecuteR:$ConfirmExecuteR
    $seedBindings = [Collections.Generic.List[object]]::new()
    foreach ($record in @($seedPlan.records)) {
      $evidence = [string]$record.evidence_directory
      $metrics = Read-Issue13V5Json (Join-Path $evidence 'process-metrics.json')
      if (-not (Test-Issue13V5ExactBoolean $metrics.passed $true) -or
          -not (Test-Issue13V5ExactBoolean $metrics.cluster_closed $true) -or
          @($metrics.lingering_pids).Count -ne 0) {
        throw "Fault channel seed telemetry failed: $($record.scenario_id)"
      }
      $seedInventory = Get-Issue13V5TreeInventory $evidence
      $seedBindings.Add([ordered]@{
        scenario_id = [string]$record.scenario_id
        root = [string]$seedInventory.root
        inventory = $seedInventory
      })
    }
    if ($seedBindings.Count -ne 10) {
      throw 'Fault seed evidence coverage is not exactly ten records.'
    }
    $workflow.seed_evidence = [object[]]$seedBindings.ToArray()
    $workflow.seeds_status = 'executed'
    Save-Issue13V5State $Config $State
    return [pscustomobject]@{ status = 'fault-channels-seeded'; count = 10 }
  }
  $fault = @($workflow.faults | Where-Object status -ceq 'planned' |
    Select-Object -First 1)
  if ($fault.Count -ne 0) {
    $fault = $fault[0]
    $plannedRecord = @($planBinding.plan.records | Where-Object {
      [string]$_.scenario_id -ceq [string]$fault.scenario_id
    })
    if ($plannedRecord.Count -ne 1) {
      throw "Fault plan record is missing: $($fault.fault_id)"
    }
    $plannedEvidence = [string]$plannedRecord[0].evidence_directory
    $finalEvidence = Get-Issue13V5ScenarioDirectory $Config `
      ([string]$fault.scenario_id)
    if ((Test-Path -LiteralPath $plannedEvidence) -or
        (Test-Path -LiteralPath $finalEvidence)) {
      throw "Planned fault evidence already exists: $($fault.fault_id)"
    }
    $null = Wait-Issue13V5CoolState $Config $CoolingSeconds 40GB
    $null = Invoke-Issue13V5Pwsh $Config @(
      '-NoLogo', '-NoProfile', '-File',
      (Join-Path ([string]$Config.harness_root) `
        'issue13-run-prep-fault-record.ps1'),
      '-PlanPath', [string]$planBinding.plan_path,
      '-ScenarioId', [string]$fault.scenario_id
    ) ('fault/execute/' + [string]$fault.fault_id) 30000 `
      -ConfirmExecuteR:$ConfirmExecuteR
    $validated = Copy-Issue13V5PlannedScenario $Config $planBinding.plan `
      ([string]$fault.scenario_id) ([string]$Config.candidate_commit) 0
    $fault.evidence = Get-Issue13V5ScenarioDirectory $Config `
      ([string]$fault.scenario_id)
    $fault.result_sha256 = [string]$validated.result_sha256
    $fault.metrics_sha256 = [string]$validated.metrics_sha256
    $fault.status = 'executed'
    Save-Issue13V5State $Config $State
    return [pscustomobject]@{
      status = 'fault-executed'; fault_id = [string]$fault.fault_id
    }
  }
  if ([string]$workflow.aggregate_status -ceq 'planned') {
    $null = Assert-Issue13V5PrepFaultEvidenceState $Config $State `
      -BeforeAggregate
    $output = Join-Path ([string]$Config.control_root) 'prep-fault-aggregate'
    if (Test-Path -LiteralPath $output) {
      throw 'Planned prep/fault aggregate output already exists.'
    }
    $null = Invoke-Issue13V5R $Config @(
      '--vanilla', (Join-Path ([string]$Config.harness_root) `
        'issue13-aggregate-prep-fault.R'),
      '--plan', [string]$planBinding.plan_path,
      '--preparation-comparison', [string]$workflow.preparation_comparison_path,
      '--import-report', [string]$workflow.import_report_path,
      '--seed-plan', [string]$workflow.seed_plan_path,
      '--output', $output
    ) 'fault/aggregate-preparation-faults' 3600 `
      -ConfirmExecuteR:$ConfirmExecuteR
    $reportPath = Join-Path $output 'prep-fault-aggregate.json'
    $report = Read-Issue13V5Json $reportPath
    if ([string]$report.status -cne 'passed' -or
        -not (Test-Issue13V5ExactBoolean $report.passed $true) -or
        [long]$report.summary.fault_gates_passed -ne 10 -or
        [long]$report.summary.rollback_gates_passed -ne 10 -or
        [long]$report.summary.visible_partial_releases -ne 0 -or
        [long]$report.summary.staging_entries -ne 0) {
      throw 'Preparation/fault aggregate failed.'
    }
    $workflow.aggregate_status = 'passed'
    $workflow.aggregate_path = (Resolve-Path -LiteralPath $reportPath).Path
    $workflow.aggregate_sha256 = Get-Issue13V5Sha256 $reportPath
    $State.status = 'scenarios-complete'
    $null = Assert-Issue13V5PrepFaultEvidenceState $Config $State
    Save-Issue13V5State $Config $State
    return [pscustomobject]@{
      status = 'scenarios-complete'; pairs = 76; faults = 10
    }
  }
  [pscustomobject]@{ status = 'scenarios-complete'; pairs = 76; faults = 10 }
}

function Invoke-Issue13V5RunNext(
  [object]$Binding,
  [object]$State
) {
  if (-not $ConfirmExecuteR) { throw 'RunNext requires -ConfirmExecuteR.' }
  $config = $Binding.config
  $null = Assert-Issue13V5AllWorktrees $config $State
  $null = Assert-Issue13V5NoConcurrentR $config
  $phase = Invoke-Issue13V5NextPhase $config $State
  if ($null -ne $phase) { return $phase }
  Invoke-Issue13V5FaultWorkflowNext $config $State
}

function Invoke-Issue13V5Aggregate(
  [object]$Binding,
  [object]$State
) {
  if (-not $ConfirmExecuteR) { throw 'Aggregate requires -ConfirmExecuteR.' }
  $config = $Binding.config
  $oracleEffectValidation = Invoke-Issue13V5OracleEffectValidation $config
  $null = Assert-Issue13V5OracleEffectControlRecord $config $State `
    $oracleEffectValidation
  if (@($State.phases | Where-Object comparison_status -cne 'completed').Count `
        -ne 0 -or
      [string]$State.prep_fault.aggregate_status -cne 'passed' -or
      @($State.prep_fault.faults | Where-Object status -cne 'executed').Count `
        -ne 0) {
    throw 'Aggregate requires 76 pairs and all ten fault gates.'
  }
  $null = Assert-Issue13V5CompletedEvidenceState $config $State
  if ([string]$State.final_aggregate.status -ceq 'passed') {
    $null = Assert-Issue13V5FinalBindings $config $State
    return Read-Issue13V5Json $State.final_aggregate.path
  }
  $scenarioCount = @(Get-ChildItem -LiteralPath (
    Join-Path ([string]$config.evidence_root) 'scenarios') -Directory).Count
  $comparisonCount = @(Get-ChildItem -LiteralPath (
    Join-Path ([string]$config.evidence_root) 'comparisons') -Directory).Count
  if ($scenarioCount -ne 162 -or $comparisonCount -ne 202) {
    throw "Evidence cardinality differs (scenarios=$scenarioCount comparisons=$comparisonCount)."
  }
  $null = Assert-Issue13V5AllWorktrees $config $State -Deep
  $null = Wait-Issue13V5CoolState $config $CoolingSeconds 40GB
  $output = Join-Path ([string]$config.control_root) 'final-aggregate'
  if (Test-Path -LiteralPath $output) {
    throw 'Planned final aggregate output already exists.'
  }
  $null = Invoke-Issue13V5R $config @(
    '--vanilla', (Join-Path ([string]$config.harness_root) `
      'issue13-aggregate.R'),
    '--evidence-root', [string]$config.evidence_root,
    '--output', $output,
    '--baseline-base-commit', $script:Issue13V5BaselineCommit,
    '--candidate-commit', [string]$config.candidate_commit,
    '--candidate-seed-commit', [string]$config.candidate_seed_commit,
    '--baseline-runtime-index', [string]$config.baseline_runtime_index,
    '--baseline-runtime-index-sha256',
      [string]$config.baseline_runtime_index_sha256
  ) 'aggregate/final' 21600 -ConfirmExecuteR:$ConfirmExecuteR
  $reportPath = Join-Path $output 'aggregate.json'
  $report = Read-Issue13V5Json $reportPath
  if ([string]$report.schema -cne 'wlv-issue13-evidence-aggregate/1' -or
      [string]$report.status -cne 'passed' -or
      -not (Test-Issue13V5ExactBoolean $report.passed $true) -or
      [long]$report.failed_check_count -ne 0 -or
      [long]$report.matrix.scenario_count -ne 162 -or
      [long]$report.matrix.comparison_count -ne 202 -or
      [long]$report.matrix.fault_count -ne 10 -or
      [string]$report.baseline_base_commit -cne
        $script:Issue13V5BaselineCommit -or
      [string]$report.candidate_commit -cne [string]$config.candidate_commit) {
    throw 'Final V5 aggregate is not a complete passed report.'
  }
  $performance = @(Import-Csv -LiteralPath (
    Join-Path $output 'performance.csv'))
  $expectedSciencePhases = @(Get-Issue13V5ExpectedSciencePhases)
  $expectedPerformanceScenarios = @(
    @($expectedSciencePhases.phase) + @('prepare/all', 'paper/0') |
      Sort-Object)
  $observedPerformanceScenarios = @($performance.scenario | Sort-Object)
  if ($performance.Count -ne 76 -or
      @($performance.scenario | Sort-Object -Unique).Count -ne 76 -or
      [string]::Join("`n", $observedPerformanceScenarios) -cne
        [string]::Join("`n", $expectedPerformanceScenarios) -or
      @($performance | Where-Object {
        [string]$_.time_passed -cne 'TRUE' -or
        [string]$_.rss_passed -cne 'TRUE' -or
        [string]$_.rss_recomputed_from_authenticated_samples -cne 'TRUE' -or
        [long]$_.baseline_rss_sample_count -le 0L -or
        [long]$_.candidate_rss_sample_count -le 0L -or
        [string]$_.baseline_samples_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        [string]$_.candidate_samples_sha256 -cnotmatch '^[0-9a-f]{64}$'
      }).Count -ne 0) {
    throw 'Final performance table failed time/RSS limits.'
  }
  $oracleDeltas = @(Import-Csv -LiteralPath (
    Join-Path $output 'oracle-classification.csv'))
  $expectedOraclePhases = @($expectedSciencePhases |
    Where-Object kind -ceq 'recalculate' | ForEach-Object phase |
    Sort-Object)
  $observedOraclePhases = @($oracleDeltas.phase | Sort-Object)
  if ($oracleDeltas.Count -ne 60 -or
      @($oracleDeltas.phase | Sort-Object -Unique).Count -ne 60 -or
      [string]::Join("`n", $observedOraclePhases) -cne
        [string]::Join("`n", $expectedOraclePhases) -or
      @($oracleDeltas | Where-Object {
        [string]$_.delta_schema -cne
          'wlv-issue13-complete-recalculation-delta/1' -or
        [string]$_.complete_delta_equal -cne 'TRUE' -or
        [string]$_.baseline_delta_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        [string]$_.candidate_delta_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
        [string]$_.baseline_delta_sha256 -cne
          [string]$_.candidate_delta_sha256
      }).Count -ne 0) {
    throw 'Final recalculation oracle table lacks 60 complete equal deltas.'
  }
  $State.final_aggregate.status = 'passed'
  $State.final_aggregate.path = (Resolve-Path -LiteralPath $reportPath).Path
  $State.final_aggregate.sha256 = Get-Issue13V5Sha256 $reportPath
  $State.final_aggregate.files = [object[]](Get-Issue13V5FileRecords `
    $output @('aggregate.json', 'checks.csv', 'oracle-classification.csv',
      'performance.csv'))
  $evidenceInventory = Get-Issue13V5TreeInventory $config.evidence_root
  $commandInventory = Get-Issue13V5TreeInventory (
    Join-Path ([string]$config.control_root) 'commands')
  $State.final_aggregate.evidence_inventory = [ordered]@{
    root = [string]$evidenceInventory.root
    file_count = [long]$evidenceInventory.file_count
    directory_count = [long]$evidenceInventory.directory_count
    total_bytes = [long]$evidenceInventory.total_bytes
    inventory_sha256 = [string]$evidenceInventory.inventory_sha256
    directory_list_sha256 = [string]$evidenceInventory.directory_list_sha256
  }
  $State.final_aggregate.command_inventory = [ordered]@{
    root = [string]$commandInventory.root
    file_count = [long]$commandInventory.file_count
    directory_count = [long]$commandInventory.directory_count
    total_bytes = [long]$commandInventory.total_bytes
    inventory_sha256 = [string]$commandInventory.inventory_sha256
    directory_list_sha256 = [string]$commandInventory.directory_list_sha256
  }
  $State.final_aggregate.prep_fault_aggregate_sha256 =
    Get-Issue13V5Sha256 $State.prep_fault.aggregate_path
  $State.final_aggregate.preparation_comparison_sha256 =
    Get-Issue13V5Sha256 $State.prep_fault.preparation_comparison_path
  $State.final_aggregate.paper0_comparison_sha256 = Get-Issue13V5Sha256 (
    Join-Path (Get-Issue13V5ComparisonDirectory $config 'parity/paper/0') `
      'comparison.json')
  $State.status = 'aggregate-passed'
  Save-Issue13V5State $config $State
  $report
}

function Invoke-Issue13V5Report(
  [object]$Binding,
  [object]$State
) {
  if (-not $ConfirmWriteReport) {
    throw 'Report requires -ConfirmWriteReport.'
  }
  $config = $Binding.config
  if ([string]$State.final_aggregate.status -cne 'passed') {
    throw 'Report requires a passed final aggregate.'
  }
  $null = Assert-Issue13V5FinalBindings $config $State
  $renderer = Join-Path $scriptRoot 'issue13-v5-render-report.ps1'
  $output = Join-Path ([string]$config.repository_root) `
    ([string]$config.report.required_path)
  if ([string]$State.report.status -ceq 'written') {
    $null = Assert-Issue13V5ReportBinding $config $State
    return Get-Item -LiteralPath $output
  }
  if ([string]$State.report.status -cne 'planned') {
    throw 'Report state is neither planned nor written.'
  }
  if (Test-Path -LiteralPath $output) {
    throw "Planned write-once report path already exists: $output"
  }
  $pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source
  & $pwsh @(
    '-NoLogo', '-NoProfile', '-File', $renderer,
    '-ConfigPath', [string]$Binding.path,
    '-StatePath', (Get-Issue13V5StatePath $config),
    '-Output', $output,
    '-ConfirmWriteReport'
  )
  if ($LASTEXITCODE -ne 0) {
    throw "Report renderer failed with exit code $LASTEXITCODE."
  }
  $text = [IO.File]::ReadAllText($output,
    [Text.UTF8Encoding]::new($false, $true))
  foreach ($bindingText in @(
      [string]$config.baseline_commit,
      [string]$config.baseline_runtime_commit,
      [string]$config.candidate_commit,
      [string]$Binding.sha256,
      [string]$State.final_aggregate.sha256,
      [string]$config.source_inventory.inventory_sha256,
      [string]$config.candidate_source_inventory.inventory_sha256,
      [string]$config.strict_baseline_smoke.sha256,
      [string]$config.compatibility_baseline_smoke.sha256,
      [string]$config.baseline_overlay.sha256,
      [string]$config.baseline_overlay.patch_id,
      [string]$config.oracle_effect.proof.sha256,
      [string]$config.oracle_effect.oracle_smoke.sha256,
      [string]$config.oracle_effect.comparisons.inventory.inventory_sha256,
      [string]$State.oracle_effect.control_record_sha256
    )) {
    if (-not $text.Contains($bindingText)) {
      throw "Generated report lacks an authenticated binding: $bindingText"
    }
  }
  foreach ($field in @($config.report.required_fields)) {
    if ($text -cnotmatch [regex]::Escape([string]$field)) {
      throw "Generated report lacks required field: $field"
    }
  }
  $State.report.status = 'written'
  $State.report.path = (Resolve-Path -LiteralPath $output).Path
  $State.report.sha256 = Get-Issue13V5Sha256 $output
  $State.status = 'complete'
  Save-Issue13V5State $config $State
  Get-Item -LiteralPath $output
}

function Get-Issue13V5Status(
  [object]$Binding,
  [object]$State
) {
  $completed = @($State.phases | Where-Object comparison_status -ceq 'completed')
  $next = @($State.phases | Sort-Object ordinal | Where-Object {
    [string]$_.comparison_status -cne 'completed'
  } | Select-Object -First 1)
  [pscustomobject][ordered]@{
    status = [string]$State.status
    revision = [long]$State.revision
    config_sha256 = [string]$Binding.sha256
    state_sha256 = Get-Issue13V5Sha256 (
      Get-Issue13V5StatePath $Binding.config)
    worktrees_completed = @($State.worktrees |
      Where-Object status -ceq 'completed').Count
    completed_pairs = $completed.Count
    remaining_pairs = 76 - $completed.Count
    next_phase = if ($next.Count) { [string]$next[0].phase } else { $null }
    fault_inputs = [string]$State.prep_fault.import_status
    fault_seed_plan = [string]$State.prep_fault.seed_plan_status
    fault_seeds = [string]$State.prep_fault.seeds_status
    faults_completed = @($State.prep_fault.faults |
      Where-Object status -ceq 'executed').Count
    prep_fault_aggregate = [string]$State.prep_fault.aggregate_status
    final_aggregate = [string]$State.final_aggregate.status
    report = [string]$State.report.status
  }
}

$binding = Assert-Issue13V5Config $ConfigPath
if ($Action -ceq 'ValidateConfig') {
  [pscustomobject]@{
    status = 'valid'
    generation = 'v5'
    config_path = [string]$binding.path
    config_sha256 = [string]$binding.sha256
    baseline_commit = $script:Issue13V5BaselineCommit
    baseline_runtime_commit = [string]$binding.config.baseline_runtime_commit
    candidate_commit = [string]$binding.config.candidate_commit
    worktrees = 29
    pairs = 76
    scenarios = 162
    comparisons = 202
    faults = 10
    oracle_effect = [pscustomobject]@{
      status = [string]$binding.oracle_effect_validation.status
      proof_sha256 =
        [string]$binding.oracle_effect_validation.proof_sha256
      strict_common_method_count = 5L
      recovered_method_count = 7L
      final_evidence_eligible = $false
      required_by_final_gate = $true
    }
  }
  return
}
if ($Action -ceq 'Initialize') {
  Initialize-Issue13V5 $binding
  return
}

$config = $binding.config
$state = Read-Issue13V5State $config $binding.sha256
if ($Action -ceq 'Status') {
  Get-Issue13V5Status $binding $state
  return
}
$lock = Enter-Issue13V5Lock $config $Action
try {
  $state = Read-Issue13V5State $config $binding.sha256
  switch ($Action) {
    'PrepareWorktrees' {
      Prepare-Issue13V5Worktrees $binding $state
    }
    'RunNext' {
      Invoke-Issue13V5RunNext $binding $state
    }
    'RunAll' {
      if (-not $ConfirmExecuteR) { throw 'RunAll requires -ConfirmExecuteR.' }
      $null = Assert-Issue13V5AllWorktrees $config $state
      while ([string]$state.status -cnotin @(
          'scenarios-complete', 'aggregate-passed', 'complete')) {
        $result = Invoke-Issue13V5RunNext $binding $state
        Write-Output $result
        $state = Read-Issue13V5State $config $binding.sha256
      }
      if ([string]$state.final_aggregate.status -cne 'passed') {
        $result = Invoke-Issue13V5Aggregate $binding $state
        Write-Output $result
        $state = Read-Issue13V5State $config $binding.sha256
      }
      if ($ConfirmWriteReport -and [string]$state.report.status -cne 'written') {
        Invoke-Issue13V5Report $binding $state
      } else {
        Get-Issue13V5Status $binding $state
      }
    }
    'Aggregate' {
      Invoke-Issue13V5Aggregate $binding $state
    }
    'Report' {
      Invoke-Issue13V5Report $binding $state
    }
  }
} finally {
  Exit-Issue13V5Lock $lock
}
