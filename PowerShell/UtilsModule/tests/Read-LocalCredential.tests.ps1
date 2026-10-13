BeforeAll {
    $script:OriginalAppData = $env:APPDATA
    $script:OriginalUserName = $env:USERNAME
    . (Join-Path $PSScriptRoot '..\public\LocalCredentials\Read-LocalCredential.ps1' -Resolve)
}

AfterAll {
    $env:APPDATA = $script:OriginalAppData
    $env:USERNAME = $script:OriginalUserName
}

Describe 'Read-LocalCredential' {
    BeforeEach {
        $env:APPDATA = $TestDrive
        $env:USERNAME = 'environment-user'
        Remove-Item -LiteralPath (Join-Path $TestDrive 'LocalCred_ExampleApp.xml') -Force -ErrorAction SilentlyContinue
    }

    It 'imports an existing credential without prompting' {
        $savedFile = Join-Path $TestDrive 'LocalCred_ExampleApp.xml'
        Set-Content -LiteralPath $savedFile -Value 'saved credential'
        $expectedCredential = [pscredential]::new(
            'saved-user',
            (ConvertTo-SecureString 'saved-password' -AsPlainText -Force)
        )
        Mock Import-Clixml { $expectedCredential }
        Mock Get-Credential { throw 'Should not prompt when a saved credential exists.' }

        $result = Read-LocalCredential -AppName 'ExampleApp'

        $result.UserName | Should -Be 'saved-user'
        Should -Invoke Import-Clixml -Times 1 -Exactly -ParameterFilter {
            $Path -eq $savedFile
        }
        Should -Invoke Get-Credential -Times 0 -Exactly
    }

    It 'prompts with the environment username and saves a new credential' {
        $savedFile = Join-Path $TestDrive 'LocalCred_ExampleApp.xml'
        $expectedCredential = [pscredential]::new(
            'environment-user',
            (ConvertTo-SecureString 'new-password' -AsPlainText -Force)
        )
        Mock Get-Credential { $expectedCredential }
        Mock Export-Clixml {}

        $result = Read-LocalCredential -AppName 'ExampleApp'

        $result.UserName | Should -Be 'environment-user'
        Should -Invoke Get-Credential -Times 1 -Exactly -ParameterFilter {
            $UserName -eq 'environment-user' -and $Message -eq 'Enter credentials for environment-user'
        }
        Should -Invoke Export-Clixml -Times 1 -Exactly -ParameterFilter {
            $Path -eq $savedFile -and $Force
        }
    }

    It 'prompts again when ForcePrompt is specified even if a credential exists' {
        $savedFile = Join-Path $TestDrive 'LocalCred_ExampleApp.xml'
        Set-Content -LiteralPath $savedFile -Value 'saved credential'
        $expectedCredential = [pscredential]::new(
            'prompted-user',
            (ConvertTo-SecureString 'prompted-password' -AsPlainText -Force)
        )
        Mock Get-Credential { $expectedCredential }
        Mock Import-Clixml { throw 'Should not import when ForcePrompt is specified.' }
        Mock Export-Clixml {}

        $result = Read-LocalCredential -AppName 'ExampleApp' -UserName 'prompted-user' -ForcePrompt

        $result.UserName | Should -Be 'prompted-user'
        Should -Invoke Get-Credential -Times 1 -Exactly
        Should -Invoke Import-Clixml -Times 0 -Exactly
        Should -Invoke Export-Clixml -Times 1 -Exactly -ParameterFilter {
            $Path -eq $savedFile -and $Force
        }
    }

    It 'rejects an empty application name' {
        { Read-LocalCredential -AppName '' } | Should -Throw
    }
}