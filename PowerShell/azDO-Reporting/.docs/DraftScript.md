# Draft 'production-ready' PowerShell script

## Summary

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


## Scripting

### Main

~~~:PowerShell

Install-Module ImportExcel -Scope CurrentUser -Force

az extension add --name azure-devops

Usage
$PAT = "<PAT>"

.\Get-AzDevOpsInventory.ps1 `
    -OrganisationUrl "https://dev.azure.com/contoso" `
    -Pat $PAT `
    -OutputFile "C:\Reports\AzDO-Inventory.xlsx"

Get-AzDevOpsInventory.ps1
param(
    [Parameter(Mandatory)]
    [string]$OrganisationUrl,

    [Parameter(Mandatory)]
    [string]$Pat,

    [string]$OutputFile = ".\AzureDevOpsInventory.xlsx"
)

#Requires -Modules ImportExcel

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module ImportExcel

# -------------------------------------------------------
# Helper Functions
# -------------------------------------------------------

function Invoke-AzDoRestMethod {
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    try {

        $base64 = :ToBase64String(
            [Text.Encoding]::ASCII.GetBytes(":$Pat")
        )

        $headers = @{
            Authorization = "Basic $base64"
        }

        Invoke-RestMethod `
            -Uri $Uri `
            -Headers $headers `
            -Method Get
    }
    catch {
        Write-Warning "Failed REST call: $Uri"
        Write-Warning $_
        return $null
    }
}

function Get-SafeCount {
    param($Object)

    if ($null -eq $Object) {
        return 0
    }

    @($Object).Count
}

Write-Host ""
Write-Host "============================================="
Write-Host "Azure DevOps Organisation Inventory"
Write-Host "============================================="
Write-Host ""

# -------------------------------------------------------
# Login Validation
# -------------------------------------------------------

