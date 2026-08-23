[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Version)

$ErrorActionPreference = 'Stop'

function Fail-Verification {
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

function Get-ExecutableJavaScript {
    param([string]$Html)

    $scriptMatches = [regex]::Matches($Html, '(?is)<script\b[^>]*>(.*?)</script>')
    $code = [string]::Join("`n", @($scriptMatches | ForEach-Object { $_.Groups[1].Value }))
    $code = [regex]::Replace($code, 'addEventListener\s*\(\s*[''"]click[''"]', 'addEventListener(__IJRU_CLICK__)')
    $code = [regex]::Replace($code, 'addEventListener\s*\(\s*[''"]input[''"]', 'addEventListener(__IJRU_INPUT__)')
    $code = [regex]::Replace($code, '(?s)`(?:\\.|[^`\\])*`', '')
    $code = [regex]::Replace($code, "(?s)'(?:\\.|[^'\\])*'", '')
    $code = [regex]::Replace($code, '(?s)"(?:\\.|[^"\\])*"', '')
    $code = [regex]::Replace($code, '(?s)/\*.*?\*/', '')
    return [regex]::Replace($code, '(?m)//[^\r\n]*', '')
}

if ($Version -notmatch '^\d+\.\d+$') { Fail-Verification "Version must use major.minor format: $Version" }

$gitRepositoryRoot = Split-Path -LiteralPath $PSScriptRoot
$repositoryRoot = $gitRepositoryRoot
$sourcePath = Join-Path $repositoryRoot 'scoring-calculator.html'
$releasePath = Join-Path $repositoryRoot 'docs\index.html'
$snapshotPath = Join-Path $repositoryRoot ("versions\scoring-calculator-v$Version.html")
$htmlPaths = @($sourcePath, $releasePath, $snapshotPath)
foreach ($htmlPath in $htmlPaths) {
    if (-not (Test-Path -LiteralPath $htmlPath -PathType Leaf)) { Fail-Verification "Required HTML file is missing: $htmlPath" }
}

$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
foreach ($htmlPath in @($releasePath, $snapshotPath)) {
    if ((Get-FileHash -LiteralPath $htmlPath -Algorithm SHA256).Hash -ne $sourceHash) { Fail-Verification "HTML SHA256 does not match the source: $htmlPath" }
}

$requiredPatterns = @(
    '(?m)^[\t ]*function\s+calcDDDJ\s*\(',
    '(?m)^[\t ]*function\s+calcDDDT\s*\(',
    '(?m)^[\t ]*function\s+calcSRQ\s*\(',
    '(?m)^[\t ]*function\s+calculate\s*\(',
    '(?m)^[\t ]*function\s+switchEvent\s*\(',
    'addEventListener\s*\(\s*__IJRU_CLICK__',
    'addEventListener\s*\(\s*__IJRU_INPUT__'
)
foreach ($htmlPath in $htmlPaths) {
    $content = Get-Content -LiteralPath $htmlPath -Raw
    $code = Get-ExecutableJavaScript $content
    foreach ($requiredPattern in $requiredPatterns) {
        if ($code -notmatch $requiredPattern) { Fail-Verification "Required event or core function is missing from: $htmlPath" }
    }
    $hasConflictStart = $content -match '(?m)^[\t ]*<<<<<<<[^\r\n]*\r?$'
    $hasConflictSeparator = $content -match '(?m)^[\t ]*=======[\t ]*\r?$'
    $hasConflictEnd = $content -match '(?m)^[\t ]*>>>>>>>[^\r\n]*\r?$'
    if ($hasConflictStart -or $hasConflictSeparator -or $hasConflictEnd) { Fail-Verification "Git merge conflict marker found in: $htmlPath" }
}

Push-Location -LiteralPath $gitRepositoryRoot
try {
    foreach ($privacyProbe in @('.workbuddy/probe', '打分记录/probe', '.worktrees/probe')) {
        git check-ignore --no-index -q -- $privacyProbe
        if ($LASTEXITCODE -ne 0) { Fail-Verification "Privacy path is not actually ignored: $privacyProbe" }
    }
    $trackedFiles = @(git ls-files)
    if ($LASTEXITCODE -ne 0) { Fail-Verification 'Unable to inspect Git tracking status.' }
} finally { Pop-Location }

foreach ($trackedFile in $trackedFiles) {
    if (Test-PrivacyPath $trackedFile) { Fail-Verification "Privacy path is tracked: $trackedFile" }
}

Write-Host "Project verification passed for v$Version."
exit 0
