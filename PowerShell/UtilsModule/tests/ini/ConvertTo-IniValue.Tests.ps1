BeforeDiscovery {
    $helperPath = $PSScriptRoot
    while (-not (Test-Path (Join-Path $helperPath 'PesterHelperModule.ps1'))) {
        $helperPath = Join-Path $helperPath '..' -Resolve
    }
    . (Join-Path $helperPath 'PesterHelperModule.ps1' -Resolve)
    $global:pester_temp_RunDate = Get-Date
    $global:pester_temp_iniValueTestCases = @(
        @{tc_key = "Name"; tc_expected = "$env:USERNAME" }
        @{tc_key = "Enabled"; tc_expected = "true" }
        @{tc_key = "Count"; tc_expected = "42" }
        @{tc_key = "StartDate"; tc_expected = $global:pester_temp_RunDate.ToString('o') }
        @{tc_key = "Servers"; tc_expected = "web01|web02" }
        @{tc_key = "Settings"; tc_expected = '{"Retry":3,"Timeout":30}' }
    )
}
BeforeAll {
    . (Find-FileInTree -RootPath $PSScriptRoot -FileName ((Split-Path $PSCommandPath -Leaf) -replace '\.Tests\.ps1$', '.ps1'))
    #    $modFile = (Find-FileInTree -RootPath $PSScriptRoot -FileName "PowerShell\UtilsModule\UtilsModule.psd1")
    #    Import-Module -Name $modFile -Force

    function New-IniValueTestData {
        $inputTable = @{
            Name      = $env:USERNAME
            Enabled   = $true
            Count     = 42
            StartDate = $global:pester_temp_RunDate
            Servers   = @('web01', 'web02')
            Settings  = @{ Retry = 3; Timeout = 30 }
        }
        return $inputTable
    }
}

AfterAll {
    # Cleanup code if needed
    foreach ($varName in (Get-Variable -Scope Global | Select-Object -ExpandProperty Name | Where-Object { $_.StartsWith('pester_temp_' ) }) ) {
        Write-Host "[ConvertTo-IniValue.Tests] Removing global variable: $varName"
        Remove-Variable -Name $varName -Scope Global -ErrorAction SilentlyContinue
    }
}

Describe "ConvertTo-IniValue Tests" {

    Context "Test a set of expected INI values" {
        BeforeEach {
            #$TestIniFile = New-TestIniFile (Find-FileInTree -RootPath $PSScriptRoot -FileName 'Test_ParseSection_KeyValuePairs.ini')
            $inputTable = New-IniValueTestData
            Write-Verbose ('[ConvertTo-IniValue.Tests] Input table: {0}' -f ($inputTable | Out-String))
        }

        It "Test section is valid and found" -ForEach $global:pester_temp_iniValueTestCases {
            param ($tc_key, $tc_expected)
            Write-Host ('[ConvertTo-IniValue.Tests] {0}. {1}' -f $____Pester.CurrentTest.Name, $tc_key) -BackgroundColor Green -ForegroundColor Black
            $iniValue = ConvertTo-IniValue -Value $inputTable[$tc_key]
            $iniValue | Should -Be $tc_expected
        }
    }

}
