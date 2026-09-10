function Invoke-AzCli {
    <#
    .SYNOPSIS
        Runs an Azure CLI command, capturing errors and returning parsed JSON results.

    .DESCRIPTION
        Wraps `az` CLI invocations, ensuring output is captured, exit codes are checked,
        and JSON output is converted to PowerShell objects. Throws a terminating error
        (or returns an object with an Error property, depending on -PassThruOnError)
        if the command fails.

    .PARAMETER Arguments
        The arguments to pass to the `az` CLI, excluding the leading 'az'.
        Can be a single string or an array of strings.

    .PARAMETER AsJson
        If specified, appends '--output json' to the arguments and converts the
        result from JSON to a PowerShell object. Defaults to $true.

    .PARAMETER PassThruOnError
        If specified, instead of throwing on failure, returns a custom object with
        Success, Output, Error, and ExitCode properties.

    .EXAMPLE
        Invoke-AzCli -Arguments 'account show'

    .EXAMPLE
        Invoke-AzCli -Arguments @('group', 'list', '--query', "[?location=='uksouth']")

    .EXAMPLE
        $result = Invoke-AzCli -Arguments 'group show --name doesnotexist' -PassThruOnError
        if (-not $result.Success) { Write-Warning $result.Error }

    .NOTES
        # Basic call, throws on failure
        $account = Invoke-AzCli -Arguments 'account show'

        # Non-throwing usage
        $result = Invoke-AzCli -Arguments @('vm', 'list', '--resource-group', 'my-rg') -PassThruOnError
        if ($result.Success) {
            $result.Output | ForEach-Object { $_.name }
        } else {
            Write-Warning "Failed: $($result.Error)"
        }
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$Arguments,

        [switch]$AsJson,

        [switch]$PassThruOnError
    )

    $azArgs = $Arguments

    if ($AsJson -and ($azArgs -notcontains '--output') -and ($azArgs -notcontains '-o')) {
        $azArgs += @('--output', 'json')
    }

    Write-Verbose "Running: az $($azArgs -join ' ')"

    try {
        # Capture stdout and stderr separately, avoid throwing on non-terminating stream writes
        $internalResult = Invoke-AzCliInternal -azArgs $azArgs
        $stdOut = $internalResult.StdOut
        $exitCode = $internalResult.ExitCode

        # Separate error records (from stderr) out of the combined stream
        $errorLines = $stdOut | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
        $outputLines = $stdOut | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }

        $rawOutput = ($outputLines -join [Environment]::NewLine)
        $rawError = ($errorLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine

        if ($exitCode -ne 0) {
            $errorMessage = if ($rawError) { $rawError } else { $rawOutput }

            if ($PassThruOnError) {
                return [pscustomobject]@{
                    Success  = $false
                    Output   = $null
                    Error    = $errorMessage
                    ExitCode = $exitCode
                }
            } else {
                throw "Azure CLI command failed (exit code $exitCode): $errorMessage"
            }
        }

        $parsedOutput = $rawOutput
        if ($AsJson -and $rawOutput) {
            try {
                $parsedOutput = $rawOutput | ConvertFrom-Json -ErrorAction Stop
            } catch {
                Write-Verbose "Output was not valid JSON, returning raw string. $_"
            }
        }

        if ($PassThruOnError) {
            return [pscustomobject]@{
                Success  = $true
                Output   = $parsedOutput
                Error    = $null
                ExitCode = $exitCode
            }
        }

        return $parsedOutput
    } catch {
        if ($PassThruOnError) {
            return [pscustomobject]@{
                Success  = $false
                Output   = $null
                Error    = $_.Exception.Message
                ExitCode = -1
            }
        } else {
            throw
        }
    }
}