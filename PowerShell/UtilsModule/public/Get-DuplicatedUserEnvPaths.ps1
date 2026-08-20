<#
.SYNOPSIS
Identifies user environment paths already defined in Machine path.

.DESCRIPTION
Identifies user environment paths already defined in Machine path.

.PARAMETER VariableName
The name of the environment variable to update. Must be either "Path" or "PSModulePath".

.PARAMETER NewPath
The full path to add to the environment variable. This path will be validated against
both user and system environment variables to prevent duplicates.

.EXAMPLE
Get-DuplicatedUserEnvPaths -VariableName "Path"

This example identifies any paths in the user's Path environment variable that are already defined in the system environment.

.EXAMPLE
Get-DuplicatedUserEnvPaths -VariableName "PSModulePath"

This example adds "C:\CustomModules" to the user's PSModulePath environment variable.

.NOTES
- The function checks both user and system environment variables to identify duplicates

.LINK
Get-DuplicatedUserEnvPaths
#>
function Get-DuplicatedUserEnvPaths {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Path", "PSModulePath")]
        [string]$VariableName
    )

    $duplicatedPaths = @()
    # Retrieve current environment paths from both user and system scopes
    $userPaths = [Environment]::GetEnvironmentVariable($VariableName, [System.EnvironmentVariableTarget]::User) -split ';'
    $systemPaths = [Environment]::GetEnvironmentVariable($VariableName, [System.EnvironmentVariableTarget]::Machine) -split ';'

    foreach ($path in $userPaths) {
        if ($systemPaths -contains $path) {
            $duplicatedPaths += $path
        }
    }
    return $duplicatedPaths
}