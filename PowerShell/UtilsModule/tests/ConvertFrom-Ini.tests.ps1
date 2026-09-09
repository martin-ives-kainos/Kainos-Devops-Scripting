BeforeAll {
    # Import the module to load the function being tested
    Import-Module (Join-Path $PSScriptRoot '..\UtilsModule.psd1' -Resolve) -Force -PassThru | Out-Null
    . (Join-Path $PSScriptRoot 'PesterHelperModule.ps1' -Resolve)

    function New-IniTestResults {
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
}

Describe 'ConvertFrom-Ini' {

    Context 'File and Content Parsing - <P_FileName>' -ForEach @(
        @{ P_Name = "File Parsing"; P_FileName = "Test_ParseSection_KeyValuePairs.ini" }
        @{ P_Name = "Content Parsing"; P_FileName = "Test_ParseSection_KeyValuePairs.ini" }
    ) {
        BeforeEach {
            $result = New-IniTestResults -TestType $P_Name -FileName $P_FileName
            Write-Verbose $result
        }
        It ('Parses sections and key/value pairs {0} from: {1}' -f $P_Name, $P_FileName) {
            Write-Host ('[ConvertFrom-Ini.tests] {0} Sections: {1}' -f $____Pester.CurrentTest.Name, ($result.Keys -join ', ')) -BackgroundColor Green -ForegroundColor Black

            $result['Database']['Server'] | Should -Be 'SQL01'
            $result['Database']['Port'] | Should -Be '1433'
            $result['Application']['Name'] | Should -Be 'MyApp'
            $result['Application']['Debug'] | Should -Be 'True'
            $result['EnvVars']['UserName'] | Should -Be $env:USERNAME
        }
    }

    Context 'File and Content Parsing - <P_FileName>' -ForEach @(
        @{ P_Name = "File Parsing"; P_FileName = "Test_IgnoresCommentsBlankLines.ini" }
        @{ P_Name = "Content Parsing"; P_FileName = "Test_IgnoresCommentsBlankLines.ini" }
    ) {
        BeforeEach {
            $result = New-IniTestResults -TestType $P_Name -FileName $P_FileName
            Write-Verbose $result
        }
        It ('Ignores comments and blank lines {0} from: {1}' -f $P_Name, $P_FileName) {
            Write-Host ('[ConvertFrom-Ini.tests] {0} Sections: {1}' -f $____Pester.CurrentTest.Name, ($result.Keys -join ', ')) -BackgroundColor Green -ForegroundColor Black
            $result['Test']['Key'] | Should -Be 'Value'
            $result.Keys.Count | Should -Be 1
        }
    }

    Context 'File and Content Parsing - <P_FileName>' -ForEach @(
        @{ P_Name = "File Parsing"; P_FileName = "Test_StoreKeysBeforeSections_global.ini" }
        @{ P_Name = "Content Parsing"; P_FileName = "Test_StoreKeysBeforeSections_global.ini" }
    ) {
        BeforeEach {
            $result = New-IniTestResults -TestType $P_Name -FileName $P_FileName
            Write-Verbose $result
        }
        It ('Stores keys before a section in _Global {0} from: {1}' -f $P_Name, $P_FileName) {
            Write-Host ('[ConvertFrom-Ini.tests] {0} Sections: {1}' -f $____Pester.CurrentTest.Name, ($result.Keys -join ', ')) -BackgroundColor Green -ForegroundColor Black
            $result['_Global']['RootKey'] | Should -Be 'RootValue'
            $result['Section']['Key'] | Should -Be 'Value'
        }
    }

    Context 'File and Content Parsing - <P_FileName>' -ForEach @(
        @{ P_Name = "File Parsing"; P_FileName = "Test_TrimWhiteSpace.ini" }
        @{ P_Name = "Content Parsing"; P_FileName = "Test_TrimWhiteSpace.ini" }
    ) {
        BeforeEach {
            $result = New-IniTestResults -TestType $P_Name -FileName $P_FileName
            Write-Verbose $result
        }

        It ('Trims whitespace around keys and values {0} from: {1}' -f $P_Name, $P_FileName) {
            Write-Host ('[ConvertFrom-Ini.tests] {0} Sections: {1}' -f $____Pester.CurrentTest.Name, ($result.Keys -join ', ')) -BackgroundColor Green -ForegroundColor Black
            $result['Test']['Key Name'] | Should -Be 'Some Value'
        }
    }
    Context 'File and Content Parsing - <P_FileName>' -ForEach @(
        @{ P_Name = "File Parsing"; P_FileName = "Test_ParseSection_KeyValuePairs.ini" }
        @{ P_Name = "Content Parsing"; P_FileName = "Test_ParseSection_KeyValuePairs.ini" }
    ) {
        BeforeEach {
            $result = New-IniTestResults -TestType $P_Name -FileName $P_FileName
            Write-Verbose $result
        }
        It ('Parses values with embedded environment variables {0} from: {1}' -f $P_Name, $P_FileName) {
            Write-Host ('[ConvertFrom-Ini.tests] {0} Sections: {1}' -f $____Pester.CurrentTest.Name, ($result.Keys -join ', ')) -BackgroundColor Green -ForegroundColor Black
            $result['EnvVars']['UserName'] | Should -Be $env:USERNAME
        }
    }

    Context 'File and Content Parsing - <P_FileName>' -ForEach @(
        @{ P_Name = "File Parsing"; P_FileName = "Test_HandlesEmbededEqualsInValue.ini" }
        @{ P_Name = "Content Parsing"; P_FileName = "Test_HandlesEmbededEqualsInValue.ini" }
    ) {
        BeforeEach {
            $result = New-IniTestResults -TestType $P_Name -FileName $P_FileName
            Write-Verbose $result
        }
        It ('Handles values containing equal signs {0} from: {1}' -f $P_Name, $P_FileName) {
            Write-Host ('[ConvertFrom-Ini.tests] {0} Sections: {1}' -f $____Pester.CurrentTest.Name, ($result.Keys -join ', ')) -BackgroundColor Green -ForegroundColor Black

            $result['Test']['Connection'] |
            Should -Be 'Server=db01;User=test=value'
        }
    }
    Context 'File and Content Parsing - <P_FileName>' -ForEach @(
        @{ P_Name = "File Parsing"; P_FileName = "Test_ParseSection_KeyValueArray.ini" }
        @{ P_Name = "Content Parsing"; P_FileName = "Test_ParseSection_KeyValueArray.ini" }
    ) {
        BeforeEach {
            $result = New-IniTestResults -TestType $P_Name -FileName $P_FileName
            Write-Verbose $result
        }
        It ('Handles array values {0} from: {1}' -f $P_Name, $P_FileName) {
            Write-Host ('[ConvertFrom-Ini.tests] {0} Sections: {1}' -f $____Pester.CurrentTest.Name, ($result.Keys -join ', ')) -BackgroundColor Green -ForegroundColor Black
            $result['SimpleArray']['TestServers'].Count | Should -Be 3
            $result['SimpleArray']['TestServers'][0] | Should -Be 'SQL01'
            $result['SimpleArray']['TestServers'][1] | Should -Be 'SQL02'
            $result['SimpleArray']['TestServers'][2] | Should -Be 'SQL03'
        }
    }
}
