$ErrorActionPreference = 'Stop'

<#
    Utility module for setting up module dependencies, building modules, and managing module paths.
    Provides the SetupModuleDependencies class with methods for:
        - Preloading scripts
        - Building module functions
        - Checking and installing required modules
        - Updating module paths
 #>
$ModuleFilePath = $PSCommandPath

# $ModuleName = [System.IO.Path]::GetFileNameWithoutExtension($ModuleFilePath)

$ModuleManifest = Import-PowerShellDataFile -Path (Resolve-Path -LiteralPath ($ModuleFilePath -replace '\.psm1$', '.psd1') -ErrorAction Stop)

$privateData = $ModuleManifest.PrivateData

if ($privateData.Keys -notcontains 'ScriptScopes') {
    $privateData['ScriptScopes'] = @('classes', 'private', 'public')
}

#region Embedded Functions

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
Get-DuplicatedUserEnvPath -VariableName "Path"

This example identifies any paths in the user's Path environment variable that are already defined in the system environment.

.EXAMPLE
Get-DuplicatedUserEnvPath -VariableName "PSModulePath"

This example adds "C:\CustomModules" to the user's PSModulePath environment variable.

.NOTES
- The function checks both user and system environment variables to identify duplicates

.LINK
Get-DuplicatedUserEnvPath
#>
function Get-DuplicatedUserEnvPath {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Path", "PSModulePath")]
        [string]$VariableName
    )
    begin {
        Write-Verbose ('[{0}|{1}] --STARTED: Identifying duplicated user environment paths for $VariableName' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName)
        $duplicatedPaths = @()
    }
    process {
        # Retrieve current environment paths from both user and system scopes
        $userPaths = (Read-EnvironmentVariable -VariableName $VariableName -Scope 'User') -split ';'
        $systemPaths = (Read-EnvironmentVariable -VariableName $VariableName -Scope 'Machine') -split ';'

        foreach ($path in $userPaths) {
            if ($systemPaths -contains $path) {
                $duplicatedPaths += $path
            }
        }
        return $duplicatedPaths
    }
    end {
        Write-Verbose ('[{0}|{1}] --COMPLETED: Identifying duplicated user environment paths for $VariableName' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName)
    }
}
function Get-PathEnvVar {
    [CmdletBinding()]
    [OutputType([array])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Path", "PSModulePath")]
        [Alias('Name')]
        [string]$VariableName,


        [ValidateSet("User", "Machine")]
        [string]$Scope = "User"
    )

    return ((Read-EnvironmentVariable -VariableName $VariableName -Scope $Scope) -split ';')
}

function Read-EnvironmentVariable {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VariableName,
        [ValidateSet("User", "Machine")]
        [string]$Scope = "User"
    )
    Write-Verbose ('[{0}|{1}] --RETRIEVING: Reading environment variable $VariableName for scope $Scope' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName)
    return [Environment]::GetEnvironmentVariable($VariableName, [System.EnvironmentVariableTarget]::$Scope)
}

function Update-UserEnvPath {

    [CmdletBinding(SupportsShouldProcess = $true)]
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
                [IO.Path]::GetFullPath([System.Environment]::ExpandEnvironmentVariables($RawPath)).TrimEnd('\')
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
            }
            else {
                Write-Host "Nothing to save"
            }
        }
    }

    $myEnvPaths = [EnvPaths]::New($VariableName)
    if ($PSCmdlet.ShouldProcess("User environment variable '$VariableName'", "$Action paths: $($Paths -join ';')")) {
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

}
Export-ModuleMember -Function Read-EnvironmentVariable, Get-DuplicatedUserEnvPath, Get-PathEnvVar, Update-UserEnvPath
#endregion Embedded Functions

$ModuleManifest | Add-Member -MemberType ScriptMethod -Name PrivateDataValue -Value {
    param([string]$key)
    if (-not $this.PrivateData.ContainsKey($key)) {
        throw "Key '$key' not found in PrivateData."
    }
    return $this.PrivateData[$key]
}

foreach ($scope in $ModuleManifest.PrivateDataValue('ScriptScopes') | Sort-Object) {
    try {
        $scriptFiles = Get-ChildItem (Join-Path $PSScriptRoot $scope -Resolve) -Recurse -Filter '*.ps1'
        foreach ($scriptFile in $scriptFiles) {
            . ($scriptFile.FullName)
        }

        if ($scope -like 'public*') {
            Export-ModuleMember -Function ($scriptFiles | Select-Object -ExpandProperty BaseName)
        }
    }
    catch {
        Write-Warning "Error accessing script scope '$scope': $($_.Exception.Message)"
    }
}

$envPaths = (Get-PathEnvVar -Name 'PSModulePath')

foreach ($pathSuffix in $ModuleManifest.PrivateDataValue('UseEnvironmentPaths')) {
    $path = (Join-Path $env:USERPROFILE $pathSuffix)
    if ($envPaths -contains $path) {
        Write-Host "Path '$path' already exists in PSModulePath." -ForegroundColor Green
        continue
    }
    Write-Host "Adding '$path' to PSModulePath." -ForegroundColor Yellow
    [System.Environment]::SetEnvironmentVariable('PSModulePath', $envPaths -join ';' + ';' + $path, 'User')
}

$allModulesInstalled = $true

foreach ($reqdModuleName in $ModuleManifest.PrivateDataValue('RequiredModules')) {
    if ($null -ne (Get-Module -ListAvailable -Name $reqdModuleName -ErrorAction SilentlyContinue)) {
        Write-Host "Module '$reqdModuleName' is already installed." -ForegroundColor Green
        continue
    }
    Write-Warning "Try to install '$reqdModuleName' for current user."
    $modOk = (Install-ReqdUserModule -Name $reqdModuleName)
    if (-not $modOk) {
        Write-Warning "Failed to install required module '$reqdModuleName'."
        $allModulesInstalled = $false
    }
}
if (-not $allModulesInstalled) {
    throw "One or more required modules failed to install."
}

