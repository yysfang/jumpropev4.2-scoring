[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = 'Stop'

function Fail-Verification {
    param([string]$Message)

    [Console]::Error.WriteLine($Message)
    exit 1
}

if ($Version -notmatch '^\d+\.\d+$') {
    Fail-Verification "Version must use major.minor format: $Version"
}

$repositoryRoot = Split-Path -LiteralPath $PSScriptRoot
$sourcePath = Join-Path -Path $repositoryRoot -ChildPath 'scoring-calculator.html'
$releasePath = Join-Path -Path $repositoryRoot -ChildPath 'docs\index.html'
$snapshotPath = Join-Path -Path $repositoryRoot -ChildPath ("versions\scoring-calculator-v$Version.html")
$htmlPaths = @($sourcePath, $releasePath, $snapshotPath)

foreach ($htmlPath in $htmlPaths) {
    if (-not (Test-Path -LiteralPath $htmlPath -PathType Leaf)) {
        Fail-Verification "Required HTML file is missing: $htmlPath"
    }
}

$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
foreach ($htmlPath in @($releasePath, $snapshotPath)) {
    if ((Get-FileHash -LiteralPath $htmlPath -Algorithm SHA256).Hash -ne $sourceHash) {
        Fail-Verification "HTML SHA256 does not match the source: $htmlPath"
    }
}

$requiredPatterns = @(
    'function\s+calcDDDJ\s*\(',
    'function\s+calcDDDT\s*\(',
    'function\s+calcSRQ\s*\(',
    'function\s+calculate\s*\(',
    'function\s+switchEvent\s*\(',
    'addEventListener\s*\('
)
$conflictPattern = '(?m)^(<<<<<<<|=======|>>>>>>>)'

foreach ($htmlPath in $htmlPaths) {
    foreach ($requiredPattern in $requiredPatterns) {
        if (-not (Select-String -LiteralPath $htmlPath -Pattern $requiredPattern -Quiet)) {
            Fail-Verification "Required event or core function is missing from: $htmlPath"
        }
    }
    if (Select-String -LiteralPath $htmlPath -Pattern $conflictPattern -Quiet) {
        Fail-Verification "Merge conflict marker found in: $htmlPath"
    }
}

$gitIgnorePath = Join-Path -Path $repositoryRoot -ChildPath '.gitignore'
if (-not (Test-Path -LiteralPath $gitIgnorePath -PathType Leaf)) {
    Fail-Verification 'Missing .gitignore privacy-path rules.'
}

$gitIgnoreContent = Get-Content -LiteralPath $gitIgnorePath -Raw
foreach ($privacyPath in @('.workbuddy/', '打分记录/', '.worktrees/')) {
    if ($gitIgnoreContent -notmatch [regex]::Escape($privacyPath)) {
        Fail-Verification "Privacy path is not ignored: $privacyPath"
    }
}

Push-Location -LiteralPath $repositoryRoot
try {
    $trackedFiles = @(git ls-files)
    if ($LASTEXITCODE -ne 0) {
        Fail-Verification 'Unable to inspect Git tracking status.'
    }
}
finally {
    Pop-Location
}

foreach ($trackedFile in $trackedFiles) {
    if ($trackedFile -like '.workbuddy/*' -or $trackedFile -like '打分记录/*' -or $trackedFile -like '.worktrees/*') {
        Fail-Verification "Privacy path is tracked: $trackedFile"
    }
}

Write-Host "Project verification passed for v$Version."
exit 0
