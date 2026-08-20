[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string[]]$reqdModules = @("PSIni"),
    [bool]$FixModulePath = $false
)
$ErrorActionPreference = "Stop"

$utilsAppPath = Join-Path $HOME "utils"

if (-not (Test-Path $utilsAppPath -PathType Container)) {
    Write-Host "Utils directory not found: $utilsAppPath"
    New-Item -ItemType Directory -Path $utilsAppPath -Force | Out-Null
}

$PsVersion = $PSVersionTable.PSVersion
if ($PsVersion.Major -lt 7) {
    Write-Host "PowerShell version 7 or higher is required. Current version: $PsVersion"

    # Check for PowerShell 7 installation
    $pwshExecutable = Get-ChildItem -Path $utilsAppPath -Filter "pwsh.exe" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (-not $pwshExecutable) {
        Write-Host "PowerShell 7 not found in utils directory: $utilsAppPath"
        exit 1
    }

    $allPaths = [environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User).Trim(';') -split ';'
    if ($allPaths -notcontains $pwshExecutable.DirectoryName) {
        Write-Host "Adding PowerShell 7 directory to PATH: $($pwshExecutable.DirectoryName)"
        $newPath = $pwshExecutable.DirectoryName + ";" + [environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
        [Environment]::SetEnvironmentVariable("PATH", $newPath, [System.EnvironmentVariableTarget]::User)
    }
}

Import-Module -Name (Join-Path $PsScriptRoot "UtilsModule") -ErrorAction Stop

Function Fix-PSModulePath {

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

Install-Module -Name PsIni -Scope CurrentUser -Force -AllowClobber
$installedModules = Get-InstalledModule -ErrorAction SilentlyContinue
$installedModules
