# Supplemental binding for exact array-proof reuse. Never changes the sealed
# scientific or metadata comparison bindings. Dot-source after their libraries.

function Get-Issue13MainApprovedArrayProofSha256 {
  # Deterministic eight-record derivation, reviewed against both original
  # authenticated reports. A self-declared/rekeyed cache is not a new proof.
  '2490e32895d34ea9029e2a24182bcbc609fb70d345329830508d35a6294d2326'
}

function Assert-Issue13MainArrayProofSelection([object]$Record,
    [AllowNull()][string]$ExpectedPath, [AllowNull()][string]$ExpectedSha256) {
  $path = if ($Record.PSObject.Properties.Name -ccontains 'array_proof_binding_path') {
    [string]$Record.array_proof_binding_path
  } else { '' }
  $sha = if ($Record.PSObject.Properties.Name -ccontains 'array_proof_binding_sha256') {
    [string]$Record.array_proof_binding_sha256
  } else { '' }
  if ([string]::IsNullOrWhiteSpace($ExpectedPath)) {
    if (-not [string]::IsNullOrWhiteSpace($path) -or -not [string]::IsNullOrWhiteSpace($sha)) {
      throw 'Array-proof reuse cannot be silently disabled during resume.'
    }
  } elseif ([string]::IsNullOrWhiteSpace($path) -or $sha -cne $ExpectedSha256 -or
      -not (Test-Issue13MainSamePath $path $ExpectedPath)) {
    throw 'Array-proof binding differs from the selected comparison campaign.'
  }
}

