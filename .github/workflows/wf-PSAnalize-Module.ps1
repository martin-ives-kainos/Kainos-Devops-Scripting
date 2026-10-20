[CmdletBinding()]
param(
    [string]$ModuleRoot
)
$erroractionpreference = 'Stop'
Write-Output ('[{0}|{1}] --STARTED: Powershell 7 Analysis on Module in {2}' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName, $ModuleRoot)