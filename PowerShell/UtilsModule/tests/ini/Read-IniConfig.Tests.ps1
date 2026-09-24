BeforeAll {
    $helperPath = $PSScriptRoot
    while (-not (Test-Path (Join-Path $helperPath 'PesterHelperModule.ps1'))) {
        $helperPath = Join-Path $helperPath '..' -Resolve
    }
    . (Join-Path $helperPath 'PesterHelperModule.ps1' -Resolve)
    # Import the module to load the function being tested
    #    Import-TestableModuleFile -ModuleName 'UtilsModule.psd1' -ModulePath $PSScriptRoot
    . (Find-FileInTree -RootPath $PSScriptRoot -FileName ((Split-Path $PSCommandPath -Leaf) -replace '\.Tests\.ps1$', '.ps1'))
    $modFile = (Find-FileInTree -RootPath $PSScriptRoot -FileName "PowerShell\UtilsModule\UtilsModule.psd1")
    Import-Module -Name $modFile -Force
}

Describe "Read-IniConfig Tests" {

    Context "When the INI file exists" {
        BeforeEach {
            $TestIniFile = New-TestIniFile (Find-FileInTree -RootPath $PSScriptRoot -FileName 'Test_ParseSection_KeyValuePairs.ini')
            $result = Read-IniConfig -ConfigFile $TestIniFile
            Write-Verbose ('[Read-IniConfig.Tests] Test INI file created at: {0}' -f $TestIniFile)
            Write-Verbose ('[Read-IniConfig.Tests] Read-IniConfig result: {0}' -f ($result | Out-String))
        }

        It "Test section is valid and found" -ForEach @(
            @{tc_section = "Database"; tc_key = "Server"; tc_expected = "SQL01" }
            @{tc_section = "Database"; tc_key = "Port"; tc_expected = "1433" }
            @{tc_section = "Application"; tc_key = "Name"; tc_expected = "MyApp" }
            @{tc_section = "Application"; tc_key = "Debug"; tc_expected = $true }
            @{tc_section = "EnvVars"; tc_key = "UserName"; tc_expected = "$env:USERNAME" }
        ) {
            param ($tc_section, $tc_key, $tc_expected)
            Write-Host ('[Read-IniConfig.Tests] {0}. {1} {2}' -f $____Pester.CurrentTest.Name, $tc_section, $tc_key) -BackgroundColor Green -ForegroundColor Black
            $result.$tc_section.$tc_key | Should -Be $tc_expected
        }
    }

    Context "When the INI file does not exist but DefaultData is provided" {
        BeforeEach {
            $TestIniFile = (Join-Path 'TestDrive:\' 'Test_DefaultData.ini')
            if (Test-Path $TestIniFile -PathType Leaf) {
                Remove-Item -Path $TestIniFile -Force
            }
            $DefaultData = @{
                General = @{
                    Key1 = 'Value1'
                    Key2 = 'Value2'
                }
            }
            Write-Verbose ('[Read-IniConfig.Tests] DefaultData prepared: {0}' -f ($DefaultData | Out-String))
        }

        It "Created INI file successfully contains the DefaultData" {
            Write-Host ('[Read-IniConfig.Tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
            Read-IniConfig -ConfigFile $TestIniFile -DefaultData $DefaultData | Out-Null
            Test-Path $TestIniFile -PathType Leaf | Should -Be $true
            $content = Get-Content -Path $TestIniFile -Raw
            $content | Should -Match "\[General\]"
            $content | Should -Match "Key1=Value1"
            $content | Should -Match "Key2=Value2"
        }
    }

    Context "When the INI file does not exist and no DefaultData is provided" {
        BeforeEach {
            $TestIniFile = (Join-Path 'TestDrive:\' 'Test_DefaultData.ini')
            if (Test-Path $TestIniFile -PathType Leaf) {
                Remove-Item -Path $TestIniFile -Force
            }
        }

        It "Should throw an error" {
            { Read-IniConfig -ConfigFile $TestIniFile } | Should -Throw
        }
    }
}
