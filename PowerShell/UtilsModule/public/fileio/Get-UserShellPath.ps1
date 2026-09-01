function Get-UserShellPath {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FolderName
    )

    # Ensure folder name exists
    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $validFolderNames = (Get-Item $regPath).Property

    if ($validFolderNames -notcontains $FolderName) {
        throw "$FolderName not a valid User Shell Folder"
    }
    return (Get-ItemProperty -Path $regPath -Name $FolderName).$FolderName
}