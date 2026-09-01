function Save-ObjectToFile {
    <#
        .SYNOPSIS
            Read a json file and load as a custom object
        .DESCRIPTION
            Read a json file and load as a custom object
        .PARAMETER Path
            The full path to the json file
        .EXAMPLE
           Save-ObjectToFile
              -P1 'param1'
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="The full path to the json file")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory=$true,
                   Position=1,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Object to be saved")]
        [ValidateNotNullOrEmpty()]
        [object]
        $InputObject
    )
    begin {
        $funcName = (Get-PSCallStack)[0].FunctionName.Replace('<Begin>','')
        Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} STARTED' -f (Get-Date), $funcName)

        $targetPath = Split-Path -Parent $Path

        if (!(Test-Path $targetPath -PathType Container)) {
            throw "Parent path in $Path not found"
        }
    }
    process {
        Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} Saving object to {2}' -f (Get-Date), $funcName, $Path)
        Set-Content $Path -Value (ConvertTo-Json -Depth 99 -InputObject $InputObject)
    }
    end {
        Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} ENDED' -f (Get-Date), $funcName)
    }
}