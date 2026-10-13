function New-PesterExcelReport {
    <#
    .SYNOPSIS
    Creates an Excel report from a Pester NUnit XML results file.

    .DESCRIPTION
    Writes a summary worksheet and a test-case details worksheet to an .xlsx workbook.
    Requires the ImportExcel PowerShell module.

    .PARAMETER XmlPath
    Path to the NUnit XML file produced by Pester.

    .PARAMETER OutputPath
    Destination path for the Excel workbook.

    .PARAMETER Force
    Replaces the destination workbook if it already exists.

    .EXAMPLE
    New-PesterExcelReport -XmlPath '.\TestResults\ModuleFunctions.xml' -OutputPath '.\TestResults\ModuleFunctions.xlsx'
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$XmlPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [switch]$Force
    )

    if (-not (Get-Command -Name Export-Excel -ErrorAction SilentlyContinue)) {
        throw "The ImportExcel module is required. Install it with 'Install-Module ImportExcel -Scope CurrentUser'."
    }

    $resolvedXmlPath = (Resolve-Path -LiteralPath $XmlPath -ErrorAction Stop).Path
    $resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)

    if ([System.IO.Path]::GetExtension($resolvedOutputPath) -ine '.xlsx') {
        throw 'OutputPath must have an .xlsx extension.'
    }

    if ((Test-Path -LiteralPath $resolvedOutputPath) -and -not $Force) {
        throw "The output workbook already exists: $resolvedOutputPath. Use -Force to replace it."
    }

    try {
        $document = [System.Xml.XmlDocument]::new()
        $document.XmlResolver = $null
        $document.Load($resolvedXmlPath)
    }
    catch {
        throw "Unable to read NUnit XML '$resolvedXmlPath': $($_.Exception.Message)"
    }

    $root = $document.DocumentElement
    if ($null -eq $root -or $root.LocalName -ne 'test-results') {
        throw "The XML file '$resolvedXmlPath' is not a Pester NUnit test-results document."
    }

    $testCases = @($document.SelectNodes('//test-case'))
    $passedCount = @($testCases | Where-Object { $_.GetAttribute('result') -eq 'Success' }).Count
    $failedCount = @($testCases | Where-Object { $_.GetAttribute('result') -eq 'Failure' }).Count
    $errorCount = @($testCases | Where-Object { $_.GetAttribute('result') -eq 'Error' }).Count
    $skippedCount = @($testCases | Where-Object { $_.GetAttribute('result') -in @('Skipped', 'Ignored', 'NotRun', 'Invalid') }).Count
    $inconclusiveCount = @($testCases | Where-Object { $_.GetAttribute('result') -eq 'Inconclusive' }).Count

    $totalCount = 0
    if (-not [int]::TryParse($root.GetAttribute('total'), [ref]$totalCount)) {
        $totalCount = $testCases.Count
    }

    $durationSeconds = 0.0
    $rootSuite = $root.SelectSingleNode('./test-suite')
    if ($null -ne $rootSuite) {
        [void][double]::TryParse(
            $rootSuite.GetAttribute('time'),
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$durationSeconds
        )
    }

    $overallResult = if (($failedCount + $errorCount) -gt 0) {
        'Failed'
    }
    elseif ($totalCount -eq 0) {
        'No tests'
    }
    elseif ($passedCount -eq $totalCount) {
        'Passed'
    }
    else {
        'Completed with skipped or inconclusive tests'
    }

    $summary = [pscustomobject][ordered]@{
        Suite            = $root.GetAttribute('name')
        Result           = $overallResult
        Total            = $totalCount
        Passed           = $passedCount
        Failed           = $failedCount
        Errors           = $errorCount
        Skipped          = $skippedCount
        Inconclusive     = $inconclusiveCount
        DurationSeconds  = $durationSeconds
        Started          = '{0} {1}' -f $root.GetAttribute('date'), $root.GetAttribute('time')
        SourceXml        = $resolvedXmlPath
        GeneratedAt      = Get-Date
    }

    $testResultRows = foreach ($testCase in $testCases) {
        $suite = $testCase.ParentNode
        while ($null -ne $suite -and $suite.LocalName -ne 'test-suite') {
            $suite = $suite.ParentNode
        }

        $failure = $testCase.SelectSingleNode('./failure')
        $failureMessage = if ($null -ne $failure) {
            $messageNode = $failure.SelectSingleNode('./message')
            if ($null -ne $messageNode) { $messageNode.InnerText } else { $failure.GetAttribute('message') }
        }
        else {
            ''
        }

        $stackTrace = if ($null -ne $failure) {
            $stackTraceNode = $failure.SelectSingleNode('./stack-trace')
            if ($null -ne $stackTraceNode) { $stackTraceNode.InnerText } else { '' }
        }
        else {
            ''
        }

        $caseDuration = 0.0
        [void][double]::TryParse(
            $testCase.GetAttribute('time'),
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$caseDuration
        )

        [pscustomobject][ordered]@{
            Suite           = if ($null -ne $suite) { $suite.GetAttribute('name') } else { '' }
            Name            = $testCase.GetAttribute('name')
            Description     = $testCase.GetAttribute('description')
            Result          = $testCase.GetAttribute('result')
            DurationSeconds = $caseDuration
            Assertions      = $testCase.GetAttribute('asserts')
            FailureMessage  = $failureMessage
            StackTrace      = $stackTrace
        }
    }

    $outputDirectory = Split-Path -Parent $resolvedOutputPath
    if (-not (Test-Path -LiteralPath $outputDirectory)) {
        New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
    }

    if ($Force -and (Test-Path -LiteralPath $resolvedOutputPath)) {
        Remove-Item -LiteralPath $resolvedOutputPath -Force -ErrorAction Stop
    }

    Export-Excel -InputObject $summary -Path $resolvedOutputPath -WorksheetName 'Summary' -TableName 'TestSummary' -AutoSize -BoldTopRow -FreezeTopRow -ErrorAction Stop

    if ($testCases.Count -gt 0) {
        Export-Excel -InputObject @($testResultRows) -Path $resolvedOutputPath -WorksheetName 'Test Results' -TableName 'TestResults' -AutoSize -BoldTopRow -FreezeTopRow -Append -ErrorAction Stop
    }

    return $resolvedOutputPath
}