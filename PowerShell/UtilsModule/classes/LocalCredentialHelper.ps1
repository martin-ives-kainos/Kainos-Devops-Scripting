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