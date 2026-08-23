[CmdletBinding()]
param([string]$Destination)

$ErrorActionPreference = 'Stop'

function Fail-Backup {
    param([string]$Message)
    [Console]::Error.WriteLine($Message)
    exit 1
}

function Test-PrivacyPath {
    param([string]$Path)
    return $Path -eq '.workbuddy' -or $Path -like '.workbuddy/*' -or
           $Path -eq '打分记录' -or $Path -like '打分记录/*' -or
           $Path -eq '.worktrees' -or $Path -like '.worktrees/*'
}

$repositoryRoot = Split-Path -LiteralPath $PSScriptRoot
$useDefaultDestination = [string]::IsNullOrWhiteSpace($Destination)
if ($useDefaultDestination) { $Destination = Join-Path $env:USERPROFILE 'Documents\IJRU-scoring-backups' }
if (-not [System.IO.Path]::IsPathFullyQualified($Destination)) { Fail-Backup "Destination must be an absolute directory: $Destination" }
if ($useDefaultDestination -and -not (Test-Path -LiteralPath $Destination -PathType Container)) { [System.IO.Directory]::CreateDirectory($Destination) | Out-Null }
if (-not (Test-Path -LiteralPath $Destination -PathType Container)) { Fail-Backup "Destination directory does not exist: $Destination" }

$destinationPath = (Resolve-Path -LiteralPath $Destination).Path
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundlePath = Join-Path $destinationPath "ijru-scoring-$timestamp.bundle"
$temporaryBundlePath = Join-Path $destinationPath (".ijru-scoring-$timestamp." + [guid]::NewGuid().ToString('N') + '.tmp')
if (Test-Path -LiteralPath $bundlePath) { Fail-Backup "Backup already exists and will not be overwritten: $bundlePath" }

Push-Location -LiteralPath $repositoryRoot
try {
    $historyPaths = @(git log --all --format= --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to scan Git history for private paths.' }
    foreach ($historyPath in $historyPaths) {
        if (Test-PrivacyPath $historyPath) { throw "Refusing to bundle privacy path in Git history: $historyPath" }
    }

    git bundle create $temporaryBundlePath --all
    if ($LASTEXITCODE -ne 0) { throw 'git bundle create failed.' }
    git bundle verify $temporaryBundlePath
    if ($LASTEXITCODE -ne 0) { throw 'git bundle verify failed.' }
    Move-Item -LiteralPath $temporaryBundlePath -Destination $bundlePath -ErrorAction Stop
}
catch {
    if (Test-Path -LiteralPath $temporaryBundlePath) { Remove-Item -LiteralPath $temporaryBundlePath -Force }
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
finally { Pop-Location }

Write-Output "BundlePath=$bundlePath"
Write-Host "Verified backup bundle: $bundlePath"
exit 0
