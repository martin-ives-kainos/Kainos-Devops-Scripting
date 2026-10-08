$ErrorActionPreference = "Stop"

# Set up the testable files to run with Pester

$moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition


$result = Invoke-Pester -Path "$moduleRoot\*" -PassThru -TagFilter 'TestCoverage'; $result.Failed | Format-List * -Force
