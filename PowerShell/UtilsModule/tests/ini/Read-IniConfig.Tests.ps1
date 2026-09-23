BeforeAll {
    $helperPath = $PSScriptRoot
    while (-not (Test-Path (Join-Path $helperPath 'PesterHelperModule.ps1'))) {
        $helperPath = Join-Path $helperPath '..' -Resolve
    }
    . (Join-Path $helperPath 'PesterHelperModule.ps1' -Resolve)
    # Import the module to load the function being tested
    #    Import-TestableModuleFile -ModuleName 'UtilsModule.psd1' -ModulePath $PSScriptRoot
    . (Find-FileInTree -RootPath $PSScriptRoot -FileName ((Split-Path $PSCommandPath -Leaf) -replace '\.Tests\.ps1$', '.ps1'))

    <#     function New-IniTestResults {
        [CmdletBinding()]
        [OutputType([hashtable])]
        param (
            [Parameter(Mandatory = $true)]
            [ValidateSet("File Parsing", "Content Parsing")]
            [string]$TestType,
            [Parameter(Mandatory = $true)]
            [string]$FileName
        )
        switch ($TestType) {
            "File Parsing" {
                $result = ConvertFrom-Ini -Path (New-TestIniFile -Path (Join-Path $PSScriptRoot ('data\{0}' -f $FileName) -Resolve))
            }
            "Content Parsing" {
                $iniContent = New-TestIniFile -Path (Join-Path $PSScriptRoot  ('data\{0}' -f $FileName) -Resolve) -ContentOnly
                $result = ConvertFrom-Ini -Content $iniContent
            }
        }
        return $result
    }
 #>}


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
        ) {
            param ($tc_section, $tc_key, $tc_expected)
            Write-Host ('[Read-IniConfig.Tests] {0}. {1} {2}' -f $____Pester.CurrentTest.Name, $tc_section, $tc_key) -BackgroundColor Green -ForegroundColor Black
            $result.$tc_section.$tc_key | Should -Be $tc_expected
        }
    }

    Context "When the INI file does not exist but DefaultData is provided" -Skip {
        BeforeEach {
            if (Test-Path $TestIniFile) {
                Remove-Item -Path $TestIniFile -Force
            }
        }


        It "Should create the INI file with DefaultData" {
            Read-IniConfig -ConfigFile $TestIniFile -DefaultData $DefaultData | Out-Null
            Test-Path $TestIniFile | Should -Be $true
            $content = Get-Content -Path $TestIniFile -Raw
            $content | Should -Match "\[General\]"
            $content | Should -Match "Key1=Value1"
            $content | Should -Match "Key2=Value2"
        }
    }


    Context "When the INI file does not exist and no DefaultData is provided" -Skip {
        BeforeEach {
            if (Test-Path $TestIniFile) {
                Remove-Item -Path $TestIniFile -Force
            }
        }


        It "Should throw an error" {
            { Read-IniConfig -ConfigFile $TestIniFile } | Should -Throw
        }
    }
}
