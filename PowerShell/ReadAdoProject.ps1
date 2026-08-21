$ErrorActionPreference = "Stop"

Import-Module -Name (Join-Path $PsScriptRoot "UtilsModule") -ErrorAction Stop

Import-Module -Name PSIni -ErrorAction Stop

$settingsFilePath = ($PSCommandPath -replace '\.ps1$', '.ini')
$settings = Import-Ini -Path $settingsFilePath

# set environment variable for current process
# $adoPatCred = [LocalCredentialHelper]::Read(("AzureDevops-{0}" -f $settings.AzureDevops.Organization))
$adoPatCred = Read-LocalCredential -AppName ("AzureDevops-{0}" -f $settings.AzureDevops.Organization)

$adoPatCred.GetNetworkCredential().Password | az devops login --organization ("https://dev.azure.com/{0}" -f $settings.AzureDevops.Organization) 

# At the moment I only have stake holder ccess, even though should have Basic soon

# Initially we can map out th pipelines

az pipelines runs list --status completed --result succeeded --top 3 --output table --project $settings.AzureDevops.Project

