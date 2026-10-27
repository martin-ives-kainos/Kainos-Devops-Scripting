if ($null -eq $PesterPreference) {
    $PesterPreference = New-PesterConfiguration
    $PesterPreference.Output.Verbosity = 'Detailed'
    # $PesterPreference.Debug.WriteDebugMessages = $true
    # $PesterPreference.Debug.WriteDebugMessagesFrom = "Mock"
    $PesterPreference.Filter.Tag = @('Unit')
}

BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\public\dialog\Show-MessageBox.ps1' -Resolve)
}

Describe -tag 'Unit' 'Show-MessageBox console fallback' {
    BeforeEach {
        $script:MessageBoxTestResponse = ''

        Mock Add-Type { throw 'WPF is unavailable in this test.' }
        Mock Read-Host { $script:MessageBoxTestResponse }
    }

    It '[T-001]returns OK after the default OK prompt' {
        Write-Output ('[Show-MessageBox.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Cyan
        $result = Show-MessageBox -Message 'Completed'

        @($result)[-1] | Should -Be 'OK'
        Should -Invoke Read-Host -Times 1 -Exactly -ParameterFilter {
            $Prompt -eq 'Press Enter to continue'
        }
    }

    It '[T-002]returns Cancel when the user selects cancel for OKCancel' {
        Write-Output ('[Show-MessageBox.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Cyan
        $script:MessageBoxTestResponse = 'c'

        Show-MessageBox -Message 'Continue?' -Buttons OKCancel | Should -Be 'Cancel'
    }

    It '[T-003]returns OK when the user does not select cancel for OKCancel' {
        Write-Output ('[Show-MessageBox.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Cyan
        $script:MessageBoxTestResponse = 'o'

        Show-MessageBox -Message 'Continue?' -Buttons OKCancel | Should -Be 'OK'
    }

    It '[T-004]returns Yes when the user selects yes for YesNo' {
        Write-Output ('[Show-MessageBox.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Cyan
        $script:MessageBoxTestResponse = 'y'

        Show-MessageBox -Message 'Continue?' -Buttons YesNo | Should -Be 'Yes'
    }

    It '[T-005]returns No when the user selects no for YesNo' {
        Write-Output ('[Show-MessageBox.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Cyan
        $script:MessageBoxTestResponse = 'n'

        Show-MessageBox -Message 'Continue?' -Buttons YesNo | Should -Be 'No'
    }

    It '[T-006]returns the configured default when the response is blank' {
        Write-Output ('[Show-MessageBox.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Cyan
        $script:MessageBoxTestResponse = ''

        Show-MessageBox -Message 'Continue?' -Buttons YesNo -Default Yes | Should -Be 'Yes'
    }

    It '[T-007]returns the configured default when the response times out' {
        Write-Output ('[Show-MessageBox.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Cyan
        Mock Read-MessageBoxResponse { $null }

        Show-MessageBox -Message 'Continue?' -Buttons YesNo -Default Yes -TimeoutSeconds 5 | Should -Be 'Yes'
        Should -Invoke Read-MessageBoxResponse -Times 1 -Exactly -ParameterFilter {
            $Prompt -eq '[Y]es / [N]o' -and $TimeoutSeconds -eq 5
        }
    }

    It '[T-008]rejects a default that is not in the button set' {
        Write-Output ('[Show-MessageBox.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Cyan
        { Show-MessageBox -Message 'Continue?' -Buttons YesNo -Default Cancel } | Should -Throw
    }

    It '[T-009]returns YesNoCancel selection based on the user input' -ForEach @(
        @{ Response = 'y'; Expected = 'Yes' }
        @{ Response = 'n'; Expected = 'No' }
        @{ Response = 'x'; Expected = 'Cancel' }
    ) {
        Write-Output ('[Show-MessageBox.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Cyan
        $script:MessageBoxTestResponse = $Response

        Show-MessageBox -Message 'Continue?' -Buttons YesNoCancel | Should -Be $Expected
    }

    It '[T-010]rejects an unsupported button set' {
        Write-Output ('[Show-MessageBox.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Cyan
        { Show-MessageBox -Message 'Continue?' -Buttons 'Retry' } | Should -Throw
    }
}