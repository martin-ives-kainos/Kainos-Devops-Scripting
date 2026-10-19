BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\public\system\Read-PsdManifest.ps1' -Resolve)
}

Describe -Tag 'Unit' 'Read-PsdManifest' {
    It 'reads manifest data including nested hashtables' {
        $manifestPath = Join-Path $TestDrive 'Example.psd1'
        @'
@{
    Name = 'Example'
    Version = '1.2.3'
    Settings = @{
        Enabled = $true
    }
}
'@ | Set-Content -LiteralPath $manifestPath

        $result = Read-PsdManifest -Path $manifestPath

        $result | Should -BeOfType [System.Collections.Hashtable]
        $result.Name | Should -BeExactly 'Example'
        $result.Version | Should -BeExactly '1.2.3'
        $result.Settings.Enabled | Should -BeTrue
    }

    It 'rejects a path that does not exist' {
        $missingPath = Join-Path $TestDrive 'Missing.psd1'

        { Read-PsdManifest -Path $missingPath } | Should -Throw
    }

    It 'rejects a directory path' {
        $directoryPath = Join-Path $TestDrive 'ManifestDirectory'
        New-Item -Path $directoryPath -ItemType Directory | Out-Null

        { Read-PsdManifest -Path $directoryPath } | Should -Throw
    }

    It 'throws when the manifest contents are invalid' {
        $manifestPath = Join-Path $TestDrive 'Invalid.psd1'
        'This is not valid PowerShell data' | Set-Content -LiteralPath $manifestPath

        { Read-PsdManifest -Path $manifestPath -ErrorAction Stop } | Should -Throw
    }
}