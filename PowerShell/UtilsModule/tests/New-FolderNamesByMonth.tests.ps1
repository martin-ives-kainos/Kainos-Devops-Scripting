BeforeDiscovery {
    $helperPath = $PSScriptRoot
    while (-not (Test-Path (Join-Path $helperPath 'PesterHelperModule.ps1'))) {
        $helperPath = Join-Path $helperPath '..' -Resolve
    }
    . (Join-Path $helperPath 'PesterHelperModule.ps1' -Resolve)
    $global:pester_temp_RunDate = Get-Date
    $t_TestCases = @()
    for ($i = 1; $i -le 12; $i++) {
        $t_TestCases += @{
            MonthNo         = $i
            FullName        = (Get-Culture).DateTimeFormat.GetMonthName($i)
            MaximumDays     = [DateTime]::DaysInMonth($global:pester_temp_RunDate.Year, $i)
            AbbreviatedName = (Get-Culture).DateTimeFormat.GetAbbreviatedMonthName($i)
            PropertyNames    = "FullName=true;AbbreviatedName=true;MaximumDays=true;Path=false"
        }
    }
    SetUpGlobalTestCases -VarName 'pester_temp_DatesNoPath' -TestCases $t_TestCases
}
BeforeAll {
    # Import
    . (Join-Path $PSScriptRoot '..\Public\Get-MonthDays.ps1' -Resolve)
    . (Join-Path $PSScriptRoot '..\Public\fileio\New-FolderNamesByMonth.ps1' -Resolve)
}
AfterAll {
    # Cleanup code if needed
    CleanUpTemporaryGlobalVariables -TestName 'New-FolderNamesByMonth.tests'
}

Describe 'New-FolderNamesByMonth' {
    Context 'Folder Names By Month No Path/RootPath' {
        BeforeAll {
            Write-Host ('[New-FolderNamesByMonth.tests] {0} BeforeAll Context: {1}' -f $____Pester.CurrentTest.Name, $____Pester.CurrentContext.Name) -BackgroundColor Green -ForegroundColor Black
            $folderNamesByMonth = New-FolderNamesByMonth
            Write-Verbose "Folder Names By Month: $($folderNamesByMonth | Out-String)"
        }
        It "Returns the expected values for month number for $MonthNo" -ForEach $global:pester_temp_DatesNoPath {
            param(
                $MonthNo,
                $FullName,
                $AbbreviatedName,
                $MaximumDays,
                $PropertyNames
            )
            Write-Host ('[New-FolderNamesByMonth.tests] {0} {1} - MonthNo: {2}' -f $____Pester.CurrentTest.Name, $____Pester.CurrentContext.Name, $MonthNo) -BackgroundColor Green -ForegroundColor Black
            $foundPropNames = $folderNamesByMonth[$MonthNo].PSObject.Properties.Name
            foreach ($pItem in $PropertyNames.Split(';')) {
                $propName, $propShouldExist = $pItem -split '='
                Write-Host ('[New-FolderNamesByMonth.tests] ----- Property: {0} Exists: {1}' -f $propName, $propShouldExist) -BackgroundColor Green -ForegroundColor Black

                ($foundPropNames -contains $propName) | Should -Be ([bool]::Parse($propShouldExist))
            }
        }

    }
    <#     It "returns ordered month metadata for all twelve months" {
        $months = New-FolderNamesByMonth

        $months.Count | Should -Be 12
        (@($months.Keys) -join ",") | Should -BeExactly "1,2,3,4,5,6,7,8,9,10,11,12"
        $months[1].FullName | Should -Be (Get-Culture).DateTimeFormat.GetMonthName(1)
        $months[2].MaximumDays | Should -Be 29
        $months[4].MaximumDays | Should -Be 30
        $months[1].PSObject.Properties.Name | Should -Not -Contain "Path"
    }

    It "creates a numbered folder for each month under the root path" {
        $rootPath = "TestDrive:\MonthlyFolders"
        New-Item -Path $rootPath -ItemType Directory | Out-Null

        $months = New-FolderNamesByMonth -RootPath $rootPath

        foreach ($monthNumber in 1..12) {
            $expectedPath = Join-Path $rootPath ("{0:00} {1}" -f $monthNumber, $months[$monthNumber].FullName)
            $months[$monthNumber].Path | Should -BeExactly $expectedPath
            Test-Path -LiteralPath $expectedPath -PathType Container | Should -BeTrue
        }
    } #>
}