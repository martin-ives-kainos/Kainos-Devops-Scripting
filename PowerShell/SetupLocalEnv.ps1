[CmdletBinding()]
param (
)
$ErrorActionPreference = "Stop"

Import-Module -Name (Join-Path $PsScriptRoot "UtilsModule" -Resolve) -ErrorAction Stop

$defaultSettingsFile = ($PSCommandPath -replace "\.ps1$", ".settings.json")

if (-not (Test-Path $defaultSettingsFile -PathType Leaf)) {
    Write-Host "Default settings file not found: creating $defaultSettingsFile"
    $defaultSettings = @{
        "reqdModules"      = @(
            "PSIni;0"
            "Pester;6.1.0"
        )
        "LocalAppFolder"    = 'utils'
        "FixModulePath"    = $false
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

# Add additional methods and properties to the userSettings object for easier access and manipulation
$userSettings | Add-Member -Force -MemberType NoteProperty -Name VerModulePaths -Value @()

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
    $this.VerModulePaths = ($modulePaths | Sort-Object -Property MajorVersion -Descending)
    return $null
}


$userSettings | Add-Member -Force -MemberType ScriptMethod -Name "GetVerPath" -Value {
    param (
        [Parameter(Mandatory = $true)]
        [int]$MajorVersion
    )
    return ($this.VerModulePaths | Where-Object { $_.MajorVersion -eq $MajorVersion }).Path
}

$userSettings.GetVerModulePaths()


$vModPath = $userSettings.GetVerPath($PsVersion.Major)

# Ensure that the required modules are installed and available in the user's PSModulePath
foreach ($modulePath in $userSettings.VerModulePaths) {
    Update-UserEnvPath -VariableName "PSModulePath" -NewPath $modulePath.Path
}

foreach ($module in $userSettings.reqdModules) {
    $modName, $modMinVer = $module -split ";"
    $iMod = Get-Module -Name $modName -ListAvailable | Where-Object {$_.Path.StartsWith($vModPath) -and ($_.Version.ToString() -ge $modMinVer)}
    if ($null -eq $iMod) {
        Write-Host "Module '$module' not found in PSModulePath. Attempting to install..."
        try {
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
        }
        catch {
            $saveParams = @{
                Name = $modName
                Path = $vModPath
            }
            if ($modMinVer -gt '0') {
                $saveParams.Add('MinimumVersion', $modMinVer)
            }
            Write-Warning "Failed to install module '$modName': $_"
            Save-Module @saveParams -Force -ErrorAction Stop
            Write-Host "Module '$modName' saved to $vModPath. Please ensure this path is included in your PSModulePath."
        }
    }
    else {
        Write-Host "Required module already installed: $modName v$($iMod.Version)"
    }

    # Test if we can import the module after installation
    $importParams = @{
        Name = $modName
    }
    if ($modMinVer -gt '0') {
        $importParams.Add('MinimumVersion', $modMinVer)
    }
    try {
        Import-Module @importParams  -ErrorAction Stop
        Write-Host "Successfully imported module: $modName v$($iMod.Version)"
    }
    catch {
        Write-Warning "Failed to import module '$modName v$($iMod.Version)' after installation: $_"
    }
}

