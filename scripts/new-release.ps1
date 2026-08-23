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

if ($Version -notmatch '^\d+\.\d+$') { Fail-Release "Version must use major.minor format: $Version" }

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
try {
    $candidateContent = Get-Content -LiteralPath $sourcePath -Raw
    foreach ($candidatePattern in @('(?m)^[\t ]*function\s+calculate\s*\(', '(?m)^[\t ]*function\s+switchEvent\s*\(', 'addEventListener\s*\(\s*[''" ]click[''" ]', 'addEventListener\s*\(\s*[''" ]input[''" ]')) {
        if ($candidateContent -notmatch $candidatePattern) { throw 'Release candidate is missing a required function or event.' }
    }
    if ($candidateContent -match '(?m)^[\t ]*<<<<<<<[^\r\n]*\r?$' -or $candidateContent -match '(?m)^[\t ]*=======[\t ]*\r?$' -or $candidateContent -match '(?m)^[\t ]*>>>>>>>[^\r\n]*\r?$') { throw 'Release candidate contains a Git conflict marker.' }

    Copy-Item -LiteralPath $releasePath -Destination $releaseBackupPath -ErrorAction Stop
    Copy-Item -LiteralPath $sourcePath -Destination $releaseCandidatePath -ErrorAction Stop
    Copy-Item -LiteralPath $sourcePath -Destination $snapshotCandidatePath -ErrorAction Stop

    Move-Item -LiteralPath $releaseCandidatePath -Destination $releasePath -Force -ErrorAction Stop
    $releaseReplaced = $true
    Move-Item -LiteralPath $snapshotCandidatePath -Destination $snapshotPath -ErrorAction Stop
    $snapshotCreated = $true

    & $verificationScript -Version $Version
    if ($LASTEXITCODE -ne 0) { throw 'Release verification failed.' }

    Remove-Item -LiteralPath $releaseBackupPath -Force -ErrorAction Stop
    Write-Host "Release v$Version created and verified."
    exit 0
}
catch {
    if ($releaseReplaced -and (Test-Path -LiteralPath $releaseBackupPath)) {
        Copy-Item -LiteralPath $releaseBackupPath -Destination $releasePath -Force
    }
    if ($snapshotCreated -and (Test-Path -LiteralPath $snapshotPath)) {
        Remove-Item -LiteralPath $snapshotPath -Force
    }
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
finally {
    foreach ($temporaryPath in @($releaseBackupPath, $releaseCandidatePath, $snapshotCandidatePath)) {
        if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force }
    }
}
