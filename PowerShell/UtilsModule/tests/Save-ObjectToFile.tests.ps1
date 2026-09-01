$ErrorActionPreference = 'Stop'
BeforeAll {

    # Source - https://stackoverflow.com/a/57768897
    # Posted by mclayton
    # Retrieved 2026-08-21, License - CC BY-SA 4.0

<#     $pesterModules = @( Get-Module -Name "Pester" -ErrorAction "SilentlyContinue" )
    if ( ($null -eq $pesterModules) -or ($pesterModules.Length -eq 0) ) {
        throw "no pester module loaded!"
    }
    if ( $pesterModules.Length -gt 1 ) {
        throw "multiple pester modules loaded!"
    }
    if ( $pesterModules[0].Version -ne ([version] "4.8.0") ) {
        throw "unsupported pester version '$($pesterModules[0].Version)'"
    }
 #>

    $scriptPath = (Join-Path (Split-Path -Parent $PSCommandPath) "..\public" -Resolve)
    $scriptName = ((Split-Path -Leaf $PSCommandPath) -replace '\.tests\.', '.')
    . (Join-Path $scriptPath $scriptName -Resolve)

    . (Join-Path (Split-Path -Parent  $PSCommandPath) "PesterHelperModule.ps1" -Resolve)
}
Describe "Passed Parameter Validation" -Tag "Unit" {
    BeforeAll {
        $ErrMsg = @{
            "NullOrEmpty" = "Cannot validate argument on parameter '{0}'. The argument is null or empty. Provide an argument that is not null or empty, and then try the command again."
        }
        New-Item "TestDrive:\_SavedObject" -ItemType Directory
    }
    Context "Testing <Name> parameter Validation" -Tag Unit -ForEach @(
        @{
            Name       = "Path"
            TestParams = @{
            }
            Expected   = ($ErrMsg.NullOrEmpty -f $Name)
        }
        @{
            Name       = "InputObject"
            TestParams = @{
                "Path" = "TestDrive:\_InvalidPath\Test.json"
            }
            Expected   = ($ErrMsg.NullOrEmpty -f $Name)
        }
        @{
            Name       = "InputObject"
            TestParams = @{
                "Path"        = "TestDrive:\_InvalidPath\Test.json"
                "InputObject" = @{"Test1" = "xxxxxx" }
            }
            Expected   = "Parent path in TestDrive:\_InvalidPath\Test.json not found"
        }
    ) {
        if (!$TestParams.ContainsKey($Name)) {
            It "[$($Name)] Null value Passed" {
                $tParams = $TestParams + @{ $Name = $null }
                { Save-ObjectToFile @tParams } | Should -Throw $Expected
            }
            It "[$($Name)] Empty value Passed" {
                $tParams = $TestParams + @{ $Name = [string]::Empty }
                { Save-ObjectToFile @tParams } | Should -Throw $Expected
            }
        }
        else {
            It "[$($Name)] Test error with $($TestParams[$Name])" {
                { Save-ObjectToFile @TestParams } | Should -Throw $Expected
            }
        }
    }
}

Describe "Function Save-ObjectToFile" -Tag Unit {
    BeforeAll {
        $tObject = (New-TestTempObject 5)
        $testFile = "TestDrive:\Test.json"
        Save-ObjectToFile -Path $testFile -InputObject $tObject
        $rObject = (ConvertFrom-JsonFile -Path $testFile )
    }

    It "Check $testFile has been created" {
        (Test-Path $testFile -PathType Leaf) | Should -BeTrue
    }
    It "Test object is not null" {
        $tObject | Should -Not -BeNullOrEmpty
    }
    It "Read object is not null" {
        $rObject | Should -Not -BeNullOrEmpty
    }
    It "Property count matched" {
        ($rObject | Get-Member -MemberType NoteProperty).Count | Should -BeExactly ($tObject | Get-Member -MemberType NoteProperty).Count
    }
}