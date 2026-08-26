[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $true)]
    [string]$CaptureRoot,

    [Parameter(Mandatory = $true)]
    [string]$BaselineSourceDataRoot,

    [Parameter(Mandatory = $true)]
    [string]$SeedEvidenceIndex,

    [Parameter(Mandatory = $true)]
    [string]$HarnessDir,

    [string]$RscriptCommand = "Rscript",

    [string]$RLibrary =
        "D:\Trabalho\Code\wlvdb\renv\library\windows\R-4.6\x86_64-w64-mingw32"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "issue13-v5-coordinator-lib.ps1")

$baselineBaseCommit = "cc2c86189a06676bcb9f0e05e08033d710a92509"
$baselineBaseTree = "0cb1142cdadd74bf95272010f5393ebe2af79f47"
$baselineRuntimeCommit = "e2f4d6dae9a6d35c966b305fabac52e489faa3e7"
$baselineRuntimeTree = "7da19c4f2913e857040ba228280f404b0e54eaab"
$methods = @(
    "wiodr13", "wiodr16", "alternative_1", "alternative_2",
    "norow_w13", "ochoa_1", "ochoa_2", "petrovic", "wiodr13v09",
    "wiodr16v09", "zerodep_1", "zerodep_2"
)
$captureMethods = @(
    "alternative_1", "alternative_2", "norow_w13", "ochoa_1",
    "ochoa_2", "petrovic", "wiodr13v09"
)
$columns = @(
    "method", "candidate_project_root", "candidate_run_root",
    "baseline_project_root", "baseline_run_root"
)
$script:rClearedEnvironment = @(
    "LANG", "LC_ALL", "LC_CTYPE",
    "R_ARCH", "R_DEFAULT_PACKAGES", "R_ENVIRON", "R_ENVIRON_USER",
    "R_HOME", "R_LIBS", "R_LIBS_SITE", "R_PROFILE", "R_PROFILE_USER",
    "R_STARTUP_DEBUG", "RENV_CONFIG_AUTOLOADER_ENABLED",
    "RENV_PATHS_LIBRARY", "RENV_PATHS_ROOT"
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

function Resolve-PhysicalExistingDirectory([string]$Path, [string]$Label) {
    $resolved = Resolve-ExistingDirectory $Path $Label
    $null = ConvertTo-Issue13V5PhysicalPath $resolved $Label
    Assert-Issue13V5NoReparseAncestors $resolved $Label
    return $resolved.TrimEnd('\')
}

function Resolve-PhysicalExistingFile([string]$Path, [string]$Label) {
    $resolved = Resolve-ExistingFile $Path $Label
    $null = ConvertTo-Issue13V5PhysicalPath $resolved $Label
    Assert-Issue13V5NoReparseAncestors $resolved $Label
    return $resolved
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path `
        -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TextSha256([string]$Value) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString(
            $algorithm.ComputeHash($bytes)
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
        throw "Tooling inventory contains a reparse point."
    }
    $records = @($items | Where-Object { -not $_.PSIsContainer } |
        ForEach-Object {
            $relative = $_.FullName.Substring($resolved.Length).TrimStart('\')
            $relative = $relative.Replace('\', '/')
            $relative + "|" + $_.Length + "|" + (Get-Sha256 $_.FullName)
        })
    [System.Array]::Sort($records, [System.StringComparer]::Ordinal)
    return (Get-TextSha256 ($records -join "`n"))
}

function Invoke-SealedRscript([string[]]$Arguments) {
    $names = @($script:rClearedEnvironment + @("R_LIBS_USER", "TZ"))
    $previous = [ordered]@{}
    foreach ($name in $names) {
        $previous[$name] = [Environment]::GetEnvironmentVariable(
            $name, [EnvironmentVariableTarget]::Process
        )
    }
    try {
        foreach ($name in $names) {
            [Environment]::SetEnvironmentVariable(
                $name, $null, [EnvironmentVariableTarget]::Process
            )
        }
        [Environment]::SetEnvironmentVariable(
            "R_LIBS_USER", $script:rLibrary,
            [EnvironmentVariableTarget]::Process
        )
        [Environment]::SetEnvironmentVariable(
            "TZ", "UTC", [EnvironmentVariableTarget]::Process
        )
        $output = @(& $script:rscriptPath @Arguments 2>&1)
        $script:rscriptExitCode = $LASTEXITCODE
        return $output
    } finally {
        foreach ($entry in $previous.GetEnumerator()) {
            [Environment]::SetEnvironmentVariable(
                [string]$entry.Key, $entry.Value,
                [EnvironmentVariableTarget]::Process
            )
        }
    }
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

function Assert-CleanWorktree([string]$Worktree, [string]$Label) {
    $status = @(& git -C $Worktree status --porcelain=v1 --untracked-files=no)
    if ($LASTEXITCODE -ne 0 -or $status.Count -ne 0) {
        throw "$Label is not clean."
    }
    Assert-GitValue $Worktree "rev-parse HEAD" $baselineRuntimeCommit `
        "$Label runtime commit"
    Assert-GitValue $Worktree "rev-parse HEAD^{tree}" $baselineRuntimeTree `
        "$Label runtime tree"
}

function Get-RunDirectories([string]$Worktree, [string]$Method) {
    $root = Join-Path $Worktree ("results\runs\" + $Method)
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $root -Directory |
        ForEach-Object { $_.FullName })
}

function Quote-Csv([string]$Value) {
    return '"' + $Value.Replace('"', '""') + '"'
}

$repository = Resolve-PhysicalExistingDirectory $RepositoryRoot "Repository root"
$sourceData = Resolve-PhysicalExistingDirectory $BaselineSourceDataRoot "Source-data root"
$harness = Resolve-PhysicalExistingDirectory $HarnessDir "Harness directory"
$seedPath = Resolve-PhysicalExistingFile $SeedEvidenceIndex "Seed evidence index"
$controllerDir = Resolve-PhysicalExistingDirectory `
    $PSScriptRoot "Controller directory"
$verifier = Resolve-PhysicalExistingFile (Join-Path $controllerDir `
    "issue13-v5-verify-diagnostic-evidence.R") "Evidence verifier"
$rscriptApplication = Get-Command -Name $RscriptCommand `
    -CommandType Application -ErrorAction Stop
$rscriptPath = Resolve-PhysicalExistingFile $rscriptApplication.Source `
    "Rscript executable"
$systemDirectory = Resolve-PhysicalExistingDirectory `
    ([Environment]::SystemDirectory) "Windows system directory"
$fsutilPath = Resolve-PhysicalExistingFile `
    (Join-Path $systemDirectory "fsutil.exe") "fsutil executable"
$script:rscriptPath = $rscriptPath
$script:rLibrary = Resolve-PhysicalExistingDirectory $RLibrary `
    "R library"
$harnessRuntime = Resolve-PhysicalExistingDirectory `
    (Split-Path -Parent $harness) "Harness runtime"
$toolPaths = @{
    bridge_builder = Resolve-PhysicalExistingFile (Join-Path $controllerDir `
        "issue13-v5-build-diagnostic-bridges.R") "Bridge builder"
    bridge_capture_script = Resolve-PhysicalExistingFile `
        $MyInvocation.MyCommand.Path "Bridge capture script"
    compare_override = Resolve-PhysicalExistingFile (Join-Path $controllerDir `
        "issue13-v5-compare-override.R") "Comparison override"
    coordinator_library = Resolve-PhysicalExistingFile (Join-Path `
        $controllerDir "issue13-v5-coordinator-lib.ps1") `
        "Coordinator physical-snapshot library"
    diagnostics_override = Resolve-PhysicalExistingFile (Join-Path $controllerDir `
        "issue13-v5-diagnostics-override.R") "Diagnostic override"
    metadata_equivalence = Resolve-PhysicalExistingFile (Join-Path $controllerDir `
        "issue13-v5-metadata-equivalence.json") `
        "Metadata equivalence manifest"
    verifier = $verifier
}
$toolRecordsBefore = @($toolPaths.Keys | Sort-Object | ForEach-Object {
    "tool_record;name=$_;sha256=$(Get-Sha256 $toolPaths[$_])"
})
$harnessInventoryBefore = Get-DirectoryInventorySha256 $harness
$harnessRuntimeInventoryBefore = `
    Get-DirectoryInventorySha256 $harnessRuntime
$rLibraryInventoryBefore = Get-DirectoryInventorySha256 $script:rLibrary
$rscriptSha256 = Get-Sha256 $rscriptPath
$fsutilSha256 = Get-Sha256 $fsutilPath
$officialSourceInventoryBefore =
    Assert-Issue13V5OfficialSourceDataInventory $sourceData
$sourceDataOriginInventoryBefore =
    [string]$officialSourceInventoryBefore.ordinal_inventory_sha256
foreach ($source in @("wiodr13", "wiodr16")) {
    $sourceManifest = Join-Path $sourceData (
        $source + "\normalized\_source_manifest.csv"
    )
    if (-not (Test-Path -LiteralPath $sourceManifest -PathType Leaf)) {
        throw "The normalized $source source manifest is missing."
    }
}
$sourceManifestHashes = @{}
$sourceInventoriesBefore = @{}
foreach ($source in @("wiodr13", "wiodr16")) {
    $sourceManifest = Join-Path $sourceData (
        $source + "\normalized\_source_manifest.csv"
    )
    $sourceManifestHashes[$source] = (Get-FileHash -LiteralPath `
        $sourceManifest -Algorithm SHA256).Hash.ToLowerInvariant()
    $sourceInventoriesBefore[$source] = Get-DirectoryInventorySha256 `
        (Join-Path $sourceData ($source + "\normalized"))
}
if (Test-Path -LiteralPath $CaptureRoot) {
    throw "CaptureRoot is write-once and must not already exist."
}
$captureParent = Split-Path -Parent $CaptureRoot
$captureParent = Resolve-PhysicalExistingDirectory `
    $captureParent "CaptureRoot parent"
$capture = [System.IO.Path]::GetFullPath($CaptureRoot)
$capturePhysicalExpected = ConvertTo-Issue13V5PhysicalPath `
    $capture "CaptureRoot"
Assert-Issue13V5NoReparseAncestors $capture "CaptureRoot"
foreach ($protectedRoot in @(
    $repository, $sourceData, $harnessRuntime, $script:rLibrary
)) {
    Assert-Issue13V5PathsDisjoint `
        $capture $protectedRoot "CaptureRoot/protected-root isolation"
}
$baselineRoot = Join-Path $capture "baseline-e2f4-runtime"
$logsRoot = Join-Path $capture "logs"
$outputIndex = Join-Path $capture "diagnostic-bridge-evidence.csv"

$seed = @(Import-Csv -LiteralPath $seedPath -Delimiter ';')
if ($seed.Count -ne $methods.Count -or
    (@($seed[0].PSObject.Properties.Name) -join "|") -cne
        ($columns -join "|") -or
    (@($seed.method | Sort-Object -Unique) -join "|") -cne
        (@($methods | Sort-Object) -join "|")) {
    throw "Seed evidence index does not have the exact 12-method schema."
}

New-Item -ItemType Directory -Path $capture | Out-Null
New-Item -ItemType Directory -Path $logsRoot | Out-Null
$capturePhysicalObserved = ConvertTo-Issue13V5PhysicalPath `
    $capture "Created CaptureRoot"
Assert-Issue13V5NoReparse $capture
if ($capturePhysicalObserved -cne $capturePhysicalExpected) {
    throw "CaptureRoot changed physical identity during creation."
}
$verifiedRecords = @()

& git -C $repository cat-file -e ($baselineBaseCommit + "^{commit}")
if ($LASTEXITCODE -ne 0) {
    throw "The canonical baseline base commit is unavailable."
}
& git -C $repository cat-file -e ($baselineRuntimeCommit + "^{commit}")
if ($LASTEXITCODE -ne 0) {
    throw "The authenticated baseline runtime commit is unavailable."
}
Assert-GitValue $repository ("rev-parse " + $baselineBaseCommit + "^{tree}") `
    $baselineBaseTree "Canonical baseline base tree"
Assert-GitValue $repository ("rev-parse " + $baselineRuntimeCommit + "^") `
    $baselineBaseCommit "Baseline runtime parent"
Assert-GitValue $repository ("rev-parse " + $baselineRuntimeCommit + "^{tree}") `
    $baselineRuntimeTree "Baseline runtime tree"
& git -C $repository worktree add --detach $baselineRoot $baselineRuntimeCommit
if ($LASTEXITCODE -ne 0) {
    throw "Could not create the clean baseline evidence worktree."
}
Assert-CleanWorktree $baselineRoot "Fresh baseline evidence worktree"

$sourceSnapshot = Join-Path $baselineRoot "source_data"
if (Test-Path -LiteralPath $sourceSnapshot) {
    throw "Fresh baseline worktree unexpectedly contains source_data."
}
$sourceDataPhysicalBefore = Copy-Issue13V5PhysicalDirectorySnapshot `
    $sourceData $sourceSnapshot "Bridge source-data snapshot"
$sourceDataSnapshotInventoryBefore =
    Get-DirectoryInventorySha256 $sourceSnapshot
if ($sourceDataSnapshotInventoryBefore -cne
        $sourceDataOriginInventoryBefore -or
    [long]$sourceDataPhysicalBefore.file_count -ne 84L -or
    [long]$sourceDataPhysicalBefore.directory_count -ne 5L) {
    throw "Physical source-data snapshot differs from its authenticated origin."
}
Assert-CleanWorktree $baselineRoot "Baseline evidence worktree after source snapshot"

foreach ($method in $captureMethods) {
    Assert-CleanWorktree $baselineRoot "Baseline before $method"
    $before = @(Get-RunDirectories $baselineRoot $method)
    $logPath = Join-Path $logsRoot ($method + ".calculate.log")
    $channel = "issue13-v5d-parent-" + $method.Replace("_", "-")
    $arguments = @(
        "--vanilla", (Join-Path $baselineRoot "scripts\run_wlv.R"),
        "--method", $method, "--workers", "1", "--channel",
        $channel, "--allow-experimental"
    )
    $runOutput = @(Invoke-SealedRscript $arguments)
    $runOutput | Set-Content -LiteralPath $logPath -Encoding utf8
    if ($script:rscriptExitCode -ne 0) {
        throw "Baseline calculation failed for $method. See $logPath"
    }
    $after = @(Get-RunDirectories $baselineRoot $method)
    $created = @($after | Where-Object { $_ -notin $before })
    if ($created.Count -ne 1) {
        throw "Baseline calculation for $method did not create exactly one run."
    }
    Assert-CleanWorktree $baselineRoot "Baseline after $method"
    $verifyLog = Join-Path $logsRoot ($method + ".verify.log")
    $verifyArguments = @(
        "--vanilla", $verifier, $harness, $controllerDir, $baselineRoot,
        $created[0], $method
    )
    $verifyOutput = @(Invoke-SealedRscript $verifyArguments)
    $verifyOutput | Set-Content -LiteralPath $verifyLog -Encoding utf8
    $evidenceRecord = @($verifyOutput | Where-Object {
        $_ -cmatch '^evidence_record;'
    })
    if ($script:rscriptExitCode -ne 0 -or $evidenceRecord.Count -ne 1) {
        throw "Evidence authentication failed for $method. See $verifyLog"
    }
    $verifyLogSha256 = (Get-FileHash -LiteralPath $verifyLog `
        -Algorithm SHA256).Hash.ToLowerInvariant()
    $verifiedRecords += (
        $evidenceRecord[0] + ";verify_log_sha256=" + $verifyLogSha256
    )
    $row = @($seed | Where-Object { $_.method -ceq $method })
    if ($row.Count -ne 1) {
        throw "Seed evidence lacks one row for $method."
    }
    $row[0].baseline_project_root = $baselineRoot.Replace('\', '/')
    $row[0].baseline_run_root = $created[0].Replace('\', '/')
}

Assert-CleanWorktree $baselineRoot "Completed baseline evidence worktree"
$ordered = foreach ($method in $methods) {
    $row = @($seed | Where-Object { $_.method -ceq $method })
    if ($row.Count -ne 1) {
        throw "Final evidence index lacks one row for $method."
    }
    $row[0]
}
$lines = @((($columns | ForEach-Object { Quote-Csv $_ }) -join ';'))
foreach ($row in $ordered) {
    $lines += (($columns | ForEach-Object {
        Quote-Csv ([string]$row.$_)
    }) -join ';')
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($outputIndex, $lines, $utf8)
$roundTrip = [System.IO.File]::ReadAllLines($outputIndex, $utf8)
if (($roundTrip -join "`n") -cne ($lines -join "`n")) {
    throw "Evidence index failed its UTF-8 byte round trip."
}

$toolRecordsAfter = @($toolPaths.Keys | Sort-Object | ForEach-Object {
    "tool_record;name=$_;sha256=$(Get-Sha256 $toolPaths[$_])"
})
$harnessInventoryAfter = Get-DirectoryInventorySha256 $harness
$harnessRuntimeInventoryAfter = `
    Get-DirectoryInventorySha256 $harnessRuntime
$rLibraryInventoryAfter = Get-DirectoryInventorySha256 $script:rLibrary
$sourceDataOriginInventoryAfter = Get-DirectoryInventorySha256 $sourceData
$sourceDataSnapshotInventoryAfter =
    Get-DirectoryInventorySha256 $sourceSnapshot
$sourceDataPhysicalAfter = Get-Issue13V5PhysicalSnapshotProof `
    $sourceData $sourceSnapshot "Bridge source-data snapshot"
$sourceInventoriesAfter = @{}
foreach ($source in @("wiodr13", "wiodr16")) {
    $sourceInventoriesAfter[$source] = Get-DirectoryInventorySha256 `
        (Join-Path $sourceData ($source + "\normalized"))
}
if (($toolRecordsAfter -join "`n") -cne ($toolRecordsBefore -join "`n") -or
    $harnessInventoryAfter -cne $harnessInventoryBefore -or
    $harnessRuntimeInventoryAfter -cne $harnessRuntimeInventoryBefore -or
    $rLibraryInventoryAfter -cne $rLibraryInventoryBefore -or
    $sourceDataOriginInventoryAfter -cne
        $sourceDataOriginInventoryBefore -or
    $sourceDataSnapshotInventoryAfter -cne
        $sourceDataSnapshotInventoryBefore -or
    $sourceDataSnapshotInventoryBefore -cne
        $sourceDataOriginInventoryBefore -or
    [string]$sourceDataPhysicalAfter.source_physical_path -cne
        [string]$sourceDataPhysicalBefore.source_physical_path -or
    [string]$sourceDataPhysicalAfter.snapshot_physical_path -cne
        [string]$sourceDataPhysicalBefore.snapshot_physical_path -or
    [long]$sourceDataPhysicalAfter.file_count -ne
        [long]$sourceDataPhysicalBefore.file_count -or
    [long]$sourceDataPhysicalAfter.directory_count -ne
        [long]$sourceDataPhysicalBefore.directory_count -or
    [string]$sourceDataPhysicalAfter.source_physical_inventory_sha256 -cne
        [string]$sourceDataPhysicalBefore.source_physical_inventory_sha256 -or
    [string]$sourceDataPhysicalAfter.snapshot_physical_inventory_sha256 -cne
        [string]$sourceDataPhysicalBefore.snapshot_physical_inventory_sha256 -or
    [string]$sourceDataPhysicalAfter.independence_sha256 -cne
        [string]$sourceDataPhysicalBefore.independence_sha256 -or
    $sourceInventoriesAfter['wiodr13'] -cne
        $sourceInventoriesBefore['wiodr13'] -or
    $sourceInventoriesAfter['wiodr16'] -cne
        $sourceInventoriesBefore['wiodr16'] -or
    (Get-Sha256 $rscriptPath) -cne $rscriptSha256 -or
    (Get-Sha256 $fsutilPath) -cne $fsutilSha256) {
    throw "Diagnostic capture tooling changed during execution."
}
$captureRecord = @(
    "schema=issue13-v5-clean-bridge-capture/2",
    "baseline_base_commit=$baselineBaseCommit",
    "baseline_base_tree=$baselineBaseTree",
    "baseline_runtime_commit=$baselineRuntimeCommit",
    "baseline_runtime_tree=$baselineRuntimeTree",
    "harness_path=$($harness.Replace('\', '/'))",
    "harness_inventory_sha256=$harnessInventoryBefore",
    "harness_runtime_path=$($harnessRuntime.Replace('\', '/'))",
    "harness_runtime_inventory_before_sha256=$harnessRuntimeInventoryBefore",
    "harness_runtime_inventory_after_sha256=$harnessRuntimeInventoryAfter",
    "rscript_path=$($rscriptPath.Replace('\', '/'))",
    "rscript_sha256=$rscriptSha256",
    "fsutil_path=$($fsutilPath.Replace('\', '/'))",
    "fsutil_sha256=$fsutilSha256",
    "r_library_path=$($script:rLibrary.Replace('\', '/'))",
    "r_library_inventory_before_sha256=$rLibraryInventoryBefore",
    "r_library_inventory_after_sha256=$rLibraryInventoryAfter",
    "tool_records=$($toolRecordsBefore.Count)",
    "baseline_worktree=$($baselineRoot.Replace('\', '/'))",
    "captured_methods=$($captureMethods -join ',')",
    "verified_records=$($verifiedRecords.Count)",
    "seed_evidence_index_sha256=$((Get-FileHash -LiteralPath $seedPath -Algorithm SHA256).Hash.ToLowerInvariant())",
    "source_data_origin_path=$($sourceData.Replace('\', '/'))",
    "source_data_snapshot_path=$($sourceSnapshot.Replace('\', '/'))",
    "source_data_origin_inventory_before_sha256=$sourceDataOriginInventoryBefore",
    "source_data_origin_inventory_after_sha256=$sourceDataOriginInventoryAfter",
    "source_data_snapshot_inventory_before_sha256=$sourceDataSnapshotInventoryBefore",
    "source_data_snapshot_inventory_after_sha256=$sourceDataSnapshotInventoryAfter",
    "source_data_origin_physical_path=$([string]$sourceDataPhysicalBefore.source_physical_path -replace '\\', '/')",
    "source_data_snapshot_physical_path=$([string]$sourceDataPhysicalBefore.snapshot_physical_path -replace '\\', '/')",
    "source_data_physical_file_count=$($sourceDataPhysicalBefore.file_count)",
    "source_data_physical_directory_count=$($sourceDataPhysicalBefore.directory_count)",
    "source_data_origin_physical_before_sha256=$($sourceDataPhysicalBefore.source_physical_inventory_sha256)",
    "source_data_origin_physical_after_sha256=$($sourceDataPhysicalAfter.source_physical_inventory_sha256)",
    "source_data_snapshot_physical_before_sha256=$($sourceDataPhysicalBefore.snapshot_physical_inventory_sha256)",
    "source_data_snapshot_physical_after_sha256=$($sourceDataPhysicalAfter.snapshot_physical_inventory_sha256)",
    "source_data_independence_before_sha256=$($sourceDataPhysicalBefore.independence_sha256)",
    "source_data_independence_after_sha256=$($sourceDataPhysicalAfter.independence_sha256)",
    "source_wiodr13_manifest_sha256=$($sourceManifestHashes['wiodr13'])",
    "source_wiodr16_manifest_sha256=$($sourceManifestHashes['wiodr16'])",
    "source_wiodr13_inventory_before_sha256=$($sourceInventoriesBefore['wiodr13'])",
    "source_wiodr13_inventory_after_sha256=$($sourceInventoriesAfter['wiodr13'])",
    "source_wiodr16_inventory_before_sha256=$($sourceInventoriesBefore['wiodr16'])",
    "source_wiodr16_inventory_after_sha256=$($sourceInventoriesAfter['wiodr16'])",
    "evidence_index=$($outputIndex.Replace('\', '/'))",
    "evidence_index_sha256=$((Get-FileHash -LiteralPath $outputIndex -Algorithm SHA256).Hash.ToLowerInvariant())"
) + $toolRecordsBefore + $verifiedRecords
$captureRecordPath = Join-Path $capture "capture-record.txt"
[System.IO.File]::WriteAllLines($captureRecordPath, $captureRecord, $utf8)
$captureRoundTrip = [System.IO.File]::ReadAllLines($captureRecordPath, $utf8)
if (($captureRoundTrip -join "`n") -cne ($captureRecord -join "`n")) {
    throw "Capture record failed its UTF-8 byte round trip."
}
Write-Output ("capture_root=" + $capture.Replace('\', '/'))
Write-Output ("evidence_index=" + $outputIndex.Replace('\', '/'))
Write-Output ("capture_record=" + $captureRecordPath.Replace('\', '/'))
Write-Output ("capture_record_sha256=" + (
    Get-FileHash -LiteralPath $captureRecordPath -Algorithm SHA256
).Hash.ToLowerInvariant())
Write-Output "captured_runs=7"
