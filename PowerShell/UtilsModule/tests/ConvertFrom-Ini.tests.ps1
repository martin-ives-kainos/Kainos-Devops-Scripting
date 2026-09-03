BeforeAll {
    # Import the module to load the function being tested
    Import-Module (Join-Path $PSScriptRoot '..\UtilsModule.psd1' -Resolve) -Force -PassThru | Out-Null
    . (Join-Path $PSScriptRoot 'PesterHelperModule.ps1' -Resolve)
}

Describe 'ConvertFrom-Ini' {

    BeforeAll {
        #        $testFile = New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test_ParseSection_KeyValuePairs.ini' -Resolve)
    }

    It 'Parses sections and key/value pairs' {

        Write-Host ('[ConvertFrom-Ini.tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        $result = ConvertFrom-Ini -Path (New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test_ParseSection_KeyValuePairs.ini' -Resolve))

        $result['Database']['Server'] | Should -Be 'SQL01'
        $result['Database']['Port'] | Should -Be '1433'
        $result['Application']['Name'] | Should -Be 'MyApp'
        $result['Application']['Debug'] | Should -Be 'True'
        $result['EnvVars']['UserName'] | Should -Be $env:USERNAME
    }

    It 'Ignores comments and blank lines' {

        Write-Host ('[ConvertFrom-Ini.tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        $result = ConvertFrom-Ini -Path (New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test_IgnoresCommentsBlankLines.ini' -Resolve))

        $result['Test']['Key'] | Should -Be 'Value'
        $result.Keys.Count | Should -Be 1
    }

    It 'Stores keys before a section in _Global' {

        Write-Host ('[ConvertFrom-Ini.tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        $result = ConvertFrom-Ini -Path (New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test_StoreKeysBeforeSections_global.ini' -Resolve))

        $result['_Global']['RootKey'] | Should -Be 'RootValue'
        $result['Section']['Key'] | Should -Be 'Value'
    }

    It 'Trims whitespace around keys and values' {

        Write-Host ('[ConvertFrom-Ini.tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        $result = ConvertFrom-Ini -Path (New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test_TrimWhiteSpace.ini' -Resolve))

        $result['Test']['Key Name'] | Should -Be 'Some Value'
    }

    It 'Parses values with embedded environment variables' {

        Write-Host ('[ConvertFrom-Ini.tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        $result = ConvertFrom-Ini -Path (New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test_ParseSection_KeyValuePairs.ini' -Resolve))

        $result['EnvVars']['UserName'] | Should -Be $env:USERNAME
    }

    It 'Handles values containing equal signs' {

        Write-Host ('[ConvertFrom-Ini.tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        $result = ConvertFrom-Ini -Path (New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test_HandlesEmbededEqualsInValue.ini' -Resolve))

        $result['Test']['Connection'] |
        Should -Be 'Server=db01;User=test=value'
    }

    It 'Handles values of arrays' {

        Write-Host ('[ConvertFrom-Ini.tests] {0}' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        $result = ConvertFrom-Ini -Path (New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test_ParseSection_KeyValueArray.ini' -Resolve))

        $result['SimpleArray']['TestServers'] | Should -BeOfType [System.Collections.Generic.List[string]]
        $result['SimpleArray']['TestServers'].Count | Should -Be 3
        $result['SimpleArray']['TestServers'][0] | Should -Be 'SQL01
        $result['SimpleArray']['TestServers'][1] | Should -Be 'SQL02'
        $result['SimpleArray']['TestServers'][2] | Should -Be 'SQL03}

    # data\Test_ParseSection_KeyValueArray.ini
    <#
[SimpleArray]
TestServers=SQL01;SQL02;SQL03

[EnvVars]
UserName=%PATH%

    #>
}
