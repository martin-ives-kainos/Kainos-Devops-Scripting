New-Module -Name 'PesterHelper' -ScriptBlock {


    function ConvertFrom-JsonFile {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true,
                Position = 0,
                ValueFromPipeline = $true,
                ValueFromPipelineByPropertyName = $true,
                HelpMessage = 'The full path to the json file')]
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
        [OutputType('System.Collections.Hashtable')]
        param (
            [Parameter(Mandatory = $true,
                Position = 0,
                ValueFromPipeline = $true,
                ValueFromPipelineByPropertyName = $true,
                HelpMessage = 'Object to convert.')]
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
                Write-Output $collection
            }
            elseif ($InputObject -is [psobject]) {
                <#  If the object has properties that need enumeration Convert it to its own hash table and return it #>
                $hash = @{}
                foreach ($property in $InputObject.PSObject.Properties) {
                    $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
                }
                return $hash
            }
            else {
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
            [string]$TokenText = 'ValidToken'
        )
        New-Item $Path -ItemType File -Force | Out-Null
        for ($globalIndex = 0; $globalIndex -lt $GroupCount; $globalIndex++) {
            for ($index = 0; $index -lt $Count; $index++) {
                $validToken = ('{1}{0:000}' -f $index, $TokenText)
                $invalidToken = ('<In{1}{0:000}>' -f $index, $TokenText)
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
            [string]$ConfigFileName = 'web.config',
            [string]$DeployConfigFileSuffix = '_Asp.Net.json',
            [string]$ZipFileSuffix = '_Asp.Net.zip'

        )
        if (!(Test-Path $DeployScriptsPath -PathType Container)) {
            New-Item $DeployScriptsPath -ItemType Directory -Force | Out-Null
        }
        $RootPath = (Split-Path -Parent $DeployScriptsPath)
        Copy-Item $SourceScriptPath $RootPath -Recurse -Force

        CreateDeployConfigJsonFile -Path (Join-Path $DeployScriptsPath ('Test.App{0}' -f $DeployConfigFileSuffix))

        $testZipPath = Join-Path $RootPath ('Test.App\1.99.{0:yyyyMMdd}.1' -f (Get-Date))
        New-Item $testZipPath -ItemType Directory -Force | Out-Null

        CreateConfigTokenizedTestFile (Join-Path $testZipPath $ConfigFileName)

        for ($subfolderIndex = 0; $subfolderIndex -lt 10; $subfolderIndex++) {
            $subFolder = Join-Path $testZipPath ('TestSubFolder_{0:000}' -f $subfolderIndex)
            New-Item $subFolder -ItemType Directory -Force | Out-Null
            for ($fileIndex = 0; $fileIndex -lt 10; $fileIndex++) {
                New-Item (Join-Path $subFolder ('TestFile-{0:000}.{1:000}' -f $subfolderIndex, $fileIndex)) -ItemType File -Force | Out-Null
            }
        }

        Compress-Archive $testZipPath -DestinationPath (Join-Path $RootPath ('Test.App{0}' -f $ZipFileSuffix))
        Remove-Item (Split-Path -Parent $testZipPath) -Force -Recurse
    }

    function CreateDeployConfigJsonFile {
        param (
            [string]$Path,
            [System.Collections.Hashtable]$Settings = @{
                'WebsiteName'           = 'Default Web Site'
                'ApplicationFolderPath' = 'TestDrive\inetpub\wwwroot\Test.App'
                'ApplicationType'       = 'WebApplication'
                'AppPoolName'           = 'Test.App'
                'ApplicationName'       = 'Test.App'
                'AppPoolDotNetVersion'  = 'v4.0'
                'ConfigFileName'        = 'web.config'
            }
        )
        $configObj = New-Object psobject
        $Settings.Keys | ForEach-Object {
            $configObj | Add-Member -MemberType NoteProperty -Name $_ -Value $Settings[$_]
        }
        Set-Content $Path -Value (ConvertTo-Json -Depth 99 -InputObject $configObj)
    }

    function Get-ParamValidationErrMessage {
        [CmdletBinding()]
        param (
            [System.Collections.Hashtable]$CustomErrors = @{}
        )
        begin {
            $funcName = 'Get-ParamValidationErrMessage'
            Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} STARTED' -f (Get-Date), $funcName)
        }
        process {
            # Default to Powershell Core
            $stdErrors = @{
                '_Default'       = 'xxxxxxx {0}'
                'NullOrEmpty'    = "Cannot validate argument on parameter '{0}'. The argument is null or empty. Provide an argument that is not null or empty, and then try the command again."
                'CannotConvert'  = 'Cannot process argument transformation on parameter ''{0}''. Cannot convert the "{1}" value of type "{2}" to type "{3}".'
                'PathTestError'  = 'Cannot validate argument on parameter ''{0}''. The " (Test-Path $_ -PathType Container) " validation script for the argument with value "{1}" did not return a result of True. Determine why the validation script failed, and then try the command again.'
                'ValidSet'       = 'Cannot validate argument on parameter ''{0}''. The argument "{1}" does not belong to the set "{2}" specified by the ValidateSet attribute. Supply an argument that is in the set and then try the command again.'
                'ElementIsNull'  = 'Cannot validate argument on parameter ''{0}''. The argument is null, empty, or an element of the argument collection contains a null value. Supply a collection that does not contain any null values and then try the command again.'
                'FindPath'       = "Cannot find path '{0}' because it does not exist."
                'FindExtn'       = "File '{0}' does not have the required extension."
                'ScriptValid'    = 'Cannot validate argument on parameter ''{0}''. The "{1}" validation script for the argument with value "{2}" did not return a result of True. Determine why the validation script failed, and then try the command again.'
                'LoadingObjFile' = "Error loading object from '{0}'"
            }

            foreach ($key in $CustomErrors) {
                if ($stdErrors.ContainsKey($key)) {
                    $stdErrors[$key] = $CustomErrors[$key]
                }
                else {
                    $stdErrors.Add($key, $CustomErrors[$key])
                }
            }

            return ($stdErrors)
        }
        end {
            Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} ENDED' -f (Get-Date), $funcName)
        }
    }

    function GetScriptFileNames {
        [CmdletBinding()]
        [OutputType([string[]])]
        param (
            [Parameter(Mandatory)]
            [ValidateScript({ (Test-Path $_ -PathType Container) })]
            [string]$Path,

            [string]$Filter = '*.ps1'
        )
        return (Get-ChildItem $Path -Filter $Filter | Select-Object -ExpandProperty BaseName)
    }

    function Get-ModuleManifestData {
        [CmdletBinding()]
        [OutputType([System.Collections.Hashtable])]
        param (
            [Parameter(Mandatory)]
            [ValidateScript({ (Test-Path $_ -PathType Leaf) })]
            [Alias('Path')]
            [string]$ManifestFile,
            [Hashtable]$DefaultCustomData = @{
                ManifestFile     = $null
                ModuleName       = $null
                ModulePath       = $null
                ModuleVersion    = $null
                ScriptScopes     = @('classes', 'private', 'public', 'internal')
                TestFolders      = @('tests')
                TestExcludeRules = @()
                TestTags         = @('Unit', 'Integration', 'Functional', 'Smoke', 'Debug', 'All')
            }
        )
        begin {
            Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} BEGIN' -f (Get-Date), $funcName)
        }
        process {
            $t_Manifest = Import-PowerShellDataFile -Path (Resolve-Path -LiteralPath $ManifestFile -ErrorAction SilentlyContinue)

            if ($t_Manifest.Keys -notcontains 'PrivateData') {
                $t_Manifest['PrivateData'] = @{
                    PSData = @{}
                }
            }

            # Ensure PrivateData has the expected defaultstructure
            foreach ($key in $DefaultCustomData.Keys) {
                if ($t_Manifest['PrivateData'].Keys -notcontains $key) {
                    $t_Manifest['PrivateData'].Add($key, $DefaultCustomData[$key])
                }
                switch ($key) {
                    'ManifestFile' {
                        $t_Manifest['PrivateData'][$key] = $ManifestFile
                    }
                    'ModulePath' {
                        $t_Manifest['PrivateData'][$key] = (Split-Path -Path $ManifestFile -Parent)
                    }
                    'ModuleName' {
                        if ($t_Manifest.Keys -contains 'RootModule') {
                            $t_Manifest['PrivateData'][$key] = ($t_Manifest.RootModule -replace '\.psm1$', '')
                        }
                        else {
                            $t_Manifest['PrivateData'][$key] = ((Split-Path -Path $ManifestFile -Leaf) -replace '\.psd1$', '')
                        }
                    }
                    'ModuleVersion' {
                        if ($t_Manifest.Keys -contains 'ModuleVersion') {
                            $t_Manifest['PrivateData'][$key] = $t_Manifest.ModuleVersion
                        }
                    }
                }
            }

            return ($t_Manifest.PrivateData)
        }
        end {
            Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} ENDED' -f (Get-Date), $funcName)
        }
    }

    function Find-FileInTree {
        param (
            [Parameter(Mandatory)]
            [ValidateScript({ (Test-Path $_ -PathType Container) })]
            [string]$RootPath,

            [Parameter(Mandatory)]
            [Alias('Name')]
            [Alias('Path')]
            [ValidateNotNullOrEmpty()]
            [string]$FileName,

            [int]$MaxDepth = 15,
            [switch]$ReturnStringIfNull
        )
        $depth = 0
        $foundFile = Get-ChildItem -Path $RootPath -Recurse -Filter $FileName -File -ErrorAction SilentlyContinue | Select-Object -First 1
        while ($null -eq $foundFile -and $depth -lt $MaxDepth) {
            $RootPath = Join-Path $RootPath '..' -Resolve
            $foundFile = Get-ChildItem -Path $RootPath -Recurse -Filter $FileName -File -ErrorAction SilentlyContinue | Select-Object -First 1
            $depth++
        }
        if ($ReturnStringIfNull -and ($null -eq $foundFile)) {
            return ("--{0}_NotFound--" -f $FileName)
        }
        return $foundFile.FullName
    }

    function Find-ScriptFile {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [Parameter(Mandatory)]
            [ValidateScript({ (Test-Path $_ -PathType Leaf) })]
            [string]$TestScriptFile
        )
        return (Find-FileInTree -RootPath (Split-Path $TestScriptFile -Parent) -FileName ((Split-Path $TestScriptFile -Leaf) -replace '.tests.ps1$', '.ps1'))
    }

    function Import-TestableModuleFile {
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({ $_.ToLower().Trim().EndsWith('.psd1') -or $_.ToLower().Trim().EndsWith('.psm1') })]
            [string]$ModuleName,
            [Parameter(Mandatory)]
            [ValidateScript({ (Test-Path $_ -PathType Container) })]
            [string]$ModulePath
        )
        $foundModule = Find-FileInTree -RootPath $ModulePath -FileName $ModuleName
        if ($null -eq $foundModule) {
            throw "Module file '$ModuleName' not found in path '$ModulePath' or its parent directories."
        }
        Import-Module $foundModule -Force -Verbose
    }

    function Invoke-MockAzCliInternalError {
        param (
            [Parameter(Mandatory)]
            [ValidateRange(-1, 9)]
            [int]$ExitCode,
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$ErrorMessage
        )
        $global:LASTEXITCODE = $ExitCode
        $result = @{
            StdOut   = @($ErrorMessage)
            ExitCode = $global:LASTEXITCODE
        }
        try {
            Write-Host ('[Invoke-AzCli.tests] {0} ---Mocking Invoke-AzCliInternal--- {1}' -f $____Pester.CurrentTest.Name, $result.StdOut[0]) -BackgroundColor Blue -ForegroundColor White
            throw $result.StdOut[0]
        }
        catch {
            $result.StdOut += $_
        }
        return $result
    }

    function CleanUpTemporaryGlobalVariables {
        [CmdletBinding()]
        [OutputType([System.Collections.Hashtable])]
        param (
            [string]$VarPrefix = 'pester_temp_',
            [string]$TestName = 'CleanUpTemporaryGlobalVariables'
        )
        foreach ($frame in (Get-PSCallStack)) {
            $loc = $frame.Location.ToString()
            if ($loc.ToLower().Contains('.tests.')) {
                $TestName = ($loc -split ':' | Select-Object -First 1)
                break
            }
        }
        foreach ($varName in (Get-Variable -Scope Global | Select-Object -ExpandProperty Name | Where-Object { $_.StartsWith('pester_temp_' ) }) ) {
            Write-Host "[$TestName] Removing global variable: $varName" -ForegroundColor Green
            Remove-Variable -Name $varName -Scope Global -ErrorAction SilentlyContinue
        }
    }

    function Get-ModuleTestableFolder {
        [CmdletBinding()]
        [OutputType([System.Collections.Hashtable])]
        param (
            [Parameter(Mandatory)]
            [ValidateScript({ (Test-Path $_ -PathType Container) })]
            [Alias('Root')]
            [Alias('Path')]
            [string]$ModulePath,
            [switch]$SkipRoot
        )
        $folderList = @{}
        if (!$SkipRoot) {
            $folderList.Add("Root", $ModulePath)
        }
        Get-ChildItem -Path (Join-Path $PSScriptRoot '..' -Resolve) -Directory -Exclude '.*' | ForEach-Object {
            $folderList.Add($_.Name, $_.FullName)
        }

        return $folderList
    }

    function Get-ModuleTestableScript {
        [CmdletBinding()]
        [OutputType([System.Collections.Hashtable[]])]
        param (
            [Parameter(Mandatory)]
            [ValidateScript({ (Test-Path $_ -PathType Container) })]
            [string]$ModulePath,
            [ValidateSet('Root', 'ScriptFolder')]
            [string]$PathType = 'ScriptFolder',
            [string]$Filter = '*.ps1',
            [string]$Exclude = '*.tests.ps1',
            [System.ObsoleteAttribute("The -Recurse parameter is deprecated. Use -PathType 'ScriptFolder' instead.")]
            [switch]$Recurse
        )

        $scriptFiles = @()

        $p_GetFiles = @{
            Path    = $ModulePath
            Filter  = $Filter
            Exclude = $Exclude
        }

        $subFolderName = $null

        switch ($PathType) {
            'Root' {
                $subFolderName = "Root"
            }
            'ScriptFolder' {
                $subFolderName = (Split-Path $ModulePath -Leaf)
                $p_GetFiles.Add('Recurse', $true)
            }
        }

        foreach ($scriptFile in (Get-ChildItem @p_GetFiles | Select-Object -ExpandProperty FullName)) {
            $newItem = @{
                tcf_ScriptFile = $scriptFile
                tcf_TestFile   = (Split-Path $scriptFile -Leaf) -replace '\.ps1$', '.Tests.ps1'
                tcf_FolderPath = $ModulePath
                tcf_FolderName = $subFolderName
                tcf_TestExists = $false
            }
            $testFile = Find-FileInTree -RootPath $ModulePath -Name $newItem.tcf_TestFile
            if ($null -ne $testFile) {
                $newItem.tcf_TestExists = $true
            }
            $scriptFiles += $newItem
        }
        return $scriptFiles
    }

    function New-TestHashTable {
        [CmdletBinding()]
        [OutputType([System.Collections.Hashtable])]
        param (
            [Parameter(Mandatory = $false,
                Position = 0,
                ValueFromPipeline = $true,
                ValueFromPipelineByPropertyName = $true,
                HelpMessage = 'Number of properties.')]
            [ValidateRange(1, 99)]
            [int]
            $PropertyCount = 10
        )
        begin {
            $table = @{}
        }
        process {
            for ($keyIndex = 0; $keyIndex -lt $PropertyCount; $keyIndex++) {
                $table.Add(('TestKey{0:00}' -f $keyIndex), @{})
                for ($index = 0; $index -lt $PropertyCount; $index++) {
                    $table[('TestKey{0:00}' -f $keyIndex)].Add(('TestName{0:00}' -f $index), ('TestValue{0:00}' -f $index))
                }
            }
        }
        end {
            return $table
        }
    }

    function New-TestTempObject {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false,
                Position = 0,
                ValueFromPipeline = $true,
                ValueFromPipelineByPropertyName = $true,
                HelpMessage = 'Number of properties.')]
            [ValidateRange(1, 99)]
            [int]
            $PropertyCount = 10
        )
        begin {
            $tObj = (New-Object psobject)
        }
        process {
            for ($index = 0; $index -lt $PropertyCount; $index++) {
                $tObj | Add-Member -MemberType NoteProperty -Name ('TestName{0:00}' -f $index) -Value ('TestValue{0:00}' -f $index)
            }
            return $tObj
        }
        end {

        }
    }

    function New-TestIniFile {
        param (
            [string]$Path,
            [switch]$ContentOnly
        )
        if ($Path -notmatch '\.ini$') {
            $Path += '.ini'
        }
        $content = Get-Content $Path
        if ($ContentOnly) {
            return $content
        }
        $FullPath = Join-Path $TestDrive (Split-Path $Path -Leaf)
        $content | Set-Content -Path $FullPath
        return $FullPath
    }

    function New-TestIsPipeline {
        [CmdletBinding()]
        [OutputType([bool])]
        param ()

        if (-not [string]::IsNullOrEmpty($env:TF_BUILD)) {
            Write-Host "Running in Azure Pipeline build." -ForegroundColor Yellow
            return $true
        }
        if (-not [string]::IsNullOrEmpty($env:GITHUB_ACTION)) {
            Write-Host "Running in GitHub Actions." -ForegroundColor Yellow
            return $true
        }

        Write-Host "Not running in a recognized pipeline." -ForegroundColor Yellow
        return $false

    }

    function New-TestSecureString {
        [CmdletBinding()]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Function is only used internally')]
        param (
            [Parameter(Mandatory = $true)]
            [string]$InputString
        )
        return (ConvertTo-SecureString $InputString -AsPlainText -Force)
    }

    function Test-WpfCanRun {
        return (
            [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT -and
            [System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA'
        )
    }

    function New-UniqueTestKey {
        [CmdletBinding()]
        [OutputType([string])]
        param ()

        $callingScript = Get-PSCallStack | Select-Object -Skip 1 | Where-Object { $_.ScriptName } | Select-Object -First 1
        $scriptName = if ($callingScript) {
            [System.IO.Path]::GetFileNameWithoutExtension($callingScript.ScriptName)
        }
        else {
            'Interactive'
        }

        return ('{0}_{1}' -f $scriptName, [guid]::NewGuid().ToString('N'))
    }

    function SetUpGlobalTestVariables {
        [CmdletBinding()]
        [OutputType([array])]
        param (
            [Parameter(Mandatory)]
            [ValidateScript({ $_.Trim().ToLower().StartsWith('pester_temp_') })]
            [Alias('Name')]
            [string]$VarName,
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [Alias('TestCases')]
            [Alias('TestCaseArray')]
            [object]$VarValue,
            [switch]$Force
        )
        if (-not (Get-Variable -Scope Global -Name $VarName -ErrorAction SilentlyContinue) -or $Force) {
            New-Variable -Name $VarName -Scope Global -Value $VarValue -Force
            Write-Host ("Set global test variable '{0}' with value '{1}' of type '[{2}]'" -f $VarName, $VarValue, ($VarValue.GetType().Name)) -ForegroundColor Green
        }
    }
}