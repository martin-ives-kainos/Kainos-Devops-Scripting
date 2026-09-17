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

function Invoke-MockAzCliInternalError {
    param (
        [Parameter(Mandatory)]
        [ValidateRange(-1, 9)]
        [int]$ExitCode,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ErrorMessage
    )
    $global:LASTEXITCODE = $ExitCode
    $result = @{
        StdOut   = @($ErrorMessage)
        ExitCode = $global:LASTEXITCODE
    }
    try {
        Write-Host ('[Invoke-AzCli.tests] {0} ---Mocking Invoke-AzCliInternal--- {1}' -f $____Pester.CurrentTest.Name, $result.StdOut[0]) -BackgroundColor Blue -ForegroundColor White
        throw $result.StdOut[0]
    }
    catch {
        $result.StdOut += $_
    }
    return $result


}

BeforeAll {
    # Import the module to load the function being tested
    Import-Module (Join-Path $PSScriptRoot '..\UtilsModule.psd1' -Resolve) -Force -PassThru | Out-Null
    . (Join-Path $PSScriptRoot 'PesterHelperModule.ps1' -Resolve)
}

AfterAll {
    Remove-Variable -Name InvokeAzCliTestArguments -Scope Global -ErrorAction SilentlyContinue
}

# For Windows-users: curl used in sample requires Windows 10 1803 / Windows Server 2019 or later
Describe 'Invoke-AzCli' {
    BeforeEach {
        $global:InvokeAzCliTestArguments = @()
        $global:LASTEXITCODE = 0
    }
    It 'appends JSON output arguments and parses JSON output by default' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock -CommandName Invoke-AzCliInternal -ModuleName 'UtilsModule' -MockWith {
            $global:InvokeAzCliTestArguments = $args[1]
            $global:LASTEXITCODE = 0
            return @{
                StdOut   = '{"name":"demo"}'
                ExitCode = $global:LASTEXITCODE
            }
        }

        $result = Invoke-AzCli -Arguments @('account', 'show') -AsJson

        @($global:InvokeAzCliTestArguments) | Should -BeExactly @('account', 'show', '--output', 'json')

        $result.name | Should -Be 'demo'
        Should -Invoke Invoke-AzCliInternal -ModuleName 'UtilsModule' -Times 1 -Exactly
    }

    It 'appends JSON output arguments, parses JSON output by default, saves output to a file when DataFilePath is specified' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock -CommandName Invoke-AzCliInternal -ModuleName 'UtilsModule' -MockWith {
            $global:InvokeAzCliTestArguments = $args[1]
            $global:LASTEXITCODE = 0
            return @{
                StdOut   = '{"name":"demo"}'
                ExitCode = $global:LASTEXITCODE
            }
        }
        $dataFilePath = "TestDrive:\datafiles\test.json"
        $result = Invoke-AzCli -Arguments @('account', 'show') -AsJson -DataFilePath $dataFilePath

        (Test-Path $dataFilePath -PathType Leaf) | Should-BeTrue
        @($global:InvokeAzCliTestArguments) | Should -BeExactly @('account', 'show', '--output', 'json')

        $result.name | Should -Be 'demo'
        Should -Invoke Invoke-AzCliInternal -ModuleName 'UtilsModule' -Times 1 -Exactly
    }


    It 'does not append JSON output arguments when an output option is supplied' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock -CommandName Invoke-AzCliInternal -ModuleName 'UtilsModule' -MockWith {
            $global:InvokeAzCliTestArguments = $args[1]
            $global:LASTEXITCODE = 0
            return @{
                StdOut   = 'demo'
                ExitCode = $global:LASTEXITCODE
            }
        }

        $result = Invoke-AzCli -Arguments @('account', 'show', '-o', 'table') -AsJson

        @($global:InvokeAzCliTestArguments) |
        Should -BeExactly @('account', 'show', '-o', 'table')

        $result | Should -Be 'demo'
        Should -Invoke Invoke-AzCliInternal -ModuleName 'UtilsModule' -Times 1 -Exactly
    }

    It 'returns raw output when AsJson is disabled' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock -CommandName Invoke-AzCliInternal -ModuleName 'UtilsModule' -MockWith {
            $global:InvokeAzCliTestArguments = $args[1]
            $global:LASTEXITCODE = 0
            return @{
                StdOut   = '{"name":"demo"}'
                ExitCode = $global:LASTEXITCODE
            }
        }

        $result = Invoke-AzCli `
            -Arguments @('account', 'show') `
            -AsJson:$false

        @($global:InvokeAzCliTestArguments) |
        Should -BeExactly @('account', 'show')

        $result | Should -Be '{"name":"demo"}'
        Should -Invoke Invoke-AzCliInternal -ModuleName 'UtilsModule' -Times 1 -Exactly
    }

    It 'returns a successful result object with PassThruOnError' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock -CommandName Invoke-AzCliInternal -ModuleName 'UtilsModule' -MockWith {
            Invoke-MockAzCliInternalError -ExitCode 0 -ErrorMessage '123'
        }

        $result = Invoke-AzCli `
            -Arguments @('group', 'show', '--name', 'demo') `
            -PassThruOnError

        $result.Success | Should -BeTrue
        $result.Output | Should -Be '123'
        $result.Error | Should -BeNullOrEmpty
        $result.ExitCode | Should -Be 0
        Should -Invoke Invoke-AzCliInternal -ModuleName 'UtilsModule' -Times 1 -Exactly
    }

    It 'returns a failure result when Azure CLI exits with a nonzero code' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock -CommandName Invoke-AzCliInternal -ModuleName 'UtilsModule' -MockWith {
            Invoke-MockAzCliInternalError -ExitCode 3 -ErrorMessage 'Resource was not found'

        }

        $result = Invoke-AzCli `
            -Arguments @('group', 'show', '--name', 'missing') `
            -PassThruOnError

        $result.Success | Should -BeFalse
        $result.Output | Should -BeNullOrEmpty
        $result.Error | Should -Match 'Resource was not found'
        $result.ExitCode | Should -Be 3
        Should -Invoke Invoke-AzCliInternal -ModuleName 'UtilsModule' -Times 1 -Exactly
    }

    It 'throws when Azure CLI exits with a nonzero code and PassThruOnError is not used' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock -CommandName Invoke-AzCliInternal -ModuleName 'UtilsModule' -MockWith {
            Invoke-MockAzCliInternalError -ExitCode 7 -ErrorMessage 'Azure CLI failure'
        }

        {
            Invoke-AzCli -Arguments @('account', 'show')
        } | Should -Throw '*Azure CLI command failed (exit code 7)*'
    }

    It 'returns ExitCode -1 when command invocation throws' {
        Mock -CommandName Invoke-AzCliInternal -ModuleName 'UtilsModule' -MockWith {
            Invoke-MockAzCliInternalError -ExitCode -1 -ErrorMessage 'Azure CLI executable could not be started.'
        }

        $result = Invoke-AzCli -Arguments @('account', 'show') -PassThruOnError

        $result.Success | Should -BeFalse
        $result.Output | Should -BeNullOrEmpty
        $result.Error | Should -Match 'Azure CLI executable could not be started'
        $result.ExitCode | Should -Be -1
    }

    It 'returns raw output when successful output is not valid JSON' {
        Write-Host ('[Invoke-AzCli.tests] {0} Message' -f $____Pester.CurrentTest.Name) -BackgroundColor Green -ForegroundColor Black
        Mock -CommandName Invoke-AzCliInternal -ModuleName 'UtilsModule' -MockWith {
            Invoke-MockAzCliInternalError -ExitCode 0 -ErrorMessage 'not valid JSON'
        }

        $result = Invoke-AzCli -Arguments @('account', 'show')

        $result | Should -Be 'not valid JSON'
    }
}