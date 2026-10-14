. (Join-Path $PSScriptRoot '..\public\Get-PathEnvVar.ps1')

Describe 'Get-PathEnvVar' {
    It 'returns the machine Path split on semicolons with boundary semicolons removed' {
        $rawPath = [Environment]::GetEnvironmentVariable(
            'Path',
            [EnvironmentVariableTarget]::Machine
        )
        $expected = $rawPath.Trim(';') -split ';'

        $result = @(Get-PathEnvVar -VariableName Path -Scope Machine)

        $result.Count | Should -Be $expected.Count
        for ($i = 0; $i -lt $expected.Count; $i++) {
            $result[$i] | Should -Be $expected[$i]
        }
    }

    It 'accepts Name as an alias for VariableName' {
        $expected = [Environment]::GetEnvironmentVariable(
            'Path',
            [EnvironmentVariableTarget]::Machine
        ).Trim(';') -split ';'

        $result = @(Get-PathEnvVar -Name Path -Scope Machine)

        $result.Count | Should -Be $expected.Count
        for ($i = 0; $i -lt $expected.Count; $i++) {
            $result[$i] | Should -Be $expected[$i]
        }
    }

    It 'rejects unsupported environment variable names' {
        { Get-PathEnvVar -VariableName 'Other' } | Should -Throw
    }

    It 'rejects unsupported scopes' {
        { Get-PathEnvVar -VariableName Path -Scope Process } | Should -Throw
    }
}
