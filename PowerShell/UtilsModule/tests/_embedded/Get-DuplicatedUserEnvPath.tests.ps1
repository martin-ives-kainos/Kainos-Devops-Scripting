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

Describe 'Get-DuplicatedUserEnvPath' {
    BeforeAll {
        Mock Read-EnvironmentVariable -ModuleName 'UtilsModule' {
            param ($VariableName, $Scope)
            Write-Host "Mock Reading environment variable $VariableName for scope $Scope" -ForegroundColor Cyan
            return ("{0}1;{0}2;{0}3;Both1;Both2;Both3" -f $Scope)
        }
    }
    It 'returns only user paths also present in the machine environment for <VariableName>' -Tag 'Unit' -ForEach @(
        @{ VariableName = 'Path' }
        @{ VariableName = 'PSModulePath' }
    ) {
<#         $userPaths = ("{0}1;{0}2;{0}3;Both1;Both2;Both3" -f 'User') -split ';'
        $machinePaths = ("{0}1;{0}2;{0}3;Both1;Both2;Both3" -f 'Machine') -split ';'
        $expectedPaths = @($userPaths | Where-Object { $machinePaths -contains $_ }) #>

        $result = (Get-DuplicatedUserEnvPath -VariableName $VariableName -Verbose)

        $result | Should -Be @('Both1', 'Both2', 'Both3')
    }

    It 'rejects an unsupported environment variable name' -Tag 'xUnit'{
        { Get-DuplicatedUserEnvPath -VariableName 'TEMP' } | Should -Throw
    }
}