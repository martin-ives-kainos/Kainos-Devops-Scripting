BeforeDiscovery {
    $helperPath = $PSScriptRoot
    while (-not (Test-Path (Join-Path $helperPath 'PesterHelperModule.ps1'))) {
        $helperPath = Join-Path $helperPath '..' -Resolve
    }
    . (Join-Path $helperPath 'PesterHelperModule.ps1' -Resolve)
    $global:pester_temp_RunDate = Get-Date

    SetUpGlobalTestCases -VarName 'pester_temp_iniValueTestCases' -TestCaseArray @(
            @{tc_section = "Database"; tc_key = "Server"; tc_expected = "SQL02" }
            @{tc_section = "Database"; tc_key = "Port"; tc_expected = "9999" }
            @{tc_section = "Application"; tc_key = "Name"; tc_expected = "MyApp2" }
            @{tc_section = "Application"; tc_key = "Debug"; tc_expected = $false }
            #            @{tc_section = "EnvVars"; tc_key = "UserName"; tc_expected = "$env:USERNAME" }
    )
}
BeforeAll {
    . (Find-FileInTree -RootPath $PSScriptRoot -FileName ((Split-Path $PSCommandPath -Leaf) -replace '\.Tests\.ps1$', '.ps1'))
    $modFile = (Find-FileInTree -RootPath $PSScriptRoot -FileName "UtilsModule\UtilsModule.psd1")
    Import-Module -Name $modFile -Force
}
AfterAll {
    # Cleanup code if needed
    CleanUpTemporaryGlobalVariables -VarPrefix 'pester_temp_'
}
Describe "Save-IniConfig Tests" {

    Context "When the INI file exists" {
        BeforeEach {
            # Create an old INI file for testing changes
            $TestIniFile = New-TestIniFile (Find-FileInTree -RootPath $PSScriptRoot -FileName 'Test_ParseSection_KeyValuePairs.ini')
            $result = Read-IniConfig -ConfigFile $TestIniFile
            Write-Verbose ('[Save-IniConfig.Tests] Origional Test INI file created at: {0}' -f $TestIniFile)
            Write-Verbose ('[Save-IniConfig.Tests] Origional Read-IniConfig result: {0}' -f ($result | Out-String))

            $result.Database.Server = "SQL02"
            $result.Database.Port = "9999"
            $result.Application.Name = "MyApp2"
            $result.Application.Debug = $false

            Save-IniConfig -ConfigFile $TestIniFile -Data $result | Out-Null
            $newResult = Read-IniConfig -ConfigFile $TestIniFile
            Write-Verbose ('[Save-IniConfig.Tests] New Read-IniConfig result: {0}' -f ($newResult | Out-String))
        }

        It "Test section is valid and found" -ForEach $global:pester_temp_iniValueTestCases {
            param ($tc_section, $tc_key, $tc_expected)
            Write-Host ('[Save-IniConfig.Tests] {0}. {1} {2}' -f $____Pester.CurrentTest.Name, $tc_section, $tc_key) -BackgroundColor Green -ForegroundColor Black
            $newResult.$tc_section.$tc_key | Should -Be $tc_expected
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
            Write-Verbose ('[Save-IniConfig.Tests] DefaultData prepared: {0}' -f ($DefaultData | Out-String))
        }

        It "Created INI file successfully contains the DefaultData" {
            Write-Host ('[Save-IniConfig.Tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
            Save-IniConfig -ConfigFile $TestIniFile -DefaultData $DefaultData | Out-Null
            Test-Path $TestIniFile -PathType Leaf | Should -Be $true
            $content = Get-Content -Path $TestIniFile -Raw
            $content | Should -Match "\[General\]"
            $content | Should -Match "Key1=Value1"
            $content | Should -Match "Key2=Value2"
        }
    }

    Context "Test saving specific data types" -Skip {
        It "Throw an error saving an object as a value" {
            $TestIniFile = (Join-Path 'TestDrive:\' 'Test_ObjectValue.ini')
            if (Test-Path $TestIniFile -PathType Leaf) {
                Remove-Item -Path $TestIniFile -Force
            }
            $InvalidData = @{
                General = @{
                    Key1 = @{ SubKey = 'SubValue' }
                }
            }
            { Save-IniConfig -ConfigFile $TestIniFile -Data $InvalidData | Out-Null } | Should -Throw
        }
    }
}
