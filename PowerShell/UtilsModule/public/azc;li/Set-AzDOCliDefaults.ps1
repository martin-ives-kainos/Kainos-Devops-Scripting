function Set-AzDOCliDefaults {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Organization,
        [String]$Project
    )

    # TODO: Consider adding validation or default values for the parameters before populating the hashtable.
    $pTable = @{}
    $ParameterList = (Get-Command -Name $MyInvocation.InvocationName).Parameters
    foreach ($key in $ParameterList.keys) {
        $var = Get-Variable -Name $key -ErrorAction SilentlyContinue
        if ($var) {
            $pTable.Add($var.name, $var.value)
        }
    }

    foreach ($key in $pTable.Keys) {
        if ([string]::IsNullOrEmpty($pTable[$key])) {
            Write-Warning "Default setting $key will be reset to blank"
            $cliArgs = @('devops', 'configure', '--defaults', ('{0}=''''' -f $key.ToLower()))
        }
        else {
            Write-Host "$key = $($pTable[$key])" -ForegroundColor Black -BackgroundColor DarkGreen
            $cliArgs = @('devops', 'configure', '--defaults', ('{0}={1}' -f $key.ToLower(), $pTable[$key]))
        }
        Invoke-AzCli -Arguments $cliArgs
    }
    Write-Host "Azure DevOps CLI defaults have been set." -ForegroundColor Black -BackgroundColor DarkGreen
    Write-Host (Invoke-AzCli -Arguments @('devops', 'configure', '--list'))
    Write-Host "-----------------------------------------" -ForegroundColor Black -BackgroundColor DarkGreen #>
}

