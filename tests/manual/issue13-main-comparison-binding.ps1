# A comparison-only derivative. The scientific harness and its binding stay fixed.
# Callers load issue13-main-lib.ps1 first; that file is frozen during live science.

function Get-Issue13MainReducedCompareOverride([string]$Text) {
  $value = $Text.Replace("`r`n", "`n")
  $oldCommit = '3ae99a848156a28431ff44cf4d9e619c6de84a83'
  $newCommit = '972d9f8fc7a887b3db485080264f2958cce13cdd'
  if ([regex]::Matches($value, $oldCommit).Count -ne 1) {
    throw 'The source comparison validator has an unexpected derivation guard.'
  }
  $oldMethods = '  methods <- c(' + "`n" +
    '    "wiodr13", "wiodr16", "alternative_1", "alternative_2", "norow_w13",' + "`n" +
    '    "ochoa_1", "ochoa_2", "petrovic", "wiodr13v09", "wiodr16v09",' + "`n" +
    '    "zerodep_1", "zerodep_2"' + "`n" + '  )'
  if ([regex]::Matches($value, [regex]::Escape($oldMethods)).Count -ne 1) {
    throw 'The source comparison validator has an unexpected method guard.'
  }
  $value.Replace($oldCommit, $newCommit).Replace(
    $oldMethods, '  methods <- c("wiodr13", "wiodr16")')
}

function Assert-Issue13MainComparisonMetadata([string]$Path) {
  $metadata = Read-Issue13MainJson $Path
  if ($metadata.schema -cne 'wlv-issue13-metadata-equivalence/1' -or
      $metadata.baseline_commit -cne
        'cc2c86189a06676bcb9f0e05e08033d710a92509' -or
      $metadata.candidate_commit_at_derivation -cne
        '972d9f8fc7a887b3db485080264f2958cce13cdd' -or
      $metadata.candidate_runtime_generation_sha256 -cne
        '600d8cdd2c692fea0b608285b84c3d260b123aac4cf1904ee8b6b997ec988c63' -or
      [string]::Join('|', [string[]]$metadata.methods) -cne
        'wiodr13|wiodr16' -or
      @($metadata.profiles).Count -ne 2 -or
      [string]::Join('|', [string[]]@($metadata.profiles.method)) -cne
        'wiodr13|wiodr16' -or
      [string]::Join('|', [string[]]$metadata.artifacts) -cne
        '_method_assumptions.csv|_method_matrices.csv|_method_solutions.csv') {
    throw 'The reduced metadata derivation has an invalid fixed scope or engine.'
  }
  $metadata
}

