BeforeAll {
    # Import the module to load the function being tested
    Import-Module (Join-Path $PSScriptRoot '..\..\UtilsModule.psd1' -Resolve) -Force -PassThru | Out-Null
}

Describe 'ConvertFrom-Ini' {

    BeforeAll {
        $testFile = Join-Path $TestDrive 'test.ini'
    }

    It 'Parses sections and key/value pairs' {
        @'
[Database]
Server=SQL01
Port=1433

[Application]
Name=MyApp
Debug=True
'@ | Set-Content $testFile

        $result = ConvertFrom-Ini -Path $testFile

        $result['Database']['Server'] | Should -Be 'SQL01'
        $result['Database']['Port'] | Should -Be '1433'
        $result['Application']['Name'] | Should -Be 'MyApp'
        $result['Application']['Debug'] | Should -Be 'True'
    }

    It 'Ignores comments and blank lines' {
        @'
; comment
# another comment

[Test]
Key=Value

'@ | Set-Content $testFile

        $result = ConvertFrom-Ini -Path $testFile

        $result['Test']['Key'] | Should -Be 'Value'
        $result.Keys.Count | Should -Be 1
    }

    It 'Stores keys before a section in _Global' {
        @'
RootKey=RootValue

[Section]
Key=Value
'@ | Set-Content $testFile

        $result = ConvertFrom-Ini -Path $testFile

        $result['_Global']['RootKey'] | Should -Be 'RootValue'
        $result['Section']['Key'] | Should -Be 'Value'
    }

    It 'Trims whitespace around keys and values' {
        @'
[Test]
   Key Name    =    Some Value
'@ | Set-Content $testFile

        $result = ConvertFrom-Ini -Path $testFile

        $result['Test']['Key Name'] | Should -Be 'Some Value'
    }

    It 'Handles values containing equal signs' {
        @'
[Test]
Connection=Server=db01;User=test=value
'@ | Set-Content $testFile

        $result = ConvertFrom-Ini -Path $testFile

        $result['Test']['Connection'] |
            Should -Be 'Server=db01;User=test=value'
    }
}
