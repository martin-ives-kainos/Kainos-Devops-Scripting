if ($null -eq $PesterPreference) {
    $PesterPreference = New-PesterConfiguration
    $PesterPreference.Output.Verbosity = 'Detailed'
    # $PesterPreference.Debug.WriteDebugMessages = $true
    # $PesterPreference.Debug.WriteDebugMessagesFrom = "Mock"
    $PesterPreference.Filter.Tag = @('Unit')
}


BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\public\Get-PathEnvVar.ps1')
    . (Join-Path $PSScriptRoot '..\..\public\system\Update-UserEnvPath.ps1')
}

Describe -Tag 'Unit' 'Update-UserEnvPath' {
    BeforeEach {
        $script:originalPath = [Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)
        $script:userPaths = @('C:\Existing')
        $script:machinePaths = @('C:\Windows\System32')

        Mock Get-PathEnvVar {
            param($VariableName, $Scope)

            if ($Scope -eq 'Machine') {
                return $script:machinePaths
            }

            return $script:userPaths
        }
    }

    AfterEach {
        [Environment]::SetEnvironmentVariable('Path', $script:originalPath, [System.EnvironmentVariableTarget]::User)
    }

    It 'adds a new path to the user environment variable' {
        Update-UserEnvPath -VariableName 'Path' -NewPath 'C:\Custom\Tools'

        [Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User) -split ';' |
            Should -Contain 'C:\Custom\Tools'
    }

    It 'does not add a path that already exists for the user' {
        $script:userPaths = @('C:\Existing', 'C:\Custom\Tools')

        Update-UserEnvPath -VariableName 'Path' -NewPath 'C:\Custom\Tools'

        [Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User) -split ';' |
            Should -Not -Contain 'C:\Custom\Tools'
    }

    It 'removes an existing user path' {
        $script:userPaths = @('C:\Existing', 'C:\Custom\Tools')

        Update-UserEnvPath -VariableName 'Path' -Paths 'C:\Custom\Tools' -Action Remove

        [Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User) -split ';' |
            Should -Not -Contain 'C:\Custom\Tools'
    }

    It 'does not save when the requested path is already absent' {
        Update-UserEnvPath -VariableName 'Path' -Paths 'C:\Missing' -Action Remove

        [Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User) |
            Should -Be $script:originalPath
    }

    It 'rejects an unsupported environment variable name' {
        { Update-UserEnvPath -VariableName 'Bogus' -NewPath 'C:\Custom\Tools' } |
            Should -Throw
    }

    It 'rejects an unsupported action' {
        { Update-UserEnvPath -VariableName 'Path' -NewPath 'C:\Custom\Tools' -Action 'Replace' } |
            Should -Throw
    }
}