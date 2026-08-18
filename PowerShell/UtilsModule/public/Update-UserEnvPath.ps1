function Update-UserEnvPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Path", "PSModulePath")]
        [string]$VariableName,

        [Parameter(Mandatory = $true)]
        [string]$NewPath
    )
    $currentValue = ([Environment]::GetEnvironmentVariable($VariableName, [System.EnvironmentVariableTarget]::User) -split ';') -ne '' ? ([Environment]::GetEnvironmentVariable($VariableName, [System.EnvironmentVariableTarget]::User) -split ';') : @()
    if ($currentValue -notcontains $NewPath) {
        $updatedValue = $currentValue + $NewPath
        [Environment]::SetEnvironmentVariable($VariableName, ($updatedValue -join ';'), [System.EnvironmentVariableTarget]::User)
        Write-Host "Updated user environment variable '$VariableName' with new path: $NewPath"
    } else {
        Write-Host "The path '$NewPath' is already present in the user environment variable '$VariableName'. No update needed."
    }
}