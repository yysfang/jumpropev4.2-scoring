$ErrorActionPreference = 'Stop'

$RepositoryRoot = Split-Path -LiteralPath $PSScriptRoot

function New-IsolatedProject {
    $projectPath = Join-Path -Path $TestDrive -ChildPath ("ijru-project-" + [guid]::NewGuid().ToString('N'))
    $scriptsPath = Join-Path -Path $projectPath -ChildPath 'scripts'
    $docsPath = Join-Path -Path $projectPath -ChildPath 'docs'
    $versionsPath = Join-Path -Path $projectPath -ChildPath 'versions'

    New-Item -ItemType Directory -Path $projectPath, $scriptsPath, $docsPath, $versionsPath -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path -Path $RepositoryRoot -ChildPath 'scoring-calculator.html') -Destination (Join-Path -Path $projectPath -ChildPath 'scoring-calculator.html')
    Copy-Item -LiteralPath (Join-Path -Path $projectPath -ChildPath 'scoring-calculator.html') -Destination (Join-Path -Path $docsPath -ChildPath 'index.html')
    Copy-Item -LiteralPath (Join-Path -Path $projectPath -ChildPath 'scoring-calculator.html') -Destination (Join-Path -Path $versionsPath -ChildPath 'scoring-calculator-v1.1.html')
    Set-Content -LiteralPath (Join-Path -Path $projectPath -ChildPath '.gitignore') -Value ".workbuddy/`n打分记录/`n.worktrees/"

    foreach ($scriptName in @('new-release.ps1', 'verify-project.ps1', 'backup-repo.ps1')) {
        $sourceScript = Join-Path -Path $RepositoryRoot -ChildPath (Join-Path -Path 'scripts' -ChildPath $scriptName)
        if (Test-Path -LiteralPath $sourceScript) {
            Copy-Item -LiteralPath $sourceScript -Destination (Join-Path -Path $scriptsPath -ChildPath $scriptName)
        }
    }

    Push-Location -LiteralPath $projectPath
    try {
        git init | Out-Null
        git config user.email 'maintenance-tests@example.invalid'
        git config user.name 'Maintenance Tests'
        git add --all
        git commit -m 'test fixture' | Out-Null
    }
    finally {
        Pop-Location
    }

    return $projectPath
}

