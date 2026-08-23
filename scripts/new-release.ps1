[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Version)

$ErrorActionPreference = 'Stop'

function Fail-Release {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
    exit 1
}

function New-AdjacentTemporaryPath {
    param([string]$Path)
    $directory = Split-Path -LiteralPath $Path
    $leaf = Split-Path -Leaf $Path
    return Join-Path $directory (".$leaf." + [guid]::NewGuid().ToString('N') + '.tmp')
}

if ($Version -notmatch '^[0-9]+\.[0-9]+$') { Fail-Release "Version must use major.minor format: $Version" }

$repositoryRoot = Split-Path -LiteralPath $PSScriptRoot
$sourcePath = Join-Path $repositoryRoot 'scoring-calculator.html'
$releasePath = Join-Path $repositoryRoot 'docs\index.html'
$snapshotPath = Join-Path $repositoryRoot ("versions\scoring-calculator-v$Version.html")
$verificationScript = Join-Path $PSScriptRoot 'verify-project.ps1'
foreach ($path in @($sourcePath, $releasePath, $verificationScript)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail-Release "Required release file is missing: $path" }
}
if (Test-Path -LiteralPath $snapshotPath) { Fail-Release "Release version already exists and will not be overwritten: $Version" }

$releaseBackupPath = New-AdjacentTemporaryPath $releasePath
$releaseCandidatePath = New-AdjacentTemporaryPath $releasePath
$snapshotCandidatePath = New-AdjacentTemporaryPath $snapshotPath
$releaseReplaced = $false
$snapshotCreated = $false
$releaseBackupCreated = $false
$preserveReleaseBackup = $false
try {
    Copy-Item -LiteralPath $releasePath -Destination $releaseBackupPath -ErrorAction Stop
    $releaseBackupCreated = $true
    Copy-Item -LiteralPath $sourcePath -Destination $releaseCandidatePath -ErrorAction Stop
    Copy-Item -LiteralPath $sourcePath -Destination $snapshotCandidatePath -ErrorAction Stop

    Move-Item -LiteralPath $releaseCandidatePath -Destination $releasePath -Force -ErrorAction Stop
    $releaseReplaced = $true
    Move-Item -LiteralPath $snapshotCandidatePath -Destination $snapshotPath -ErrorAction Stop
    $snapshotCreated = $true

    & $verificationScript -Version $Version
    if ($LASTEXITCODE -ne 0) { throw 'Release verification failed.' }

    Remove-Item -LiteralPath $releaseBackupPath -Force -ErrorAction Stop
    $releaseBackupCreated = $false
    Write-Host "Release v$Version created and verified."
    exit 0
}
catch {
    $releaseFailureMessage = $_.Exception.Message
    $rollbackFailureMessage = $null
    if ($releaseReplaced -and $releaseBackupCreated -and (Test-Path -LiteralPath $releaseBackupPath)) {
        try {
            Copy-Item -LiteralPath $releaseBackupPath -Destination $releasePath -Force -ErrorAction Stop
            $releaseReplaced = $false
        } catch {
            $rollbackFailureMessage = $_.Exception.Message
            $preserveReleaseBackup = $true
        }
    }
    if ($snapshotCreated -and (Test-Path -LiteralPath $snapshotPath)) {
        try {
            Remove-Item -LiteralPath $snapshotPath -Force -ErrorAction Stop
            $snapshotCreated = $false
        } catch {
            if (-not $rollbackFailureMessage) { $rollbackFailureMessage = $_.Exception.Message }
        }
    }
    if ($preserveReleaseBackup) {
        $absoluteRecoveryBackupPath = [System.IO.Path]::GetFullPath($releaseBackupPath)
        Write-Output "RecoveryBackupPath=$absoluteRecoveryBackupPath"
        [Console]::Error.WriteLine("$releaseFailureMessage Rollback failed: $rollbackFailureMessage Recovery backup preserved at: $absoluteRecoveryBackupPath")
    } else {
        [Console]::Error.WriteLine($releaseFailureMessage)
    }
    exit 1
}
finally {
    foreach ($temporaryPath in @($releaseCandidatePath, $snapshotCandidatePath)) {
        if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force }
    }
    if ($releaseBackupCreated -and -not $preserveReleaseBackup -and (Test-Path -LiteralPath $releaseBackupPath)) {
        Remove-Item -LiteralPath $releaseBackupPath -Force
    }
}
