if ($null -eq $PesterPreference) {
    $PesterPreference = New-PesterConfiguration
    $PesterPreference.Output.Verbosity = 'Detailed'
    # $PesterPreference.Debug.WriteDebugMessages = $true
    # $PesterPreference.Debug.WriteDebugMessagesFrom = "Mock"
    $PesterPreference.Filter.Tag = @('Unit')
}

BeforeAll {
    $helperPath = $PSScriptRoot
    while (-not (Test-Path (Join-Path $helperPath 'PesterHelperModule.ps1'))) {
        $helperPath = Join-Path $helperPath '..' -Resolve
    }
    . (Join-Path $helperPath 'PesterHelperModule.ps1' -Resolve)

    Import-Module (Join-Path $PSScriptRoot '..\..\UtilsModule.psd1' -Resolve)

    $b4all_td = "TestDrive:\Utils\"
    Write-Verbose "Setting up test drive at $b4all_td"


    function Get-MockedModuleResult {
        param (
            [string]$Name = 'Example.Module',
            [version]$Version = [version]'1.2.3',
            [string]$Repository = 'PSGallery'
        )
        return [pscustomobject]@{
            Name       = $Name
            Version    = $Version
            Repository = $Repository
        }
    }
}

Describe 'Install-ReqdUserModule' {
    BeforeEach {
        Mock Find-Module -ModuleName 'UtilsModule' {
            $stepId = Get-PesterStepId $____Pester.CurrentTest.Name
            $params = ConvertFrom-PesterBoundParameters $PesterBoundParameters
            Write-Host ("{0} Mock Finding module: {1} from {2}" -f $stepId, $params.Name, $params.Repository) -ForegroundColor Cyan
            switch ($stepId) {
                '[T-003]' {
                    Write-Host (("{0} Return a higer version" -f $stepId)) -ForegroundColor Cyan
                    return (Get-MockedModuleResult @params -Version "1.2.99")
                }
                default {
                }
            }
            return (Get-MockedModuleResult @params)
        }
        Mock Get-Module -ModuleName 'UtilsModule' {
            $stepId = Get-PesterStepId $____Pester.CurrentTest.Name
            $params = ConvertFrom-PesterBoundParameters $PesterBoundParameters
            Write-Host ("{0} Mock Getting module: {1}" -f $stepId, $params.Name) -ForegroundColor Cyan
            switch ($stepId) {
                '[T-003]' {
                    Write-Host (("{0} Setting specific behavior for test" -f $stepId)) -ForegroundColor Cyan
                    $t003_getModuleCallCount++
                    if ($t003_getModuleCallCount -gt 1) {
                        return (Get-MockedModuleResult -Name $params['Name'] -Version $params['Version'])
                    }
                }
            }
            return (Get-MockedModuleResult @params)
        }

        Mock Install-Module -ModuleName 'UtilsModule' {
            $stepId = Get-PesterStepId $____Pester.CurrentTest.Name
            $params = ConvertFrom-PesterBoundParameters $PesterBoundParameters
            Write-Host ("{0} Mock Install-Module: {1}" -f $stepId, $params.Name) -ForegroundColor Cyan
            return (Get-MockedModuleResult -Name $params.Name -Repository $params.Repository)
        }


        Mock Read-EnvironmentVariable -ModuleName 'UtilsModule' {
            param ($VariableName, $Scope)
            Write-Host "Mock Reading environment variable $VariableName for scope $Scope" -ForegroundColor Cyan

            $td_Path = ("{0};{1}" -f (Join-Path $b4all_td 'PowerShell\Modules'), (Join-Path $b4all_td 'WindowsPowerShell\Modules'))
            $td_Path -split ';' | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

            return $td_Path
        }

    }

    It '[T-001] requires a non-empty module name' -Tag 'Unit' {
        { Install-ReqdUserModule -Name '' } | Should -Throw "Cannot validate argument on parameter 'Name'. The argument is null or empty. Provide an argument that is not null or empty, and then try the command again."

    }

    It '[T-002] returns the installed module when it is already current' -Tag 'Unit' {
        <#         Mock Find-Module -ModuleName 'UtilsModule' {
            Write-Host "[T-002] Mock Finding module: $Name in repository $Repository" -ForegroundColor Cyan
            return (Get-MockedModuleResult -Name $Name -Repository $Repository)
        } #>
        <#         Mock Get-Module -ModuleName 'UtilsModule' {
            Write-Host "[T-002] Mock Getting module: $Name" -ForegroundColor Cyan
            return (Get-MockedModuleResult -Name $Name)
        } #>
        <#         Mock Install-Module -ModuleName 'UtilsModule' {
            param ($Name, $Repository, $Scope, $Force, $AllowClobber)
            Write-Host "[T-002] Mock Installing module: $Name from $Repository for $Scope" -ForegroundColor Cyan
            return (Get-MockedModuleResult -Name $Name -Repository $Repository)
        }
 #>
        $result = Install-ReqdUserModule -Name 'Example.Module'

        $result.Name | Should -BeExactly 'Example.Module'
        $result.Version.ToString() | Should -BeExactly '1.2.3'
        Should -Invoke Install-Module -ModuleName 'UtilsModule' -Times 0 -Exactly
    }

    It '[T-003] installs and returns the module when a newer version is available' -Tag 'WIP' {
        # TODO: Implement the logic to mock Get-Module and Find-Module for this test case
        $t003_getModuleCallCount = 0
        Write-Host ('[Install-ReqdUserModule.tests] {0} Set counter and Mocks' -f (Get-PesterStepId $____Pester.CurrentTest.Name)) -ForegroundColor Cyan

        <#  #>
        Mock Install-Module {
            $params = $PesterBoundParameters
            $stepId = Get-PesterStepId $____Pester.CurrentTest.Name
            Write-Host "{0} Mock Installing module: {1} from {2}" -f $stepId, $params['Name'], $params['Repository'] -ForegroundColor Cyan
        }

        $result = Install-ReqdUserModule -Name 'Example.Module'

        $result | Should -Be (Get-MockedModuleResult -Name 'Example.Module' -Version '2.0.0')
        Should -Invoke Install-Module -ModuleName 'UtilsModule' -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'Example.Module' -and
            $Repository -eq 'PSGallery' -and
            $Scope -eq 'CurrentUser'
        }
    }
}