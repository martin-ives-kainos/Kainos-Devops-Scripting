$ErrorActionPreference = "Stop"

# Set up the testable files to run with Pester

$moduleRoot = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ChildPath ".." -Resolve)

# TODO: Move the PesterHelperModule to it's own repository/product module
. (Get-ChildItem $moduleRoot -Recurse -File "PesterHelperModule.ps1" | Select-Object -ExpandProperty FullName | Select-Object -First 1)
if ($null -eq (Get-Command -Name 'New-TestIsPipeline' -ErrorAction SilentlyContinue -Module 'PesterHelper')) {
    throw "Failed to import PesterHelperModule or 'New-TestIsPipeline' command not found."
}

Import-Module (Join-Path $moduleRoot "UtilsModule.psd1")
$manifestData = (Get-ModuleManifestData -Path (Join-Path $moduleRoot "UtilsModule.psd1"))

$filterTags = @('Unit')

$isBuildPipeline = (-not [string]::IsNullOrEmpty($env:TF_BUILD))

if (-not $isBuildPipeline) {
    $env:BUILD_ARTIFACTSTAGINGDIRECTORY = Join-Path -Path $moduleRoot -ChildPath ".temp"
    if ($IsWindows) {
        $filterTags = (New-WpfSimpleListSelect -Title "Select Test Tags" -Items $manifestData.TestTags)
    }
}
if (-not (Test-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY)) {
    New-Item -ItemType Directory -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY
}
$testResultOutputPath = (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "TestResults")



$testConfig = New-PesterConfiguration
$testConfig.Output.Verbosity = 'Detailed'
$testConfig.Should.ErrorAction = 'Stop'
$testConfig.Filter.Tag = $filterTags
$testConfig.Run.Path = (Get-ChildItem (Join-Path $moduleRoot 'tests' -Resolve) -Recurse -File "*.tests.ps1" -Exclude "_*.tests.ps1" | Select-Object -ExpandProperty FullName)
$testConfig.Run.PassThru = $true
$testConfig.Run.Throw = $true
$testConfig.TestResult.Enabled = $true
$testConfig.TestResult.OutputFormat = 'NUnitXml'
$testConfig.TestResult.OutputPath = (Join-Path $testResultOutputPath "ModuleFunctions.xml")

if (-not $isBuildPipeline) {
    $runAllTests = Show-MessageBox -Message "Do you want to run $($filterTags -join ', ') tests?" -Title "Run $($filterTags -join ', ') Tests" -Buttons "YesNo" -Default "Yes"
}
else {
    $runAllTests = "Yes"
}

try {
    if ($runAllTests -eq "Yes") {
        $result = Invoke-Pester -Configuration $testConfig
        $result
    }
    else {
        Write-Host "Skipping all function tests." -ForegroundColor Yellow
    }
}
catch {
    $_ | Format-List * -Force
}
finally {
    if (-not $isBuildPipeline) {
        $runFTCoverage = Show-MessageBox -Message "Do you want to run Function Test Coverage?" -Title "Function Test Coverage" -Buttons "YesNo" -Default "Yes"
    }
    else {
        $runFTCoverage = "Yes"
    }

    if ($runFTCoverage -eq "Yes") {
        try {
            $testConfig.Filter.Tag = 'TestCoverage'
            $testConfig.TestResult.OutputPath = (Join-Path $testResultOutputPath "ModuleFunctionTestCoverage.xml")
            $testConfig.Run.Path = (Get-ChildItem $moduleRoot -Recurse -File "_*.tests.ps1" | Select-Object -ExpandProperty FullName)

            Invoke-Pester -Configuration $testConfig
        }
        catch {
            $_ | Format-List * -Force
        }
    }
    else {
        Write-Host "Skipping function test coverage." -ForegroundColor Yellow
    }
}

$testXmlFiles = Get-ChildItem -Path $testResultOutputPath -Filter "*.xml" -Recurse
foreach ($xmlResults in $testXmlFiles) {
    Write-Host "Found test result XML: $($xmlResults.FullName)"
    New-PesterExcelReport -XmlPath $xmlResults.FullName -OutputPath (Join-Path $testResultOutputPath (("{0}.xlsx" -f $xmlResults.BaseName))) -Force
}
