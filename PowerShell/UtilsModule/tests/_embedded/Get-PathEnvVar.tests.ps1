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

Describe 'Get-PathEnvVar' {
    BeforeAll {
        Mock Read-EnvironmentVariable -ModuleName 'UtilsModule' {
            param ($VariableName, $Scope)
            Write-Host "Mock Reading environment variable $VariableName for scope $Scope" -ForegroundColor Cyan
            return ("{0}1;{0}2;{0}3;Both1;Both2;Both3" -f $Scope)
        }

        $t_settings = @{
            Scope        = 'Machine'
            VariableName = 'Path'
        }
        $t_settings.RawPath = ("{0}1;{0}2;{0}3;Both1;Both2;Both3" -f $t_settings.Scope)
        $t_settings.Expected = $t_settings.RawPath.Trim(';') -split ';'
        Write-Verbose "Test settings: $($t_settings | Out-String)"
    }
    It '[T-001] returns the machine Path split on semicolons with boundary semicolons removed' -Tag 'Unit' {

        $result = @(Get-PathEnvVar -VariableName $t_settings.VariableName -Scope $t_settings.Scope)

        $result.Count | Should -Be $t_settings.Expected.Count
        for ($i = 0; $i -lt $t_settings.Expected.Count; $i++) {
            $result[$i] | Should -Be $t_settings.Expected[$i]
        }
    }

    It '[T-002] accepts Name as an alias for VariableName' -Tag 'Unit' {
        $result = @(Get-PathEnvVar -Name $t_settings.VariableName -Scope $t_settings.Scope)

        $result.Count | Should -Be $t_settings.Expected.Count
        for ($i = 0; $i -lt $t_settings.Expected.Count; $i++) {
            $result[$i] | Should -Be $t_settings.Expected[$i]
        }
    }

    It '[T-003] rejects unsupported environment variable names' -Tag 'Unit' {
        { Get-PathEnvVar -VariableName 'Other' } | Should -Throw
    }

    It '[T-004] rejects unsupported scopes' -Tag 'Unit' {
        { Get-PathEnvVar -VariableName Path -Scope Process } | Should -Throw
    }
}