function Assert-Issue13MainMetadataDerivation(
  [string]$MetadataPath, [string]$ProvenancePath, [string]$DifferencePath,
  [object]$Config
) {
  $metadata = Assert-Issue13MainComparisonMetadata $MetadataPath
  $provenance = Read-Issue13MainJson $ProvenancePath
  $difference = Read-Issue13MainJson $DifferencePath
  $oracle = $provenance.oracle_applicability
  $metadataSha = Get-Issue13MainSha256 $MetadataPath
  $oldPath = Join-Path $Config.harness_root 'issue13-v5-metadata-equivalence.json'
  if ($provenance.schema -cne 'wlv-issue13-main-metadata-derivation-provenance/1' -or
      $difference.schema -cne 'wlv-issue13-main-metadata-profile-diff/1' -or
      $provenance.outputs.metadata.sha256 -cne $metadataSha -or
      $difference.new_manifest_sha256 -cne $metadataSha -or
      $provenance.outputs.difference_report.sha256 -cne
        (Get-Issue13MainSha256 $DifferencePath) -or
      $difference.old_manifest_sha256 -cne (Get-Issue13MainSha256 $oldPath) -or
      $difference.new_candidate_runtime_generation_sha256 -cne
        $metadata.candidate_runtime_generation_sha256 -or
      [string]::Join('|', @($provenance.derivation.methods)) -cne 'wiodr13|wiodr16' -or
      [string]::Join('|', @($difference.scope.methods)) -cne 'wiodr13|wiodr16' -or
      [string]::Join('|', @($provenance.derivation.artifacts)) -cne
        [string]::Join('|', @($metadata.artifacts)) -or
      [string]::Join('|', @($difference.scope.artifacts)) -cne
        [string]::Join('|', @($metadata.artifacts)) -or
      -not (Test-Issue13MainExactBoolean $provenance.derivation.scientific_payloads_opened $false) -or
      -not (Test-Issue13MainExactBoolean $provenance.derivation.calculations_executed $false) -or
      -not (Test-Issue13MainExactBoolean $provenance.derivation.isolated_r_process_per_arm $true) -or
      $oracle.schema -cne 'wlv-issue13-main-oracle-metadata-applicability/1' -or
      $oracle.metadata_baseline_commit -cne $metadata.baseline_commit -or
      $oracle.executed_oracle_commit -cne 'e2f4d6dae9a6d35c966b305fabac52e489faa3e7' -or
      [long]$oracle.summary.table_count -ne 6 -or
      [long]$oracle.summary.identical_table_count -ne 6 -or
      [long]$oracle.summary.difference_count -ne 0 -or
      @($oracle.differences).Count -ne 0 -or
      @($oracle.table_comparisons).Count -ne 6 -or
      -not (Test-Issue13MainExactBoolean $oracle.summary.all_tables_identical $true) -or
      [long]$difference.summary.table_count -ne 12 -or
      [long]$difference.summary.identical_table_count -ne 12 -or
      -not (Test-Issue13MainExactBoolean $difference.summary.all_scoped_tables_identical $true) -or
      [long]$difference.summary.total_difference_count -ne @($difference.differences).Count) {
    throw 'The metadata derivation does not prove its scope, hashes, or oracle applicability.'
  }
  foreach ($property in $provenance.validation.PSObject.Properties) {
    if (-not (Test-Issue13MainExactBoolean $property.Value $true)) {
      throw "Metadata derivation validation failed: $($property.Name)"
    }
  }
  foreach ($field in @('profile_envelope_difference_count', 'schema_difference_count',
      'row_count_difference_count', 'cell_difference_count')) {
    if ([long]$difference.summary.$field -ne 0) {
      throw 'Metadata table changes require explicit investigation before binding.'
    }
  }
  $expectedCommits = @{
    baseline = 'cc2c86189a06676bcb9f0e05e08033d710a92509'
    oracle = 'e2f4d6dae9a6d35c966b305fabac52e489faa3e7'
    candidate = '972d9f8fc7a887b3db485080264f2958cce13cdd'
  }
  foreach ($arm in @('baseline', 'oracle', 'candidate')) {
    $input = $provenance.inputs.$arm
    if ($input.commit -cne $expectedCommits[$arm] -or
        $input.tree -cnotmatch '^[0-9a-f]{40}$' -or
        -not (Test-Issue13MainExactBoolean $input.code_only $true) -or
        -not (Test-Issue13MainExactBoolean $input.tracked_status_clean $true) -or
        -not (Test-Issue13MainExactBoolean $input.untracked_status_clean $true)) {
      throw "Metadata derivation input is not the clean pinned code root: $arm"
    }
  }
  if (-not (Test-Issue13MainExactBoolean $provenance.profile_negative_smoke.passed $true)) {
    throw 'The metadata negative smoke did not pass.'
  }
  $true
}

