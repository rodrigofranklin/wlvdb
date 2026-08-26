param(
  [Parameter(Mandatory = $true)][string]$ConfigPath,
  [Parameter(Mandatory = $true)][string]$StatePath,
  [Parameter(Mandatory = $true)][string]$Output,
  [switch]$ConfirmWriteAttestation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Issue13V5DeliveryAttesterInvocationPath =
  (Resolve-Path -LiteralPath $PSCommandPath).Path
$scriptRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
. (Join-Path $scriptRoot 'issue13-v5-coordinator-lib.ps1')

$script:Issue13V5DeliveryReportPath = 'docs/validation/issue-13.md'
$script:Issue13V5DeliveryAttesterPath =
  'run_logs/issue13-native-gate-orchestrator-v5/' +
    'issue13-v5-attest-delivery.ps1'

function Invoke-Issue13V5DeliveryGit(
  [string]$Repository,
  [string[]]$Arguments
) {
  $git = (Get-Command git -ErrorAction Stop).Source
  $output = @(& $git -C $Repository @Arguments 2>$null)
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
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = (Get-Command git -ErrorAction Stop).Source
  $start.UseShellExecute = $false
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  foreach ($argument in @('-C', $Repository, 'cat-file', 'blob', $Blob)) {
    $null = $start.ArgumentList.Add($argument)
  }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $start
  $memory = [IO.MemoryStream]::new()
  try {
    if (-not $process.Start()) {
      throw 'Could not start git cat-file.'
    }
    $copyTask = $process.StandardOutput.BaseStream.CopyToAsync($memory)
    $errorTask = $process.StandardError.ReadToEndAsync()
    $null = $copyTask.GetAwaiter().GetResult()
    $errorText = $errorTask.GetAwaiter().GetResult()
    $null = $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
      throw ('git cat-file failed (' + $process.ExitCode + '): ' +
        $errorText.Trim())
    }
    [byte[]]$memory.ToArray()
  } finally {
    $memory.Dispose()
    $process.Dispose()
  }
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
