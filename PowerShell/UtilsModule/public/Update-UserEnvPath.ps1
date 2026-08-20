function Update-UserEnvPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Path", "PSModulePath")]
        [string]$VariableName,

        [Parameter(Mandatory = $true)]
        [string]$NewPath
    )
    # TODO: Implement logic to update the user environment variable with the new path, ensuring no duplicates and maintaining proper formatting.

    $currPaths = @{
        'System' = [Environment]::GetEnvironmentVariable($VariableName, [System.EnvironmentVariableTarget]::System) -split ';'
        'User' = [Environment]::GetEnvironmentVariable($VariableName, [System.EnvironmentVariableTarget]::User) -split ';'
    }

<# 
    $allPaths = [environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User).Trim(';') -split ';'
    if ($allPaths -notcontains $pwshExecutable.DirectoryName) {
        Write-Host "Adding PowerShell 7 directory to PATH: $($pwshExecutable.DirectoryName)"
        $newPath = $pwshExecutable.DirectoryName + ";" + [environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
        [Environment]::SetEnvironmentVariable("PATH", $newPath, [System.EnvironmentVariableTarget]::User)
    }
#>


    <#     $currentValue = ([Environment]::GetEnvironmentVariable($VariableName, [System.EnvironmentVariableTarget]::User) -split ';') -ne '' ? ([Environment]::GetEnvironmentVariable($VariableName, [System.EnvironmentVariableTarget]::User) -split ';') : @()
    if ($currentValue -notcontains $NewPath) {
        $updatedValue = $currentValue + $NewPath
        [Environment]::SetEnvironmentVariable($VariableName, ($updatedValue -join ';'), [System.EnvironmentVariableTarget]::User)
        Write-Host "Updated user environment variable '$VariableName' with new path: $NewPath"
    } else {
        Write-Host "The path '$NewPath' is already present in the user environment variable '$VariableName'. No update needed."
    } #>
}