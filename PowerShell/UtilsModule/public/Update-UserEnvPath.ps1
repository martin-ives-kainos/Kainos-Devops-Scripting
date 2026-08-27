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
Array of full paths to add/remove to/from the user environment variable. This path will be validated against
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
        [Alias('NewPath', 'NewPaths')]
        [string[]]$Paths,

        [ValidateSet('Add', 'Remove')]
        [string]$Action = 'Add'

    )

    # Retrieve current environment paths from both user and system scopes

    class EnvPaths {
        [string]$Name
        [System.Collections.Generic.List[string]]$UserPaths = @()
        [System.Collections.Generic.List[string]]$MachinePaths = @()
        [System.Collections.Generic.List[string]]$PathList
        [bool]$IsDirty

        EnvPaths([string]$Name) {
            $this.Name = $Name
            $this.LoadPathList()

        }

        [void] LoadPathList() {
            $this.UserPaths = [System.Collections.Generic.List[string]](Get-PathEnvVar $this.Name)
            $this.MachinePaths = [System.Collections.Generic.List[string]](Get-PathEnvVar $this.Name 'Machine')

            $this.PathList = [System.Collections.Generic.List[string]]::new()

            foreach ($path in ($this.UserPaths | Select-Object -Unique -CaseInsensitive)) {
                $trimmed = $path.Trim()
                if (-not [string]::IsNullOrWhiteSpace($trimmed) -and $this.MachinePaths -notcontains $trimmed) {
                    $this.PathList.Add($trimmed)
                }
            }
            $this.IsDirty = $false
        }

        [string[]] NormalisedPaths([string[]]$Paths) {
            [string[]]$normList = @()
            foreach ($path in $Paths) {
                try {
                    $normList += [IO.Path]::GetFullPath([System.Environment]::ExpandEnvironmentVariables($path)).TrimEnd('\')
                }
                catch {
                    $normList += $path.TrimEnd('\')
                }
            }
            return $normList
        }

        [string] FullExpandedPath([string]$RawPath) {
            return try {
                [IO.Path]::GetFullPath(
                    [System.Environment]::ExpandEnvironmentVariables($RawPath)
                ).TrimEnd('\')
            }
            catch {
                $existing.TrimEnd('\')
            }
        }

        [bool] ExistsInMachinePaths([string]$Path) {
            return $this.ExistsInPathList($Path, $this.MachinePaths)
        }
        [bool] ExistsInPathList([string]$Path) {
            return $this.ExistsInPathList($Path, $this.PathList)
        }
        [bool] ExistsInUserPaths([string]$Path) {
            return $this.ExistsInPathList($Path, $this.UserPaths)
        }
        [bool] ExistsInPathList([string]$Path, [System.Collections.Generic.List[string]]$TargetList) {
            return ($TargetList.IndexOf($Path) -gt -1)
        }

        [void] AddPaths([string[]]$Paths) {

            foreach ($newPath in $this.NormalisedPaths($Paths)) {
                if ($this.ExistsInPathList($newPath)) {
                    Write-Host "Path $newPath already exists, skipped"
                }
                else {
                    Write-Host "Path $newPath will be added when saved"
                    $this.PathList.Add($newPath)
                    $this.IsDirty = $true
                }
            }
        }

        [void] RemovePaths([string[]]$Paths) {

            foreach ($oldPath in $this.NormalisedPaths($Paths)) {
                if ($this.ExistsInPathList($oldPath)) {
                    $index = $this.PathList.IndexOf($oldPath)
                    $this.PathList.RemoveAt($index)
                    Write-Host "Path $oldPath found in list at $index, will be removed on save"
                    $this.IsDirty = $true
                }
                else {
                    Write-Host "Path $oldPath not found. skipped"
                }
            }
        }

        [void] Save() {
            if ($this.IsDirty) {
                Write-Host "Saving user path for $($this.Name)"
                [Environment]::SetEnvironmentVariable($this.Name, ($this.PathList.ToArray() -join ';'), [System.EnvironmentVariableTarget]::User)
            } else {
                Write-Host "Nothing to save"
            }
        }
    }

    $myEnvPaths = [EnvPaths]::New($VariableName)
    switch ($Action) {
        'Add' {
            $myEnvPaths.AddPaths($Paths)
        }
        'Remove' {
            $myEnvPaths.RemovePaths($Paths)
        }
    }
    $myEnvPaths.Save()

}