<#
1. Load the Invoke-AzCli function from the adjacent source file.
2. Create a harmless placeholder `az` command so Pester can mock it without invoking
   the real Azure CLI.
3. Before each test:
   - Reset captured arguments.
   - Reset LASTEXITCODE.
4. Test successful JSON execution:
   - Mock az to return JSON and exit code 0.
   - Verify --output json is appended.
   - Verify JSON is converted to a PowerShell object.
5. Test explicit output formatting:
   - Pass -o table.
   - Verify no additional --output json arguments are appended.
   - Verify raw output is returned.
6. Test AsJson disabled:
   - Pass -AsJson:$false.
   - Verify arguments are unchanged.
   - Verify raw output is returned.
7. Test successful PassThruOnError:
   - Verify Success, Output, Error, and ExitCode values.
8. Test command failure with PassThruOnError:
   - Mock stderr and a nonzero exit code.
   - Verify the returned failure object contains the error and exit code.
9. Test command failure without PassThruOnError:
   - Verify a terminating exception is thrown.
10. Test invocation exceptions:
    - Mock az itself to throw.
    - Verify PassThruOnError returns ExitCode -1.
11. Test invalid JSON:
    - Verify invalid JSON is returned as a raw string rather than causing failure.
#>

# Invoke-AzCli.Tests.ps1

BeforeAll {
    # Import the module to load the function being tested
    Import-Module (Join-Path $PSScriptRoot '..\UtilsModule.psd1' -Resolve) -Force -PassThru | Out-Null
    . (Join-Path $PSScriptRoot 'PesterHelperModule.ps1' -Resolve)

    # Placeholder command required so Pester can mock Azure CLI calls
    function az {
        throw 'The az command should have been mocked.'
    }
}

AfterAll {
    Remove-Variable -Name InvokeAzCliTestArguments -Scope Global -ErrorAction SilentlyContinue
}

Describe 'Invoke-AzCli' {
    BeforeEach {
        $global:InvokeAzCliTestArguments = @()
        $global:LASTEXITCODE = 0
    }
    It 'appends JSON output arguments and parses JSON output by default' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock az {
            $global:InvokeAzCliTestArguments = @($args)
            $global:LASTEXITCODE = 0
            '{"name":"demo"}'
        }

        $result = Invoke-AzCli -Arguments @('account', 'show')

        @($global:InvokeAzCliTestArguments) |
            Should -BeExactly @('account', 'show', '--output', 'json')

        $result.name | Should -Be 'demo'
        Should -Invoke az -Times 1 -Exactly
    }

    It 'does not append JSON output arguments when an output option is supplied' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock az {
            $global:InvokeAzCliTestArguments = @($args)
            $global:LASTEXITCODE = 0
            'demo'
        }

        $result = Invoke-AzCli -Arguments @('account', 'show', '-o', 'table')

        @($global:InvokeAzCliTestArguments) |
            Should -BeExactly @('account', 'show', '-o', 'table')

        $result | Should -Be 'demo'
        Should -Invoke az -Times 1 -Exactly
    }

    It 'returns raw output when AsJson is disabled' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock az {
            $global:InvokeAzCliTestArguments = @($args)
            $global:LASTEXITCODE = 0
            '{"name":"demo"}'
        }

        $result = Invoke-AzCli `
            -Arguments @('account', 'show') `
            -AsJson:$false

        @($global:InvokeAzCliTestArguments) |
            Should -BeExactly @('account', 'show')

        $result | Should -Be '{"name":"demo"}'
    }

    It 'returns a successful result object with PassThruOnError' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock az {
            $global:InvokeAzCliTestArguments = @($args)
            $global:LASTEXITCODE = 0
            '{"id":"123"}'
        }

        $result = Invoke-AzCli `
            -Arguments @('group', 'show', '--name', 'demo') `
            -PassThruOnError

        $result.Success | Should -BeTrue
        $result.Output.id | Should -Be '123'
        $result.Error | Should -BeNullOrEmpty
        $result.ExitCode | Should -Be 0
    }

    It 'returns a failure result when Azure CLI exits with a nonzero code' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock az {
            $global:InvokeAzCliTestArguments = @($args)
            $global:LASTEXITCODE = 3
            Write-Error 'Resource was not found'
        }

        $result = Invoke-AzCli `
            -Arguments @('group', 'show', '--name', 'missing') `
            -PassThruOnError

        $result.Success | Should -BeFalse
        $result.Output | Should -BeNullOrEmpty
        $result.Error | Should -Match 'Resource was not found'
        $result.ExitCode | Should -Be 3
    }

    It 'throws when Azure CLI exits with a nonzero code and PassThruOnError is not used' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock az {
            $global:LASTEXITCODE = 7
            Write-Error 'Azure CLI failure'
        }

        {
            Invoke-AzCli -Arguments @('account', 'show')
        } | Should -Throw '*Azure CLI command failed (exit code 7)*'
    }

    It 'returns ExitCode -1 when command invocation throws' {
        Mock az {
            throw 'Azure CLI executable could not be started.'
        }

        $result = Invoke-AzCli `
            -Arguments @('account', 'show') `
            -PassThruOnError

        $result.Success | Should -BeFalse
        $result.Output | Should -BeNullOrEmpty
        $result.Error | Should -Match 'Azure CLI executable could not be started'
        $result.ExitCode | Should -Be -1
    }

    It 'returns raw output when successful output is not valid JSON' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock az {
            $global:LASTEXITCODE = 0
            'not valid JSON'
        }

        $result = Invoke-AzCli -Arguments @('account', 'show')

        $result | Should -Be 'not valid JSON'
    }
}