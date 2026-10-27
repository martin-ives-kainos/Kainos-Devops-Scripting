if ($null -eq $PesterPreference) {
    $PesterPreference = New-PesterConfiguration
    $PesterPreference.Output.Verbosity = 'Detailed'
    # $PesterPreference.Debug.WriteDebugMessages = $true
    # $PesterPreference.Debug.WriteDebugMessagesFrom = "Mock"
    $PesterPreference.Filter.Tag = @('Unit')
}

BeforeAll {
    # Provide mockable command stubs when ImportExcel is not installed.
    function Open-ExcelPackage {
        param ([string]$Path)
    }

    function Close-ExcelPackage {
        param ($ExcelPackage)
    }

    . (Join-Path $PSScriptRoot '..\..\public\excel\Set-ExcelWorkbookCategory.ps1')
}

Describe 'Set-ExcelWorkbookCategory' -Tag 'Unit' {
    BeforeEach {
        $script:workbookPath = Join-Path $TestDrive 'sample.xlsx'
        New-Item -Path $script:workbookPath -ItemType File -Force | Out-Null

        $script:excelPackage = [PSCustomObject]@{
            Workbook = [PSCustomObject]@{
                Properties = [PSCustomObject]@{
                    Category = $null
                }
            }
        }

        Mock Open-ExcelPackage {
            $script:excelPackage
        }

        Mock Close-ExcelPackage {}
    }
    It '[T001] sets the requested category and closes the workbook' {
        Set-ExcelWorkbookCategory -Workbooks $script:workbookPath -Classification Public

        $script:excelPackage.Workbook.Properties.Category | Should -Be 'Public'
        Should -Invoke Open-ExcelPackage -Times 1 -Exactly
        Should -Invoke Close-ExcelPackage -Times 1 -Exactly
    }

    It '[T002] uses Confidential as the default category' {
        Set-ExcelWorkbookCategory -Workbooks $script:workbookPath

        $script:excelPackage.Workbook.Properties.Category | Should -Be 'Confidential'
    }

    It '[T003] accepts workbook paths from the pipeline by property name' {
        [PSCustomObject]@{ Workbooks = $script:workbookPath } | Set-ExcelWorkbookCategory -Classification 'Client Shared'
        $script:excelPackage.Workbook.Properties.Category | Should -Be 'Client Shared'
        Should -Invoke Open-ExcelPackage -Times 1 -Exactly
    }

    It '[T004] warns and skips workbooks that do not exist' {
        $missingPath = Join-Path $TestDrive 'missing.xlsx'
        $warnings = @()

        Set-ExcelWorkbookCategory -Workbooks $missingPath `
            -WarningVariable warnings -WarningAction SilentlyContinue

        $warnings | Should -Match 'does not exist'
        Should -Invoke Open-ExcelPackage -Times 0 -Exactly
        Should -Invoke Close-ExcelPackage -Times 1 -Exactly
    }

    It '[T005] rejects unsupported classifications' {
        {
            Set-ExcelWorkbookCategory -Workbooks $script:workbookPath `
                -Classification 'Internal'
        } | Should -Throw
    }
}