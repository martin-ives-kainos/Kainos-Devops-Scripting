$ErrorActionPreference = "Stop"

class LocalCredentialHelper {
    static [pscredential] Read([string]$AppName) {
        return [LocalCredentialHelper]::Read($AppName, $env:USERNAME)
    }
    static [pscredential] Read([string]$AppName, [string]$UserName) {
        $savedFile = [LocalCredentialHelper]::SavedCredentialFileName($AppName)

        if (Test-Path $savedFile -PathType Leaf) {
            $credential = Import-Clixml -Path $savedFile
        }
        else {
            $credential = Get-Credential -UserName $UserName -Message "Enter credentials for $UserName"
            $credential | Export-Clixml -Path $savedFile
        }
        return $credential
    }

    static [string] SavedCredentialFileName([string]$AppName) {
        $file = ('LocalCred_{0}.xml' -f $AppName)
        return (Join-Path $env:USERPROFILE $file)
    }
}

Import-Module -Name (Join-Path $PsScriptRoot "UtilsModule") -ErrorAction Stop

Import-Module -Name PSIni -ErrorAction Stop

$settingsFilePath = ($PSCommandPath -replace '\.ps1$', '.ini')
$settings = Import-Ini -Path $settingsFilePath

# set environment variable for current process
$adoPatCred = [LocalCredentialHelper]::Read(("AzureDevops-{0}" -f $settings.AzureDevops.Organization))
$env:AZURE_DEVOPS_EXT_PAT = $adoPatCred.GetNetworkCredential().Password

az devops login --organization ("https://dev.azure.com/{0}" -f $settings.AzureDevops.Organization) #--project $settings.AzureDevops.Project

az pipelines runs list --status completed --result succeeded --top 3 --output table

