function Save-IniConfig {
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
        [Parameter(Mandatory = $true,
            Position = 1,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Path for a ini formatted config file.')]
        [ValidateNotNull()]
        [Alias('DefaultData')]
        [hashtable]$Data
    )
    begin {
        Write-Verbose ('[{0}|{1}] --STARTED: message-text' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName)
    }
    process {
        $iniContent = @()
        foreach ($section in $Data.Keys) {
            $iniContent += "[$section]"
            foreach ($key in $Data[$section].Keys) {
                $value = (ConvertTo-IniValue $Data[$section][$key])
                $iniContent += ("{0}={1}" -f $key, $value)
            }
        }
        Set-Content -Path $ConfigFile -Value $iniContent -Force -Encoding UTF8
        Write-Verbose ('[{0}|{1}] --SAVED: {2}' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName, $ConfigFile)
    }
    end {
        Write-Verbose ('[{0}|{1}] --ENDED: message-text' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName)
    }
}

