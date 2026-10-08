BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\private\Invoke-AzCliInternal.ps1' -Resolve)
    function az { }
}

Describe -tag 'Unit' 'Invoke-AzCliInternal' {
    BeforeEach {
        $global:InvokeAzCliInternalTestArguments = @()
        $global:InvokeAzCliInternalTestOutput = @()
        $global:InvokeAzCliInternalTestExitCode = 0
        $global:LASTEXITCODE = 0

        Mock -CommandName az -MockWith {
            $global:InvokeAzCliInternalTestArguments = @($args)
            $global:LASTEXITCODE = $global:InvokeAzCliInternalTestExitCode
            $global:InvokeAzCliInternalTestOutput
        }
    }

    It 'forwards arguments and returns standard output and the successful exit code' {
        $global:InvokeAzCliInternalTestOutput = @('{"name":"demo"}', 'completed')
        $azArgs = @('account', 'show', '--output', 'json')

        $result = Invoke-AzCliInternal -azArgs $azArgs

        @($global:InvokeAzCliInternalTestArguments) | Should -BeExactly $azArgs
        @($result.StdOut) | Should -BeExactly $global:InvokeAzCliInternalTestOutput
        $result.ExitCode | Should -Be 0
    }

    It 'returns standard output and a nonzero exit code when az fails' {
        $global:InvokeAzCliInternalTestOutput = @('Resource not found')
        $global:InvokeAzCliInternalTestExitCode = 3

        $result = Invoke-AzCliInternal -azArgs @('group', 'show', '--name', 'missing')

        @($result.StdOut) | Should -BeExactly $global:InvokeAzCliInternalTestOutput
        $result.ExitCode | Should -Be 3
    }
}