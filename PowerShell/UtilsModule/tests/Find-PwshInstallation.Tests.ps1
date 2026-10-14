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
        Mock Write-Host {}

        $result = Find-PwshInstallation

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Host -Exactly 1 -ParameterFilter {
            $Object -eq 'PowerShell 7 executable not found in PATH.'
        }
    }
}