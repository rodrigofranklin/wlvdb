[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $true)]
    [string]$Stage5CaptureRoot,

    [Parameter(Mandatory = $true)]
    [string]$BaselineSourceDataRoot,

    [Parameter(Mandatory = $true)]
    [string]$BridgeCaptureRoot,

    [Parameter(Mandatory = $true)]
    [string]$BridgeManifest,

    [Parameter(Mandatory = $true)]
    [string]$HarnessDir,

    [string]$RscriptCommand = "Rscript"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$baselineBaseCommit = "cc2c86189a06676bcb9f0e05e08033d710a92509"
$baselineBaseTree = "0cb1142cdadd74bf95272010f5393ebe2af79f47"
$baselineRuntimeCommit = "e2f4d6dae9a6d35c966b305fabac52e489faa3e7"
$baselineRuntimeTree = "7da19c4f2913e857040ba228280f404b0e54eaab"
$methods = @(
    "wiodr13", "wiodr16", "alternative_1", "alternative_2",
    "norow_w13", "ochoa_1", "ochoa_2", "petrovic", "wiodr13v09",
    "wiodr16v09", "zerodep_1", "zerodep_2"
)
$runtimeMethods = @(
    "alternative_1", "alternative_2", "norow_w13", "ochoa_1",
    "ochoa_2", "petrovic", "wiodr13v09"
)
$stages = @(1, 4, 5)
$bridgeColumns = @(
    "method", "candidate_project_root", "candidate_run_root",
    "baseline_project_root", "baseline_run_root"
)
$stageColumns = @(
    "method", "candidate_reference_project_root",
    "candidate_reference_run_root", "baseline_reference_project_root",
    "baseline_reference_run_root", "baseline_target_project_root",
    "baseline_target_parent_run_root", "baseline_target_run_root"
)

