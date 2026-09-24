function Read-IniConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Path to a ini formatted config file.')]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigFile,
        [Parameter(Mandatory = $false,
            Position = 1,
            ValueFromPipeline = $false,
            ValueFromPipelineByPropertyName = $false,
            HelpMessage = 'Default data for the config file.')]
        [hashtable]$DefaultData = @{}
    )
    begin {
        Write-Verbose ('[{0}|{1}] --STARTED: message-text' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName)
        if (-not (Test-Path $ConfigFile -PathType Leaf) -and $DefaultData.Count -gt 0) {
            Write-Verbose ('[{0}|{1}] --INFO: Config file not found, creating default' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName)
            Save-IniConfig -ConfigFile $ConfigFile -DefaultData $DefaultData
        }
        if (-not (Test-Path $ConfigFile -PathType Leaf)) {
            Write-Warning ('[{0}|{1}] --ERROR: Config file not found' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName)
            throw "Config file not found: $ConfigFile"
            return
        }
    }
    process {
        $iniContent = Get-Content $configFile
        $ConfigData = @{}
        $section = $null
        foreach ($line in $iniContent) {
            if ($line -match '^\[(.+)\]$') {
                $section = $matches[1]
                $ConfigData[$section] = @{}
            }
            elseif ($line -match '^([^=]+)=(.+)$' -and $section) {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                switch ($value.GetType().Name) {
                    'String' {
                        if ($value -match '^(True|False)$') {
                            $value = [bool]::Parse($value)
                        }
                        elseif ($value -match '^\d+$') {
                            $value = [int]::Parse($value)
                        }
                        elseif ($value -match '^\d+\.\d+$') {
                            $value = [double]::Parse($value)
                        }
                        elseif ($value.Contains("%")) {
                            $envVarPattern = '%(?<VarName>[^%]+)%'
                            foreach ($match in [regex]::Matches($value, $envVarPattern)) {
                                $value = [System.Environment]::ExpandEnvironmentVariables($value)
                            }
                        }
                    }
                }
                $ConfigData[$section][$key] = $value
            }
        }
        return $ConfigData
    }
    end {
        Write-Verbose ('[{0}|{1}] --ENDED: message-text' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName)
    }
}
