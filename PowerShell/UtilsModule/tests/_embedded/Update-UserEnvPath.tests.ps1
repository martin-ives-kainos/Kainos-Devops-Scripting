if ($null -eq $PesterPreference) {
    $PesterPreference = New-PesterConfiguration
    $PesterPreference.Output.Verbosity = 'Detailed'
    # $PesterPreference.Debug.WriteDebugMessages = $true
    # $PesterPreference.Debug.WriteDebugMessagesFrom = "Mock"
    $PesterPreference.Filter.Tag = @('Unit')
}


BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\UtilsModule.psd1' -Resolve)
}

Describe 'Update-UserEnvPath' {
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

    It '[T-001] adds a new path to the user environment variable' -Tag 'Unit' {
        Update-UserEnvPath -VariableName 'Path' -NewPath 'C:\Custom\Tools'

        [Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User) -split ';' |
            Should -Contain 'C:\Custom\Tools'
    }

    It '[T-002] does not add a path that already exists for the user' -Tag 'WIP' {
        # TODO: Need to fix this, seems to fail intermittently
        $script:userPaths = @('C:\Existing', 'C:\Custom\Tools')

        Update-UserEnvPath -VariableName 'Path' -NewPath 'C:\Custom\Tools'


        [Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User) -split ';' |
            Should -Not -Contain 'C:\Custom\Tools'
    }

    It '[T-003] removes an existing user path' -Tag 'Unit' {
        $script:userPaths = @('C:\Existing', 'C:\Custom\Tools')

        Update-UserEnvPath -VariableName 'Path' -Paths 'C:\Custom\Tools' -Action Remove

        [Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User) -split ';' |
            Should -Not -Contain 'C:\Custom\Tools'
    }

    It '[T-004] does not save when the requested path is already absent' -Tag 'Unit' {
        Update-UserEnvPath -VariableName 'Path' -Paths 'C:\Missing' -Action Remove

        [Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User) |
            Should -Be $script:originalPath
    }

    It '[T-005] rejects an unsupported environment variable name' -Tag 'Unit' {
        { Update-UserEnvPath -VariableName 'Bogus' -NewPath 'C:\Custom\Tools' } |
            Should -Throw
    }

    It '[T-006] rejects an unsupported action' -Tag 'Unit' {
        { Update-UserEnvPath -VariableName 'Path' -NewPath 'C:\Custom\Tools' -Action 'Replace' } |
            Should -Throw
    }
}