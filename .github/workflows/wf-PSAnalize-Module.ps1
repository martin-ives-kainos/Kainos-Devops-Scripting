[CmdletBinding()]
param(
    [string]$ModuleRoot,
    [string[]]$ExcludeFolders = @('bin', 'obj', '.temp')
)
$erroractionpreference = 'Stop'

if (-not $env:GITHUB_ACTION) {
    Write-Warning "Running outside of GitHub Actions."
    $ModuleRoot = (Join-Path $PSScriptRoot '../../PowerShell/UtilsModule' -Resolve)

    $pssaModule = Get-Module PSScriptAnalyzer
    if (-not $pssaModule) {
        Write-Warning "PSScriptAnalyzer module is not loaded. Find if available."
        $pssaModule = Get-Module PSScriptAnalyzer -ListAvailable
        if ($pssaModule) {
            Write-Host "PSScriptAnalyzer module found. Importing..."
            Import-Module PSScriptAnalyzer
        }
        else {
            Write-Warning "PSScriptAnalyzer module not found."
        }
    }

    $logFile = Join-Path $ModuleRoot ".temp" #'PSAnalysis.log'
    if (-not (Test-Path $logFile -PathType Container)) {
        New-Item -Path $logFile -ItemType Directory -Force | Out-Null
    }
    $logFile = (Join-Path $logFile '_PSAnalysis.log')
}

Write-Host "Module root: $ModuleRoot - Find first manifest file..."

$privateData = @{
    ScriptScopes  = @('classes', 'private', 'public', 'internal')
    TestFolders   = @('tests')
    ModuleName    = $null
    ModuleVersion = $null
    ModulePath    = $null
    ManifestFile  = $null
}
foreach ($manifestFile in (Get-ChildItem -Path $ModuleRoot -Recurse -File -Include *.psd1)) {
    if ($manifestFile) {
        $t_Manifest = Import-PowerShellDataFile -Path (Resolve-Path -LiteralPath $manifestFile -ErrorAction SilentlyContinue)
        if (-not $t_Manifest) {
            continue
        }
        if ($t_Manifest.Keys -notcontains 'PrivateData') {
            continue
        }
        $privateData.ModuleName = ($t_Manifest.RootModule -replace '\.psm1$', '')
        $privateData.ModuleVersion = $t_Manifest.ModuleVersion
        $privateData.ModulePath = $manifestFile.DirectoryName
        $privateData.ManifestFile = $manifestFile.FullName
        foreach ($pdKey in $t_Manifest.PrivateData.Keys) {
            if ($privateData.Keys -notcontains $pdKey) {
                $privateData[$pdKey] = $t_Manifest.PrivateData[$pdKey]
            }
            else {
                $privateData[$pdKey] = $t_Manifest.PrivateData[$pdKey]
            }
        }
        break
    }
}

Write-Host "Starting validation of PowerShell scripts in $ModuleRoot..."

$pspasyntexfiles = @()

$modscriptFolders = @{
    Scoped = @()
    Test   = @()
}

foreach ($scope in ($privateData.ScriptScopes + $privateData.TestFolders)) {
    $scriptsPath = Join-Path $ModuleRoot $scope
    if (-not (Test-Path $scriptsPath -PathType Container)) {
        continue
    }
    Write-Host "Processing scope: $scope"
    foreach ($modScript in (Get-ChildItem -Path $scriptsPath -Recurse -File -Include *.ps1, *.psm1, *.psd1)) {
        if ($ExcludeFolders -contains (Split-Path -Leaf $modScript.DirectoryName)) {
            continue
        }
        if ($pspasyntexfiles -notcontains $modScript) {
            $pspasyntexfiles += $modScript
        }
    }
}

$failSteps = @{
    SyntaxCheck    = $false
    ScriptAnalyzer = $false
}
if ($pspasyntexfiles.Count -eq 0) {
    Write-Host "No PowerShell scoped or test scripts found in $ModuleRoot"
    exit 0
}

