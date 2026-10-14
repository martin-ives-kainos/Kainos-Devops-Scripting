# Complete Project Inventory Report

This is a set of extracts fro the current project, depends on the authentication and/or running context within an Azure Pipeline job.

~~~:PowerShell

Import-Module ImportExcel
$OrgUrl = "https://dev.azure.com/MyOrganisation"

# Get all projects
$Projects = az devops project list --org $OrgUrl --output json | ConvertFrom-Json
$Report = foreach ($Project in $Projects.value) {
    Write-Host "Processing $($Project.name)..."

    # Repositories
    $Repos = az repos list --project $Project.name --org $OrgUrl --output json 2>$null | ConvertFrom-Json

    # Pipelines
    $Pipelines = az pipelines list --project $Project.name --org $OrgUrl --output json 2>$null | ConvertFrom-Json

    # Teams
    $Teams = az devops team list --project $Project.name --org $OrgUrl --output json 2>$null | ConvertFrom-Json

    [PSCustomObject]@{
        ProjectName      = $Project.name
        Id               = $Project.id
        Description      = $Project.description
        Visibility       = $Project.visibility
        State            = $Project.state
        Url              = $Project.url
        Revision         = $Project.revision
        RepositoryCount  = @($Repos).Count
        PipelineCount    = @($Pipelines).Count
        TeamCount        = @($Teams).Count
    }
}

$ExcelFile = ".\AzureDevOps-ProjectReport.xlsx"
$Report | Export-Excel -Path $ExcelFile -WorksheetName Projects -TableName Projects -FreezeTopRow -BoldTopRow -AutoSize -AutoFilter

Write-Host "Report created: $ExcelFile"

~~~
