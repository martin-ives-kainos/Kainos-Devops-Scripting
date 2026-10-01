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
        [string]$DataFilePath,
        [switch]$AsJson,
        [switch]$PassThruOnError
    )

    $diagFuncName = (Get-PSCallStack)[0].FunctionName
    $azArgs = $Arguments

    if ($AsJson -and ($azArgs -notcontains '--output') -and ($azArgs -notcontains '-o')) {
        $azArgs += @('--output', 'json')
    }

    Write-Host "[${diagFuncName}] Running: az $($azArgs -join ' ')"

    try {
        Write-Host "[${diagFuncName}]...Capture stdout and stderr separately, avoid throwing on non-terminating stream writes"
        $internalResult = Invoke-AzCliInternal -azArgs $azArgs
        $stdOut = $internalResult.StdOut
        $exitCode = $internalResult.ExitCode

        Write-Host "[${diagFuncName}]...Separate error records (from stderr) out of the combined stream"
        $errorLines = $stdOut | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
        $outputLines = $stdOut | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }

        $rawOutput = ($outputLines -join [Environment]::NewLine)
        $rawError = ($errorLines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine

        if ($exitCode -ne 0) {
            Write-Host "...Azure CLI command failed with exit code $exitCode"
            $errorMessage = if ($rawError) { $rawError } else { $rawOutput }

            if ($PassThruOnError) {
                Write-Host "...Returning error object due to PassThruOnError"
                return [pscustomobject]@{
                    Success  = $false
                    Output   = $null
                    Error    = $errorMessage
                    ExitCode = $exitCode
                }
            }
            else {
                throw "[${diagFuncName}] Azure CLI command failed (exit code $exitCode): $errorMessage"
            }
        }

        $parsedOutput = $rawOutput
        if ($AsJson -and $rawOutput) {
            try {
                Write-Host "[${diagFuncName}] ...Parsing raw output as JSON"
                $parsedOutput = $rawOutput | ConvertFrom-Json -ErrorAction Stop

                if (![string]::IsNullOrEmpty($DataFilePath)) {
                    Write-Host "[${diagFuncName}] ...Ensure parent directory exists for data file"
                    $parentDir = Split-Path $DataFilePath -Parent
                    if (-not (Test-Path $parentDir -PathType Container)) {
                        New-Item -ItemType Directory -Path $parentDir | Out-Null
                    }
                    Write-Host "[${diagFuncName}] ...Writing parsed output to data file: $DataFilePath"
                    $parsedOutput | ConvertTo-Json -Depth 99 | Set-Content -Path $DataFilePath -Force
                }
            }
            catch {
                Write-Warning "[${diagFuncName}] Output was not valid JSON, returning raw string. $_"
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
    }
    catch {
        if ($PassThruOnError) {
            return [pscustomobject]@{
                Success  = $false
                Output   = $null
                Error    = $_.Exception.Message
                ExitCode = -1
            }
        }
        else {
            throw
        }
    }
}