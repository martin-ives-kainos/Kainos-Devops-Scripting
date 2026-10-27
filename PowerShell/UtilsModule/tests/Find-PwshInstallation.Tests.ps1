if ($null -eq $PesterPreference) {
    $PesterPreference = New-PesterConfiguration
    $PesterPreference.Output.Verbosity = 'Detailed'
    $PesterPreference.Debug.WriteDebugMessages = $false
    $PesterPreference.Debug.WriteDebugMessagesFrom = "Mock"
    $PesterPreference.Filter.Tag = @('Unit')
}

BeforeAll {
    . (Join-Path $PSScriptRoot '..\public\Find-PwshInstallation.ps1' -Resolve)
}

Describe -Tag 'Unit' 'Find-PwshInstallation' {
    It 'returns the executable path when pwsh is available' {
        Mock Get-Command {
            [pscustomobject]@{ Source = 'C:\Program Files\PowerShell\7\pwsh.exe' }
        }

        Find-PwshInstallation | Should -Be 'C:\Program Files\PowerShell\7\pwsh.exe'
    }

    It 'writes a message and returns null when pwsh is unavailable' {
        Mock Get-Command { $null }
        Mock Write-Information {
            Write-Host 'Mocked Write-Information called'
        }

        $result = Find-PwshInstallation

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Information -Exactly 1
    }
}