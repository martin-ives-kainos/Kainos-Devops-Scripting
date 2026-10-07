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
    SetUpGlobalTestCases -VarName 'pester_temp_RunDate' -VarValue (Get-Date)
    SetUpGlobalTestCases -VarName 'pester_temp_ModuleRootPath' -VarValue (Join-Path $PSScriptRoot '..' -Resolve)
    SetUpGlobalTestCases -VarName 'pester_temp_ScriptPaths' -VarValue (Get-ModuleTestableFolders -ModulePath $global:pester_temp_ModuleRootPath -SkipRoot)
    SetUpGlobalTestCases -VarName 'pester_temp_TestCounter' -VarValue @{TestatableFiles = 0; TestFilesFound = 0 }

    $tc_ScriptFiles = @{}
    foreach ($scriptPath in $Global:pester_temp_ScriptPaths.Keys) {
        $tc_ScriptFiles.Add($scriptPath, @())
        foreach ($scriptFile in Get-ModuleTestableScripts -ModulePath $Global:pester_temp_ScriptPaths[$scriptPath] -PathType "ScriptFolder" | Select-Object -ExpandProperty tcf_ScriptFile) {
            $tc_ScriptFiles[$scriptPath] += $scriptFile
        }
    }
    SetUpGlobalTestCases -VarName 'pester_temp_ScriptFiles' -VarValue $tc_ScriptFiles
}

AfterAll {
    CleanUpTemporaryGlobalVariables
}

Describe "Function coverage for UtilsModule" {
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
            $TestFile = (Find-FileInTree -FileName ((Split-Path -Leaf $t_scriptFile) -replace '\.ps1$', '.Tests.ps1') -RootPath (Split-Path -Parent $t_scriptFile))
            if (-not $TestFile) {
                Write-Host ('[_FunctionCoverage.tests]  Test not found for script file, {0}' -f $t_scriptFile) -ForegroundColor Yellow
                Set-ItResult -Inconclusive -Because "Manual check required for script file '$_'" -Verbose
            }
            else {
                Write-Host ('[_FunctionCoverage.tests] Check script files, {0}' -f $t_scriptFile) -ForegroundColor Blue
                (Test-Path -Path $TestFile -PathType Leaf) | Should -Be $true
                $Global:pester_temp_TestCounter.TestFilesFound += 1
            }
        }
    }
}

Describe "Validate Function Coverage" {
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
