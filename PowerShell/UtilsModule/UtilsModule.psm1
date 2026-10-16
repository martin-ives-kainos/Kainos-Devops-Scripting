$ErrorActionPreference = 'Stop'

<#
    Utility module for setting up module dependencies, building modules, and managing module paths.
    Provides the SetupModuleDependencies class with methods for:
        - Preloading scripts
        - Building module functions
        - Checking and installing required modules
        - Updating module paths
 #>
$ModuleFilePath = $PSCommandPath

# $ModuleName = [System.IO.Path]::GetFileNameWithoutExtension($ModuleFilePath)

$ModuleManifest = Import-PowerShellDataFile -Path (Resolve-Path -LiteralPath ($ModuleFilePath -replace '\.psm1$', '.psd1') -ErrorAction Stop)

$privateData = $ModuleManifest.PrivateData

if ($privateData.Keys -notcontains 'ScriptScopes') {
    $privateData['ScriptScopes'] = @('classes', 'private', 'public')
}


$ModuleManifest | Add-Member -MemberType ScriptMethod -Name PrivateDataValue -Value {
    param([string]$key)
    if (-not $this.PrivateData.ContainsKey($key)) {
        throw "Key '$key' not found in PrivateData."
    }
    return $this.PrivateData[$key]
}

foreach ($scope in $ModuleManifest.PrivateDataValue('ScriptScopes') | Sort-Object) {
    try {
        $scriptFiles = Get-ChildItem (Join-Path $PSScriptRoot $scope -Resolve) -Recurse -Filter '*.ps1'
        foreach ($scriptFile in $scriptFiles) {
            . ($scriptFile.FullName)
        }

        if ($scope -like 'public*') {
            Export-ModuleMember -Function ($scriptFiles | Select-Object -ExpandProperty BaseName)
        }
    }
    catch {
        Write-Warning "Error accessing script scope '$scope': $($_.Exception.Message)"
    }
}

$envPaths = (Get-PathEnvVar -Name 'PSModulePath')

foreach ($pathSuffix in $ModuleManifest.PrivateDataValue('UseEnvironmentPaths')) {
    $path = (Join-Path $env:USERPROFILE $pathSuffix)
    if ($envPaths -contains $path) {
        Write-Host "Path '$path' already exists in PSModulePath." -ForegroundColor Green
        continue
    }
    Write-Host "Adding '$path' to PSModulePath." -ForegroundColor Yellow
    [System.Environment]::SetEnvironmentVariable('PSModulePath', $envPaths -join ';' + ';' + $path, 'User')
}

$allModulesInstalled = $true

foreach ($reqdModuleName in $ModuleManifest.PrivateDataValue('RequiredModules')) {
    if ($null -ne (Get-Module -ListAvailable -Name $reqdModuleName -ErrorAction SilentlyContinue)) {
        Write-Host "Module '$reqdModuleName' is already installed." -ForegroundColor Green
        continue
    }
    Write-Warning "Try to install '$reqdModuleName' for current user."
    $modOk = (Install-ReqdUserModule -Name $reqdModuleName)
    if (-not $modOk) {
        Write-Warning "Failed to install required module '$reqdModuleName'."
        $allModulesInstalled = $false
    }
}
if (-not $allModulesInstalled) {
    throw "One or more required modules failed to install."
}

