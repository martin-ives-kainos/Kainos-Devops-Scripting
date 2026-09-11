function Set-AzDOCliDefaults {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Organization,
        [String]$Project
    )

    $cmd = Get-Command Set-AzDOCliDefaults

    $ValidKeys = $PSBoundParameters.GetEnumerator().Keys | Sort-Object -Unique -ExpandProperty Key

    foreach ($cmdParam in $cmd.Parameters.GetEnumerator()) {
        if ($cmdParam.key -eq 'Verbose') {
            break
        }
        $ValidKeys += $cmdParam.Key
    }

    $ValidKeys = $ValidKeys | Sort-Object -Unique

    # Read the passed parameter values for all arguments
    foreach ($parameter in $PSBoundParameters.GetEnumerator()) {
        if ($ValidKeys -notcontains $parameter.Key) {
            $cliArgs = @('devops', 'configure', '--defaults', ('{0}=''''' -f $parameter.Key.ToLower()))
        }
        else {
            $cliArgs = @('devops', 'configure', '--defaults', ('{0}={1}' -f $parameter.Key.ToLower(), $parameter.Value))
        }
        Invoke-AzCli -Arguments $cliArgs
    }
    Write-Host "Azure DevOps CLI defaults have been set." -ForegroundColor Black -BackgroundColor DarkGreen
    Write-Host (Invoke-AzCli -Arguments @('devops', 'configure', '--list'))
    Write-Host "-----------------------------------------" -ForegroundColor Black -BackgroundColor DarkGreen
}