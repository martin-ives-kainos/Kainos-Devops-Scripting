BeforeAll {
    $scriptPath = (Join-Path (Split-Path -Parent $PSCommandPath) "..\public\ini" -Resolve)
    . (Join-Path $scriptPath "Get-IniContent.ps1" -Resolve)
    . (Join-Path $scriptPath "Set-IniValue.ps1" -Resolve)
}

Describe "Set-IniValue" -Tag Unit {
    It "creates a new section and key when the file does not exist" {
        $path = Join-Path $TestDrive "new-settings.ini"

        Set-IniValue -Path $path -Section "database" -Key "host" -Value "localhost"

        Test-Path $path | Should -BeTrue

        $result = Get-IniContent -Path $path
        $result["database"]["host"] | Should -Be "localhost"
    }

    It "updates an existing key in an existing section" {
        $path = Join-Path $TestDrive "existing-settings.ini"
        @'
[database]
host=old-host
port=5432
'@ | Set-Content -Path $path

        Set-IniValue -Path $path -Section "database" -Key "host" -Value "new-host"

        $result = Get-IniContent -Path $path
        $result["database"]["host"] | Should -Be "new-host"
        $result["database"]["port"] | Should -Be "5432"
    }

    It "adds a new section and preserves existing sections" {
        $path = Join-Path $TestDrive "multi-section.ini"
        @'
[database]
host=localhost
'@ | Set-Content -Path $path

        Set-IniValue -Path $path -Section "app" -Key "name" -Value "sample"

        $result = Get-IniContent -Path $path
        $result.ContainsKey("database") | Should -BeTrue
        $result.ContainsKey("app") | Should -BeTrue
        $result["database"]["host"] | Should -Be "localhost"
        $result["app"]["name"] | Should -Be "sample"
    }

    It "throws when any required parameter is null or empty" {
        { Set-IniValue -Path $null -Section "database" -Key "host" -Value "localhost" } | Should -Throw
        { Set-IniValue -Path (Join-Path $TestDrive "x.ini") -Section $null -Key "host" -Value "localhost" } | Should -Throw
        { Set-IniValue -Path (Join-Path $TestDrive "x.ini") -Section "database" -Key $null -Value "localhost" } | Should -Throw
        { Set-IniValue -Path (Join-Path $TestDrive "x.ini") -Section "database" -Key "host" -Value $null } | Should -Throw
    }
}
