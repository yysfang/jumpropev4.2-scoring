[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = 'Stop'

function Fail-Release {
    param([string]$Message)

    [Console]::Error.WriteLine($Message)
    exit 1
}

if ($Version -notmatch '^\d+\.\d+$') {
    Fail-Release "Version must use major.minor format: $Version"
}

$repositoryRoot = Split-Path -LiteralPath $PSScriptRoot
$sourcePath = Join-Path -Path $repositoryRoot -ChildPath 'scoring-calculator.html'
$releasePath = Join-Path -Path $repositoryRoot -ChildPath 'docs\index.html'
$snapshotPath = Join-Path -Path $repositoryRoot -ChildPath ("versions\scoring-calculator-v$Version.html")
$verificationScript = Join-Path -Path $PSScriptRoot -ChildPath 'verify-project.ps1'

if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    Fail-Release "Source HTML is missing: $sourcePath"
}
if (-not (Test-Path -LiteralPath $releasePath -PathType Leaf)) {
    Fail-Release "Release page is missing: $releasePath"
}
if (-not (Test-Path -LiteralPath $verificationScript -PathType Leaf)) {
    Fail-Release "Verification script is missing: $verificationScript"
}
if (Test-Path -LiteralPath $snapshotPath) {
    Fail-Release "Release version already exists and will not be overwritten: $Version"
}

Copy-Item -LiteralPath $sourcePath -Destination $releasePath
Copy-Item -LiteralPath $sourcePath -Destination $snapshotPath

& $verificationScript -Version $Version
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Release v$Version created and verified."
exit 0
