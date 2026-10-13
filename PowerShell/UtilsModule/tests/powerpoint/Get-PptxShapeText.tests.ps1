BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\public\powerpoint\Get-PptxShapeText.ps1' -Resolve)

    function New-TestPptxShape {
        param(
            [string]$Text = '',
            [bool]$HasText = $true
        )

        [pscustomobject]@{
            Type         = 1
            HasTextFrame = $HasText
            TextFrame    = [pscustomobject]@{
                HasText  = $HasText
                TextRange = [pscustomobject]@{ Text = $Text }
            }
            HasTable     = $false
        }
    }
}

Describe -Tag 'Unit' 'Get-PptxShapeText' {
    It 'returns text from a shape with a text frame' {
        $shape = New-TestPptxShape -Text 'Shape text'

        Get-PptxShapeText -Shape $shape | Should -BeExactly 'Shape text'
    }

    It 'returns an empty string for a shape without text or a table' {
        $shape = New-TestPptxShape -HasText $false

        Get-PptxShapeText -Shape $shape | Should -BeExactly ''
    }

    It 'concatenates text from grouped shapes recursively' {
        $nestedGroup = [pscustomobject]@{
            Type      = 6
            GroupItems = @(
                (New-TestPptxShape -Text 'B')
                (New-TestPptxShape -Text 'C')
            )
        }
        $group = [pscustomobject]@{
            Type      = 6
            GroupItems = @(
                (New-TestPptxShape -Text 'A')
                $nestedGroup
            )
        }

        Get-PptxShapeText -Shape $group | Should -BeExactly 'ABC'
    }

    It 'concatenates table cell text in row-major order' {
        $cells = foreach ($text in @('A', 'B', 'C', 'D')) {
            [pscustomobject]@{ Shape = [pscustomobject]@{ TextFrame = [pscustomobject]@{ TextRange = [pscustomobject]@{ Text = $text } } } }
        }
        $table = [pscustomobject]@{
            Rows    = [pscustomobject]@{ Count = 2 }
            Columns = [pscustomobject]@{ Count = 2 }
            Cells   = $cells
        }
        $table | Add-Member -MemberType ScriptMethod -Name Cell -Value {
            param($Row, $Column)
            $cellIndex = (($Row - 1) * $this.Columns.Count) + $Column - 1
            $this.Cells[$cellIndex]
        }
        $shape = New-TestPptxShape -HasText $false
        $shape.HasTable = $true
        $shape | Add-Member -MemberType NoteProperty -Name Table -Value $table

        Get-PptxShapeText -Shape $shape | Should -BeExactly 'ABCD'
    }
}