# Syntax check using the PowerShell 7 parser
foreach ($file in ($pspasyntexfiles)) {
    Write-Host "--- Checking $($file.FullName) ---"
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    foreach ($e in $errors) {
        $failSteps['SyntaxCheck'] = $true
        Write-Host "::error file=$($file.FullName),line=$($e.Extent.StartLineNumber),col=$($e.Extent.StartColumnNumber)::$($e.Message)"
    }
}
if ($failSteps['SyntaxCheck']) {
    Write-Warning "Syntax check failed for one or more PowerShell scripts."
}
else {
    Write-Host "Syntax check passed for all PowerShell scripts."
}

if (Test-Path $privateData.ManifestFile -PathType Leaf) {
    Test-ModuleManifest -Path $privateData.ManifestFile | Format-Table -AutoSize
}

if (-not $env:GITHUB_ACTION) {
    Start-Transcript -Path $logFile -Force
}

# TODO: Add handling for test script files as well in the syntax check loop
Write-Host "Starting PowerShell 7 syntax compatibility + error-level analyzer rules..."
$pssasettings = @{
    Scoped = @{
        Rules = @{
            PSUseCompatibleSyntax = @{
                Enable         = $true
                TargetVersions = @('7.0')
            }
        }
    }
    Test    = @{
        Rules        = @{
            PSUseCompatibleSyntax = @{
                Enable         = $true
                TargetVersions = @('7.0')
            }
        }
        ExcludeRules = @(
            'PSAvoidGlobalVars',
            'PSAvoidUsingWriteHost',
            'PSUseShouldProcessForStateChangingFunctions',
            'PSReviewUnusedParameter',
            'PSUseDeclaredVarsMoreThanAssignments'
        )
    }
}

foreach ($fileType in $pssasettings.Keys) {
    $pssaFolders = @()

    Write-Host "Processing $fileType settings..."
    switch ($fileType) {
        'Scoped' {
            $privateData.ScriptScopes | ForEach-Object {
                try {
                    $pssaFolders += (Join-Path $ModuleRoot $_ -Resolve)
                }
                catch {
                    Write-Warning "Failed to process script scope: $_"
                }
            }
        }
        'Test' {
            $privateData.TestFolders | ForEach-Object {
                try {
                    $pssaFolders += (Join-Path $ModuleRoot $_ -Resolve)
                }
                catch {
                    Write-Warning "Failed to process test folder: $_"
                }
            }
        }
        default {
            # Handle other file types if needed
            Write-Warning "Unhandled file type: $fileType"
            continue
        }
    }

    foreach ($folder in $pssaFolders) {
        if ($ExcludeFolders -contains (Split-Path $folder -Leaf)) {
            Write-Warning "Skipping excluded folder: $folder"
            continue
        }
        Write-Host "===Analyzing folder: $folder==="
        $results = @(
            Invoke-ScriptAnalyzer -Path $folder -Recurse -Settings $pssasettings[$fileType]
            Invoke-ScriptAnalyzer -Path $folder -Recurse -Severity Error
        ) | Sort-Object ScriptPath, Line, RuleName -Unique

        $prevFile = $null

        foreach ($r in $results) {
            if ($prevFile -ne $r.ScriptPath) {
                $prevFile = $r.ScriptPath
                Write-Host "   --- Analyzing $($r.ScriptPath) ---"
            }
            $level = if ($r.Severity -eq 'Error' -or $r.RuleName -eq 'PSUseCompatibleSyntax') { 'error' } else { 'warning' }
            if ($level -eq 'error') { $failSteps['ScriptAnalyzer'] = $true }
            Write-Host "::$level file=$($r.ScriptPath),line=$($r.Line),col=$($r.Column)::[$($r.RuleName)] $($r.Message)"
        }
    }
}

if (-not $env:GITHUB_ACTION) {
    Stop-Transcript
    Write-Host "Transcript saved to $logFile"
}

if ($failSteps['SyntaxCheck'] -or $failSteps['ScriptAnalyzer']) {
    throw "PowerShell 7 validation failed."
}
else {
    Write-Host "Validated $($pspasyntexfiles.Count) files - no PowerShell 7 issues found."
}
Write-Host "PowerShell 7 analysis completed."