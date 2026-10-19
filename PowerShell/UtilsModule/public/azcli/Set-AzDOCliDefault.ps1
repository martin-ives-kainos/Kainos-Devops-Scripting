function Set-AzDOCliDefault {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Function is only used internally')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Organization,
        [String]$Project
    )

    $pTable = @{}
    $ParameterList = (Get-Command -Name $MyInvocation.InvocationName).Parameters
    foreach ($key in $ParameterList.keys) {
        $var = Get-Variable -Name $key -ErrorAction SilentlyContinue
        if ($var) {
            $pTable.Add($var.name, $var.value)
        }
    }

    Write-Output ('[{0}|{1}] Setting Azure DevOps CLI defaults for Organization: {2}, Project: {3}' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName, $Organization, $Project)

    foreach ($key in $pTable.Keys) {
        if ([string]::IsNullOrEmpty($pTable[$key])) {
            Write-Warning "Default setting $key will be reset to blank"
            $cliArgs = @('devops', 'configure', '--defaults', ('{0}=''''' -f $key.ToLower()))
        }
        else {
            Write-Output "$key = $($pTable[$key])"
            $cliArgs = @('devops', 'configure', '--defaults', ('{0}={1}' -f $key.ToLower(), $pTable[$key]))
        }
        Invoke-AzCli -Arguments $cliArgs
    }
    Write-Output "Azure DevOps CLI defaults have been set."
    Write-Output (Invoke-AzCli -Arguments @('devops', 'configure', '--list'))
    Write-Output "-----------------------------------------"
}

