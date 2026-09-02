BeforeAll {
    # Import the module to load the function being tested
    Import-Module (Join-Path $PSScriptRoot '..\UtilsModule.psd1' -Resolve) -Force -PassThru | Out-Null
}

function New-TestIniFile {
    param (
        [string]$Path
    )
    if ($Path -notmatch '\.ini$') {
        $Path += '.ini'
    }
    $FullPath = Join-Path $TestDrive (Split-Path $Path -Leaf)
    Get-Content $Path | Set-Content -Path $FullPath
    return $FullPath
}

Describe 'ConvertFrom-Ini' {

    BeforeAll {
        #        $testFile = New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test1.ini' -Resolve)
    }

    It 'Parses sections and key/value pairs' {

        Write-Host $____Pester.CurrentTest.Name -ForegroundColor Yellow -BackgroundColor Blue
        $result = ConvertFrom-Ini -Path (New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test1.ini' -Resolve))

        $result['Database']['Server'] | Should -Be 'SQL01'
        $result['Database']['Port'] | Should -Be '1433'
        $result['Application']['Name'] | Should -Be 'MyApp'
        $result['Application']['Debug'] | Should -Be 'True'
        $result['EnvVars']['UserName'] | Should -Be $env:USERNAME
    }

    It 'Ignores comments and blank lines' {

        Write-Host $____Pester.CurrentTest.Name -ForegroundColor Yellow -BackgroundColor Blue
        $result = ConvertFrom-Ini -Path (New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test2.ini' -Resolve))

        $result['Test']['Key'] | Should -Be 'Value'
        $result.Keys.Count | Should -Be 1
    }

    It 'Stores keys before a section in _Global' {

        Write-Host $____Pester.CurrentTest.Name -ForegroundColor Yellow -BackgroundColor Blue
        $result = ConvertFrom-Ini -Path (New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test3.ini' -Resolve))

        $result['_Global']['RootKey'] | Should -Be 'RootValue'
        $result['Section']['Key'] | Should -Be 'Value'
    }

    It 'Trims whitespace around keys and values' {

        Write-Host $____Pester.CurrentTest.Name -ForegroundColor Yellow -BackgroundColor Blue
        $result = ConvertFrom-Ini -Path (New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test_TrimWhiteSpace.ini' -Resolve))

        $result['Test']['Key Name'] | Should -Be 'Some Value'
    }

    It 'Handles values containing equal signs' {

        Write-Host $____Pester.CurrentTest.Name -ForegroundColor Yellow -BackgroundColor Blue
        $result = ConvertFrom-Ini -Path (New-TestIniFile -Path (Join-Path $PSScriptRoot 'data\Test_HandlesEmbededEqualsInValue.ini' -Resolve))

        $result['Test']['Connection'] |
        Should -Be 'Server=db01;User=test=value'
    }
}
