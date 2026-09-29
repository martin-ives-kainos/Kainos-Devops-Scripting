[cmdletbinding()]
param(
    [hashtable]$ModulesList = @{
        "PSWriteOffice"   = "0"
        "powershell-yaml" = "0"
        "PSDocs"          = "0"
    }
)

$errorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot "UtilsModule\UtilsModule.psd1" -Resolve)

# Where are our userdefined powershell modules located?
$dupPath = Get-DuplicatedUserEnvPaths -VariableName "PSModulePath"

if ($dupPath.Count -gt 0) {
    $dupPath | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    throw "Duplicated PSModulePath entries found"
}

# determine user specific module paths
$userPaths = [Environment]::GetEnvironmentVariable("PSModulePath", [System.EnvironmentVariableTarget]::User) -split ';'

$modulePaths = @{}

foreach ($path in $userPaths) {
    Write-Host "Checking path: $path" -ForegroundColor Cyan
    if (-not (Test-Path $path -PathType Container)) {
        New-Item -ItemType Directory -Path $path | Out-Null
        Write-Host "Created path: $path" -ForegroundColor Green
    }
    else {
        Write-Host "Path already exists: $path" -ForegroundColor Gray
    }
    if ($path.ToLower().Contains('\windowspowershell\') -and !$modulePaths.ContainsKey('v5')) {
        Write-Host "Found Windows PowerShell path: $path" -ForegroundColor Magenta
        $modulePaths['v5'] = $path
    }
    if ($path.ToLower().Contains('\powershell\') -and !$modulePaths.ContainsKey('v7')) {
        Write-Host "Found PowerShell path: $path" -ForegroundColor Magenta
        $modulePaths['v7'] = $path
    }
}

if (-not $modulePaths.ContainsKey('v5')) {
    throw "Windows PowerShell path not found"
}
if (-not $modulePaths.ContainsKey('v7')) {
    throw "PowerShell path not found"
}

$psRepo = Get-PSRepository -Name "PSGallery"
if (-not $psRepo) {
    throw "PSGallery repository not found"
}
if ($psRepo.InstallationPolicy -ne 'Trusted') {
    Write-Warning "PSGallery repository is not trusted"
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
}

foreach ($modName in $ModulesList.Keys) {
    Write-Host "Processing module: $modName" -ForegroundColor Cyan
    $installedModule = Get-Module -Name $modName -ListAvailable
    switch ($installedModule.count) {
        0 {
            Write-Host "Module $modName is not installed" -ForegroundColor Red
        }
        1 {
            Write-Host "Module $modName (v$($installedModule.Version)) is installed" -ForegroundColor Green
        }
        Default {
            Write-Host "Multiple versions ($($installedModule.Count)) of module $modName are installed" -ForegroundColor Yellow
        }
    }
    <#     $iVer = $ModulesList | Where-Object { $_.Name -eq $modName }
    if ($null -ne $iver) {
        Write-Host "Found module version: $($iVer[$modName])" -ForegroundColor Green
    }
 #>
}
