<# function Set-ExcelWorkbookCategory {
    [CmdletBinding()]
    param ()

} #>


function Set-ExcelWorkbookCategory {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            Position = 0,
            # ParameterSetName="ParameterSetName",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Specifies a path to one or more excel workbooks.")]
        [Alias("Path")]
        [ValidateNotNullOrEmpty()]
        [string[]]$Workbooks,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Public','Client Shared', 'Company Restricted', 'Confidential')]
        [string]$Classification = 'Confidential'
    )
    begin {
        Write-Verbose ('[{0}|{1}] --STARTED: message-text' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName)
    }
    process {
        foreach ($xlWorkbook in $Workbooks) {
            try {
            if (-not (Test-Path -LiteralPath $xlWorkbook -PathType Leaf)) {
                Write-Warning "The workbook '$xlWorkbook' does not exist."
                continue
            }
            Write-Host ('[{0}|{1}] Setting category for workbook: {2} to {3}' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName, $xlWorkbook, $Classification)
            $excelPackage = Open-ExcelPackage -Path $xlWorkbook # Open the Excel package using ImportExcel helpers
            $excelPackage.Workbook.Properties.Category = $Classification

            }
            catch {
                throw $_
            }
            finally {
                if ($excelPackage) {
                    Close-ExcelPackage -ExcelPackage $excelPackage
                }
            }
        }
    }
    end {
        Write-Verbose ('[{0}|{1}] --ENDED: message-text' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName)
    }
}