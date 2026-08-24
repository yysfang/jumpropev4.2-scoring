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

function Test-HtmlWhitespace {
    param([char]$Character)
    return $Character -eq ' ' -or $Character -eq "`t" -or $Character -eq "`n" -or
           $Character -eq "`r" -or $Character -eq "`f"
}

function Read-HtmlTag {
    param([string]$Html, [int]$StartIndex)

    if ($StartIndex -ge $Html.Length -or $Html[$StartIndex] -ne '<') { return $null }
    $index = $StartIndex + 1
    $isEndTag = $false
    if ($index -lt $Html.Length -and $Html[$index] -eq '/') {
        $isEndTag = $true
        $index++
    }
    if ($index -ge $Html.Length -or -not [char]::IsLetter($Html[$index])) { return $null }

    $nameStart = $index
    while ($index -lt $Html.Length) {
        $character = $Html[$index]
        if ((Test-HtmlWhitespace $character) -or $character -eq '/' -or $character -eq '>') { break }
        $index++
    }
    $tagName = $Html.Substring($nameStart, $index - $nameStart).ToLowerInvariant()
    $attributes = @{}

    while ($index -lt $Html.Length) {
        while ($index -lt $Html.Length -and (Test-HtmlWhitespace $Html[$index])) { $index++ }
        if ($index -ge $Html.Length) { break }
        if ($Html[$index] -eq '>') { $index++; break }
        if ($Html[$index] -eq '/') { $index++; continue }

        $attributeStart = $index
        while ($index -lt $Html.Length) {
            $character = $Html[$index]
            if ((Test-HtmlWhitespace $character) -or $character -eq '=' -or $character -eq '/' -or $character -eq '>') { break }
            $index++
        }
        if ($index -eq $attributeStart) { $index++; continue }

        $attributeName = $Html.Substring($attributeStart, $index - $attributeStart).ToLowerInvariant()
        while ($index -lt $Html.Length -and (Test-HtmlWhitespace $Html[$index])) { $index++ }
        $attributeValue = ''
        if ($index -lt $Html.Length -and $Html[$index] -eq '=') {
            $index++
            while ($index -lt $Html.Length -and (Test-HtmlWhitespace $Html[$index])) { $index++ }
            if ($index -lt $Html.Length -and ($Html[$index] -eq [char]34 -or $Html[$index] -eq [char]39)) {
                $quote = $Html[$index]
                $index++
                $valueStart = $index
                while ($index -lt $Html.Length -and $Html[$index] -ne $quote) { $index++ }
                $attributeValue = $Html.Substring($valueStart, $index - $valueStart)
                if ($index -lt $Html.Length) { $index++ }
            } else {
                $valueStart = $index
                while ($index -lt $Html.Length -and -not (Test-HtmlWhitespace $Html[$index]) -and $Html[$index] -ne '>') { $index++ }
                $attributeValue = $Html.Substring($valueStart, $index - $valueStart)
            }
        }
        if (-not $attributes.ContainsKey($attributeName)) { $attributes[$attributeName] = $attributeValue }
    }

    return [pscustomobject]@{
        Name = $tagName
        IsEndTag = $isEndTag
        Attributes = $attributes
        EndIndex = $index
    }
}

function Find-HtmlEndTag {
    param([string]$Html, [int]$StartIndex, [string]$TagName)

    $searchIndex = $StartIndex
    $needle = "</$TagName"
    while ($searchIndex -lt $Html.Length) {
        $candidateIndex = $Html.IndexOf($needle, $searchIndex, [System.StringComparison]::OrdinalIgnoreCase)
        if ($candidateIndex -lt 0) { return $null }
        $afterName = $candidateIndex + $needle.Length
        if ($afterName -ge $Html.Length -or (Test-HtmlWhitespace $Html[$afterName]) -or $Html[$afterName] -eq '/' -or $Html[$afterName] -eq '>') {
            $candidateTag = Read-HtmlTag -Html $Html -StartIndex $candidateIndex
            if ($candidateTag -and $candidateTag.IsEndTag -and $candidateTag.Name -eq $TagName) {
                return [pscustomobject]@{
                    StartIndex = $candidateIndex
                    Tag = $candidateTag
                }
            }
        }
        $searchIndex = $candidateIndex + 2
    }
    return $null
}

