[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string[]]$reqdModules = @("PSIni"),
    [bool]$FixModulePath = $false
)
$ErrorActionPreference = "Stop"

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

    $localModPath = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules"
    if (-not (Test-Path $localModPath -PathType Container)) {
        Write-Host "Creating local module path: $localModPath"
        New-Item -ItemType Directory -Path $localModPath -Force | Out-Null
    }
    $newPsModPath = ($localModPath + ";" + ($fixPsModPath -join ';')).Trim(';')
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
