<#  Function coverage tests for the UtilsModule
        Examine the function coverage for the UtilsModule, check each frunction, class etc
        Bring this back to basics, manually look at testing each function and script.
#>

BeforeDiscovery {

    $helperPath = $PSScriptRoot
    while (-not (Test-Path (Join-Path $helperPath 'PesterHelperModule.ps1'))) {
        $helperPath = Join-Path $helperPath '..' -Resolve
    }
    . (Join-Path $helperPath 'PesterHelperModule.ps1' -Resolve)
    SetUpGlobalTestVariables -VarName 'pester_temp_RunDate' -VarValue (Get-Date)
    SetUpGlobalTestVariables -VarName 'pester_temp_ModuleRootPath' -VarValue (Join-Path $PSScriptRoot '..' -Resolve)
    SetUpGlobalTestVariables -VarName 'pester_temp_ScriptPaths' -VarValue (Get-ModuleTestableFolders -ModulePath $global:pester_temp_ModuleRootPath -SkipRoot)
    SetUpGlobalTestVariables -VarName 'pester_temp_TestCounter' -VarValue @{TestatableFiles = 0; TestFilesFound = 0 }

    $tc_ScriptFiles = @{}
    foreach ($scriptPath in $Global:pester_temp_ScriptPaths.Keys | Sort-Object) {
        $tc_ScriptFiles.Add($scriptPath, @())
        foreach ($scriptFile in Get-ModuleTestableScripts -ModulePath $Global:pester_temp_ScriptPaths[$scriptPath] -PathType "ScriptFolder" | Select-Object -ExpandProperty tcf_ScriptFile) {
            $tc_ScriptFiles[$scriptPath] += $scriptFile
        }
    }
    SetUpGlobalTestVariables -VarName 'pester_temp_ScriptFiles' -VarValue $tc_ScriptFiles
}

AfterAll {
    CleanUpTemporaryGlobalVariables
}

BeforeAll {
    Write-Host "Starting function coverage tests for UtilsModule..." -ForegroundColor Cyan
    function New-ShouldBeTested {
        [CmdletBinding()]
        [Alias('Should-BeTested')]
        param (
            [Parameter(ValueFromPipeline)] $Actual,
            [Parameter(Position = 0)]      $Expected = $True,
            [string] $Because
        )
        end {
            $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $Input
            $Actual = $assert.Actual()

            if ($Actual -ne $Expected) {
                $assert.Fail('<because>.', @{ Expected = $Expected; Because = $Because })
            }
        }
    }

}

Describe -Tag 'TestCoverage' "Function coverage for UtilsModule" {
    Context "Test the root folder, no scripts requiring tests should be there" {
        It "Should not have any scripts requiring tests in the root folder" {
            $rootScripts = Get-ModuleTestableScripts -ModulePath $global:pester_temp_ModuleRootPath  -PathType "Root"
            $Global:pester_temp_TestCounter.TestatableFiles += $rootScripts.Count

            $rootScripts.Count | Should -Be 0
        }
    }
    Context "Test the script folders, all scripts should have corresponding tests" -ForEach $Global:pester_temp_ScriptPaths.Keys {
        Write-Host ('[_FunctionCoverage.tests] Checking files in {0} ({1})' -f $_, $Global:pester_temp_ScriptPaths[$_]) -ForegroundColor Cyan
        Write-Host ('[_FunctionCoverage.tests] ....Found {0} files in {1}' -f $Global:pester_temp_ScriptFiles[$_].Count, $_) -ForegroundColor Cyan
        $Global:pester_temp_TestCounter.TestatableFiles += $Global:pester_temp_ScriptFiles[$_].Count
        It "Should have corresponding tests for all scripts in the folder '$_'" -ForEach $Global:pester_temp_ScriptFiles[$_] {
            $t_scriptFile = $_
            $t_testScript = ((Split-Path -Leaf $t_scriptFile) -replace '\.ps1$', '.Tests.ps1')
            $TestFilePath = (Find-FileInTree -FileName $t_testScript -RootPath (Split-Path -Parent $t_scriptFile) -ReturnStringIfNull)
            if (Test-Path -Path $TestFilePath -PathType Leaf) {
                $Global:pester_temp_TestCounter.TestFilesFound += 1
            }
            else {
                Write-Host ('[_FunctionCoverage.tests]  Test not found for script file, {0}' -f $t_scriptFile) -ForegroundColor Yellow
            }
            (Test-Path -Path $TestFilePath -PathType Leaf) | Should-BeTested -Because "Test file '$t_testScript' for script '$t_scriptFile' should exist"
        }
    }
}

Describe -Tag 'TestCoverage' "Validate Function Coverage" {
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
