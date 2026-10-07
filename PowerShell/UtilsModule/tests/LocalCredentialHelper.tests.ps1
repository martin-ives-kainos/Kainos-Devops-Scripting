BeforeAll {
    $script:OriginalUserProfile = $env:USERPROFILE
    . (Join-Path $PSScriptRoot '..\classes\LocalCredentialHelper.ps1' -Resolve)
}

AfterAll {
    $env:USERPROFILE = $script:OriginalUserProfile
}

Describe 'LocalCredentialHelper' {
    BeforeEach {
        $env:USERPROFILE = $TestDrive
    }

    It 'builds the saved credential filename under the user profile' {
        [LocalCredentialHelper]::SavedCredentialFileName('ExampleApp') |
            Should -Be (Join-Path $TestDrive 'LocalCred_ExampleApp.xml')
    }

    It 'reads an existing saved credential without prompting' {
        $expectedCredential = [pscredential]::new(
            'test-user',
            (ConvertTo-SecureString 'test-password' -AsPlainText -Force)
        )
        $savedFile = [LocalCredentialHelper]::SavedCredentialFileName('ExampleApp')
        $expectedCredential | Export-Clixml -Path $savedFile

        $result = [LocalCredentialHelper]::Read('ExampleApp', 'ignored-user')

        $result.UserName | Should -Be 'test-user'
        $result.GetNetworkCredential().Password | Should -Be 'test-password'
    }

    It 'prompts for and saves a credential when no saved file exists' {
        $expectedCredential = [pscredential]::new(
            'prompted-user',
            (ConvertTo-SecureString 'prompted-password' -AsPlainText -Force)
        )
        $savedFile = [LocalCredentialHelper]::SavedCredentialFileName('PromptedApp')
        Remove-Item -LiteralPath $savedFile -Force -ErrorAction SilentlyContinue
        Mock Get-Credential { $expectedCredential }

        $result = [LocalCredentialHelper]::Read('PromptedApp', 'prompted-user')

        $result.UserName | Should -Be 'prompted-user'
        (Test-Path -LiteralPath $savedFile -PathType Leaf) | Should -BeTrue
        Should -Invoke Get-Credential -Times 1 -Exactly -ParameterFilter {
            $UserName -eq 'prompted-user' -and $Message -eq 'Enter credentials for prompted-user'
        }
    }
}