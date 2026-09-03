New-Module -Name "PesterHelper" -ScriptBlock {
    function New-TestTempObject {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false,
                Position = 0,
                ValueFromPipeline = $true,
                ValueFromPipelineByPropertyName = $true,
                HelpMessage = "Number of properties.")]
            [ValidateRange(1, 99)]
            [int]
            $PropertyCount = 10
        )
        $tObj = (New-Object psobject)
        for ($index = 0; $index -lt $PropertyCount; $index++) {
            $tObj | Add-Member -MemberType NoteProperty -Name ("TestName{0:00}" -f $index) -Value ("TestValue{0:00}" -f $index)
        }
        return $tObj
    }

    function New-TestHashTable {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false,
                Position = 0,
                ValueFromPipeline = $true,
                ValueFromPipelineByPropertyName = $true,
                HelpMessage = "Number of properties.")]
            [ValidateRange(1, 99)]
            [int]
            $PropertyCount = 10
        )
        $table = @{}
        for ($keyIndex = 0; $keyIndex -lt $PropertyCount; $keyIndex++) {
            $table.Add(("TestKey{0:00}" -f $keyIndex), @{})
            for ($index = 0; $index -lt $PropertyCount; $index++) {
                $table[("TestKey{0:00}" -f $keyIndex)].Add(("TestName{0:00}" -f $index), ("TestValue{0:00}" -f $index))
            }
        }
        return $table
    }

    function ConvertFrom-JsonFile {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true,
                Position = 0,
                ValueFromPipeline = $true,
                ValueFromPipelineByPropertyName = $true,
                HelpMessage = "The full path to the json file")]
            [ValidateNotNullOrEmpty()]
            [string]
            $Path,

            [switch]$AsHashTable
        )
        begin {
            $funcName = (Get-PSCallStack)[0].FunctionName.Replace('<Begin>', '')
            Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} STARTED' -f (Get-Date), $funcName)
            if (!(Test-Path $Path -PathType Leaf)) {
                throw "Unable to find source file $Path"
            }
        }
        process {
            if ($PSVersionTable.PSVersion.Major -eq 5) {
                $returnObj = ConvertFrom-Json -InputObject (Get-Content -Path $Path -Raw)

                if ($AsHashTable) {
                    return (ConvertTo-Hashtable -InputObject $returnObj)
                }
                return (ConvertFrom-Json -InputObject (Get-Content -Path $Path -Raw))

            }
            if ($AsHashTable) {
                return (ConvertFrom-Json -AsHashtable -Depth 99 -InputObject (Get-Content -Path $Path -Raw))
            }
            return (ConvertFrom-Json -Depth 99 -InputObject (Get-Content -Path $Path -Raw))
        }
        end {
            Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} ENDED' -f (Get-Date), $funcName)
        }
    }

    function Get-ParamValidationErrMessages {
        [CmdletBinding()]
        param (
            [hashtable]$CustomErrors = @{}
        )
        begin {
            $funcName = "Get-ParamValidationErrMessages"
            Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} STARTED' -f (Get-Date), $funcName)
        }
        process {
            # Default to Powershell Core
            $stdErrors = @{
                "_Default"       = "xxxxxxx {0}"
                "NullOrEmpty"    = "Cannot validate argument on parameter '{0}'. The argument is null or empty. Provide an argument that is not null or empty, and then try the command again."
                "CannotConvert"  = 'Cannot process argument transformation on parameter ''{0}''. Cannot convert the "{1}" value of type "{2}" to type "{3}".'
                "PathTestError"  = 'Cannot validate argument on parameter ''{0}''. The " (Test-Path $_ -PathType Container) " validation script for the argument with value "{1}" did not return a result of True. Determine why the validation script failed, and then try the command again.'
                "ValidSet"       = 'Cannot validate argument on parameter ''{0}''. The argument "{1}" does not belong to the set "{2}" specified by the ValidateSet attribute. Supply an argument that is in the set and then try the command again.'
                "ElementIsNull"  = 'Cannot validate argument on parameter ''{0}''. The argument is null, empty, or an element of the argument collection contains a null value. Supply a collection that does not contain any null values and then try the command again.'
                "FindPath"       = "Cannot find path '{0}' because it does not exist."
                "FindExtn"       = "File '{0}' does not have the required extension."
                "ScriptValid"    = 'Cannot validate argument on parameter ''{0}''. The "{1}" validation script for the argument with value "{2}" did not return a result of True. Determine why the validation script failed, and then try the command again.'
                "LoadingObjFile" = "Error loading object from '{0}'"
            }

            foreach ($key in $CustomErrors) {
                if ($stdErrors.ContainsKey($key)) {
                    $stdErrors[$key] = $CustomErrors[$key]
                } else {
                    $stdErrors.Add($key, $CustomErrors[$key])
                }
            }

            return ($stdErrors)
        }
        end {
            Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} ENDED' -f (Get-Date), $funcName)
        }
    }

    function ConvertTo-Hashtable {
        <#
            .SYNOPSIS
                Converts a custom object into a hashtable
            .DESCRIPTION
                Converts a custom object into a hashtable
            .PARAMETER InputObject
                Object to convert.
        #>
        [CmdletBinding()]
        [OutputType('hashtable')]
        param (
            [Parameter(Mandatory = $true,
                Position = 0,
                ValueFromPipeline = $true,
                ValueFromPipelineByPropertyName = $true,
                HelpMessage = "Object to convert.")]
            [ValidateNotNullOrEmpty()]
            [object]
            $InputObject
        )
        begin {
            $funcName = (Get-PSCallStack)[0].FunctionName.Replace('<Begin>', '')
            Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} STARTED' -f (Get-Date), $funcName)

            <#  Return null if the input is null. This can happen when calling the function
                recursively and a property is null #>
            if ($null -eq $InputObject) {
                return $null
            }

        }
        process {
            <#  Check if the input is an array or collection. If so, we also need to convert
                those types into hash tables as well. This function will convert all child
                objects into hash tables (if applicable) #>
            if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
                $collection = @(
                    foreach ($object in $InputObject) {
                        ConvertTo-Hashtable -InputObject $object
                    }
                )

                <# Return the array but don't enumerate it because the object may be pretty complex #>
                Write-Output -NoEnumerate $collection
            } elseif ($InputObject -is [psobject]) {
                <#  If the object has properties that need enumeration Convert it to its own hash table and return it #>
                $hash = @{}
                foreach ($property in $InputObject.PSObject.Properties) {
                    $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
                }
                return $hash
            } else {
                <#  If the object isn't an array, collection, or other object, it's already a hash table
                    So just return it. #>
                $InputObject
            }

        }
        end {
            Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} ENDED' -f (Get-Date), $funcName)
        }
    }
    function CreateConfigTokenizedTestFile {
        param (
            [string]$Path,
            [int]$Count = 10,
            [int]$GroupCount = 3,
            [string]$TokenText = "ValidToken"
        )
        New-Item $Path -ItemType File -Force | Out-Null
        for ($gindex = 0; $gindex -lt $GroupCount; $gindex++) {
            for ($index = 0; $index -lt $Count; $index++) {
                $validToken = ("{1}{0:000}" -f $index,$TokenText)
                $invalidToken = ("<In{1}{0:000}>" -f $index,$TokenText)
                Add-Content $Path -Value "Test token named $validToken should be found and replaced with: '{$validToken}'"
                Add-Content $Path -Value "Test other delimited token '$invalidToken' should not found or replaced"
            }
        }
    }
    function CreateStartPointFolder {
        [CmdletBinding()]
        param (
            [string]$DeployScriptsPath,
            [string]$SourceScriptPath,
            [string]$ConfigFileName = "web.config",
            [string]$DeployConfigFileSuffix = "_Asp.Net.json",
            [string]$ZipFileSuffix = "_Asp.Net.zip"

        )
        if (!(Test-Path $DeployScriptsPath -PathType Container)) {
            New-Item $DeployScriptsPath -ItemType Directory -Force | Out-Null
        }
        $RootPath = (Split-Path -Parent $DeployScriptsPath)
        Copy-Item $SourceScriptPath $RootPath -Recurse -Force

        CreateDeployConfigJsonFile -Path (Join-Path $DeployScriptsPath ("Test.App{0}" -f $DeployConfigFileSuffix))

        $testZipPath = Join-Path $RootPath ("Test.App\1.99.{0:yyyyMMdd}.1" -f (Get-Date))
        New-Item $testZipPath -ItemType Directory -Force | Out-Null

        CreateConfigTokenizedTestFile (Join-Path $testZipPath $ConfigFileName)

        for ($subfolderIndex = 0; $subfolderIndex -lt 10; $subfolderIndex++) {
            $subFolder = Join-Path $testZipPath ("TestSubFolder_{0:000}" -f $subfolderIndex)
            New-Item $subFolder -ItemType Directory -Force | Out-Null
            for ($fileIndex = 0; $fileIndex -lt 10; $fileIndex++) {
                New-Item (Join-Path $subFolder ("TestFile-{0:000}.{1:000}" -f $subfolderIndex, $fileIndex)) -ItemType File -Force | Out-Null
            }
        }

        Compress-Archive $testZipPath -DestinationPath (Join-Path $RootPath ("Test.App{0}" -f $ZipFileSuffix))
        Remove-Item (Split-Path -Parent $testZipPath) -Force -Recurse
    }

    function CreateDeployConfigJsonFile {
        param (
            [string]$Path,
            [hashtable]$Settings = @{
                "WebsiteName"           = "Default Web Site"
                "ApplicationFolderPath" = "TestDrive\inetpub\wwwroot\Test.App"
                "ApplicationType"       = "WebApplication"
                "AppPoolName"           = "Test.App"
                "ApplicationName"       = "Test.App"
                "AppPoolDotNetVersion"  = "v4.0"
                "ConfigFileName"        = "web.config"
            }
        )
        $configObj = New-Object psobject
        $Settings.Keys | ForEach-Object {
            $configObj | Add-Member -MemberType NoteProperty -Name $_ -Value $Settings[$_]
        }
        Set-Content $Path -Value (ConvertTo-Json -Depth 99 -InputObject $configObj)
    }

    function GetScriptFileNames {
        [CmdletBinding()]
        [OutputType([string[]])]
        param (
            [Parameter(Mandatory)]
            [ValidateScript({ (Test-Path $_ -PathType Container) })]
            [string]$Path,

            [string]$Filter = "*.ps1"
        )
        return (Get-ChildItem $Path -Filter $Filter | Select-Object -ExpandProperty BaseName)
    }

    function GetTestCases {
        [CmdletBinding()]
        [OutputType([array])]
        param (
<#             [Parameter()]
            [TypeName]
            $ParameterName #>
        )
        return @(
            @{ Name = "Name1"; Value = 'Value1'}
        )
    }
    function New-TestIniFile {
        param (
            [string]$Path
        )
        if ($Path -notmatch '\.ini$') {
            $Path += '.ini'
        }
        $FullPath = Join-Path $TestDrive (Split-Path $Path -Leaf)
        Get-Content $Path | Set-Content -Path $FullPath
        return $FullPath
    }
}