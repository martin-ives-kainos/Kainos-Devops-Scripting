BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\public\system\Get-DuplicatedUserEnvPaths.ps1' -Resolve)
}

Describe -Tag 'Unit' 'Get-DuplicatedUserEnvPaths' {
    It 'returns only user paths also present in the machine environment for <VariableName>' -ForEach @(
        @{ VariableName = 'Path' }
        @{ VariableName = 'PSModulePath' }
    ) {
        $userPaths = [Environment]::GetEnvironmentVariable(
            $VariableName,
            [System.EnvironmentVariableTarget]::User
        ) -split ';'
        $machinePaths = [Environment]::GetEnvironmentVariable(
            $VariableName,
            [System.EnvironmentVariableTarget]::Machine
        ) -split ';'
        $expectedPaths = @($userPaths | Where-Object { $machinePaths -contains $_ })

        $result = @(Get-DuplicatedUserEnvPaths -VariableName $VariableName)

        $result | Should -Be $expectedPaths
    }

    It 'rejects an unsupported environment variable name' {
        { Get-DuplicatedUserEnvPaths -VariableName 'TEMP' } | Should -Throw
    }
}