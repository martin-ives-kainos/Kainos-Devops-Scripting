function Get-PathEnvVar {
    [CmdletBinding()]
    [OutputType([array])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Path", "PSModulePath")]
        [string]$VariableName,


        [ValidateSet("User", "Machine")]
        [string]$Scope = "User"
    )

    # Retrieve current environment paths from both user and system scopes
    $target = [System.EnvironmentVariableTarget]::$Scope
    $rawPath = [Environment]::GetEnvironmentVariable($VariableName, $target).Trim(';')
    return ($rawPath -split ';')
}