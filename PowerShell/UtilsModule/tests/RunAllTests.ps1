$ErrorActionPreference = "Stop"

# Set up the testable files to run with Pester

class TestRunSettings {
    [string]$SettingsFilePath
    [hashtable]$ManifestData
    [bool]$IsDirty = $false
    [string]$TestResultOutputPath
    hidden [hashtable]$_settings = @{
        RequiredEnvVars = @{'PESTER_FILTER_TAGS' = @{
                'Description'     = 'Tags to filter Pester tests by'
                'Required'        = $true
                'Default'         = 'Unit'
                'ManifestDataKey' = 'TestTags'
            }
        }
    }
    TestRunSettings([string]$Path, [string]$ManifestFile) {
        if (Test-Path $ManifestFile -PathType Leaf) {
            $this.ManifestData = (Get-ModuleManifestData -Path $ManifestFile)
        }
        else {
            throw "Manifest file not found: $ManifestFile"
        }
        $this.SettingsFilePath = $Path
        if (-not (Test-Path -Path $this.SettingsFilePath -PathType Leaf)) {
            $this.Save()
        }
        $this.Load()
    }

    [void]ClearTestResults() {
        foreach ($xmlResults in $this.GetTestResultXmlFiles()) {
            Write-Host "Removing test result XML: $($xmlResults.FullName)"
            Remove-Item -Path $xmlResults.FullName -Force
        }
    }

    [void]ExportTestResults() {
        foreach ($xmlResults in $this.GetTestResultXmlFiles()) {
            Write-Host "Found test result XML: $($xmlResults.FullName)"
            New-PesterExcelReport -XmlPath $xmlResults.FullName -OutputPath ($xmlResults.FullName -replace '\.xml$', '.xlsx') -Force
        }
    }

    [System.IO.FileInfo[]]GetTestResultXmlFiles() {
        return Get-ChildItem -Path $this.TestResultOutputPath -Filter "*.xml" -Recurse
    }



    [void]Load() {
        $this._settings = Get-Content -Path $this.SettingsFilePath -Raw | ConvertFrom-Json -AsHashtable -Depth 99
        if ($this._settings.Keys -notcontains 'PesterConfig') {
            $this.IsDirty = $true
            $this._settings['PesterConfig'] = @{
                Output_Verbosity        = 'Detailed'
                Should_ErrorAction      = 'Stop'
                Run_PassThru            = $true
                Run_Throw               = $true
                TestResult_Enabled      = $true
                TestResult_OutputFormat = 'NUnitXml'
            }
        }
        if ($this._settings.Keys -notcontains 'RunTestStages') {
            $this.IsDirty = $true
            $this._settings['RunTestStages'] = @{
                ModuleFunctions = $true
                TestCoverage    = $true
            }
        }
        $this.Save()
    }

    [bool]ManifestKeyExits([string]$key) {
        return $this.ManifestData.ContainsKey($key)
    }

    [object]ManifestValue([string]$key) {
        if ($this.ManifestData.ContainsKey($key)) {
            return $this.ManifestData[$key]
        }
        throw "Manifest key not found: $key"
    }

    [object]PesterConfiguration([string[]]$RunPath, [string]$ResultName) {
 		if (!$ResultName.ToLower().EndsWith('.xml')) {
			$ResultName += '.xml'
		}
        $testConfig = New-PesterConfiguration
        $testConfig.Output.Verbosity = $this._settings['PesterConfig'].Output_Verbosity
        $testConfig.Should.ErrorAction = $this._settings['PesterConfig'].Should_ErrorAction
        $testConfig.Run.PassThru = $this._settings['PesterConfig'].Run_PassThru
        $testConfig.Run.Throw = $this._settings['PesterConfig'].Run_Throw
        $testConfig.TestResult.Enabled = $this._settings['PesterConfig'].TestResult_Enabled
        $testConfig.TestResult.OutputFormat = $this._settings['PesterConfig'].TestResult_OutputFormat
        $testConfig.Filter.Tag = [Environment]::GetEnvironmentVariable('PesterFilterTags', [EnvironmentVariableTarget]::Process)
        $testConfig.Run.Path = $RunPath
        $testConfig.TestResult.OutputPath = (Join-Path $this.TestResultOutputPath $ResultName)
        return $testConfig
    }
    [void]Save() {
        if ($this.IsDirty) {
            $this._settings | ConvertTo-Json -Depth 99 | Set-Content -Path $this.SettingsFilePath -Force
            $this.IsDirty = $false
        }
    }