function Invoke-ProjectScript {
    param(
        [string]$ProjectPath,
        [string]$ScriptName,
        [hashtable]$ScriptParameters = @{}
    )

    Push-Location -LiteralPath $ProjectPath
    try {
        $null = & (Join-Path -Path $ProjectPath -ChildPath (Join-Path -Path 'scripts' -ChildPath $ScriptName)) @ScriptParameters
        return $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}

Describe 'IJRU maintenance scripts' {
    It 'verifies a project whose three HTML copies are identical and complete' {
        $projectPath = New-IsolatedProject

        $exitCode = Invoke-ProjectScript -ProjectPath $projectPath -ScriptName 'verify-project.ps1' -ScriptParameters @{ Version = '1.1' }

        $exitCode | Should Be 0
    }

    It 'rejects a project whose published HTML differs from the source' {
        $projectPath = New-IsolatedProject
        Add-Content -LiteralPath (Join-Path -Path $projectPath -ChildPath 'docs\index.html') -Value '<!-- mismatch -->'

        $exitCode = Invoke-ProjectScript -ProjectPath $projectPath -ScriptName 'verify-project.ps1' -ScriptParameters @{ Version = '1.1' }

        $exitCode | Should Not Be 0
    }

    It 'rejects an invalid release version without writing a snapshot' {
        $projectPath = New-IsolatedProject
        $snapshotPath = Join-Path -Path $projectPath -ChildPath 'versions\scoring-calculator-vbad.html'

        $exitCode = Invoke-ProjectScript -ProjectPath $projectPath -ScriptName 'new-release.ps1' -ScriptParameters @{ Version = 'bad' }

        $exitCode | Should Not Be 0
        Test-Path -LiteralPath $snapshotPath | Should Be $false
    }

    It 'rejects an existing release version without overwriting its snapshot' {
        $projectPath = New-IsolatedProject
        $snapshotPath = Join-Path -Path $projectPath -ChildPath 'versions\scoring-calculator-v1.1.html'
        $beforeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $snapshotPath).Hash

        $exitCode = Invoke-ProjectScript -ProjectPath $projectPath -ScriptName 'new-release.ps1' -ScriptParameters @{ Version = '1.1' }

        $exitCode | Should Not Be 0
        (Get-FileHash -Algorithm SHA256 -LiteralPath $snapshotPath).Hash | Should Be $beforeHash
    }

    It 'publishes the source to the release page and a new version snapshot, then verifies it' {
        $projectPath = New-IsolatedProject
        Add-Content -LiteralPath (Join-Path -Path $projectPath -ChildPath 'docs\index.html') -Value '<!-- stale -->'
        $snapshotPath = Join-Path -Path $projectPath -ChildPath 'versions\scoring-calculator-v1.2.html'

        $exitCode = Invoke-ProjectScript -ProjectPath $projectPath -ScriptName 'new-release.ps1' -ScriptParameters @{ Version = '1.2' }

        $exitCode | Should Be 0
        Test-Path -LiteralPath $snapshotPath | Should Be $true
        $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path -Path $projectPath -ChildPath 'scoring-calculator.html')).Hash
        (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path -Path $projectPath -ChildPath 'docs\index.html')).Hash | Should Be $sourceHash
        (Get-FileHash -Algorithm SHA256 -LiteralPath $snapshotPath).Hash | Should Be $sourceHash
        (Invoke-ProjectScript -ProjectPath $projectPath -ScriptName 'verify-project.ps1' -ScriptParameters @{ Version = '1.2' }) | Should Be 0
    }

    It 'creates a verifiable bundle in an explicitly selected absolute directory' {
        $projectPath = New-IsolatedProject
        $destinationPath = Join-Path -Path $TestDrive -ChildPath ("bundles-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null

        $exitCode = Invoke-ProjectScript -ProjectPath $projectPath -ScriptName 'backup-repo.ps1' -ScriptParameters @{ Destination = $destinationPath }
        $bundles = @(Get-ChildItem -LiteralPath $destinationPath -Filter 'ijru-scoring-*.bundle')

        $exitCode | Should Be 0
        $bundles.Count | Should Be 1
        Push-Location -LiteralPath $projectPath
        try {
            git bundle verify $bundles[0].FullName | Out-Null
            $LASTEXITCODE | Should Be 0
        }
        finally {
            Pop-Location
        }
    }

    It 'uses the fixed Documents directory by default without deleting an existing backup' {
        $projectPath = New-IsolatedProject
        $documentsPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
        $sentinelPath = Join-Path -Path $documentsPath -ChildPath 'ijru-scoring-20000101-000000.bundle'
        $beforeBundles = @(Get-ChildItem -LiteralPath $documentsPath -Filter 'ijru-scoring-*.bundle' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
        $createdBundles = @()
        Set-Content -LiteralPath $sentinelPath -Value 'do not delete'

        try {
            $exitCode = Invoke-ProjectScript -ProjectPath $projectPath -ScriptName 'backup-repo.ps1'
            $afterBundles = @(Get-ChildItem -LiteralPath $documentsPath -Filter 'ijru-scoring-*.bundle' | Select-Object -ExpandProperty FullName)
            $createdBundles = @($afterBundles | Where-Object { $beforeBundles -notcontains $_ -and $_ -ne $sentinelPath })

            $exitCode | Should Be 0
            Test-Path -LiteralPath $sentinelPath | Should Be $true
            $createdBundles.Count | Should Be 1
            Split-Path -LiteralPath $createdBundles[0] | Should Be $documentsPath
            Push-Location -LiteralPath $projectPath
            try {
                git bundle verify $createdBundles[0] | Out-Null
                $LASTEXITCODE | Should Be 0
            }
            finally {
                Pop-Location
            }
        }
        finally {
            if (Test-Path -LiteralPath $sentinelPath) {
                Remove-Item -LiteralPath $sentinelPath -Force
            }
            foreach ($bundlePath in @($createdBundles)) {
                if (Test-Path -LiteralPath $bundlePath) {
                    Remove-Item -LiteralPath $bundlePath -Force
                }
            }
        }
    }
}
