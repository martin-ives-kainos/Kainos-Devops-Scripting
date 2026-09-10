function Invoke-AzCliInternal {
    param (
        [string[]]$azArgs
    )
    $stdOut = & az @azArgs 2>&1
    $exitCode = $LASTEXITCODE
    return @{
        StdOut   = $stdOut
        ExitCode = $exitCode
    }
}
