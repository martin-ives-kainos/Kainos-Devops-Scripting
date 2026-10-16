$errorActionPreference = "Stop"
if (-not $env:TF_BUILD) {
    Write-Host ('[{0}|{1}] --STARTED: Set up emulation for local script testing' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName)

    $env:AGENT_WORKFOLDER = $PSScriptRoot
    # Assuming we are within a local development environment, cloned from the repository.
    while (-not (Test-Path $env:AGENT_WORKFOLDER '.git' -PathType Container)) {
        $env:AGENT_WORKFOLDER = (Join-Path $env:AGENT_WORKFOLDER ".." -Resolve )
    }


    $env:AZDO_ORGANIZATION = $env:USERDOMAIN
    $env:AZDO_PERSONAL_ACCESS_TOKEN = New-Guid
    Write-Host ('[{0}|{1}] --ENDED--: Set up emulation for local script testing' -f (Get-Date -Format 'yyyy-MMM-dd HH:mm:ss'), (Get-PSCallStack)[0].FunctionName)
}