az devops configure `
    --defaults organization=$OrganisationUrl 1>$null

Write-Host "Retrieving Projects..."

$ProjectList = az devops project list `
    --org $OrganisationUrl `
    --output json

$Projects = ($ProjectList | ConvertFrom-Json).value

if (!$Projects) {
    throw "No projects found."
}

# -------------------------------------------------------
# Collections
# -------------------------------------------------------

$ProjectSheet            = [System.Collections.Generic.List[Object]]::new()
$RepositorySheet         = [System.Collections.Generic.List[Object]]::new()
$PipelineSheet           = [System.Collections.Generic.List[Object]]::new()
$TeamSheet               = [System.Collections.Generic.List[Object]]::new()
$VariableGroupSheet      = [System.Collections.Generic.List[Object]]::new()
$ServiceConnectionSheet  = [System.Collections.Generic.List[Object]]::new()

# -------------------------------------------------------
# Process Projects
# -------------------------------------------------------

foreach ($Project in $Projects) {

    Write-Host "Processing [$($Project.name)]"

    try {

        # ----------------------------------------
        # Project Detail
        # ----------------------------------------

        $ProjectDetail =
            az devops project show `
                --project $Project.name `
                --org $OrganisationUrl `
                --output json |
            ConvertFrom-Json

        $ProcessTemplate =
            $ProjectDetail.capabilities.processTemplate.templateName

        # ----------------------------------------
        # Repositories
        # ----------------------------------------

        $Repos =
            az repos list `
                --project $Project.name `
                --org $OrganisationUrl `
                --output json 2>$null |
            ConvertFrom-Json

        foreach ($Repo in ($Repos | Where-Object { $_ })) {

            $RepositorySheet.Add(
                [PSCustomObject]@{
                    Project       = $Project.name
                    Repository    = $Repo.name
                    DefaultBranch = $Repo.defaultBranch
                    Size          = $Repo.size
                    RemoteUrl     = $Repo.remoteUrl
                }
            )
        }

        # ----------------------------------------
        # Pipelines
        # ----------------------------------------

        $Pipelines =
            az pipelines list `
                --project $Project.name `
                --org $OrganisationUrl `
                --output json 2>$null |
            ConvertFrom-Json

        foreach ($Pipeline in ($Pipelines | Where-Object { $_ })) {

            $PipelineSheet.Add(
                [PSCustomObject]@{
                    Project      = $Project.name
                    PipelineName = $Pipeline.name
                    Id           = $Pipeline.id
                    Folder       = $Pipeline.folder
                    Revision     = $Pipeline.revision
                }
           )
        }

        # ----------------------------------------
        # Teams
        # ----------------------------------------

        $Teams =
            az devops team list `
                --project $Project.name `
                --org $OrganisationUrl `
                --output json 2>$null |
            ConvertFrom-Json

        foreach ($Team in ($Teams | Where-Object { $_ })) {

            $TeamSheet.Add(
                [PSCustomObject]@{
                    Project = $Project.name
                    Team    = $Team.name
                    TeamId  = $Team.id
                }
            )
        }

        # ----------------------------------------
        # Variable Groups
        # ----------------------------------------

        $VariableGroupsUri =
            "$OrganisationUrl/$($Project.name)/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"

        $VariableGroups =
            Invoke-AzDoRestMethod -Uri $VariableGroupsUri

        foreach ($Group in ($VariableGroups.value | Where-Object { $_ })) {

            $VariableGroupSheet.Add(
                [PSCustomObject]@{
                    Project       = $Project.name
                    VariableGroup = $Group.name
                    Id            = $Group.id
                    Variables     = $Group.variables.Count
                }
            )
        }

        # ----------------------------------------
        # Service Connections
        # ----------------------------------------

        $ServiceConnectionsUri =
            "$OrganisationUrl/$($Project.name)/_apis/serviceendpoint/endpoints?api-version=7.1"

        $ServiceConnections =
            Invoke-AzDoRestMethod -Uri $ServiceConnectionsUri

        foreach ($Connection in ($ServiceConnections.value | Where-Object { $_ })) {

            $ServiceConnectionSheet.Add(
                [PSCustomObject]@{
                    Project           = $Project.name
                    ServiceConnection = $Connection.name
                    Type              = $Connection.type
                    Id                = $Connection.id
                }
            )
        }

        # ----------------------------------------
        # Project Summary
        # ----------------------------------------

        $ProjectSheet.Add(
            [PSCustomObject]@{
                ProjectName            = $Project.name
                Id                     = $Project.id
                Description            = $Project.description
                Visibility             = $Project.visibility
                State                  = $Project.state
                ProcessTemplate        = $ProcessTemplate
                Revision               = $Project.revision
                RepositoryCount        = Get-SafeCount $Repos
                PipelineCount          = Get-SafeCount $Pipelines
                TeamCount              = Get-SafeCount $Teams
                VariableGroupCount     = Get-SafeCount $VariableGroups.value
                ServiceConnectionCount = Get-SafeCount $ServiceConnections.value
            }
        )
    }
    catch {
        Write-Warning "Failed processing project [$($Project.name)]"
        Write-Warning $_
    }
}

# -------------------------------------------------------
# Executive Summary
# -------------------------------------------------------

$Summary = [PSCustomObject]@{
    TotalProjects           = $ProjectSheet.Count
    TotalRepositories       = $RepositorySheet.Count
    TotalPipelines          = $PipelineSheet.Count
    TotalTeams              = $TeamSheet.Count
    TotalVariableGroups     = $VariableGroupSheet.Count
    TotalServiceConnections = $ServiceConnectionSheet.Count
    ReportGenerated         = (Get-Date)
}

# -------------------------------------------------------
# Excel Export
# -------------------------------------------------------

if (Test-Path $OutputFile) {
    Remove-Item $OutputFile -Force
}

$Summary |
    Export-Excel `
        -Path $OutputFile `
        -WorksheetName Summary `
        -TableStyle Medium6 `
        -AutoSize

$ProjectSheet |
    Export-Excel `
        -Path $OutputFile `
        -WorksheetName Projects `
        -TableStyle Medium2 `
        -FreezeTopRow `
        -AutoSize `
        -AutoFilter

$RepositorySheet |
    Export-Excel `
        -Path $OutputFile `
        -WorksheetName Repositories `
        -TableStyle Medium2 `
        -FreezeTopRow `
        -AutoSize `
        -AutoFilter

$PipelineSheet |
    Export-Excel `
        -Path $OutputFile `
        -WorksheetName Pipelines `
        -TableStyle Medium2 `
        -FreezeTopRow `
        -AutoSize `
        -AutoFilter

$TeamSheet |
    Export-Excel `
        -Path $OutputFile `
        -WorksheetName Teams `
        -TableStyle Medium2 `
        -FreezeTopRow `
        -AutoSize `
        -AutoFilter

$VariableGroupSheet |
    Export-Excel `
        -Path $OutputFile `
        -WorksheetName VariableGroups `
        -TableStyle Medium2 `
        -FreezeTopRow `
        -AutoSize `
        -AutoFilter

$ServiceConnectionSheet |
    Export-Excel `
        -Path $OutputFile `
        -WorksheetName ServiceConnections `
        -TableStyle Medium2 `
        -FreezeTopRow `
        -AutoSize `
        -AutoFilter

# -------------------------------------------------------
# Charts
# -------------------------------------------------------

$Excel = Open-ExcelPackage $OutputFile

$SummaryWS = $Excel.Workbook.Worksheets["Summary"]

Add-ExcelChart `
    -Worksheet $SummaryWS `
    -ChartType PieExploded3D `
    -Title "Azure DevOps Assets" `
    -Range "A1:B6" `
    -Height 400 `
    -Width 600 `
    -Row 10 `
    -Column 1

Close-ExcelPackage $Excel

Write-Host ""
Write-Host "Report completed successfully"
Write-Host "Output: $OutputFile"
Write-Host ""

~~~

## Enhancements

- Parallel project processing using ForEach-Object -Parallel (PowerShell 7).
- Branch policy inventory via the Policy REST API.
- Agent pools and deployment pools.
- Build pipelines and release pipelines separately.
- Environment inventory and approvals.
- User/group permissions audit.
- Inactive repositories and stale pipelines reporting.
- Workbook dashboard with pivot tables and charts.
- HTML report generation alongside Excel.
- Historical snapshots for trend analysis.