function Get-HtmlScriptElements {
    param([string]$Html)

    $index = 0
    $templateDepth = 0
    $rawTextElements = @('style', 'xmp', 'iframe', 'noembed', 'noframes', 'textarea', 'title', 'noscript')
    while ($index -lt $Html.Length) {
        if ($Html[$index] -ne '<') { $index++; continue }
        if ($index + 3 -lt $Html.Length -and $Html.Substring($index, 4) -eq '<!--') {
            $commentEnd = $Html.IndexOf('-->', $index + 4, [System.StringComparison]::Ordinal)
            $index = if ($commentEnd -lt 0) { $Html.Length } else { $commentEnd + 3 }
            continue
        }

        $tag = Read-HtmlTag -Html $Html -StartIndex $index
        if (-not $tag) { $index++; continue }
        $index = $tag.EndIndex
        if ($tag.IsEndTag) {
            if ($tag.Name -eq 'template' -and $templateDepth -gt 0) { $templateDepth-- }
            continue
        }
        if ($tag.Name -eq 'template') {
            $templateDepth++
            continue
        }
        if ($tag.Name -eq 'plaintext') {
            $index = $Html.Length
            continue
        }
        if ($tag.Name -in $rawTextElements) {
            $rawTextEnd = Find-HtmlEndTag -Html $Html -StartIndex $tag.EndIndex -TagName $tag.Name
            $index = if ($rawTextEnd) { $rawTextEnd.Tag.EndIndex } else { $Html.Length }
            continue
        }
        if ($tag.Name -ne 'script') { continue }

        $bodyStart = $tag.EndIndex
        $scriptEnd = Find-HtmlEndTag -Html $Html -StartIndex $bodyStart -TagName 'script'
        $bodyEnd = if ($scriptEnd) { $scriptEnd.StartIndex } else { $Html.Length }
        if ($templateDepth -eq 0) {
            [pscustomobject]@{
                Attributes = $tag.Attributes
                Body = $Html.Substring($bodyStart, $bodyEnd - $bodyStart)
            }
        }
        $index = if ($scriptEnd) { $scriptEnd.Tag.EndIndex } else { $Html.Length }
    }
}

function Get-ExecutableJavaScript {
    param([string]$Html)

    $result = New-Object System.Text.StringBuilder
    foreach ($script in @(Get-HtmlScriptElements -Html $Html)) {
        $scriptType = if ($script.Attributes.ContainsKey('type')) { $script.Attributes['type'].Trim().ToLowerInvariant() } else { '' }
        if ($scriptType -and $scriptType -notin @('text/javascript', 'application/javascript', 'application/ecmascript', 'text/ecmascript', 'module')) { continue }
        if ($script.Attributes.ContainsKey('src')) { continue }
        if ($scriptType -ne 'module' -and $script.Attributes.ContainsKey('nomodule')) { continue }

        $body = $script.Body
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

if ($Version -notmatch '^[0-9]+\.[0-9]+$') { Fail-Verification "Version must use major.minor format: $Version" }

$gitRepositoryRoot = Split-Path -LiteralPath $PSScriptRoot
$repositoryRoot = $gitRepositoryRoot
$sourcePath = Join-Path $repositoryRoot 'scoring-calculator.html'
$releasePath = Join-Path $repositoryRoot 'docs\index.html'
$snapshotPath = Join-Path $repositoryRoot ("versions\scoring-calculator-v$Version.html")
$htmlPaths = @($sourcePath, $releasePath, $snapshotPath)
foreach ($htmlPath in $htmlPaths) {
    if (-not (Test-Path -LiteralPath $htmlPath -PathType Leaf)) { Fail-Verification "Required HTML file is missing: $htmlPath" }
}

$forbiddenBrandText = @('IJRU', 'Championship Scoring System', '加入跳绳圈', '方泽伟 Richard', 'a17724605074')
$allProjectHtmlPaths = @(Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File -Filter '*.html' | Select-Object -ExpandProperty FullName)
foreach ($htmlPath in $allProjectHtmlPaths) {
    $content = Get-Content -LiteralPath $htmlPath -Raw
    foreach ($forbiddenText in $forbiddenBrandText) {
        if ($content.Contains($forbiddenText)) { Fail-Verification "Forbidden rebrand text found in: $htmlPath" }
    }
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
$requiredBrandPatterns = @(
    '(?is)<title>\s*国际规则花样算分\s*</title>',
    '(?is)<h1\b[^>]*>\s*国际规则花样算分\s*</h1>',
    '(?is)<div\b[^>]*\bclass\s*=\s*["''][^"'']*\bsubtitle\b[^"'']*["''][^>]*>\s*V4\.2\s*</div>'
)
foreach ($htmlPath in $htmlPaths) {
    $content = Get-Content -LiteralPath $htmlPath -Raw
    foreach ($requiredBrandPattern in $requiredBrandPatterns) {
        if ($content -notmatch $requiredBrandPattern) { Fail-Verification "Required rebrand text is missing from: $htmlPath" }
    }
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
