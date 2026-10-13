BeforeAll {
    $helperPath = $PSScriptRoot
    while (-not (Test-Path (Join-Path $helperPath 'PesterHelperModule.ps1'))) {
        $helperPath = Join-Path $helperPath '..' -Resolve
    }
    . (Join-Path $helperPath 'PesterHelperModule.ps1' -Resolve)

    . (Find-FileInTree -RootPath (Join-Path $helperPath '..' -Resolve) -FileName ((Split-Path -Leaf $PSCommandPath) -Replace '.tests.ps1$', '.ps1'))
}

Describe -Tag 'Unit' 'Install-ReqdUserModule' {
    BeforeEach {
        $script:latestModule = [pscustomobject]@{
            Name    = 'Example.Module'
            Version = [version]'2.0.0'
        }
        $script:installedModule = [pscustomobject]@{
            Name    = 'Example.Module'
            Version = [version]'2.0.0'
        }
    }

    It 'requires a non-empty module name' {
        { Install-ReqdUserModule -Name '' } | Should -Throw
    }

    It 'returns the installed module when it is already current' {
        Mock Find-Module { $script:latestModule }
        Mock Get-Module { $script:installedModule }
        Mock Install-Module {}

        $result = Install-ReqdUserModule -Name 'Example.Module'

        $result | Should -Be $script:installedModule
        Should -Invoke Install-Module -Times 0 -Exactly
    }

    It 'installs and returns the module when a newer version is available' {
        $script:getModuleCallCount = 0
        Mock Find-Module { $script:latestModule }
        Mock Get-Module {
            $script:getModuleCallCount++
            if ($script:getModuleCallCount -gt 1) {
                return $script:installedModule
            }
        }
        Mock Install-Module {}

        $result = Install-ReqdUserModule -Name 'Example.Module'

        $result | Should -Be $script:installedModule
        Should -Invoke Install-Module -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'Example.Module' -and
            $Repository -eq 'PSGallery' -and
            $Scope -eq 'CurrentUser'
        }
    }
}