function Assert-Issue13MainComparisonBinding(
  [string]$Path,
  [string]$ExpectedSha256,
  [object]$Config
) {
  $resolved = ConvertTo-Issue13MainFullPath $Path -RequireExistingFile
  if ((Get-Issue13MainSha256 $resolved) -cne $ExpectedSha256) {
    throw 'The comparison-only binding changed.'
  }
  $binding = Read-Issue13MainJson $resolved
  if ($binding.schema -cne 'wlv-issue13-main-comparison-binding/1' -or
      $binding.campaign_id -cne $Config.campaign_id -or
      $binding.classification -cne 'metadata-derivation-only-no-science-reexecution' -or
      @($binding.records).Count -ne 47 -or
      @($binding.changed_files).Count -ne 2 -or
      -not (Test-Issue13MainSamePath $binding.source_manifest $Config.harness_manifest) -or
      $binding.source_manifest_sha256 -cne
        (Get-Issue13MainSha256 $Config.harness_manifest)) {
    throw 'The comparison derivative does not bind this scientific campaign.'
  }
  $sourceManifest = Read-Issue13MainJson $Config.harness_manifest
  foreach ($arm in @('baseline', 'candidate')) {
    $record = $binding.arm_bindings.$arm
    $expectedCommit = if ($arm -ceq 'baseline') {
      'e2f4d6dae9a6d35c966b305fabac52e489faa3e7'
    } else { '972d9f8fc7a887b3db485080264f2958cce13cdd' }
    $armBinding = Get-Issue13MainArmBinding $Config $arm
    if ([string]$record.commit -cne $expectedCommit -or
        [string]$armBinding.commit -cne $expectedCommit -or
        -not (Test-Issue13MainSamePath $record.path $Config.arms.$arm.binding_path) -or
        (Get-Issue13MainSha256 $record.path) -cne $record.sha256) {
      throw "The comparison derivative has a different execution arm: $arm"
    }
  }
  $sourceRoot = Split-Path -Parent $Config.harness_root
  $runtimeRoot = ConvertTo-Issue13MainFullPath $binding.runtime_root `
    -RequireExistingDirectory
  if ((Test-Issue13MainSamePath $sourceRoot $runtimeRoot) -or
      $runtimeRoot.StartsWith($sourceRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase) -or
      $sourceRoot.StartsWith($runtimeRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Comparison tooling must not overwrite the scientific tooling.'
  }
  $sourceRecords = @{}
  foreach ($record in @($sourceManifest.derived_output_tooling.records)) {
    $sourceRecords[[string]$record.relative_path] = $record
  }
  $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $changes = [Collections.Generic.List[string]]::new()
  $metadataRelative = 'issue13-evidence-harness/issue13-v5-metadata-equivalence.json'
  $overrideRelative = 'issue13-evidence-harness/issue13-v5-compare-override.R'
  foreach ($record in @($binding.records)) {
    $relative = ([string]$record.relative_path).Replace('\', '/')
    $target = [IO.Path]::GetFullPath((Join-Path $runtimeRoot $relative))
    $source = [IO.Path]::GetFullPath((Join-Path $sourceRoot $relative))
    if (-not $seen.Add($relative) -or
        -not $target.StartsWith($runtimeRoot + [IO.Path]::DirectorySeparatorChar,
          [StringComparison]::OrdinalIgnoreCase) -or
        -not $source.StartsWith($sourceRoot + [IO.Path]::DirectorySeparatorChar,
          [StringComparison]::OrdinalIgnoreCase) -or
        $null -eq $sourceRecords[$relative] -or
        (Get-Issue13MainSha256 $source) -cne
          [string]$sourceRecords[$relative].sha256 -or
        (Get-Issue13MainSha256 $target) -cne [string]$record.sha256 -or
        [long](Get-Item -LiteralPath $target).Length -ne [long]$record.size_bytes) {
      throw 'A comparison tooling file escaped, changed, or lacks source evidence.'
    }
    if ($relative -ceq $overrideRelative) {
      $expected = Get-Issue13MainReducedCompareOverride (
        [IO.File]::ReadAllText($source, [Text.UTF8Encoding]::new($false, $true)))
      if ([IO.File]::ReadAllText($target, [Text.UTF8Encoding]::new($false, $true)) -cne
          $expected) {
        throw 'The comparison validator differs outside its two fixed guards.'
      }
      $changes.Add($relative)
    } elseif ($relative -ceq $metadataRelative) {
      $null = Assert-Issue13MainComparisonMetadata $target
      if ((Get-Issue13MainSha256 $target) -cne $binding.metadata_sha256) {
        throw 'The comparison metadata differs from its derived profile.'
      }
      $changes.Add($relative)
    } elseif ([string]$record.sha256 -cne
        [string]$sourceRecords[$relative].sha256) {
      throw "Non-metadata comparison tooling changed: $relative"
    }
  }
  if ($seen.Count -ne $sourceRecords.Count -or
      @([IO.Directory]::EnumerateFiles($runtimeRoot, '*',
        [IO.SearchOption]::AllDirectories)).Count -ne 47 -or
      [string]::Join('|', @($changes | Sort-Object)) -cne
        [string]::Join('|', @($binding.changed_files | Sort-Object))) {
    throw 'The comparison derivative has incomplete file/change coverage.'
  }
  $null = Assert-Issue13MainFileRecords ([object[]]$binding.derivation_records)
  if ([string]::Join('|', @($binding.derivation_records.role | Sort-Object)) -cne
      'historical-profile-differences|metadata|provenance') {
    throw 'Comparison metadata derivation records are incomplete.'
  }
  $metadataRecord = @($binding.derivation_records | Where-Object role -CEQ 'metadata')[0]
  if ([string]$metadataRecord.sha256 -cne $binding.metadata_sha256) {
    throw 'Comparison metadata differs from the original derivation output.'
  }
  $provenanceRecord = @($binding.derivation_records | Where-Object role -CEQ 'provenance')[0]
  $differenceRecord = @($binding.derivation_records | Where-Object role -CEQ 'historical-profile-differences')[0]
  $null = Assert-Issue13MainMetadataDerivation $metadataRecord.path `
    $provenanceRecord.path $differenceRecord.path $Config
  $null = Assert-Issue13MainControllerSnapshots ([object[]]$binding.controller_records)
  $binding
}

