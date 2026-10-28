<#  Function coverage tests for the UtilsModule
        Examine the function coverage for the UtilsModule, check each frunction, class etc
        Bring this back to basics, manually look at testing each function and script.
#>

if ($null -eq $PesterPreference) {
    $PesterPreference = New-PesterConfiguration
    $PesterPreference.Output.Verbosity = 'Detailed'
    # $PesterPreference.Debug.WriteDebugMessages = $true
    # $PesterPreference.Debug.WriteDebugMessagesFrom = "Mock"
    $PesterPreference.Filter.Tag = @('TestCoverage')
}


BeforeDiscovery {

    $helperPath = $PSScriptRoot
    while (-not (Test-Path (Join-Path $helperPath 'PesterHelperModule.ps1'))) {
        $helperPath = Join-Path $helperPath '..' -Resolve
    }
    . (Join-Path $helperPath 'PesterHelperModule.ps1' -Resolve)
    SetUpGlobalTestVariables -VarName 'pester_temp_RunDate' -VarValue (Get-Date)
    SetUpGlobalTestVariables -VarName 'pester_temp_ModuleRootPath' -VarValue (Join-Path $PSScriptRoot '..' -Resolve)
<#     SetUpGlobalTestVariables -VarName 'pester_temp_ScriptPaths' -VarValue (Get-ModuleTestableFolder -ModulePath $global:pester_temp_ModuleRootPath -SkipRoot)
    SetUpGlobalTestVariables -VarName 'pester_temp_TestCounter' -VarValue @{TestatableFiles = 0; TestFilesFound = 0 }

    $tc_TestCoverageNotRequired = @('ConvertTo-Hashtable.ps1')

    $tc_ScriptFiles = @{}
    foreach ($scriptPath in $Global:pester_temp_ScriptPaths.Keys | Sort-Object) {
        $tc_ScriptFiles.Add($scriptPath, @())
        Write-Host ("---Processing script path {0}" -f $scriptPath) -ForegroundColor Cyan
        foreach ($scriptFile in Get-ModuleTestableScript -ModulePath $Global:pester_temp_ScriptPaths[$scriptPath] -PathType "ScriptFolder" | Select-Object -ExpandProperty tcf_ScriptFile) {
            if ($tc_TestCoverageNotRequired -contains (Split-Path $scriptFile -Leaf)) {
                Write-Host ("------Skipping test coverage for {0}" -f (Split-Path $scriptFile -Leaf)) -ForegroundColor Yellow
                continue
            }
            $tc_ScriptFiles[$scriptPath] += $scriptFile
        }
    }
    SetUpGlobalTestVariables -VarName 'pester_temp_ScriptFiles' -VarValue $tc_ScriptFiles #>
}

AfterAll {
    CleanUpTemporaryGlobalVariables
}

BeforeAll {
    Write-Host "Starting function coverage tests for UtilsModule..." -ForegroundColor Cyan
    function New-ShouldBeTested {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Function is only used internally')]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Function is only used internally')]
        [CmdletBinding()]
        [Alias('Should-BeTested')]
        param (
            [Parameter(ValueFromPipeline)] $Actual,
            [Parameter(Position = 0)]      $Expected = $True,
            [string] $Because
        )
        begin {
            $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $Input
            $Actual = $assert.Actual()
        }
        process {
            if ($Actual -ne $Expected) {
                $assert.Fail('<because>.', @{ Expected = $Expected; Because = $Because })
            }
            else {
                $assert.Pass()
            }
        }
        end { }

    }
    # Create a list of all testable script files and list of test files found
    $b4allTestableFolders = (Get-ModuleTestableFolder -ModulePath $global:pester_temp_ModuleRootPath -SkipRoot)
    Write-Host ('[_FunctionCoverage.tests] Found testable folders: {0}' -f $b4allTestableFolders.Count) -ForegroundColor Cyan
}

Describe -Tag 'TestCoverage' "Function coverage for UtilsModule" {
    Context "Test the root folder, no scripts requiring tests should be there" {
        It "Should not have any scripts requiring tests in the root folder" {
            $rootScripts = Get-ModuleTestableScript -ModulePath $global:pester_temp_ModuleRootPath  -PathType "Root"
            $Global:pester_temp_TestCounter.TestatableFiles += $rootScripts.Count

            $rootScripts.Count | Should -Be 0
        }
    }
}

Describe -Tag 'TestCoverage2' "Validate Function Coverage" {
    BeforeAll {
        Write-Host "*---------------------------------------------------------"
        Write-Host "* Validating function coverage for UtilsModule:"
        Write-Host "* Testable files:   $($Global:pester_temp_TestCounter.TestatableFiles)"
        Write-Host "* Test files found: $($Global:pester_temp_TestCounter.TestFilesFound)"
        Write-Host "*---------------------------------------------------------*"
    }
    It "Should have all testable files covered by tests" {
        $Global:pester_temp_TestCounter.TestFilesFound | Should -Be $Global:pester_temp_TestCounter.TestatableFiles
    }
}
