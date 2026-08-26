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
$captureMethods = @(
    "alternative_1", "alternative_2", "norow_w13", "ochoa_1",
    "ochoa_2", "petrovic", "wiodr13v09"
)
$columns = @(
    "method", "candidate_project_root", "candidate_run_root",
    "baseline_project_root", "baseline_run_root"
)

function Resolve-ExistingDirectory([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Label does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
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

$repository = Resolve-ExistingDirectory $RepositoryRoot "Repository root"
$sourceData = Resolve-ExistingDirectory $BaselineSourceDataRoot "Source-data root"
$harness = Resolve-ExistingDirectory $HarnessDir "Harness directory"
$seedPath = (Resolve-Path -LiteralPath $SeedEvidenceIndex).Path
$controllerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$verifier = Join-Path $controllerDir "issue13-v5-verify-diagnostic-evidence.R"
if (-not (Test-Path -LiteralPath $verifier -PathType Leaf)) {
    throw "The diagnostic evidence verifier is missing."
}
foreach ($source in @("wiodr13", "wiodr16")) {
    $sourceManifest = Join-Path $sourceData (
        $source + "\normalized\_source_manifest.csv"
    )
    if (-not (Test-Path -LiteralPath $sourceManifest -PathType Leaf)) {
        throw "The normalized $source source manifest is missing."
    }
}
$sourceManifestHashes = @{}
foreach ($source in @("wiodr13", "wiodr16")) {
    $sourceManifest = Join-Path $sourceData (
        $source + "\normalized\_source_manifest.csv"
    )
    $sourceManifestHashes[$source] = (Get-FileHash -LiteralPath `
        $sourceManifest -Algorithm SHA256).Hash.ToLowerInvariant()
}
if (Test-Path -LiteralPath $CaptureRoot) {
    throw "CaptureRoot is write-once and must not already exist."
}
$captureParent = Split-Path -Parent $CaptureRoot
if (-not (Test-Path -LiteralPath $captureParent -PathType Container)) {
    throw "CaptureRoot parent does not exist: $captureParent"
}
$capture = [System.IO.Path]::GetFullPath($CaptureRoot)
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

$sourceLink = Join-Path $baselineRoot "source_data"
if (Test-Path -LiteralPath $sourceLink) {
    throw "Fresh baseline worktree unexpectedly contains source_data."
}
New-Item -ItemType Junction -Path $sourceLink -Target $sourceData | Out-Null
Assert-CleanWorktree $baselineRoot "Baseline evidence worktree after source link"

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
    $runOutput = @(& $RscriptCommand @arguments 2>&1)
    $runOutput | Set-Content -LiteralPath $logPath -Encoding utf8
    if ($LASTEXITCODE -ne 0) {
        throw "Baseline calculation failed for $method. See $logPath"
    }
    $after = @(Get-RunDirectories $baselineRoot $method)
    $created = @($after | Where-Object { $_ -notin $before })
    if ($created.Count -ne 1) {
        throw "Baseline calculation for $method did not create exactly one run."
    }
    Assert-CleanWorktree $baselineRoot "Baseline after $method"
    $verifyLog = Join-Path $logsRoot ($method + ".verify.log")
    $verifyOutput = @(& $RscriptCommand --vanilla $verifier `
        $harness $controllerDir $baselineRoot $created[0] $method 2>&1)
    $verifyOutput | Set-Content -LiteralPath $verifyLog -Encoding utf8
    $evidenceRecord = @($verifyOutput | Where-Object {
        $_ -cmatch '^evidence_record;'
    })
    if ($LASTEXITCODE -ne 0 -or $evidenceRecord.Count -ne 1) {
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

$captureRecord = @(
    "schema=issue13-v5-clean-bridge-capture/1",
    "baseline_base_commit=$baselineBaseCommit",
    "baseline_base_tree=$baselineBaseTree",
    "baseline_runtime_commit=$baselineRuntimeCommit",
    "baseline_runtime_tree=$baselineRuntimeTree",
    "baseline_worktree=$($baselineRoot.Replace('\', '/'))",
    "captured_methods=$($captureMethods -join ',')",
    "verified_records=$($verifiedRecords.Count)",
    "seed_evidence_index_sha256=$((Get-FileHash -LiteralPath $seedPath -Algorithm SHA256).Hash.ToLowerInvariant())",
    "source_wiodr13_manifest_sha256=$($sourceManifestHashes['wiodr13'])",
    "source_wiodr16_manifest_sha256=$($sourceManifestHashes['wiodr16'])",
    "evidence_index=$($outputIndex.Replace('\', '/'))",
    "evidence_index_sha256=$((Get-FileHash -LiteralPath $outputIndex -Algorithm SHA256).Hash.ToLowerInvariant())"
) + $verifiedRecords
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
