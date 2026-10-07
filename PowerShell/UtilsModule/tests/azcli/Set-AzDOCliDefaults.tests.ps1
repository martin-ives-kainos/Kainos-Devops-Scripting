BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\public\azcli\Set-AzDOCliDefaults.ps1' -Resolve)

    function Invoke-AzCli {
        param([string[]]$Arguments)

        $script:AzCliDefaultTestCalls += ,($Arguments -join '|')
        'configured'
    }
}

Describe 'Set-AzDOCliDefaults' {
    BeforeEach {
        $script:AzCliDefaultTestCalls = @()
    }

    It 'sets the supplied organization and project defaults, then lists the defaults' {
        Set-AzDOCliDefaults -Organization 'https://dev.azure.com/example' -Project 'Sample Project'

        $script:AzCliDefaultTestCalls.Count | Should -Be 3
        $script:AzCliDefaultTestCalls | Should -Contain 'devops|configure|--defaults|organization=https://dev.azure.com/example'
        $script:AzCliDefaultTestCalls | Should -Contain 'devops|configure|--defaults|project=Sample Project'
        $script:AzCliDefaultTestCalls | Should -Contain 'devops|configure|--list'
    }
}