. (Join-Path $PSScriptRoot '..\public\Get-MonthDay.ps1')

Describe 'Get-MonthDay' {
    BeforeAll {
        $monthDays = Get-MonthDay
    }

    It 'returns a table with twelve months' {
        $monthDays | Should -BeOfType [System.Collections.Hashtable]
        $monthDays.Count | Should -Be 12
    }

    It 'uses the current culture month names' {
        foreach ($month in 1..12) {
            $monthDays[$month].Month |
                Should -Be (Get-Culture).DateTimeFormat.GetMonthName($month)
        }
    }

    It 'returns the maximum number of days for each month' {
        $expectedDays = @{
            1 = 31; 2 = 29; 3 = 31; 4 = 30
            5 = 31; 6 = 30; 7 = 31; 8 = 31
            9 = 30; 10 = 31; 11 = 30; 12 = 31
        }

        foreach ($month in $expectedDays.Keys) {
            $monthDays[$month].MaximumDays |
                Should -Be $expectedDays[$month]
        }
    }
}