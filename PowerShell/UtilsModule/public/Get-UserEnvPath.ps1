function Get-UserEnvPath {
    [CmdletBinding()]
    [OutputType([array])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Path", "PSModulePath")]
        [string]$VariableName
    )

    # Retrieve current environment paths from both user and system scopes
    return ([Environment]::GetEnvironmentVariable($VariableName, [System.EnvironmentVariableTarget]::User) -split ';')
}