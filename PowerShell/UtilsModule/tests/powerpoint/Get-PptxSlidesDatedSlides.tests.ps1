BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\public\Get-DateFromString.ps1' -Resolve)
    . (Join-Path $PSScriptRoot '..\..\public\powerpoint\Get-PptxShapeText.ps1' -Resolve)
    . (Join-Path $PSScriptRoot '..\..\public\powerpoint\Get-PptxSlidesDatedSlides.ps1' -Resolve)

    function New-TestPptxDatedSlide {
        param(
            [int]$SlideNumber,
            [string[]]$Texts = @()
        )

        $shapes = foreach ($text in $Texts) {
            [pscustomobject]@{
                Type         = 1
                HasTextFrame = $true
                TextFrame    = [pscustomobject]@{
                    HasText   = $true
                    TextRange = [pscustomobject]@{ Text = $text }
                }
                HasTable     = $false
            }
        }

        [pscustomobject]@{
            SlideNumber         = $SlideNumber
            Shapes              = @($shapes)
            SlideShowTransition = [pscustomobject]@{ Hidden = $false }
        }
    }
}

Describe -Tag 'Unit' 'Get-PptxSlidesDatedSlides' {
    It 'returns only slides in the default slide range' {
        $presentation = [pscustomobject]@{
            Slides = @(
                (New-TestPptxDatedSlide -SlideNumber 3)
                (New-TestPptxDatedSlide -SlideNumber 4)
                (New-TestPptxDatedSlide -SlideNumber 10)
                (New-TestPptxDatedSlide -SlideNumber 11)
            )
        }

        $result = @(Get-PptxSlidesDatedSlides -InputObject $presentation)

        $result.Count | Should -Be 2
        @($result.SlideNumber) | Should -Be @(4, 10)
    }

    It 'extracts a date and matching month line and hides the slide' {
        $slide = New-TestPptxDatedSlide -SlideNumber 4 -Texts @(
            '2026-10-13'
            'October milestone'
        )
        $presentation = [pscustomobject]@{ Slides = @($slide) }
        Mock Get-DateFromString {
            if ($InputString -eq '2026-10-13') {
                return [pscustomobject]@{ Success = $true; Date = [datetime]::new(2026, 10, 13) }
            }
            return [pscustomobject]@{ Success = $false; Date = $null }
        }

        $result = @(Get-PptxSlidesDatedSlides -InputObject $presentation)

        $result.Count | Should -Be 1
        $result[0].DateFound | Should -Be ([datetime]::new(2026, 10, 13))
        $result[0].LineFound | Should -BeExactly 'October milestone'
        $slide.SlideShowTransition.Hidden | Should -BeTrue
    }

    It 'uses the configured slide range and month names' {
        $slide = New-TestPptxDatedSlide -SlideNumber 2 -Texts @('Launch milestone')
        $presentation = [pscustomobject]@{
            Slides = @(
                (New-TestPptxDatedSlide -SlideNumber 1 -Texts @('Launch milestone'))
                $slide
            )
        }
        Mock Get-DateFromString { [pscustomobject]@{ Success = $false; Date = $null } }

        $result = @(Get-PptxSlidesDatedSlides -InputObject $presentation -StartSlide 2 -EndSlide 2 -MonthNames @('Launch'))

        $result.Count | Should -Be 1
        $result[0].SlideNumber | Should -Be 2
        $result[0].LineFound | Should -BeExactly 'Launch milestone'
        $slide.SlideShowTransition.Hidden | Should -BeTrue
    }

    It 'rejects a start slide greater than the end slide' {
        $presentation = [pscustomobject]@{ Slides = @() }

        { Get-PptxSlidesDatedSlides -InputObject $presentation -StartSlide 5 -EndSlide 4 } |
            Should -Throw 'StartSlide cannot be greater than EndSlide.'
    }
}