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

    $result = New-Object System.Text.StringBuilder
    foreach ($match in [regex]::Matches($Html, '(?is)<script\b(?<attributes>[^>]*)>(?<body>.*?)</script>')) {
        $typeMatch = [regex]::Match($match.Groups['attributes'].Value, '(?i)\btype\s*=\s*(?:"(?<value>[^"]*)"|''(?<value>[^'']*)''|(?<value>[^\s>]+))')
        $scriptType = if ($typeMatch.Success) { $typeMatch.Groups['value'].Value.Trim().ToLowerInvariant() } else { '' }
        if ($scriptType -and $scriptType -notin @('text/javascript', 'application/javascript', 'application/ecmascript', 'text/ecmascript', 'module')) { continue }

        $body = $match.Groups['body'].Value
        $state = 'code'
        $escaped = $false
        $stringValue = New-Object System.Text.StringBuilder
        for ($index = 0; $index -lt $body.Length; $index++) {
            $character = $body[$index]
            $next = if ($index + 1 -lt $body.Length) { $body[$index + 1] } else { [char]0 }
            if ($state -eq 'code') {
                if ($character -eq '/' -and $next -eq '/') { $state = 'line-comment'; $index++; continue }
                if ($character -eq '/' -and $next -eq '*') { $state = 'block-comment'; $index++; continue }
                if ($character -eq '<' -and $index + 3 -lt $body.Length -and $body.Substring($index, 4) -eq '<!--') { $state = 'html-comment'; $index += 3; continue }
                if ($character -eq [char]39) { $state = 'single-string'; $stringValue.Clear() | Out-Null; $escaped = $false; continue }
                if ($character -eq [char]34) { $state = 'double-string'; $stringValue.Clear() | Out-Null; $escaped = $false; continue }
                if ($character -eq [char]96) { $state = 'template-string'; $escaped = $false; continue }
                [void]$result.Append($character)
                continue
            }
            if ($state -eq 'line-comment') {
                if ($character -eq "`n") { [void]$result.Append("`n"); $state = 'code' }
                continue
            }
            if ($state -eq 'block-comment') {
                if ($character -eq '*' -and $next -eq '/') { $state = 'code'; $index++; continue }
                if ($character -eq "`n") { [void]$result.Append("`n") }
                continue
            }
            if ($state -eq 'html-comment') {
                if ($character -eq '-' -and $index + 2 -lt $body.Length -and $body.Substring($index, 3) -eq '-->') { $state = 'code'; $index += 2; continue }
                if ($character -eq "`n") { [void]$result.Append("`n") }
                continue
            }
            if ($state -eq 'template-string') {
                if ($escaped) { $escaped = $false; continue }
                if ($character -eq [char]92) { $escaped = $true; continue }
                if ($character -eq [char]96) { $state = 'code'; continue }
                if ($character -eq "`n") { [void]$result.Append("`n") }
                continue
            }
            if ($escaped) { [void]$stringValue.Append($character); $escaped = $false; continue }
            if ($character -eq [char]92) { $escaped = $true; continue }
            if (($state -eq 'single-string' -and $character -eq [char]39) -or ($state -eq 'double-string' -and $character -eq [char]34)) {
                if ($stringValue.ToString() -eq 'click') { [void]$result.Append('__IJRU_CLICK__') }
                if ($stringValue.ToString() -eq 'input') { [void]$result.Append('__IJRU_INPUT__') }
                $state = 'code'
                continue
            }
            if ($character -eq "`n") { [void]$result.Append("`n"); $state = 'code'; continue }
            [void]$stringValue.Append($character)
        }
        [void]$result.Append("`n")
    }
    return $result.ToString()
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
