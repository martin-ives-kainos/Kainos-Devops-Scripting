<#
.SYNOPSIS
Updates a user environment variable with a new path while preventing duplicates.

.DESCRIPTION
This function adds a new path to a user environment variable (Path or PSModulePath) 
if it doesn't already exist in either the user or system environment. The function ensures
no duplicate paths are added and maintains proper path formatting using semicolon separators.

.PARAMETER VariableName
The name of the environment variable to update. Must be either "Path" or "PSModulePath".

.PARAMETER NewPath
The full path to add to the environment variable. This path will be validated against
both user and system environment variables to prevent duplicates.

.EXAMPLE
Update-UserEnvPath -VariableName "Path" -NewPath "C:\CustomTools\bin"

This example adds "C:\CustomTools\bin" to the user's Path environment variable if it doesn't
already exist in the user or system environment.

.EXAMPLE
Update-UserEnvPath -VariableName "PSModulePath" -NewPath "C:\CustomModules"

This example adds "C:\CustomModules" to the user's PSModulePath environment variable.

.NOTES
- The function checks both user and system environment variables to avoid duplicates
- If the path exists in the system environment, it is not added to the user environment
- Changes are persisted to the user's environment profile
- Requires appropriate permissions to modify environment variables

.LINK
Update-UserEnvPath
#>
function Update-UserEnvPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Path", "PSModulePath")]
        [string]$VariableName,

        [Parameter(Mandatory = $true)]
        [string]$NewPath
    )

    # Retrieve current environment paths from both user and system scopes
    $userPaths = [Environment]::GetEnvironmentVariable($VariableName, [System.EnvironmentVariableTarget]::User) -split ';'
    $systemPaths = [Environment]::GetEnvironmentVariable($VariableName, [System.EnvironmentVariableTarget]::Machine) -split ';'

    # Check if the path already exists in the system environment variable
    if ($systemPaths -contains $NewPath) {
        Write-Host "The path '$NewPath' is already present in the system environment variable '$VariableName'. No update needed."
        return
    }

    # Add the new path to user environment if it's not already present
    if ($userPaths -notcontains $NewPath) {
        $updatedPaths = $userPaths + $NewPath
        [Environment]::SetEnvironmentVariable($VariableName, ($updatedPaths -join ';'), [System.EnvironmentVariableTarget]::User)
        Write-Host "Updated user environment variable '$VariableName' with new path: $NewPath"
    } else {
        Write-Host "The path '$NewPath' is already present in the user environment variable '$VariableName'. No update needed."
    }
}