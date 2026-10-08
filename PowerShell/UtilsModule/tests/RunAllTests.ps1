$ErrorActionPreference = "Stop"

# Set up the testable files to run with Pester

$moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

$excludedFilter = @(
    (Split-Path -Parent $PSCommandPath)
)

$allTestFiles = Get-ChildItem -Path $moduleRoot -Recurse -Filter *.tests.ps1 -Exclude $excludedFilter

foreach ($testFile in $allTestFiles) {
    $result = Invoke-Pester -Path $testFile.FullName -PassThru
    $result.Failed | Format-List * -Force
}

$result = Invoke-Pester -Path "$moduleRoot\Get-UserShellPath.tests.ps1" -PassThru; $result.Failed | Format-List * -Force
