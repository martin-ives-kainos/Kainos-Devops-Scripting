$ErrorActionPreference = "Stop"

# Set up the testable files to run with Pester

$moduleRoot = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ChildPath ".." -Resolve)

Import-Module (Join-Path $moduleRoot "UtilsModule.psd1")

$isBuildPipeline = (-not [string]::IsNullOrEmpty($env:TF_BUILD))

if (-not $isBuildPipeline) {
    $env:BUILD_ARTIFACTSTAGINGDIRECTORY = Join-Path -Path $moduleRoot -ChildPath ".temp"
}
if (-not (Test-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY)) {
    New-Item -ItemType Directory -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY
}
$testResultOutputPath = (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "TestResults")

$testConfig = New-PesterConfiguration
$testConfig.Output.Verbosity = 'Detailed'
$testConfig.Should.ErrorAction = 'Stop'
$testConfig.Filter.Tag = 'Unit'
$testConfig.Run.Path = "$moduleRoot\*"
$testConfig.Run.ExcludePath = @("_*.tests.ps1")
$testConfig.Run.PassThru = $true
$testConfig.Run.Throw = $true
$testConfig.TestResult.Enabled = $true
$testConfig.TestResult.OutputFormat = 'NUnitXml'
$testConfig.TestResult.OutputPath = (Join-Path $testResultOutputPath "ModuleFunctions.xml")

if (-not $isBuildPipeline) {
    $runAllTests = Show-MessageBox -Message "Do you want to run all tests?" -Title "Run All Tests" -Buttons "YesNo" -Default "Yes"
}
else {
    $runAllTests = "Yes"
}

if ($runAllTests -eq "Yes") {
    try {
        $result = Invoke-Pester -Configuration $testConfig
        $result
    }
    catch {
        $_ | Format-List * -Force
    }
    finally {
        $testConfig.TestResult.OutputPath = (Join-Path $testResultOutputPath "ModuleFunctionTestCoverage.xml")
        $testConfig.Run.Path = @("_*.tests.ps1")
        $testConfig.Run.ExcludePath = $null

        Invoke-Pester -Configuration $testConfig
    }
} else {
    Write-Host "Skipping all tests." -ForegroundColor Yellow
}

$testXmlFiles = Get-ChildItem -Path $testResultOutputPath -Filter "*.xml" -Recurse
$testXmlFiles