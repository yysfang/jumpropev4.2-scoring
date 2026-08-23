[CmdletBinding()]
param(
    [string]$Destination
)

$ErrorActionPreference = 'Stop'

function Fail-Backup {
    param([string]$Message)

    [Console]::Error.WriteLine($Message)
    exit 1
}

$repositoryRoot = Split-Path -LiteralPath $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Destination)) {
    $Destination = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
}

if (-not [System.IO.Path]::IsPathFullyQualified($Destination)) {
    Fail-Backup "Destination must be an absolute directory: $Destination"
}
if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
    Fail-Backup "Destination directory does not exist: $Destination"
}

$destinationPath = (Resolve-Path -LiteralPath $Destination).Path
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundlePath = Join-Path -Path $destinationPath -ChildPath ("ijru-scoring-$timestamp.bundle")
if (Test-Path -LiteralPath $bundlePath) {
    Fail-Backup "Backup already exists and will not be overwritten: $bundlePath"
}

Push-Location -LiteralPath $repositoryRoot
try {
    git bundle create $bundlePath --all
    if ($LASTEXITCODE -ne 0) {
        Fail-Backup 'git bundle create failed.'
    }

    git bundle verify $bundlePath
    if ($LASTEXITCODE -ne 0) {
        Fail-Backup 'git bundle verify failed.'
    }
}
finally {
    Pop-Location
}

Write-Host "Verified backup bundle: $bundlePath"
exit 0
