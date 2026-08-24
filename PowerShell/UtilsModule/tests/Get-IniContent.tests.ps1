BeforeAll {
    $scriptPath = (Join-Path (Split-Path -Parent $PSCommandPath) "..\public\ini" -Resolve)
    . (Join-Path $scriptPath "Get-IniContent.ps1" -Resolve)
}

Describe "Get-IniContent" -Tag Unit {
    It "reads sections and key-value pairs from an INI file" {
        $iniContent = @'
[database]
host=localhost
port=5432

[app]
name=sample
mode=prod
'@

        $path = Join-Path $TestDrive "settings.ini"
        Set-Content -Path $path -Value $iniContent

        $result = Get-IniContent -Path $path

        $result.Keys.Count | Should -Be 2
        $result["database"]["host"] | Should -Be "localhost"
        $result["database"]["port"] | Should -Be "5432"
        $result["app"]["name"] | Should -Be "sample"
        $result["app"]["mode"] | Should -Be "prod"
    }

    It "ignores blank lines and does not create empty sections" {
        $iniContent = @'

[database]
host=localhost


[app]
name=sample
'@

        $path = Join-Path $TestDrive "settings-with-blanks.ini"
        Set-Content -Path $path -Value $iniContent

        $result = Get-IniContent -Path $path

        $result.ContainsKey("database") | Should -BeTrue
        $result.ContainsKey("app") | Should -BeTrue
        $result.ContainsKey("") | Should -BeFalse
    }

    It "throws when the INI file path is not supplied" {
        { Get-IniContent -Path $null } | Should -Throw
    }
}
