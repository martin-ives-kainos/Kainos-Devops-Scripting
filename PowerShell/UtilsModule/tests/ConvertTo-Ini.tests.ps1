BeforeAll {
    # Import the module to load the function being tested
    Import-Module (Join-Path $PSScriptRoot '..\UtilsModule.psd1' -Resolve) -Force -PassThru | Out-Null
    . (Join-Path $PSScriptRoot 'PesterHelperModule.ps1' -Resolve)
}

Describe 'ConvertTo-Ini' {
    It 'Throws an error when the path is empty' {
        Write-Host ('[ConvertTo-Ini.tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        $data = @{
            Database = @{
                Server = 'SQL01'
                Port   = '1433'
            }
        }

        { ConvertTo-Ini -InputObject $data -Path '' } | Should -Throw "Cannot validate argument on parameter 'Path'. Path cannot be empty."
    }
    It 'Throws an error when the path is invalid' {
        Write-Host ('[ConvertTo-Ini.tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        $data = @{
            Database = @{
                Server = 'SQL01'
                Port   = '1433'
            }
        }

        { ConvertTo-Ini -InputObject $data -Path '::invalid_path::' } | Should -Throw "Cannot bind argument to parameter 'Path' because it is an empty string."
    }

    It 'Converts a hashtable to INI format' {
        Write-Host ('[ConvertTo-Ini.tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        $data = @{
            Database = @{
                Server = 'SQL01'
                Port   = '1433'
            }
        }

        ConvertTo-Ini -InputObject $data -Path (Join-Path $TestDrive 'test.ini')

        $ini = Get-Content (Join-Path $TestDrive 'test.ini') -Raw

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

        ConvertTo-Ini -InputObject $data -Path (Join-Path $TestDrive 'test.ini')
        $ini = Get-Content (Join-Path $TestDrive 'test.ini') -Raw

        $ini | Should -Match '^RootKey=RootValue'
        $ini | Should -Not -Match '\[_Global\]'
    }
}