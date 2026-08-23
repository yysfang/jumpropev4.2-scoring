$ErrorActionPreference = 'Stop'
$RepositoryRoot = Split-Path -LiteralPath $PSScriptRoot

function New-IsolatedProject {
    param([switch]$WithCommit)
    $projectPath = Join-Path -Path $TestDrive -ChildPath ("ijru-" + [guid]::NewGuid().ToString('N'))
    if (-not $script:ProjectTemplatePath) {
        $script:ProjectTemplatePath = Join-Path -Path $TestDrive -ChildPath 'ijru-template'
        New-Item -ItemType Directory -Path $script:ProjectTemplatePath, (Join-Path $script:ProjectTemplatePath 'scripts'), (Join-Path $script:ProjectTemplatePath 'docs'), (Join-Path $script:ProjectTemplatePath 'versions') -Force | Out-Null
        $sourcePath = Join-Path $script:ProjectTemplatePath 'scoring-calculator.html'
        Copy-Item -LiteralPath (Join-Path $RepositoryRoot 'scoring-calculator.html') -Destination $sourcePath
        Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $script:ProjectTemplatePath 'docs\index.html')
        Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $script:ProjectTemplatePath 'versions\scoring-calculator-v1.1.html')
        Set-Content -LiteralPath (Join-Path $script:ProjectTemplatePath '.gitignore') -Value ".workbuddy/`n打分记录/`n.worktrees/"
        foreach ($name in 'new-release.ps1', 'verify-project.ps1', 'backup-repo.ps1') {
            Copy-Item -LiteralPath (Join-Path $RepositoryRoot (Join-Path 'scripts' $name)) -Destination (Join-Path $script:ProjectTemplatePath (Join-Path 'scripts' $name))
        }
        Push-Location -LiteralPath $script:ProjectTemplatePath
        try {
            git init | Out-Null
            git config core.autocrlf false
            git config user.email 'maintenance-tests@example.invalid'
            git config user.name 'Maintenance Tests'
            git add --all
            git commit -m fixture | Out-Null
        } finally { Pop-Location }
    }
    Copy-Item -LiteralPath $script:ProjectTemplatePath -Destination $projectPath -Recurse
    $projectPath
}

function Invoke-ProjectScript {
    param([string]$ProjectPath, [string]$ScriptName, [hashtable]$ScriptParameters = @{})
    Push-Location -LiteralPath $ProjectPath
    try {
        $output = @(& (Join-Path $ProjectPath (Join-Path 'scripts' $ScriptName)) @ScriptParameters)
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
    } finally { Pop-Location }
}

function Sync-ProjectHtml {
    param([string]$ProjectPath, [string]$Version = '1.1')
    $sourcePath = Join-Path $ProjectPath 'scoring-calculator.html'
    Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $ProjectPath 'docs\index.html') -Force
    Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $ProjectPath ("versions\scoring-calculator-v$Version.html")) -Force
}

function Add-PrivacyHistory {
    param([string]$ProjectPath, [string]$RelativePath = '.workbuddy\history-secret.txt')
    $secretPath = Join-Path $ProjectPath $RelativePath
    New-Item -ItemType Directory -Path (Split-Path -LiteralPath $secretPath) -Force | Out-Null
    Set-Content -LiteralPath $secretPath -Value secret
    Push-Location -LiteralPath $ProjectPath
    try {
        git checkout -b privacy-history | Out-Null
        git add -f -- $RelativePath
        git commit -m 'private history' | Out-Null
        git checkout - | Out-Null
    } finally { Pop-Location }
}

