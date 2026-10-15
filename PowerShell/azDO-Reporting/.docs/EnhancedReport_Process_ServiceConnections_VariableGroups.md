# Enhanced Report with Process, Service Connections and Variable Groups

This produces the kind of governance and estate inventory report typically used by Azure DevOps platform teams and auditors.

## Some details require REST API calls.

~~~:PowerShell

$PAT = $env:AZDO_PAT

$Base64PAT = :ToBase64String(
    [Text.Encoding]::ASCII.GetBytes(":$PAT")
)

$Headers = @{
    Authorization = "Basic $Base64PAT"
}
~~~

## Service Connections Count

~~~:PowerShell

$EndpointsUri = "$OrgUrl/$($Project.name)/_apis/serviceendpoint/endpoints?api-version=7.1"

$EndpointCount = (
    Invoke-RestMethod `
        -Uri $EndpointsUri `
        -Headers $Headers
).value.Count

~~~

## Variable Groups Count

~~~:PowerShell

$VarGroupUri =
"$OrgUrl/$($Project.name)/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"

$VarGroupCount = (
    Invoke-RestMethod `
        -Uri $VarGroupUri `
        -Headers $Headers
).value.Count

~~~

Process Template

~~~:PowerShell

$ProjectDetails = az devops project show `
    --project $Project.name `
    --org $OrgUrl `
    --output json | ConvertFrom-Json

$ProcessName = $ProjectDetails.capabilities.processTemplate.templateName

~~~

## Multi-Worksheet Executive Report

### Create separate worksheets:

~~~:PowerShell

$Projects       | Export-Excel $ExcelFile -WorksheetName Projects
$Repositories   | Export-Excel $ExcelFile -WorksheetName Repositories
$Pipelines      | Export-Excel $ExcelFile -WorksheetName Pipelines
$ServiceConns   | Export-Excel $ExcelFile -WorksheetName ServiceConnections
$VariableGroups | Export-Excel $ExcelFile -WorksheetName VariableGroups
$Teams          | Export-Excel $ExcelFile -WorksheetName Teams

~~~

### Add formatting:

~~~:PowerShell

$excel = Open-ExcelPackage $ExcelFile

foreach($ws in $excel.Workbook.Worksheets)
{
    $ws.Cells.AutoFitColumns()
    $ws.View.FreezePanes(2,1)

    Add-ConditionalFormatting `
        -Worksheet $ws `
        -Address "A2:Z5000" `
        -RuleType Expression `
        -ConditionValue 'MOD(ROW(),2)=0'
}

Close-ExcelPackage $excel

~~~

### Power BI Style Summary Worksheet

~~~:PowerShell

$Summary = [PSCustomObject]@{
    Projects           = $Projects.Count
    TotalRepositories  = ($Report.RepositoryCount | Measure-Object -Sum).Sum
    TotalPipelines     = ($Report.PipelineCount | Measure-Object -Sum).Sum
    TotalTeams         = ($Report.TeamCount | Measure-Object -Sum).Sum
}

~~~

### Export:

~~~:PowerShell

$Summary |
 Export-Excel `
    -Path $ExcelFile `
    -WorksheetName Summary `
    -TableStyle Medium6

~~~

## Recommended Enterprise Layout

### Worksheet 1: Executive Summary

Total Projects
Total Repos
Total Pipelines
Total Teams
Total Service Connections
Total Variable Groups

### Worksheet 2: Projects

Name
State
Visibility
Process
Created

### Worksheet 3: Repositories

Project
Repo Name
Size
Default Branch

### Worksheet 4: Pipelines

Project
Pipeline Name
Folder
Revision

### Worksheet 5: Security

Administrators
Service Connections
Permissions

### Worksheet 6: Governance

Variable Groups
Branch Policies
Environments
Agent Pools

## Other Ideas

- Provide the complete production-ready script
- Add repositories, teams, and security details
- Include charts and an executive summary