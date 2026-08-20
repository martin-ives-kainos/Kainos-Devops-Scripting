[CmdletBinding()]
param (
#    [Parameter(Mandatory = $false)]
#    [string[]]$reqdModules = @("PSIni"),
#    [bool]$FixModulePath = $false
)
$ErrorActionPreference = "Stop"

Import-Module -Name (Join-Path $PsScriptRoot "UtilsModule" -Resolve) -ErrorAction Stop

$defaultSettingsFile = ($PSCommandPath -replace "\.ps1$", ".settings.json")

if (-not (Test-Path $defaultSettingsFile -PathType Leaf)) {
    Write-Host "Default settings file not found: creating $defaultSettingsFile"
    $defaultSettings = @{
        "reqdModules"      = @(
            "PSIni"
            "Pester"
        )
        "LocalAppFolder"    = 'utils'
        "FixModulePath"    = $FixModulePath
        "LocalModulePaths" = @(
            "Documents\WindowsPowerShell\Modules"
            "Documents\PowerShell\Modules"
        )
    }
    $defaultSettings | ConvertTo-Json -Depth 99 | Out-File -Append $defaultSettingsFile
}
$defaultSettings = Get-Content -Path $defaultSettingsFile -Raw | ConvertFrom-Json
$userSettingsFile = Join-Path $env:APPDATA ((Split-Path $PSCommandPath -Leaf) -replace "\.ps1$", ".user.settings.json")

if (-not (Test-Path $userSettingsFile -PathType Leaf)) {
    Write-Host "User settings file not found: creating $userSettingsFile"
    $defaultSettings | ConvertTo-Json -Depth 99 | Out-File -Append $userSettingsFile
}
$userSettings = Get-Content -Path $userSettingsFile -Raw | ConvertFrom-Json

$utilsAppPath = Join-Path $HOME "utils"

if (-not (Test-Path $utilsAppPath -PathType Container)) {
    Write-Host "Utils directory not found: $utilsAppPath"
    New-Item -ItemType Directory -Path $utilsAppPath -Force | Out-Null
}

$pwshPath = Split-Path (Find-PwshInstallation) -Parent
if (-not $pwshPath) {
    Write-Host "PowerShell 7 executable not found. Please install PowerShell 7 and ensure it is in your PATH."
    exit 1
}

$unblockLog = Join-Path $pwshPath "unblock.log"
if (-not (Test-Path $unblockLog -PathType Leaf)) {
    Write-Host "Unblocking PowerShell 7 executable: $pwshPath"
    Get-ChildItem $pwshPath -Recurse | Unblock-File
    New-Item -ItemType File -Path $unblockLog -Force -Value "Unblocked on $(Get-Date)" | Out-Null
}

# Ensure that the PowerShell 7 directory is in the user PATH environment variable
Update-UserEnvPath -VariableName "Path" -NewPath $pwshPath

$PsVersion = $PSVersionTable.PSVersion
if ($PsVersion.Major -lt 7) {
    Write-Host "PowerShell version 7 or higher is required. Current version: $PsVersion"

    # We already found the pwsh executable, so we can add its directory to the user PATH if it's not already there.
    # $pwshExecutable = Get-Command pwsh -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
    # Check for PowerShell 7 installation
    # $pwshExecutable = Get-ChildItem -Path $utilsAppPath -Filter "pwsh.exe" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1


    <#  TODO: See the utility function Update-UserEnvPath in UtilsModule/public/Update-UserEnvPath.ps1 for a more robust implementation of updating the user environment variable.
    $allPaths = [environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User).Trim(';') -split ';'
    if ($allPaths -notcontains $pwshExecutable.DirectoryName) {
        Write-Host "Adding PowerShell 7 directory to PATH: $($pwshExecutable.DirectoryName)"
        $newPath = $pwshExecutable.DirectoryName + ";" + [environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
        [Environment]::SetEnvironmentVariable("PATH", $newPath, [System.EnvironmentVariableTarget]::User)
    } #>
}

Import-Module -Name (Join-Path $PsScriptRoot "UtilsModule") -ErrorAction Stop

function Fix-PSModulePath {

    $psModPath = [Environment]::GetEnvironmentVariable("PSModulePath", [System.EnvironmentVariableTarget]::User) -split ';'

    $fixPsModPath = @()
    foreach ($path in $psModPath) {
        if ($path.StartsWith($HOME) -and $path.ToLower().Contains("modules")) {
            Write-Host "Removing conflicting module path from user environment variable: $path"
            continue
        }
        $fixPsModPath += $path
    }

    $localPaths = @(
        (Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules"),
        (Join-Path $env:USERPROFILE "Documents\PowerShell\Modules")
    )
    foreach ($localPath in $localPaths) {
        if (-not (Test-Path $localPath -PathType Container)) {
            Write-Host "Creating local module path: $localPath"
            New-Item -ItemType Directory -Path $localPath -Force | Out-Null
        }
    }
    $newPsModPath = (($localPaths -join ';').Trim(';') + ";" + ($fixPsModPath -join ';')).Trim(';')
    [Environment]::SetEnvironmentVariable("PSModulePath", $newPsModPath, [System.EnvironmentVariableTarget]::User)
}

# Fix if there is a conflicyting module path in the user environment variable`
if ($FixModulePath) {
    Write-Host "Fixing PSModulePath in user environment variable..."
    Fix-PSModulePath
}


# $env:PSModulePath = $env:PSModulePath -replace "C:\\Program Files\\PowerShell\\Modules", ""

$psGallery = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
if (-not $psGallery) {
    Write-Host "PSGallery repository not found. Registering..."
    Register-PSRepository -Name "PSGallery" -SourceLocation "https://www.powershellgallery.com/api/v2/" -InstallationPolicy Trusted
}
if (-not $psGallery.Trusted) {
    Write-Host "PSGallery repository is not trusted. Setting it to trusted..."
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted  
}

#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -ErrorAction SilentlyContinue

$psModPath = [Environment]::GetEnvironmentVariable("PSModulePath", [System.EnvironmentVariableTarget]::User) -split ';'

foreach ($module in $userSettings.reqdModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing required module: $module"
        Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber

    }
    else {
        Write-Host "Required module already installed: $module"
    }
}

<# Install-Module -Name PsIni -Scope CurrentUser -Force -AllowClobber
$installedModules = Get-InstalledModule -ErrorAction SilentlyContinue
$installedModules #>
