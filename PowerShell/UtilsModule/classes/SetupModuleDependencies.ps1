class SetupModuleDependencies {
    [string]$ModuleFilePath
    hidden [hashtable]$_ModuleManifest = $null
    [string]$ModuleName
    [bool]$ShowOutput = $true

    SetupModuleDependencies([string]$ModuleFilePath) {
        if (-not (Test-Path -LiteralPath $ModuleFilePath -PathType Leaf)) {
            throw "Module file path '$ModuleFilePath' does not exist."
        }
        $this.ModuleFilePath = $ModuleFilePath
        $this.ModuleName = [System.IO.Path]::GetFileNameWithoutExtension($ModuleFilePath)
        foreach ($script in $this.GetModuleManifestPrivateDataValue('ScriptsToPreload')) {
            $this.WriteOutput("Preloading script '$script'...")
            $scriptItem = Get-ChildItem (Split-Path -Parent $this.ModuleFilePath -Resolve) -Recurse -Filter $script | Select-Object -First 1
            if ($null -eq $scriptItem) {
                Write-Warning "Script file '$script' not found in module path."
                continue
            }
            . ($scriptItem.FullName)
            $this.WriteOutput(("Sourced script file '{0}' --- Check function '{1}' availability" -f $scriptItem.FullName, $scriptItem.BaseName))
            $checkFunction = Get-Command -Name $scriptItem.BaseName -ErrorAction SilentlyContinue
            if ($null -eq $checkFunction) {
                Write-Warning "Function '$($scriptItem.BaseName)' not found after sourcing script file '$($scriptItem.FullName)'."
            }
        }
        $this.ModulePathUpdate()
        $this.BuildModule()
    }

    [bool] BuildModule() {
        $this.WriteOutput("Building module...")
        $success = $true
        $scopes = [hashtable]$this.GetModuleManifestPrivateDataValue('ScriptScopes')
        if ($scopes.Count -eq 0) {
            throw "No script scopes defined in module manifest."
        }
        foreach ($key in $scopes.Keys) {
            $this.WriteOutput("...Processing script scope '$key'...")
            try {
                $scriptFiles = Get-ChildItem (Join-Path $PSScriptRoot $key -Resolve) -Recurse -Filter '*.ps1'
                foreach ($scriptFile in $scriptFiles) {
                    $this.WriteOutput("......Sourcing script file '$($scriptFile.FullName)'")
                    . ($scriptFile.FullName)
                }

                if ($scopes[$key]) {
                    $this.WriteOutput("......Exporting functions from script scope '$key'")
                    Export-ModuleMember -Function ($scriptFiles | Select-Object -ExpandProperty BaseName)
                }
            }
            catch {
                $success = $false
                # Write-Warning $_.Exception.Message
                Write-Warning "Error loading $key $($_.Exception.Message)"
            }

        }

        <# $reqdModules = @('ImportExcel')

foreach ($module in $reqdModules) {
    if ([SetupModuleDependencies]::ModuleInstalled($module)) {
        Write-Host "Module '$module' is already installed." -ForegroundColor Green
        continue
    }
    Write-Warning "Try to install '$module' for current user."
    if (![SetupModuleDependencies]::ModuleInstall($module)) {
        Write-Error "Failed to install required module '$module'."
        break
    }
}

 #>

        return $success
    }

    [object] GetModuleManifestPrivateDataValue([string]$Key) {
        if ($this.ModuleManifest().Keys -contains 'PrivateData') {
            if ($this.ModuleManifest().PrivateData.Keys -contains $Key) {
                return $this.ModuleManifest().PrivateData.$Key
            }
        }
        return $null
    }

    [bool] ModuleInstalled([string]$Name) {
        return ( $null -ne (Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue) )
    }

    [hashtable] ModuleManifest() {
        if ($null -eq $this._ModuleManifest) {
            $manifestPath = Resolve-Path -LiteralPath ($this.ModuleFilePath -replace '\.psm1$', '.psd1') -ErrorAction Stop
            $this._ModuleManifest = Import-PowerShellDataFile -Path $manifestPath.Path
        }
        return $this._ModuleManifest
    }

    [bool] ModuleInstall([string]$Name) {
        try {
            Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -AcceptLicense -ErrorAction Stop
            return $true
        }
        catch {
            return $false
        }
    }

    [void] ModulePathUpdate() {
        $envPaths = (Get-PathEnvVar -Name 'PSModulePath')

        foreach ($pathSuffix in $this.ModuleManifest().PrivateData.UseEnvironmentPaths) {
            $path = (Join-Path $env:USERPROFILE $pathSuffix)
            if ($envPaths -contains $path) {
                Write-Host "Path '$path' already exists in PSModulePath." -ForegroundColor Green
                continue
            }
            Write-Host "Adding '$path' to PSModulePath." -ForegroundColor Yellow
            [System.Environment]::SetEnvironmentVariable('PSModulePath', $envPaths -join ';' + ';' + $path, 'User')
        }
    }

    [string[]] PreloadScriptsList() {
        if ($this.ModuleManifest().Keys -contains 'PrivateData') {
            if ($this.ModuleManifest().PrivateData.Keys -contains 'ScriptsToPreload') {
                return $this.ModuleManifest().PrivateData.ScriptsToPreload
            }
        }
        return @()
    }
    [string[]] GetModuleScopes() {
        return @('classes', 'private', 'public')
    }
    <#     [bool] RequiredModuleInstall() {
        $success = $true
        $requiredModules = $this.GetModuleManifestPrivateDataValue('RequiredModules')
        if ($null -eq $requiredModules) {
            Write-Warning "No required modules specified in the module manifest."
            return $false
        }

        foreach ($module in $requiredModules) {
            if (-not $this.ModuleInstalled($module)) {
                $modOk = (Install-ReqdUserModule -Name $module)
                if (-not $modOk) {
                    Write-Warning "Failed to install required module '$module'."
                    $success = $false
                }
            }
        }

        return $success
    }
 #>
    [void] WriteOutput([string]$Msg) {
        if ($this.ShowOutput) {
            Write-Host ("[{0}] | {1}]" -f $this.ModuleName, $Msg) -ForegroundColor Cyan
        }
    }
}