function Assert-Issue13MainComparisonBindingIdentity(
  [object]$Job, [object]$Attempt, [string]$Path, [string]$Sha256
) {
  foreach ($record in @($Job, $Attempt)) {
    if ([string]$record.comparison_binding_sha256 -cne $Sha256 -or
        -not (Test-Issue13MainSamePath $record.comparison_binding_path $Path)) {
      throw 'A comparison attempt belongs to another comparison binding.'
    }
  }
  $true
}

function Assert-Issue13MainComparisonInputs([object]$Job, [object]$Config) {
  if (@($Job.input_contracts).Count -ne 2 -or
      [string]::Join('|', @($Job.input_contracts.side)) -cne 'candidate|baseline') {
    throw 'Comparison input contracts are incomplete.'
  }
  foreach ($contract in @($Job.input_contracts)) {
    $side = [string]$contract.side
    $arm = [string]$contract.arm
    if ($arm -cnotin @('candidate', 'baseline') -or
        [string]$contract.method -cnotin @('wiodr13', 'wiodr16')) {
      throw 'Comparison input has an unsupported arm or method.'
    }
    $armBinding = Get-Issue13MainArmBinding $Config $arm
    $path = [string]$Job.($side + '_result')
    $report = Read-Issue13MainJson $path
    if ([string]$contract.commit -cne [string]$armBinding.commit -or
        -not ([string]$contract.scenario_id).StartsWith($arm + '/',
          [StringComparison]::Ordinal) -or
        [string]$Job.($side + '_selector') -cne ('run:' + $contract.method) -or
        -not (Test-Issue13MainSamePath $report.project_root `
          $armBinding.roots.($contract.method))) {
      throw "Comparison input contract differs from its execution arm: $side"
    }
    $null = Test-Issue13MainScenarioEvidence (Split-Path -Parent $path) `
      ([string]$contract.scenario_id) ([string]$contract.commit) `
      ([long]$contract.expected_worker_processes)
  }
  $true
}
