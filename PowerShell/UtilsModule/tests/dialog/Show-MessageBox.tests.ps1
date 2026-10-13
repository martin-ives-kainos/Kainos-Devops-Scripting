BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\public\dialog\Show-MessageBox.ps1' -Resolve)
}

Describe -tag 'Unit' 'Show-MessageBox console fallback' {
    BeforeEach {
        $script:MessageBoxTestResponse = ''

        Mock Add-Type { throw 'WPF is unavailable in this test.' }
        Mock Read-Host { $script:MessageBoxTestResponse }
    }

    It 'returns OK after the default OK prompt' {
        $result = Show-MessageBox -Message 'Completed'

        @($result)[-1] | Should -Be 'OK'
        Should -Invoke Read-Host -Times 1 -Exactly -ParameterFilter {
            $Prompt -eq 'Press Enter to continue'
        }
    }

    It 'returns Cancel when the user selects cancel for OKCancel' {
        $script:MessageBoxTestResponse = 'c'

        Show-MessageBox -Message 'Continue?' -Buttons OKCancel | Should -Be 'Cancel'
    }

    It 'returns OK when the user does not select cancel for OKCancel' {
        $script:MessageBoxTestResponse = 'o'

        Show-MessageBox -Message 'Continue?' -Buttons OKCancel | Should -Be 'OK'
    }

    It 'returns Yes when the user selects yes for YesNo' {
        $script:MessageBoxTestResponse = 'y'

        Show-MessageBox -Message 'Continue?' -Buttons YesNo | Should -Be 'Yes'
    }

    It 'returns No when the user selects no for YesNo' {
        $script:MessageBoxTestResponse = 'n'

        Show-MessageBox -Message 'Continue?' -Buttons YesNo | Should -Be 'No'
    }

    It 'returns the configured default when the response is blank' {
        $script:MessageBoxTestResponse = ''

        Show-MessageBox -Message 'Continue?' -Buttons YesNo -Default Yes | Should -Be 'Yes'
    }

    It 'returns the configured default when the response times out' {
        Mock Read-MessageBoxResponse { $null }

        Show-MessageBox -Message 'Continue?' -Buttons YesNo -Default Yes -TimeoutSeconds 5 | Should -Be 'Yes'
        Should -Invoke Read-MessageBoxResponse -Times 1 -Exactly -ParameterFilter {
            $Prompt -eq '[Y]es / [N]o' -and $TimeoutSeconds -eq 5
        }
    }

    It 'rejects a default that is not in the button set' {
        { Show-MessageBox -Message 'Continue?' -Buttons YesNo -Default Cancel } | Should -Throw
    }

    It 'returns YesNoCancel selection based on the user input' -ForEach @(
        @{ Response = 'y'; Expected = 'Yes' }
        @{ Response = 'n'; Expected = 'No' }
        @{ Response = 'x'; Expected = 'Cancel' }
    ) {
        $script:MessageBoxTestResponse = $Response

        Show-MessageBox -Message 'Continue?' -Buttons YesNoCancel | Should -Be $Expected
    }

    It 'rejects an unsupported button set' {
        { Show-MessageBox -Message 'Continue?' -Buttons 'Retry' } | Should -Throw
    }
}