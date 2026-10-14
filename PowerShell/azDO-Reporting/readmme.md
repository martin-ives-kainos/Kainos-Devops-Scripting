# Azure Devops Reporting

## A good approach is to use:

- Azure DevOps CLI (az devops)
- ImportExcel PowerShell module
- Azure DevOps REST API where the CLI does not expose sufficient detail

The report can include:
- Organisation
- Project Name
- Description
- Visibility
- State
- Process Template
- Default Team
- Created Date
- Last Update Date
- Repository Count
- Pipeline Count
- Variable Group Count
- Service Connection Count
- Board Area Paths
- Team Count
- Project Administrators

## Prerequisites

~~~:PowerShell
# Azure CLI
az extension add --name azure-devops

# ImportExcel
Install-Module ImportExcel -Scope CurrentUser

Authenticate:
PowerShell
az login

az devops configure `
--defaults organization=https://dev.azure.com/MyOrganisation
~~~

