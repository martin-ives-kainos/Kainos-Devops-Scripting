BeforeAll {
    # Import the module to load the function being tested
    Import-Module (Join-Path $PSScriptRoot '..\UtilsModule.psd1' -Resolve) -Force -PassThru | Out-Null
    . (Join-Path $PSScriptRoot 'PesterHelperModule.ps1' -Resolve)
}

Describe 'ConvertTo-Ini' {

    It 'Converts a hashtable to INI format' {
        Write-Host ('[ConvertTo-Ini.tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        $data = @{
            Database = @{
                Server = 'SQL01'
                Port   = '1433'
            }
        }

        $ini = ConvertTo-Ini -InputObject $data

        $ini | Should -Match '\[Database\]'
        $ini | Should -Match 'Server=SQL01'
        $ini | Should -Match 'Port=1433'
    }

    It 'Writes global keys without a section header' {
        Write-Host ('[ConvertTo-Ini.tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        $data = @{
            _Global = @{
                RootKey = 'RootValue'
            }
        }

        $ini = ConvertTo-Ini -InputObject $data

        $ini | Should -Match '^RootKey=RootValue'
        $ini | Should -Not -Match '\[_Global\]'
    }

    It 'Round trips successfully' {
        Write-Host ('[ConvertTo-Ini.tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        $original = @{
            Database = @{
                Server = 'SQL01'
                Port   = '1433'
            }
            Application = @{
                Name  = 'MyApp'
                Debug = 'True'
            }
        }

        $ini = ConvertTo-Ini -InputObject $original

        $path = Join-Path $TestDrive 'roundtrip.ini'
        $ini | Set-Content $path

        $reloaded = ConvertFrom-Ini -Path $path

        $reloaded['Database']['Server'] | Should -Be 'SQL01'
        $reloaded['Database']['Port']   | Should -Be '1433'
        $reloaded['Application']['Name'] | Should -Be 'MyApp'
        $reloaded['Application']['Debug'] | Should -Be 'True'
    }
}