    [void]ValidateRequiredEnvVars() {
        $missingEnvVars = @()
        foreach ($envVar in $this._settings.RequiredEnvVars.Keys) {
            $envSetting = $this._settings.RequiredEnvVars[$envVar]
            $envValue = [Environment]::GetEnvironmentVariable(($envVar), [EnvironmentVariableTarget]::Process)
            if ([string]::IsNullOrEmpty($envValue)) {
                if ($envSetting.Required) {
                    Write-Warning "Required environment variable not set: $envVar"
                    $missingEnvVars += $envVar
                    continue
                }
                if ([string]::IsNullOrEmpty($envValue)) {
                    [Environment]::SetEnvironmentVariable($envVar, $envSetting.Default, [EnvironmentVariableTarget]::Process)
                    $envValue = $envSetting.Default
                }
            }
            if ($envSetting.ManifestDataKey -and $this.ManifestKeyExits($envSetting.ManifestDataKey)) {

                if ($this.ManifestValue($envSetting.ManifestDataKey) -notcontains $envValue) {
                    Write-Warning ("Env var: {0} '{1}' does not match manifest key '{2}' '{3}'" -f $envVar, $envValue, $envSetting.ManifestDataKey, $this.ManifestValue($envSetting.ManifestDataKey))
                    $missingEnvVars += $envVar
                    continue
                }
            }
        }
        if ($missingEnvVars.Count -gt 0) {
            throw "Missing required environment variables: $($missingEnvVars -join ', ')"
        }
    }
}

$moduleRoot = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ChildPath ".." -Resolve)

# TODO: Move the PesterHelperModule to it's own repository/product module
. (Get-ChildItem $moduleRoot -Recurse -File "PesterHelperModule.ps1" | Select-Object -ExpandProperty FullName | Select-Object -First 1)
if ($null -eq (Get-Command -Name 'New-TestIsPipeline' -ErrorAction SilentlyContinue -Module 'PesterHelper')) {
    throw "Failed to import PesterHelperModule or 'New-TestIsPipeline' command not found."
}

Import-Module (Join-Path $moduleRoot "UtilsModule.psd1")

if (-not (New-TestIsPipeline)) {
    $env:PESTER_OUTPUT_ROOT = Join-Path -Path $moduleRoot -ChildPath ".temp"
    $env:PESTER_FILTER_TAGS = 'Unit'
}

$testRunSettings = [TestRunSettings]::new(($PSCommandPath -replace '\.ps1$', '.runsettings.json'), (Join-Path $moduleRoot "UtilsModule.psd1"))

try {
    $testRunSettings.ValidateRequiredEnvVars()
}
catch {
    Write-Error $_.Exception.Message
}

$testRunSettings.TestResultOutputPath = (Join-Path -Path $env:PESTER_OUTPUT_ROOT -ChildPath "TestResults")
$testRunPath = (Get-ChildItem (Join-Path $moduleRoot 'tests' -Resolve) -Recurse -File "*.tests.ps1" -Exclude "_*.tests.ps1" | Select-Object -ExpandProperty FullName)
$testConfig = $testRunSettings.PesterConfiguration($testRunPath, "ModuleFunction")
$testRunSettings.ClearTestResults()

try {
    if ($testRunSettings._settings['RunTestStages'].ModuleFunctions) {
        $result = Invoke-Pester -Configuration $testConfig
        $result
    }
    else {
        Write-Host "Skipping ModuleFunctions tests as per RunTestStages configuration."
    }
}
catch {
    $_ | Format-List * -Force
}
finally {
    try {
        if ($testRunSettings._settings['RunTestStages'].TestCoverage) {
            $testConfig.Filter.Tag = 'TestCoverage'
            $testConfig.TestResult.OutputPath = (Join-Path $testRunSettings.TestResultOutputPath "ModuleFunctionTestCoverage.xml")
            $testConfig.Run.Path = (Get-ChildItem $moduleRoot -Recurse -File "_*.tests.ps1" | Select-Object -ExpandProperty FullName)

            Invoke-Pester -Configuration $testConfig
        }
        else {
            Write-Host "Skipping TestCoverage tests as per RunTestStages configuration."
        }
    }
    catch {
        $_ | Format-List * -Force
    }
}
$testRunSettings.ExportTestResults()