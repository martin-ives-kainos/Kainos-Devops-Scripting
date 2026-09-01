function Read-LocalCredential {
    [CmdletBinding()]
    [OutputType([pscredential])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AppName,

        [Parameter(Mandatory = $false)]
        [string]$UserName,

        [switch]$ForcePrompt
    )

    if (-not $UserName) {
        $UserName = $env:USERNAME
    }

    $savedFile = (Join-Path $env:APPDATA ('LocalCred_{0}.xml' -f $AppName.Trim()))
    if (Test-Path $savedFile -PathType Leaf) {
        $credential = Import-Clixml -Path $savedFile
    }
    else {
        $credential = Get-Credential -UserName $UserName -Message "Enter credentials for $UserName"
        $credential | Export-Clixml -Path $savedFile
    }
    return $credential
}
