BeforeAll {
    . (Join-Path $PSScriptRoot '..\public\New-PesterExcelReport.ps1')

    function Export-Excel {
        [CmdletBinding()]
        param (
            [object[]]$InputObject,
            [string]$Path,
            [string]$WorksheetName,
            [string]$TableName,
            [switch]$AutoSize,
            [switch]$BoldTopRow,
            [switch]$FreezeTopRow,
            [switch]$Append
        )
    }

    $script:xmlPath = Join-Path $TestDrive 'pester-results.xml'
    @'
<?xml version="1.0" encoding="utf-8"?>
<test-results name="Pester" total="3" errors="0" failures="1" not-run="1" date="2026-10-08" time="10:00:00">
  <test-suite name="Pester" time="2.5">
    <results>
      <test-suite name="Example.Tests.ps1">
        <results>
          <test-suite name="Example feature">
            <results>
              <test-case name="passes" description="a passing test" result="Success" time="0.5" asserts="1" />
              <test-case name="fails" description="a failing test" result="Failure" time="1.0" asserts="1">
                <failure><message>Expected true</message><stack-trace>at Example.Tests.ps1:10</stack-trace></failure>
              </test-case>
              <test-case name="is skipped" description="a skipped test" result="Skipped" time="0" asserts="0" />
            </results>
          </test-suite>
        </results>
      </test-suite>
    </results>
  </test-suite>
</test-results>
'@ | Set-Content -LiteralPath $script:xmlPath -Encoding utf8
}

Describe -Tag 'Unit' 'Check requirements to be able to runNew-PesterExcelReport' {
    BeforeAll {
        $importedodules = Get-Module -ListAvailable
    }
    It 'requires the ImportExcel module' {
        ($importedodules | Where-Object { $_.Name -eq 'ImportExcel' }) | Should -Not -Be $null
    }
}

Describe -Tag 'Unit' 'New-PesterExcelReport' {
  BeforeEach {
    $script:exportCalls = @()
    Mock Export-Excel {
      $script:exportCalls += [pscustomobject]@{
        InputObject   = @($InputObject)
        Path          = $Path
        WorksheetName = $WorksheetName
        TableName     = $TableName
        Append        = $Append.IsPresent
      }
        }
    }

    It 'exports a summary and test cases to separate worksheets' {
        $outputPath = Join-Path $TestDrive 'report.xlsx'

        $result = New-PesterExcelReport -XmlPath $script:xmlPath -OutputPath $outputPath

        $result | Should -Be ([System.IO.Path]::GetFullPath($outputPath))
        $script:exportCalls.Count | Should -Be 2
        $script:exportCalls[0].WorksheetName | Should -Be 'Summary'
        $summary = $script:exportCalls[0].InputObject[0]
        $summary.Total | Should -Be 3
        $summary.Passed | Should -Be 1
        $summary.Failed | Should -Be 1
        $summary.Skipped | Should -Be 1
        $summary.Result | Should -Be 'Failed'
        $script:exportCalls[1].WorksheetName | Should -Be 'Test Results'
        $script:exportCalls[1].Append | Should -BeTrue
        $script:exportCalls[1].InputObject.Count | Should -Be 3
        $script:exportCalls[1].InputObject[1].FailureMessage | Should -Be 'Expected true'
        $script:exportCalls[1].InputObject[1].Suite | Should -Be 'Example feature'
    }

    It 'rejects XML that is not a NUnit test-results document' {
        $invalidXmlPath = Join-Path $TestDrive 'invalid.xml'
        '<testsuites />' | Set-Content -LiteralPath $invalidXmlPath

        { New-PesterExcelReport -XmlPath $invalidXmlPath -OutputPath (Join-Path $TestDrive 'invalid.xlsx') } |
            Should -Throw '*not a Pester NUnit test-results document*'
    }

    It 'does not overwrite an existing workbook without Force' {
        $outputPath = Join-Path $TestDrive 'existing.xlsx'
        'existing' | Set-Content -LiteralPath $outputPath

        { New-PesterExcelReport -XmlPath $script:xmlPath -OutputPath $outputPath } |
            Should -Throw '*already exists*'
    }
}