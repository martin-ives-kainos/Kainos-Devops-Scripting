

<#
- Authenticates using Azure CLI
- Uses Azure DevOps CLI wherever possible
- Uses REST APIs for information not exposed by the CLI
- Generates a multi-worksheet Excel workbook using ImportExcel
- Includes:
  - Projects
  - Repositories
  - Pipelines
  - Teams
  - Variable Groups
  - Service Connections
  - Executive Summary
- Includes error handling
- Supports PAT authentication
- Performs reasonably well against large organizations
- Required Modules
  - Az.DevOps
  - ImportExcel

 #>

[CmdletBinding()]
param(
    [string]$Organization, # = $env:AZDO_ORGANIZATION,
    [string]$OutputPath, # = (Join-Path (Get-Location) ("AzDoProjectOverview-{0:yyyyMMdd-HHmmss}.xlsx" -f (Get-Date))),
    [string]$Pat,
    [string[]]$Project = @()
)


<# function Invoke-AzDoCliJson { #TODO: Replace with Uutilsodule function call for consistency
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$ArgumentList)

    $result = & az @ArgumentList 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Azure DevOps CLI failed: $($result -join [Environment]::NewLine)"
    }
    $json = $result -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($json)) { return @() }
    return ConvertFrom-Json -InputObject $json
} #>

function Get-AzDoAuthorizationHeader {
    [CmdletBinding()]
    param([string]$PersonalAccessToken)

    if (-not [string]::IsNullOrWhiteSpace($PersonalAccessToken)) {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PersonalAccessToken"))
        return @{ Authorization = "Basic $encoded" }
    }

    $tokenOutput = & az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken --output tsv 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($tokenOutput -join ''))) {
        throw "Unable to obtain an Azure DevOps access token. Sign in with Azure CLI or provide -Pat."
    }
    return @{ Authorization = "Bearer $(($tokenOutput -join '').Trim())" }
}

function Invoke-AzDoRestGet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][System.Collections.Hashtable]$Headers
    )

    $items = @()
    $nextUri = $Uri
    do {
        $response = Invoke-WebRequest -Uri $nextUri -Headers $Headers -Method Get -UseBasicParsing
        $body = $response.Content | ConvertFrom-Json
        if ($null -ne $body.value) { $items += @($body.value) }
        elseif ($null -ne $body) { $items += $body }
        $continuation = $response.Headers['x-ms-continuationtoken']
        if ($continuation) {
            $separator = if ($nextUri.Contains('?')) { '&' } else { '?' }
            $nextUri = "$Uri${separator}continuationToken=$([Uri]::EscapeDataString([string]$continuation))"
        }
        else { $nextUri = $null }
    } while ($nextUri)
    return , $items
}

