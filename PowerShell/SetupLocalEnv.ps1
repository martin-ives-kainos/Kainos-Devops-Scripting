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
            "5;Documents\WindowsPowerShell\Modules"
            "7;Documents\PowerShell\Modules"
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

$utilsAppPath = Join-Path $HOME $userSettings.LocalAppFolder

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
}

# Clean up any duplicate entries in the user PSModulePath environment variable
$dupPath = Get-DuplicatedUserEnvPaths -VariableName "PSModulePath"
if ($dupPath.Count -gt 0) {
    Write-Host "Duplicate entries found in user PSModulePath: $($dupPath -join ', ')"
    $userPSModulePath = [Environment]::GetEnvironmentVariable("PSModulePath", [System.EnvironmentVariableTarget]::User) -split ';'
    $cleanedPaths = $userPSModulePath | Where-Object { $dupPath -notcontains $_ }
    [Environment]::SetEnvironmentVariable("PSModulePath", ($cleanedPaths -join ';'), [System.EnvironmentVariableTarget]::User)
    Write-Host "Cleaned up duplicate entries in user PSModulePath."
}

$userSettings | Add-Member -MemberType ScriptMethod -Name "GetVerModulePaths" -Value {
    $modulePaths = @()
    foreach ($path in $this.LocalModulePaths) {
        $newPath = New-Object PSObject -Property @{
            MajorVersion = ($path -split ';')[0]
            Path         = (Join-Path $HOME ($path -split ';')[1])
        }
        if (Test-Path $newPath.Path -PathType Container) {
            New-Item -ItemType Directory -Path $newPath.Path -Force | Out-Null
        }
        $modulePaths += $newPath
    }
    return $modulePaths
}

$verModPaths = $userSettings.GetVerModulePaths() | Sort-Object -Property MajorVersion -Descending

# Ensure that the required modules are installed and available in the user's PSModulePath
foreach ($modulePath in $verModPaths) {
    Update-UserEnvPath -VariableName "PSModulePath" -NewPath $modulePath.Path
}

foreach ($module in $userSettings.reqdModules) {
    if (-not (Get-InstalledModule -Name $module -ErrorAction SilentlyContinue)) {
        Write-Host "Installing required module: $module"
        try {
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to install module '$module': $_"
            Save-Module -Name $module -Path $utilsAppPath -Force -ErrorAction Stop
            Write-Host "Module '$module' saved to $utilsAppPath. Please ensure this path is included in your PSModulePath."
        }
    }
    else {
        Write-Host "Required module already installed: $module"
    }
}