function Resolve-ExistingDirectory([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Label does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Resolve-ExistingFile([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path `
        -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TextSha256([string]$Value) {
    $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString(
            $algorithm.ComputeHash($utf8Bytes)
        ) -replace '-', '').ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

function Get-DirectoryInventorySha256([string]$Root) {
    $resolved = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
    $items = @(Get-ChildItem -LiteralPath $resolved -Recurse -Force)
    if (@($items | Where-Object {
        ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    }).Count -ne 0) {
        throw "Source inventory contains a reparse point."
    }
    $records = @($items | Where-Object { -not $_.PSIsContainer } |
        ForEach-Object {
            $relative = $_.FullName.Substring($resolved.Length).TrimStart('\')
            $relative = $relative.Replace('\', '/')
            $hash = Get-Sha256 $_.FullName
            $relative + "|" + $_.Length + "|" + $hash
        } | Sort-Object)
    $recordText = $records -join "`n"
    return (Get-TextSha256 $recordText)
}

function Assert-GitValue(
    [string]$Worktree,
    [string]$Arguments,
    [string]$Expected,
    [string]$Label
) {
    $actual = (& git -C $Worktree $Arguments.Split(" ")) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $actual -cne $Expected) {
        throw "$Label mismatch. Expected $Expected; observed $actual."
    }
}

function Assert-CleanWorktree(
    [string]$Worktree,
    [string]$Commit,
    [string]$Tree,
    [string]$Label
) {
    $status = @(& git -C $Worktree status --porcelain=v1 `
        --untracked-files=no)
    if ($LASTEXITCODE -ne 0 -or $status.Count -ne 0) {
        throw "$Label is not clean."
    }
    Assert-GitValue $Worktree "rev-parse HEAD" $Commit "$Label commit"
    Assert-GitValue $Worktree "rev-parse HEAD^{tree}" $Tree "$Label tree"
}

function Convert-EvidenceRecord([string]$Line) {
    $parts = @($Line.Split(';'))
    if ($parts.Count -lt 2 -or $parts[0] -cne "evidence_record") {
        throw "Invalid diagnostic evidence record."
    }
    $result = @{}
    for ($index = 1; $index -lt $parts.Count; $index++) {
        $pair = @($parts[$index].Split(@('='), 2))
        if ($pair.Count -ne 2 -or -not $pair[0] -or
            $result.ContainsKey($pair[0])) {
            throw "Invalid or duplicate diagnostic evidence field."
        }
        $result[$pair[0]] = $pair[1]
    }
    return $result
}

function Get-CaptureValue(
    [string[]]$Lines,
    [string]$Key
) {
    $matches = @($Lines | Where-Object {
        $_ -clike ($Key + "=*")
    })
    if ($matches.Count -ne 1) {
        throw "Capture record lacks singular field $Key."
    }
    return $matches[0].Substring($Key.Length + 1)
}

function Invoke-EvidenceVerifier(
    [string]$ProjectRoot,
    [string]$RunRoot,
    [string]$Method,
    [string]$Mode = "calculate",
    [string]$ParentRunId = "-",
    [string]$Stage = "-",
    [string]$LogPath
) {
    $output = @(& $RscriptCommand --vanilla $script:verifier `
        $script:harness $script:controllerDir $ProjectRoot $RunRoot $Method `
        $Mode $ParentRunId $Stage 2>&1)
    $output | Set-Content -LiteralPath $LogPath -Encoding utf8
    $records = @($output | Where-Object { $_ -cmatch '^evidence_record;' })
    if ($LASTEXITCODE -ne 0 -or $records.Count -ne 1) {
        throw "Evidence verification failed for $Method/$Mode. See $LogPath"
    }
    return [pscustomobject]@{
        Line = [string]$records[0]
        Fields = Convert-EvidenceRecord ([string]$records[0])
        LogSha256 = Get-Sha256 $LogPath
    }
}

function Quote-Csv([string]$Value) {
    return '"' + $Value.Replace('"', '""') + '"'
}

function Assert-Within(
    [string]$Path,
    [string]$Root,
    [string]$Label
) {
    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    $prefix = $fullRoot + '\'
    if (-not $fullPath.StartsWith(
        $prefix, [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "$Label escapes its expected root."
    }
}

function Copy-HardLinkedTree(
    [string]$Source,
    [string]$Destination,
    [string]$AllowedSourceRoot,
    [string]$AllowedDestinationRoot
) {
    $sourceFull = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
    $destinationFull = [System.IO.Path]::GetFullPath($Destination).TrimEnd('\')
    Assert-Within $sourceFull $AllowedSourceRoot "Hard-link source"
    Assert-Within $destinationFull $AllowedDestinationRoot `
        "Hard-link destination"
    if ((Split-Path -Qualifier $sourceFull) -cne
        (Split-Path -Qualifier $destinationFull)) {
        throw "Hard-link evidence clone must remain on one volume."
    }
    if (Test-Path -LiteralPath $destinationFull) {
        throw "Hard-link evidence destination already exists."
    }
    $items = @(Get-ChildItem -LiteralPath $sourceFull -Recurse -Force)
    if (@($items | Where-Object {
        ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    }).Count -ne 0) {
        throw "Evidence parent contains a reparse point."
    }
    New-Item -ItemType Directory -Path $destinationFull | Out-Null
    $directories = @($items | Where-Object { $_.PSIsContainer } |
        Sort-Object { $_.FullName.Length })
    foreach ($directory in $directories) {
        $relative = $directory.FullName.Substring($sourceFull.Length).TrimStart('\')
        New-Item -ItemType Directory -Path (Join-Path $destinationFull `
            $relative) | Out-Null
    }
    foreach ($file in @($items | Where-Object { -not $_.PSIsContainer })) {
        $relative = $file.FullName.Substring($sourceFull.Length).TrimStart('\')
        $target = Join-Path $destinationFull $relative
        New-Item -ItemType HardLink -Path $target `
            -Target $file.FullName | Out-Null
    }
}

function Get-SealedBridgeValue(
    [object[]]$Rows,
    [string]$Column,
    [string]$Label
) {
    $values = @($Rows | ForEach-Object { [string]$_.$Column } |
        Sort-Object -Unique)
    if ($values.Count -ne 1 -or -not $values[0]) {
        throw "$Label lacks a singular sealed $Column."
    }
    return $values[0]
}

$repository = Resolve-ExistingDirectory $RepositoryRoot "Repository root"
$sourceData = Resolve-ExistingDirectory $BaselineSourceDataRoot `
    "Source-data root"
$bridgeCapture = Resolve-ExistingDirectory $BridgeCaptureRoot `
    "Bridge capture root"
$script:harness = Resolve-ExistingDirectory $HarnessDir "Harness directory"
$bridgeManifestPath = Resolve-ExistingFile $BridgeManifest "Bridge manifest"
$script:controllerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:verifier = Resolve-ExistingFile (Join-Path $script:controllerDir `
    "issue13-v5-verify-diagnostic-evidence.R") "Evidence verifier"
$launcher = Resolve-ExistingFile (Join-Path $script:controllerDir `
    "issue13-v5-run-stage5-evidence.R") "Stage-five launcher"
$recipePaths = @{
    bridge_capture_script = Resolve-ExistingFile (Join-Path `
        $script:controllerDir "issue13-v5-capture-clean-bridge-evidence.ps1") `
        "Bridge capture recipe"
    bridge_builder = Resolve-ExistingFile (Join-Path $script:controllerDir `
        "issue13-v5-build-diagnostic-bridges.R") "Bridge builder recipe"
    stage5_capture_script = (Resolve-Path -LiteralPath `
        $MyInvocation.MyCommand.Path).Path
    stage5_builder = Resolve-ExistingFile (Join-Path $script:controllerDir `
        "issue13-v5-build-stage5-profiles.R") "Stage-five builder recipe"
    verifier = $script:verifier
    launcher = $launcher
    diagnostics_override = Resolve-ExistingFile (Join-Path `
        $script:controllerDir "issue13-v5-diagnostics-override.R") `
        "Diagnostic runtime override"
    compare_override = Resolve-ExistingFile (Join-Path `
        $script:controllerDir "issue13-v5-compare-override.R") `
        "Comparison runtime override"
}
$bridgeIndexPath = Resolve-ExistingFile (Join-Path $bridgeCapture `
    "diagnostic-bridge-evidence.csv") "Bridge evidence index"
$bridgeRecordPath = Resolve-ExistingFile (Join-Path $bridgeCapture `
    "capture-record.txt") "Bridge capture record"
$bridgeRecordLines = @([System.IO.File]::ReadAllLines(
    $bridgeRecordPath, [System.Text.Encoding]::UTF8
))
if ($bridgeRecordLines[0] -cne "schema=issue13-v5-clean-bridge-capture/1" -or
    (Get-CaptureValue $bridgeRecordLines "verified_records") -cne "7" -or
    (Get-CaptureValue $bridgeRecordLines "evidence_index_sha256") -cne
        (Get-Sha256 $bridgeIndexPath)) {
    throw "Bridge capture record is not bound to its evidence index."
}
$bridgeCaptureRecords = @($bridgeRecordLines | Where-Object {
    $_ -cmatch '^evidence_record;'
})
if ($bridgeCaptureRecords.Count -ne 7) {
    throw "Bridge capture record lacks the exact seven run records."
}
if (Test-Path -LiteralPath $Stage5CaptureRoot) {
    throw "Stage5CaptureRoot is write-once and must not already exist."
}
$captureParent = Split-Path -Parent $Stage5CaptureRoot
if (-not (Test-Path -LiteralPath $captureParent -PathType Container)) {
    throw "Stage5CaptureRoot parent does not exist: $captureParent"
}
$capture = [System.IO.Path]::GetFullPath($Stage5CaptureRoot)
$logsRoot = Join-Path $capture "logs"
$worktreesRoot = Join-Path $capture "worktrees"
$stageIndexPath = Join-Path $capture "stage5-evidence-index.csv"
New-Item -ItemType Directory -Path $capture | Out-Null
New-Item -ItemType Directory -Path $logsRoot | Out-Null
New-Item -ItemType Directory -Path $worktreesRoot | Out-Null

foreach ($source in @("wiodr13", "wiodr16")) {
    Resolve-ExistingFile (Join-Path $sourceData (
        $source + "\normalized\_source_manifest.csv"
    )) "Normalized $source source manifest" | Out-Null
}
$sourceInventoriesBefore = @{}
foreach ($source in @("wiodr13", "wiodr16")) {
    $sourceInventoriesBefore[$source] = Get-DirectoryInventorySha256 `
        (Join-Path $sourceData ($source + "\normalized"))
}
Assert-GitValue $repository ("rev-parse " + $baselineBaseCommit +
    "^{tree}") $baselineBaseTree "Baseline base tree"
Assert-GitValue $repository ("rev-parse " + $baselineRuntimeCommit +
    "^{tree}") $baselineRuntimeTree "Baseline runtime tree"
Assert-GitValue $repository ("rev-parse " + $baselineRuntimeCommit +
    "^") $baselineBaseCommit "Baseline runtime parent"

$bridgeIndex = @(Import-Csv -LiteralPath $bridgeIndexPath -Delimiter ';')
if ($bridgeIndex.Count -ne 12 -or
    (@($bridgeIndex[0].PSObject.Properties.Name) -join "|") -cne
        ($bridgeColumns -join "|") -or
    (@($bridgeIndex.method | Sort-Object -Unique) -join "|") -cne
        (@($methods | Sort-Object) -join "|")) {
    throw "Bridge evidence index lacks the exact 12-method schema."
}
$bridgeRows = @(Import-Csv -LiteralPath $bridgeManifestPath -Delimiter ';')
if (-not $bridgeRows.Count) {
    throw "The sealed diagnostic bridge manifest is empty."
}

$referenceRecords = @()
$referenceByMethod = @{}
foreach ($method in $methods) {
    $row = @($bridgeIndex | Where-Object { $_.method -ceq $method })
    if ($row.Count -ne 1) {
        throw "Bridge evidence index lacks one row for $method."
    }
    $logPath = Join-Path $logsRoot ($method + ".reference.verify.log")
    $verified = Invoke-EvidenceVerifier $row[0].baseline_project_root `
        $row[0].baseline_run_root $method "calculate" "-" "-" $logPath
    $referenceByMethod[$method] = $verified
    $expectedCommit = if ($method -cin $runtimeMethods) {
        $baselineRuntimeCommit
    } else {
        $baselineBaseCommit
    }
    $expectedTree = if ($method -cin $runtimeMethods) {
        $baselineRuntimeTree
    } else {
        $baselineBaseTree
    }
    if ($verified.Fields.commit -cne $expectedCommit -or
        $verified.Fields.tree -cne $expectedTree -or
        $verified.Fields.mode -cne "calculate" -or
        $verified.Fields.at_stage -cne "" -or
        $verified.Fields.parent_run_id -cne "") {
        throw "Baseline reference identity is invalid for $method."
    }
    $sealed = @($bridgeRows | Where-Object {
        $_.method -ceq $method -and
        $_.artifact_name -ceq "_anomalies.csv"
    })
    if (-not $sealed.Count) {
        throw "Diagnostic bridges lack anomaly ownership for $method."
    }
    $bindings = @{
        run_id = "evidence_baseline_run_id"
        anomalies_sha256 = "evidence_baseline_artifact_sha256"
        request_sha256 = "evidence_baseline_request_sha256"
        source_sha256 = "evidence_baseline_source_sha256"
        commit = "evidence_baseline_commit"
        tree = "evidence_baseline_tree"
    }
    foreach ($field in $bindings.Keys) {
        $sealedValue = Get-SealedBridgeValue $sealed $bindings[$field] $method
        if ($verified.Fields[$field] -cne $sealedValue) {
            throw "Baseline reference $field differs from bridge for $method."
        }
    }
    if ($method -cin $runtimeMethods) {
        $captured = @($bridgeCaptureRecords | Where-Object {
            (Convert-EvidenceRecord ($_ -replace
                ';verify_log_sha256=[0-9a-f]{64}$', '')).method -ceq $method
        })
        if ($captured.Count -ne 1 -or
            ($captured[0] -replace
                ';verify_log_sha256=[0-9a-f]{64}$', '') -cne
                $verified.Line) {
            throw "Reused calculate parent differs from bridge capture for $method."
        }
    }
    $referenceRecords += (
        $verified.Line.Replace("evidence_record;",
            "evidence_record;role=baseline_reference;") +
        ";verify_log_sha256=" + $verified.LogSha256
    )
}

$commitTrees = @{
    $baselineBaseCommit = $baselineBaseTree
    $baselineRuntimeCommit = $baselineRuntimeTree
}
$worktrees = @{}
foreach ($stage in $stages) {
    foreach ($commit in @($baselineBaseCommit, $baselineRuntimeCommit)) {
        $root = Join-Path $worktreesRoot (
            "stage-" + $stage + "-" + $commit.Substring(0, 12)
        )
        & git -C $repository worktree add --detach $root $commit
        if ($LASTEXITCODE -ne 0) {
            throw "Could not create isolated stage-$stage worktree."
        }
        Assert-CleanWorktree $root $commit $commitTrees[$commit] `
            "Fresh stage-$stage worktree"
        $sourceLink = Join-Path $root "source_data"
        if (Test-Path -LiteralPath $sourceLink) {
            throw "Fresh stage-$stage worktree unexpectedly has source_data."
        }
        New-Item -ItemType Junction -Path $sourceLink `
            -Target $sourceData | Out-Null
        Assert-CleanWorktree $root $commit $commitTrees[$commit] `
            "Stage-$stage worktree after source link"
        $worktrees[([string]$stage + "|" + $commit)] = $root
    }
}

$stageRows = @()
$seedRecords = @()
$targetRecords = @()
foreach ($method in $methods) {
    $bridgeRow = @($bridgeIndex | Where-Object { $_.method -ceq $method })[0]
    $reference = $referenceByMethod[$method]
    $commit = $reference.Fields.commit
    foreach ($stage in $stages) {
        $worktree = $worktrees[([string]$stage + "|" + $commit)]
        Assert-CleanWorktree $worktree $commit $commitTrees[$commit] `
            "Before stage-$stage $method"
        $parentDestination = Join-Path $worktree (
            "results\runs\" + $method + "\" + $reference.Fields.run_id
        )
        Copy-HardLinkedTree $bridgeRow.baseline_run_root `
            $parentDestination $bridgeRow.baseline_project_root $worktree
        $parentVerifyLog = Join-Path $logsRoot (
            $method + ".stage-" + $stage + ".parent.verify.log"
        )
        $cloned = Invoke-EvidenceVerifier $worktree $parentDestination `
            $method "calculate" "-" "-" $parentVerifyLog
        if ($cloned.Line -cne $reference.Line) {
            throw "Cloned parent differs from sealed reference for $method."
        }
        $methodRoot = Split-Path -Parent $parentDestination
        $before = @(Get-ChildItem -LiteralPath $methodRoot -Directory |
            ForEach-Object { $_.FullName })
        $runLog = Join-Path $logsRoot (
            $method + ".stage-" + $stage + ".recalculate.log"
        )
        $channel = "issue13-v5d-stage-" + $stage + "-" +
            $method.Replace("_", "-")
        $runOutput = @(& $RscriptCommand --vanilla $launcher $worktree `
            $method $reference.Fields.run_id ([string]$stage) $channel 2>&1)
        $runOutput | Set-Content -LiteralPath $runLog -Encoding utf8
        if ($LASTEXITCODE -ne 0) {
            throw "Stage-$stage recalculation failed for $method. See $runLog"
        }
        $aliasRecords = @($runOutput | Where-Object {
            $_ -cmatch '^recalculation_record;'
        })
        if ($aliasRecords.Count -ne 1) {
            throw "Stage-$stage $method lacks one parent alias record."
        }
        $after = @(Get-ChildItem -LiteralPath $methodRoot -Directory |
            ForEach-Object { $_.FullName })
        $created = @($after | Where-Object { $_ -notin $before })
        if ($created.Count -ne 1) {
            throw "Stage-$stage $method did not create exactly one child."
        }
        Assert-CleanWorktree $worktree $commit $commitTrees[$commit] `
            "After stage-$stage $method"
        $verifyLog = Join-Path $logsRoot (
            $method + ".stage-" + $stage + ".target.verify.log"
        )
        $target = Invoke-EvidenceVerifier $worktree $created[0] $method `
            "recalculate" $reference.Fields.run_id ([string]$stage) `
            $verifyLog
        $seedRecords += (
            ([string]$aliasRecords[0]).Replace("recalculation_record;",
                "seed_record;role=parent_alias;channel=$channel;") +
            ";parent_verify_log_sha256=" + $cloned.LogSha256 +
            ";run_log_sha256=" + (Get-Sha256 $runLog)
        )
        $targetRecords += (
            $target.Line.Replace("evidence_record;",
                "evidence_record;role=baseline_target;") +
            ";run_log_sha256=" + (Get-Sha256 $runLog) +
            ";verify_log_sha256=" + $target.LogSha256
        )
        $stageRows += [pscustomobject]@{
            method = $method
            candidate_reference_project_root =
                $bridgeRow.candidate_project_root.Replace('\', '/')
            candidate_reference_run_root =
                $bridgeRow.candidate_run_root.Replace('\', '/')
            baseline_reference_project_root =
                $bridgeRow.baseline_project_root.Replace('\', '/')
            baseline_reference_run_root =
                $bridgeRow.baseline_run_root.Replace('\', '/')
            baseline_target_project_root = $worktree.Replace('\', '/')
            baseline_target_parent_run_root =
                $parentDestination.Replace('\', '/')
            baseline_target_run_root = $created[0].Replace('\', '/')
        }
    }
}
if ($stageRows.Count -ne 36 -or $seedRecords.Count -ne 36 -or
    $targetRecords.Count -ne 36) {
    throw "Stage-five capture lacks its exact 12 x 3 target matrix."
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$lines = @((($stageColumns | ForEach-Object { Quote-Csv $_ }) -join ';'))
foreach ($row in $stageRows) {
    $lines += (($stageColumns | ForEach-Object {
        Quote-Csv ([string]$row.$_)
    }) -join ';')
}
[System.IO.File]::WriteAllLines($stageIndexPath, $lines, $utf8)
if (([System.IO.File]::ReadAllLines($stageIndexPath, $utf8) -join "`n") `
    -cne ($lines -join "`n")) {
    throw "Stage-five evidence index failed its UTF-8 round trip."
}

$emptyStatusSha256 = Get-TextSha256 ""
$worktreeRecords = foreach ($key in @($worktrees.Keys | Sort-Object)) {
    $parts = @($key.Split('|'))
    "worktree_record;key=$key;path=$($worktrees[$key].Replace('\', '/'))" +
        ";commit=$($parts[1]);tree=$($commitTrees[$parts[1]])" +
        ";git_status_sha256=$emptyStatusSha256"
}
$sourceInventoriesAfter = @{}
foreach ($source in @("wiodr13", "wiodr16")) {
    $sourceInventoriesAfter[$source] = Get-DirectoryInventorySha256 `
        (Join-Path $sourceData ($source + "\normalized"))
    if ($sourceInventoriesAfter[$source] -cne
        $sourceInventoriesBefore[$source]) {
        throw "Normalized $source source inventory changed during capture."
    }
}
$recipeRecords = foreach ($name in @($recipePaths.Keys | Sort-Object)) {
    "recipe_record;name=$name;sha256=$(Get-Sha256 $recipePaths[$name])"
}
$captureRecord = @(
    "schema=issue13-v5-clean-stage5-capture/1",
    "baseline_base_commit=$baselineBaseCommit",
    "baseline_base_tree=$baselineBaseTree",
    "baseline_runtime_commit=$baselineRuntimeCommit",
    "baseline_runtime_tree=$baselineRuntimeTree",
    "methods=$($methods -join ',')",
    "stages=$($stages -join ',')",
    "bridge_capture_record_sha256=$(Get-Sha256 $bridgeRecordPath)",
    "bridge_evidence_index_sha256=$(Get-Sha256 $bridgeIndexPath)",
    "bridge_manifest_sha256=$(Get-Sha256 $bridgeManifestPath)",
    "stage5_evidence_index_sha256=$(Get-Sha256 $stageIndexPath)",
    "source_wiodr13_inventory_before_sha256=$($sourceInventoriesBefore['wiodr13'])",
    "source_wiodr13_inventory_after_sha256=$($sourceInventoriesAfter['wiodr13'])",
    "source_wiodr16_inventory_before_sha256=$($sourceInventoriesBefore['wiodr16'])",
    "source_wiodr16_inventory_after_sha256=$($sourceInventoriesAfter['wiodr16'])",
    "recipe_records=$($recipeRecords.Count)",
    "reference_records=$($referenceRecords.Count)",
    "seed_records=$($seedRecords.Count)",
    "target_records=$($targetRecords.Count)",
    "worktree_records=$($worktreeRecords.Count)"
) + $recipeRecords + $worktreeRecords + $referenceRecords +
    $seedRecords + $targetRecords
$captureRecordPath = Join-Path $capture "capture-record.txt"
[System.IO.File]::WriteAllLines($captureRecordPath, $captureRecord, $utf8)
if (([System.IO.File]::ReadAllLines($captureRecordPath, $utf8) -join "`n") `
    -cne ($captureRecord -join "`n")) {
    throw "Stage-five capture record failed its UTF-8 round trip."
}

foreach ($key in $worktrees.Keys) {
    $parts = @($key.Split('|'))
    Assert-CleanWorktree $worktrees[$key] $parts[1] `
        $commitTrees[$parts[1]] "Completed stage-five worktree"
}
Write-Output ("capture_root=" + $capture.Replace('\', '/'))
Write-Output ("evidence_index=" + $stageIndexPath.Replace('\', '/'))
Write-Output ("capture_record=" + $captureRecordPath.Replace('\', '/'))
Write-Output ("capture_record_sha256=" + (Get-Sha256 $captureRecordPath))
Write-Output "reference_runs_reauthenticated=12"
Write-Output "baseline_recalculations=36"