Describe 'IJRU maintenance scripts' {
    It 'verifies matching complete HTML copies' {
        $projectPath = New-IsolatedProject
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Be 0
    }

    It 'rejects mismatched published HTML' {
        $projectPath = New-IsolatedProject
        Add-Content -LiteralPath (Join-Path $projectPath 'docs\index.html') -Value '<!-- mismatch -->'
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
    }

    It 'rejects a comment that merely looks like an ignore rule' {
        $projectPath = New-IsolatedProject
        Set-Content -LiteralPath (Join-Path $projectPath '.gitignore') -Value "# .workbuddy/`n打分记录/`n.worktrees/"
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
    }

    It 'rejects a privacy path tracked exactly at the root name' {
        $projectPath = New-IsolatedProject
        Set-Content -LiteralPath (Join-Path $projectPath '.workbuddy') -Value private
        Push-Location -LiteralPath $projectPath
        try { git add -- '.workbuddy'; git commit -m 'private root' | Out-Null } finally { Pop-Location }
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
    }

    It 'rejects a missing explicit input binding even with matching hashes' {
        $projectPath = New-IsolatedProject
        $sourcePath = Join-Path $projectPath 'scoring-calculator.html'
        Set-Content -LiteralPath $sourcePath -Value ((Get-Content -LiteralPath $sourcePath -Raw) -replace "addEventListener\('input'", "addEventListener('keyup'")
        Sync-ProjectHtml $projectPath
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
    }

    It 'rejects an input binding that exists only in a JavaScript comment' {
        $projectPath = New-IsolatedProject
        $sourcePath = Join-Path $projectPath 'scoring-calculator.html'
        $content = (Get-Content -LiteralPath $sourcePath -Raw) -replace "addEventListener\('input'", "addEventListener('keyup'"
        Set-Content -LiteralPath $sourcePath -Value ($content + "`n<script>// addEventListener('input')</script>")
        Sync-ProjectHtml $projectPath
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
    }

    It 'rejects a calculate function that exists only in a JavaScript string' {
        $projectPath = New-IsolatedProject
        $sourcePath = Join-Path $projectPath 'scoring-calculator.html'
        $content = (Get-Content -LiteralPath $sourcePath -Raw) -replace 'function calculate\(', 'function removedCalculate('
        Set-Content -LiteralPath $sourcePath -Value ($content + "`n<script>const fake = ```nfunction calculate(`n```;</script>")
        Sync-ProjectHtml $projectPath
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
    }

    It 'rejects required code that exists only in a text template script' {
        $projectPath = New-IsolatedProject
        $sourcePath = Join-Path $projectPath 'scoring-calculator.html'
        $content = (Get-Content -LiteralPath $sourcePath -Raw) -replace 'function calculate\(', 'function removedCalculate(' -replace "addEventListener\('input'", "addEventListener('keyup'"
        $fakeTemplate = @'
<script type="text/template">
function calculate() {}
node.addEventListener('input', noop);
</script>
'@
        Set-Content -LiteralPath $sourcePath -Value ($content + "`n" + $fakeTemplate)
        Sync-ProjectHtml $projectPath
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
    }

    It 'rejects required code that exists only in an application JSON script' {
        $projectPath = New-IsolatedProject
        $sourcePath = Join-Path $projectPath 'scoring-calculator.html'
        $content = (Get-Content -LiteralPath $sourcePath -Raw) -replace 'function calculate\(', 'function removedCalculate(' -replace "addEventListener\('input'", "addEventListener('keyup'"
        $fakeJson = @'
<script type="application/json">
function calculate() {}
node.addEventListener('input', noop);
</script>
'@
        Set-Content -LiteralPath $sourcePath -Value ($content + "`n" + $fakeJson)
        Sync-ProjectHtml $projectPath
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
    }

    It 'rejects required code that exists only inside an HTML comment in a script' {
        $projectPath = New-IsolatedProject
        $sourcePath = Join-Path $projectPath 'scoring-calculator.html'
        $content = (Get-Content -LiteralPath $sourcePath -Raw) -replace 'function calculate\(', 'function removedCalculate(' -replace "addEventListener\('input'", "addEventListener('keyup'"
        Set-Content -LiteralPath $sourcePath -Value ($content + "`n<script><!--`nfunction calculate() {}`nnode.addEventListener('input', noop);`n--></script>")
        Sync-ProjectHtml $projectPath
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
    }

    It 'accepts real required code after a line comment with unmatched quotes' {
        $projectPath = New-IsolatedProject
        $sourcePath = Join-Path $projectPath 'scoring-calculator.html'
        $commentAndFunction = @'
// calculator's "entry
function calculate(
'@
        $content = (Get-Content -LiteralPath $sourcePath -Raw) -replace 'function calculate\(', $commentAndFunction
        Set-Content -LiteralPath $sourcePath -Value $content
        Sync-ProjectHtml $projectPath
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Be 0
    }

    It 'accepts a seven-equals explanatory line that is not a conflict marker' {
        $projectPath = New-IsolatedProject
        $sourcePath = Join-Path $projectPath 'scoring-calculator.html'
        Add-Content -LiteralPath $sourcePath -Value '======= explanatory separator'
        Sync-ProjectHtml $projectPath
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Be 0
    }

    It 'rejects a full Git conflict marker sequence' {
        $projectPath = New-IsolatedProject
        $sourcePath = Join-Path $projectPath 'scoring-calculator.html'
        Add-Content -LiteralPath $sourcePath -Value "`n<<<<<<< HEAD`nleft`n=======`nright`n>>>>>>> branch"
        Sync-ProjectHtml $projectPath
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
    }

    It 'rejects a lone Git conflict start marker' {
        $projectPath = New-IsolatedProject
        $sourcePath = Join-Path $projectPath 'scoring-calculator.html'
        Add-Content -LiteralPath $sourcePath -Value "`n<<<<<<< HEAD"
        Sync-ProjectHtml $projectPath
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
    }

    It 'rejects a lone Git conflict separator marker' {
        $projectPath = New-IsolatedProject
        $sourcePath = Join-Path $projectPath 'scoring-calculator.html'
        Add-Content -LiteralPath $sourcePath -Value "`n======="
        Sync-ProjectHtml $projectPath
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
    }

    It 'rejects a lone Git conflict end marker' {
        $projectPath = New-IsolatedProject
        $sourcePath = Join-Path $projectPath 'scoring-calculator.html'
        Add-Content -LiteralPath $sourcePath -Value "`n>>>>>>> branch"
        Sync-ProjectHtml $projectPath
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
    }

    It 'does not allow IJRU_VERIFY_CONTENT_ROOT to bypass a real release-page mismatch' {
        $projectPath = New-IsolatedProject
        $alternateRoot = Join-Path $TestDrive ("alternate-content-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $alternateRoot, (Join-Path $alternateRoot 'docs'), (Join-Path $alternateRoot 'versions') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $projectPath 'scoring-calculator.html') -Destination (Join-Path $alternateRoot 'scoring-calculator.html')
        Copy-Item -LiteralPath (Join-Path $alternateRoot 'scoring-calculator.html') -Destination (Join-Path $alternateRoot 'docs\index.html')
        Copy-Item -LiteralPath (Join-Path $alternateRoot 'scoring-calculator.html') -Destination (Join-Path $alternateRoot 'versions\scoring-calculator-v1.1.html')
        Add-Content -LiteralPath (Join-Path $projectPath 'docs\index.html') -Value mismatch
        $previousContentRoot = $env:IJRU_VERIFY_CONTENT_ROOT
        try {
            $env:IJRU_VERIFY_CONTENT_ROOT = $alternateRoot
            (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.1' }).ExitCode | Should Not Be 0
        } finally { $env:IJRU_VERIFY_CONTENT_ROOT = $previousContentRoot }
    }

    It 'rejects an invalid version without changing the release page or writing a snapshot' {
        $projectPath = New-IsolatedProject
        $releasePath = Join-Path $projectPath 'docs\index.html'
        $beforeHash = (Get-FileHash -LiteralPath $releasePath -Algorithm SHA256).Hash
        $result = Invoke-ProjectScript $projectPath 'new-release.ps1' @{ Version = 'bad' }
        $result.ExitCode | Should Not Be 0
        (Get-FileHash -LiteralPath $releasePath -Algorithm SHA256).Hash | Should Be $beforeHash
        Test-Path -LiteralPath (Join-Path $projectPath 'versions\scoring-calculator-vbad.html') | Should Be $false
    }

    It 'rejects a duplicate version without changing the release page or snapshot' {
        $projectPath = New-IsolatedProject
        $releasePath = Join-Path $projectPath 'docs\index.html'
        $snapshotPath = Join-Path $projectPath 'versions\scoring-calculator-v1.1.html'
        $releaseHash = (Get-FileHash -LiteralPath $releasePath -Algorithm SHA256).Hash
        $snapshotHash = (Get-FileHash -LiteralPath $snapshotPath -Algorithm SHA256).Hash
        $result = Invoke-ProjectScript $projectPath 'new-release.ps1' @{ Version = '1.1' }
        $result.ExitCode | Should Not Be 0
        (Get-FileHash -LiteralPath $releasePath -Algorithm SHA256).Hash | Should Be $releaseHash
        (Get-FileHash -LiteralPath $snapshotPath -Algorithm SHA256).Hash | Should Be $snapshotHash
    }

    It 'leaves no partial release when source validation fails' {
        $projectPath = New-IsolatedProject
        $sourcePath = Join-Path $projectPath 'scoring-calculator.html'
        $releasePath = Join-Path $projectPath 'docs\index.html'
        $beforeHash = (Get-FileHash -LiteralPath $releasePath -Algorithm SHA256).Hash
        Set-Content -LiteralPath $sourcePath -Value ((Get-Content -LiteralPath $sourcePath -Raw) -replace 'function calculate\(', 'function removedCalculate(')
        $result = Invoke-ProjectScript $projectPath 'new-release.ps1' @{ Version = '1.2' }
        $result.ExitCode | Should Not Be 0
        (Get-FileHash -LiteralPath $releasePath -Algorithm SHA256).Hash | Should Be $beforeHash
        Test-Path -LiteralPath (Join-Path $projectPath 'versions\scoring-calculator-v1.2.html') | Should Be $false
    }

    It 'publishes and verifies a new release' {
        $projectPath = New-IsolatedProject
        Add-Content -LiteralPath (Join-Path $projectPath 'docs\index.html') -Value stale
        $result = Invoke-ProjectScript $projectPath 'new-release.ps1' @{ Version = '1.2' }
        $snapshotPath = Join-Path $projectPath 'versions\scoring-calculator-v1.2.html'
        $result.ExitCode | Should Be 0
        (Get-FileHash -LiteralPath (Join-Path $projectPath 'docs\index.html') -Algorithm SHA256).Hash | Should Be (Get-FileHash -LiteralPath (Join-Path $projectPath 'scoring-calculator.html') -Algorithm SHA256).Hash
        Test-Path -LiteralPath $snapshotPath | Should Be $true
        (Invoke-ProjectScript $projectPath 'verify-project.ps1' @{ Version = '1.2' }).ExitCode | Should Be 0
    }

    It 'rejects a relative backup destination' {
        $projectPath = New-IsolatedProject
        $result = Invoke-ProjectScript $projectPath 'backup-repo.ps1' @{ Destination = 'relative-backups' }
        $result.ExitCode | Should Not Be 0
        Test-Path -LiteralPath (Join-Path $projectPath 'relative-backups') | Should Be $false
    }

    It 'creates a verifiable bundle in a custom absolute directory' {
        $projectPath = New-IsolatedProject -WithCommit
        $destinationPath = Join-Path $TestDrive ("bundles-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
        $result = Invoke-ProjectScript $projectPath 'backup-repo.ps1' @{ Destination = $destinationPath }
        $bundles = @(Get-ChildItem -LiteralPath $destinationPath -Filter 'ijru-scoring-*.bundle')
        $result.ExitCode | Should Be 0
        $bundles.Count | Should Be 1
        Push-Location -LiteralPath $projectPath
        try { git bundle verify $bundles[0].FullName | Out-Null; $LASTEXITCODE | Should Be 0 } finally { Pop-Location }
    }

    It 'refuses timestamp collisions without overwriting existing bundles' {
        $projectPath = New-IsolatedProject -WithCommit
        $destinationPath = Join-Path $TestDrive ("collision-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
        $paths = @(0..12 | ForEach-Object { Join-Path $destinationPath ('ijru-scoring-' + (Get-Date).AddSeconds($_).ToString('yyyyMMdd-HHmmss') + '.bundle') })
        foreach ($path in $paths) { Set-Content -LiteralPath $path -Value 'do not overwrite' }
        $result = Invoke-ProjectScript $projectPath 'backup-repo.ps1' @{ Destination = $destinationPath }
        $result.ExitCode | Should Not Be 0
        foreach ($path in $paths) { (Get-Content -LiteralPath $path -Raw).TrimEnd() | Should Be 'do not overwrite' }
    }

    It 'leaves no final or temporary bundle when bundle verification fails' {
        $projectPath = New-IsolatedProject -WithCommit
        $destinationPath = Join-Path $TestDrive ("verify-failure-" + [guid]::NewGuid().ToString('N'))
        $shimPath = Join-Path $TestDrive ("git-shim-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $destinationPath, $shimPath -Force | Out-Null
        $shimContents = @'
@echo off
if /I "%1 %2"=="bundle verify" exit /b 1
"C:\Program Files\Git\cmd\git.exe" %*
'@
        Set-Content -LiteralPath (Join-Path $shimPath 'git.cmd') -Value $shimContents
        $originalPath = $env:PATH
        try { $env:PATH = "$shimPath;$originalPath"; $result = Invoke-ProjectScript $projectPath 'backup-repo.ps1' @{ Destination = $destinationPath } } finally { $env:PATH = $originalPath }
        $result.ExitCode | Should Not Be 0
        @(Get-ChildItem -LiteralPath $destinationPath -File).Count | Should Be 0
    }

    It 'refuses privacy paths present in another Git ref history' {
        $projectPath = New-IsolatedProject -WithCommit
        $destinationPath = Join-Path $TestDrive ("privacy-history-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
        Add-PrivacyHistory $projectPath
        $result = Invoke-ProjectScript $projectPath 'backup-repo.ps1' @{ Destination = $destinationPath }
        $result.ExitCode | Should Not Be 0
        @(Get-ChildItem -LiteralPath $destinationPath -File).Count | Should Be 0
    }

    It 'refuses Chinese privacy paths present in another Git ref history' {
        $projectPath = New-IsolatedProject -WithCommit
        $destinationPath = Join-Path $TestDrive ("chinese-privacy-history-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
        Add-PrivacyHistory $projectPath '打分记录\history-secret.txt'
        $result = Invoke-ProjectScript $projectPath 'backup-repo.ps1' @{ Destination = $destinationPath }
        $result.ExitCode | Should Not Be 0
        @(Get-ChildItem -LiteralPath $destinationPath -File).Count | Should Be 0
    }

    It 'uses an isolated Documents IJRU-scoring-backups default and preserves its GUID sentinel' {
        $projectPath = New-IsolatedProject -WithCommit
        $testProfile = Join-Path $TestDrive ("profile-" + [guid]::NewGuid().ToString('N'))
        $defaultDirectory = Join-Path $testProfile 'Documents\IJRU-scoring-backups'
        $sentinelPath = Join-Path $defaultDirectory ("ijru-scoring-sentinel-" + [guid]::NewGuid().ToString('N') + '.bundle')
        $createdPath = $null
        $previousProfile = $env:USERPROFILE
        try {
            $env:USERPROFILE = $testProfile
            New-Item -ItemType Directory -Path $defaultDirectory -Force | Out-Null
            Test-Path -LiteralPath $sentinelPath | Should Be $false
            Set-Content -LiteralPath $sentinelPath -Value sentinel
            $result = Invoke-ProjectScript $projectPath 'backup-repo.ps1'
            $bundleOutput = @($result.Output | Where-Object { $_ -like 'BundlePath=*' })
            $createdPath = $bundleOutput[0].Substring('BundlePath='.Length)
            $result.ExitCode | Should Be 0
            Split-Path -LiteralPath $createdPath | Should Be $defaultDirectory
            Test-Path -LiteralPath $createdPath | Should Be $true
            Test-Path -LiteralPath $sentinelPath | Should Be $true
        } finally {
            $env:USERPROFILE = $previousProfile
            if ($createdPath -and (Test-Path -LiteralPath $createdPath)) { Remove-Item -LiteralPath $createdPath -Force }
            if (Test-Path -LiteralPath $sentinelPath) { Remove-Item -LiteralPath $sentinelPath -Force }
        }
    }
}