function Assert-Issue13MainArrayProofHistory([object]$State,
    [AllowNull()][string]$ExpectedPath, [AllowNull()][string]$ExpectedSha256) {
  # Check every attempt before repair can convert an integrity error into a
  # retry, including passed attempts that the scheduler will otherwise skip.
  foreach ($comparison in @($State.comparisons)) {
    foreach ($attempt in @($comparison.attempts)) {
      Assert-Issue13MainArrayProofSelection $attempt $ExpectedPath $ExpectedSha256
      if ((Get-Issue13MainSha256 $attempt.job_path) -cne $attempt.job_sha256) {
        throw 'Historical comparison job changed.'
      }
      $job = Read-Issue13MainJson $attempt.job_path
      Assert-Issue13MainArrayProofSelection $job $ExpectedPath $ExpectedSha256
      if (Test-Path -LiteralPath $attempt.result_path -PathType Leaf) {
        if (-not [string]::IsNullOrWhiteSpace([string]$attempt.result_sha256) -and
            (Get-Issue13MainSha256 $attempt.result_path) -cne $attempt.result_sha256) {
          throw 'Historical comparison outcome changed.'
        }
        Assert-Issue13MainArrayProofSelection (Read-Issue13MainJson $attempt.result_path) `
          $ExpectedPath $ExpectedSha256
      }
    }
  }
}

function Assert-Issue13MainArrayProofBinding([string]$Path, [string]$ExpectedSha256,
    [string]$ConfigPath, [string]$ComparisonBindingPath) {
  if ((Get-Issue13MainSha256 $Path) -cne $ExpectedSha256) { throw 'Array-proof binding changed.' }
  $document = Read-Issue13MainJson $Path
  $config = Read-Issue13MainJson $ConfigPath
  $science = Read-Issue13MainJson (Join-Path $config.control_root 'state.json')
  if ($document.schema -cne 'wlv-issue13-main-array-proof-binding/1' -or
      $document.config_sha256 -cne (Get-Issue13MainSha256 $ConfigPath) -or
      -not (Test-Issue13MainSamePath $document.config_path $ConfigPath) -or
      $document.science_binding_sha256 -cne $science.tooling_binding_sha256 -or
      -not (Test-Issue13MainSamePath $document.science_binding_path $science.tooling_binding_path) -or
      (Get-Issue13MainSha256 $document.science_binding_path) -cne $document.science_binding_sha256 -or
      -not (Test-Issue13MainSamePath $document.comparison_binding_path $ComparisonBindingPath) -or
      $document.comparison_binding_sha256 -cne (Get-Issue13MainSha256 $ComparisonBindingPath)) {
    throw 'Array-proof binding belongs to different scientific/comparison inputs.'
  }
  $comparison = Assert-Issue13MainComparisonBinding $ComparisonBindingPath `
    $document.comparison_binding_sha256 $config
  $expectedRoles = @('entrypoint', 'library', 'builder', 'validator', 'cache')
  if (@($document.records).Count -ne $expectedRoles.Count -or
      @($document.records.role | Sort-Object -Unique).Count -ne $expectedRoles.Count -or
      @($document.records.role | Where-Object { $_ -cnotin $expectedRoles }).Count) {
    throw 'Array-proof file coverage differs.'
  }
  $records = @{}
  foreach ($record in @($document.records)) {
    if ((Get-Issue13MainSha256 $record.path) -cne $record.sha256 -or
        [long](Get-Item -LiteralPath $record.path).Length -ne [long]$record.size_bytes) {
      throw "Array-proof file changed: $($record.role)"
    }
    $records[$record.role] = $record
  }
  if ($records.cache.sha256 -cne (Get-Issue13MainApprovedArrayProofSha256)) {
    throw 'Array-proof cache is not the independently verified deterministic derivation.'
  }
  $cache = Read-Issue13MainJson $records.cache.path
  if ($cache.schema -cne 'wlv-issue13-main-array-proof-cache/1' -or
      $cache.campaign_id -cne $config.campaign_id -or @($cache.records).Count -ne 8 -or
      $cache.context.config_sha256 -cne $document.config_sha256 -or
      $cache.context.science_tooling_binding_sha256 -cne $document.science_binding_sha256 -or
      $cache.context.comparison_binding_sha256 -cne $document.comparison_binding_sha256 -or
      @($cache.origins).Count -ne 2) { throw 'Array-proof cache context differs.' }
  $origins = @{
    'early/parity/wiodr13/002' = 'bf820579c98f74cc7803998dc2030445fdc7dab69e169a1186372118b233fcca'
    'early/parity/wiodr16/001' = 'e6df7054cc0226149c38320616f73c887dea58144ac9dce3782d3b625c0273b4'
  }
  if (@($cache.origins.comparison_id | Sort-Object -Unique).Count -ne 2) {
    throw 'Array-proof origins are duplicated.'
  }
  foreach ($origin in @($cache.origins)) {
    if (-not $origins.ContainsKey($origin.comparison_id) -or
        $origin.comparison.sha256 -cne $origins[$origin.comparison_id]) {
      throw 'Array-proof origin is not an approved complete comparison.'
    }
    foreach ($field in @('job', 'attempt_result', 'process', 'comparison', 'candidate_result', 'baseline_result')) {
      if ((Get-Issue13MainSha256 $origin.$field.path) -cne $origin.$field.sha256) {
        throw "Array-proof origin changed: $field"
      }
    }
    $null = Assert-Issue13MainControllerSnapshots ([object[]]$origin.controller_records)
  }
  [pscustomobject]@{ document = $document; records = $records; comparison = $comparison }
}

function New-Issue13MainArrayProofBinding([string]$OutputRoot, [string]$CachePath,
    [string]$ConfigPath, [string]$ComparisonBindingPath) {
  $root = ConvertTo-Issue13MainFullPath $OutputRoot
  if (Test-Path -LiteralPath $root) { throw 'Use a new array-proof binding directory.' }
  if ((Get-Issue13MainSha256 $CachePath) -cne (Get-Issue13MainApprovedArrayProofSha256)) {
    throw 'Array-proof cache is not the independently verified deterministic derivation.'
  }
  $config = Read-Issue13MainJson $ConfigPath
  $science = Read-Issue13MainJson (Join-Path $config.control_root 'state.json')
  $sources = [ordered]@{
    entrypoint = Join-Path $PSScriptRoot 'issue13-main-array-proof-compare.R'
    library = Join-Path $PSScriptRoot 'issue13-main-array-proof-lib.R'
    builder = Join-Path $PSScriptRoot 'issue13-main-array-proof-build.R'
    validator = Join-Path $PSScriptRoot 'issue13-main-array-proof-binding.ps1'
    cache = $CachePath
  }
  $null = New-Item -ItemType Directory -Path $root
  $records = foreach ($role in $sources.Keys) {
    $source = ConvertTo-Issue13MainFullPath $sources[$role] -RequireExistingFile
    $sha = Get-Issue13MainSha256 $source
    $target = Join-Path $root (Split-Path -Leaf $source)
    Copy-Item -LiteralPath $source -Destination $target
    if ((Get-Issue13MainSha256 $target) -cne $sha) { throw 'Array-proof snapshot changed during copying.' }
    [ordered]@{ role = $role; path = $target; sha256 = $sha
      size_bytes = [long](Get-Item -LiteralPath $target).Length; source_path = $source }
  }
  $document = [ordered]@{
    schema = 'wlv-issue13-main-array-proof-binding/1'; created_at_utc = [DateTime]::UtcNow.ToString('o')
    config_path = [IO.Path]::GetFullPath($ConfigPath); config_sha256 = Get-Issue13MainSha256 $ConfigPath
    science_binding_path = $science.tooling_binding_path; science_binding_sha256 = $science.tooling_binding_sha256
    comparison_binding_path = [IO.Path]::GetFullPath($ComparisonBindingPath)
    comparison_binding_sha256 = Get-Issue13MainSha256 $ComparisonBindingPath
    records = @($records)
  }
  $path = Join-Path $root 'array-proof-binding.json'
  $sha = Write-Issue13MainJson $document $path
  $null = Assert-Issue13MainArrayProofBinding $path $sha $ConfigPath $ComparisonBindingPath
  [pscustomobject]@{ path = $path; sha256 = $sha }
}

function Get-Issue13MainArrayProofArguments([object]$Proof) {
  $document = $Proof.document
  $entry = @($Proof.comparison.records | Where-Object relative_path -CEQ 'issue13-evidence-harness/issue13-compare-results.R')
  if ($entry.Count -ne 1) { throw 'Original comparison entrypoint is missing.' }
  @('--comparison-root', $Proof.comparison.runtime_root,
    '--comparison-results-sha256', $entry[0].sha256,
    '--proof-lib', $Proof.records.library.path, '--proof-lib-sha256', $Proof.records.library.sha256,
    '--array-proof', $Proof.records.cache.path, '--array-proof-sha256', $Proof.records.cache.sha256,
    '--config', $document.config_path, '--config-sha256', $document.config_sha256,
    '--science-binding', $document.science_binding_path, '--science-binding-sha256', $document.science_binding_sha256,
    '--comparison-binding', $document.comparison_binding_path,
    '--comparison-binding-sha256', $document.comparison_binding_sha256)
}
