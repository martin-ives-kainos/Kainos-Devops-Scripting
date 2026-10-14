BeforeAll {
    . (Join-Path $PSScriptRoot '..\public\Get-DateFromString.ps1' -Resolve)
}

Describe -Tag 'Unit' 'Get-DateFromString' {
    It 'parses an input using the supplied exact format' {
        $result = Get-DateFromString -InputString '03 Feb 2024' -Formats @('dd MMM yyyy')

        $result.Success | Should -BeTrue
        $result.Date | Should -Be ([datetime]::new(2024, 2, 3))
        $result.Format | Should -Be 'dd MMM yyyy'
    }

    It 'removes ordinal suffixes before parsing' {
        $result = Get-DateFromString -InputString '3rd Feb 2024' -Formats @('d MMM yyyy')

        $result.Success | Should -BeTrue
        $result.Date | Should -Be ([datetime]::new(2024, 2, 3))
        $result.Format | Should -Be 'd MMM yyyy'
    }

    It 'falls back to standard parsing when no exact format matches' {
        $result = Get-DateFromString -InputString 'February 3, 2024' -Formats @('yyyyMMdd')

        $result.Success | Should -BeTrue
        $result.Date | Should -Be ([datetime]::new(2024, 2, 3))
        $result.Format | Should -Be 'AutoDetected'
    }

    It 'returns an unsuccessful result for an unparseable input' {
        $result = Get-DateFromString -InputString 'not a date' -Formats @()

        $result.Success | Should -BeFalse
        $result.Date | Should -BeNullOrEmpty
        $result.Format | Should -BeNullOrEmpty
    }
}