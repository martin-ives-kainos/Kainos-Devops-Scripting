function Find-PwshInstallation {
    $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if (-not $pwshPath) {
        Write-Output "PowerShell 7 executable not found in PATH."
        return $null
    }
    return $pwshPath
}