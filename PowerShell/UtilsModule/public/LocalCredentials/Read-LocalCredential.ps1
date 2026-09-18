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
    if ((Test-Path $savedFile -PathType Leaf) -and (-not $ForcePrompt)) {
        $credential = Import-Clixml -Path $savedFile
    }
    else {
        Write-Warning "Enter credential for $AppName ($UserName) to save to $savedFile"
        $credential = Get-Credential -UserName $UserName -Message "Enter credentials for $UserName"
        $credential | Export-Clixml -Path $savedFile -Force
    }
    return $credential
}
