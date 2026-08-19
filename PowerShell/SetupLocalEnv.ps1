$ErrorActionPreference = "Stop"

Import-Module -Name (Join-Path $PsScriptRoot "UtilsModule") -ErrorAction Stop

$reqdModules = @("PSIni", "Pester")

$psGallery = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
if (-not $psGallery) {
    Write-Host "PSGallery repository not found. Registering..."
    Register-PSRepository -Name "PSGallery" -SourceLocation "https://www.powershellgallery.com/api/v2/" -InstallationPolicy Trusted
}
if (-not $psGallery.Trusted) {
    Write-Host "PSGallery repository is not trusted. Setting it to trusted..."
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted  
}

$localModPath = Join-Path $env:USERPROFILE "Documents\PowerShell\Modules"
if (-not (Test-Path $localModPath -PathType Container)) {
    Write-Host "Creating local module path: $localModPath"
    New-Item -ItemType Directory -Path $localModPath -Force | Out-Null
}

$localModuleFolders = Get-ChildItem -Path $localModPath -Directory | Select-Object -ExpandProperty Name

foreach ($module in $reqdModules) {
    if ($localModuleFolders -notcontains $module) {
        Write-Host "Module '$module' not found in local module path. Installing..."
        Save-Module -Name $module -Path $localModPath -Repository PSGallery -Force
    }
    else {
        Write-Host "Module '$module' already exists in local module path. Skipping installation."
    }
}


<# Save-Module -Name PSIni -Path $localModPath -Repository PSGallery
Get-ChildItem -Path $localModPath
 #>