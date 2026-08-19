function Get-LocalCredentialPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName
    )
       
    return (Join-Path $env:USERPROFILE ('LocalCred_{0}.xml' -f $AppName.Trim()))
}