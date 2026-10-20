[CmdletBinding()]
param(
    [string]$ModuleRoot,
    [ValidateSet('Module', 'Test')]
    [string]$FileTypeCheck = 'Module'
)
$erroractionpreference = 'Stop'

if (-not $env:GITHUB_ACTION) {
    Write-Warning "Running outside of GitHub Actions."
    $ModuleRoot = (Join-Path $PSScriptRoot '../../PowerShell/UtilsModule' -Resolve)
}

Write-Host "Starting validation of PowerShell $FileTypeCheck scripts in $ModuleRoot..."

$files = @()

switch ($FileTypeCheck) {
    'Module' {
        $files = (Get-ChildItem -Path $ModuleRoot -Recurse -File -Include *.ps1, *.psm1, *.psd1 | Where-Object { $_.Name.Trim().ToLower().EndsWith('.tests.ps1') -eq $false } )
    }
    'Test' {
        $files = (Get-ChildItem -Path $ModuleRoot -Recurse -File -Include *.tests.ps1)
    }
}


$failSteps = @{
    SyntaxCheck    = $false
    ScriptAnalyzer = $false
}
if ($files.Count -eq 0) {
    Write-Host "No PowerShell $FileTypeCheck scripts found in $ModuleRoot"
    exit 0
}

# Syntax check using the PowerShell 7 parser
foreach ($file in $files) {
    Write-Host "--- Checking $($file.FullName) ---"
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    foreach ($e in $errors) {
        $failSteps['SyntaxCheck'] = $true
        Write-Host "::error file=$($file.FullName),line=$($e.Extent.StartLineNumber),col=$($e.Extent.StartColumnNumber)::$($e.Message)"
    }
}
if ($failSteps['SyntaxCheck']) {
    Write-Warning "Syntax check failed for one or more PowerShell $FileTypeCheck scripts."
}
else {
    Write-Host "Syntax check passed for all PowerShell $FileTypeCheck scripts."
}

if ($FileTypeCheck -eq 'Module') {
    Test-ModuleManifest -Path (Join-Path $ModuleRoot 'UtilsModule.psd1') | Format-Table -AutoSize
}

Write-Host "Starting PowerShell 7 syntax compatibility + error-level analyzer rules..."
$settings = @{
    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('7.0')
        }
    }
}
$results = @(
    Invoke-ScriptAnalyzer -Path $ModuleRoot -Recurse -Settings $settings
    Invoke-ScriptAnalyzer -Path $ModuleRoot -Recurse -Severity Error
) | Sort-Object ScriptPath, Line, RuleName -Unique

$prevFile = $null

foreach ($r in $results) {
    if ($prevFile -ne $r.ScriptPath) {
        $prevFile = $r.ScriptPath
        Write-Host "--- Analyzing $($r.ScriptPath) ---"
    }
    $level = if ($r.Severity -eq 'Error' -or $r.RuleName -eq 'PSUseCompatibleSyntax') { 'error' } else { 'warning' }
    if ($level -eq 'error') { $failSteps['ScriptAnalyzer'] = $true }
    Write-Host "::$level file=$($r.ScriptPath),line=$($r.Line),col=$($r.Column)::[$($r.RuleName)] $($r.Message)"
}

if ($failSteps['SyntaxCheck'] -or $failSteps['ScriptAnalyzer']) {
    throw "PowerShell 7 validation failed."
}
else {
    Write-Host "Validated $($files.Count) files - no PowerShell 7 issues found."
}
Write-Host "PowerShell 7 $FileTypeCheck analysis completed."