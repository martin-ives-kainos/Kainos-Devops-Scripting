@echo off
# set AGENT_DIRECTORY=D:\Agent\A1
set AGENT_NAME=%COMPUTERNAME%-A1
set AGENT_POOL=ivesma-sh
set AZDO_URL=https://dev.azure.com/ivesma
set /p "AGENT_TOKEN=Agent token: "

choco install azure-pipelines-agent --params "'/Directory:%AGENT_DIRECTORY% /Token:%AGENT_TOKEN% /Pool:%AGENT_POOL% /Url:%AZDO_URL /AgentName:%AGENT_NAME% /ClearDirectory'"
:: choco install azure-pipelines-agent --params "'/Directory:D:\Agent\A1 /Token:xxxxxxxxxxx /Pool:ivesma-sh /Url:https://dev.azure.com/ivesma /AgentName:%COMPUTERNAME%-A1 /ClearDirectory'"