function Invoke-AzDoProjectOverview {
    <# Internal entry point; dot-source this script in Pester and call this function directly. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$OrganizationUrl,
        [Parameter(Mandatory)][string]$WorkbookPath,
        [string]$PersonalAccessToken,
        [string[]]$ProjectNames
    )

    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        throw 'The ImportExcel module is required. Install it with: Install-Module ImportExcel'
    }
    Import-Module ImportExcel -ErrorAction Stop

    $organizationUrl = $OrganizationUrl.TrimEnd('/')
    $headers = Get-AzDoAuthorizationHeader -PersonalAccessToken $PersonalAccessToken
    $errors = [System.Collections.Generic.List[object]]::new()
    $projects = @(Invoke-AzDoCliJson -ArgumentList @('devops', 'project', 'list', '--org', $organizationUrl, '--output', 'json'))
    if ($ProjectNames -and $ProjectNames.Count -gt 0) {
        $projects = @($projects | Where-Object { $ProjectNames -contains $_.name })
    }

    $repositories = @()
    $pipelines = @()
    $teams = @()
    $variableGroups = @()
    $serviceConnections = @()
    foreach ($currentProject in $projects) {
        $projectName = [string]$currentProject.name
        $projectId = [string]$currentProject.id
        $projectArgument = @('--project', $projectName, '--org', $organizationUrl, '--output', 'json')

        foreach ($report in @(
                @{ Name = 'Repositories'; Command = @('repos', 'list') },
                @{ Name = 'Pipelines'; Command = @('pipelines', 'list') },
                @{ Name = 'Teams'; Command = @('devops', 'team', 'list') },
                @{ Name = 'Variable Groups'; Command = @('pipelines', 'variable-group', 'list') },
                @{ Name = 'Service Connections'; Command = @('devops', 'service-endpoint', 'list') }
            )) {
            try {
                $rows = @(Invoke-AzDoCliJson -ArgumentList (@($report.Command) + $projectArgument))
                foreach ($row in $rows) {
                    $row | Add-Member -NotePropertyName Project -NotePropertyValue $projectName -Force
                    switch ($report.Name) {
                        'Repositories' { $repositories += $row }
                        'Pipelines' { $pipelines += $row }
                        'Teams' { $teams += $row }
                        'Variable Groups' { $variableGroups += $row }
                        'Service Connections' { $serviceConnections += $row }
                    }
                }
            }
            catch {
                $errors.Add([pscustomobject]@{ Project = $projectName; Area = $report.Name; Error = $_.Exception.Message })
            }
        }

        # The CLI does not expose all project metadata consistently; use REST as a fallback source.
        if (-not $currentProject.description) {
            try {
                $details = Invoke-RestMethod -Uri "$organizationUrl/_apis/projects/$projectId`?api-version=7.1" -Headers $headers -Method Get
                if ($details.description) { $currentProject | Add-Member -NotePropertyName description -NotePropertyValue $details.description -Force }
            }
            catch {
                $errors.Add([pscustomobject]@{ Project = $projectName; Area = 'Project details'; Error = $_.Exception.Message })
            }
        }
    }

    $summary = @(
        [pscustomobject]@{ Metric = 'Projects'; Count = $projects.Count },
        [pscustomobject]@{ Metric = 'Repositories'; Count = $repositories.Count },
        [pscustomobject]@{ Metric = 'Pipelines'; Count = $pipelines.Count },
        [pscustomobject]@{ Metric = 'Teams'; Count = $teams.Count },
        [pscustomobject]@{ Metric = 'Variable Groups'; Count = $variableGroups.Count },
        [pscustomobject]@{ Metric = 'Service Connections'; Count = $serviceConnections.Count },
        [pscustomobject]@{ Metric = 'Collection errors'; Count = $errors.Count }
    )

    $outputDirectory = Split-Path -Parent $WorkbookPath
    if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    $sheets = @(
        @{ Name = 'Executive Summary'; Data = $summary },
        @{ Name = 'Projects'; Data = $projects },
        @{ Name = 'Repositories'; Data = $repositories },
        @{ Name = 'Pipelines'; Data = $pipelines },
        @{ Name = 'Teams'; Data = $teams },
        @{ Name = 'Variable Groups'; Data = $variableGroups },
        @{ Name = 'Service Connections'; Data = $serviceConnections },
        @{ Name = 'Errors'; Data = @($errors) }
    )
    $firstSheet = $true
    foreach ($sheet in $sheets) {
        $exportParameters = @{ InputObject = @($sheet.Data); Path = $WorkbookPath; WorksheetName = $sheet.Name; AutoSize = $true; FreezeTopRow = $true }
        if (-not $firstSheet) { $exportParameters.Append = $true }
        Export-Excel @exportParameters
        $firstSheet = $false
    }

    [pscustomobject]@{
        Organization = $organizationUrl
        OutputPath   = $WorkbookPath
        ProjectCount = $projects.Count
        ErrorCount   = $errors.Count
    }
}

function Test-PesterInvocation {
    foreach ($frame in @(Get-PSCallStack)) {
        if ($frame.FunctionName -match '(?i)Pester|^(Describe|Context|It|BeforeAll|BeforeEach|AfterAll|AfterEach)$' -or
            $frame.ScriptName -match '(?i)\.Tests?\.ps1$') {
            return $true
        }
    }
    return $false
}

<# if (-not $env:TF_BUILD) {
    $env:AGENT_WORKFOLDER =
    $env:AZDO_ORGANIZATION
    $env:AZDO_PERSONAL_ACCESS_TOKEN =
}
 #>


# Dot-sourcing only defines functions; do not run the report when called by Pester.
if (-not (Test-PesterInvocation)) {
    if ([string]::IsNullOrWhiteSpace($Organization)) {
        throw 'Specify -Organization or set the AZDO_ORGANIZATION environment variable.'
    }
    Invoke-AzDoProjectOverview -OrganizationUrl $Organization -WorkbookPath $OutputPath -PersonalAccessToken $Pat -ProjectNames $Project
}
else {
    Write-Host 'Skipping report generation because it is being invoked by Pester.'
}

