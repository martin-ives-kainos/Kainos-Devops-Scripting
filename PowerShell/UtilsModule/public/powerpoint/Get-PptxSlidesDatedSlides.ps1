function Get-PptxSlidesDatedSlides {
    [CmdletBinding()]
    [OutputType([array])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'FromFile')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'FromObject')]
        [ValidateNotNullOrEmpty()]
        [Alias('Presentation')]
        [object]$InputObject,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateRange(1, 100)]
        [int]$StartSlide = 4,
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateRange(1, 100)]
        [int]$EndSlide = 10,
        [Parameter(Mandatory = $false, Position = 3)]
        [string[]]$MonthNames = @('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December')
    )

    if ($StartSlide -gt $EndSlide) {
        throw 'StartSlide cannot be greater than EndSlide.'
    }
    switch ($PSCmdlet.ParameterSetName) {
        'FromFile' {
            $pptApp = New-Object -ComObject PowerPoint.Application
            $presentation = $pptApp.Presentations.Open($Path)
        }
        'FromObject' {
            $presentation = $InputObject
        }
    }

    $datedSlides = @()
    foreach ($slide in $presentation.Slides) {
        if ($slide.SlideNumber -lt $StartSlide -or $slide.SlideNumber -gt $EndSlide) {
            continue
        }
        Write-Host "Slide $($slide.SlideNumber)"
        $newDatedSlide = (New-Object psobject)
        $newDatedSlide | Add-Member -MemberType NoteProperty -Name SlideNumber -Value $slide.SlideNumber
        $newDatedSlide | Add-Member -MemberType NoteProperty -Name DateFound -Value ''
        $newDatedSlide | Add-Member -MemberType NoteProperty -Name LineFound -Value ''
        foreach ($shape in $slide.Shapes) {
            try {
                $text = (Get-PptxShapeText $shape)
                $lines = $text -split "`r`n|`n|`r"
                foreach ($line in $lines) {
                    $lineDate = Get-DateFromString -InputString $line.Trim()
                    if ($lineDate.Success) {
                        $newDatedSlide.DateFound = $lineDate.Date
                    }
                    if ($MonthNames | ForEach-Object { $line.Trim().ToUpper().Contains($_.ToUpper()) } | Where-Object { $_ }) {
                        Write-Host $line
                        $newDatedSlide.LineFound = $line
                        $slide.SlideShowTransition.Hidden = $true
                        break
                    }
                }

            } catch {
                Write-Host "Error reading shape text: $_"
            }
        }
        $datedSlides += $newDatedSlide
    }

    return $datedSlides

    switch ($PSCmdlet.ParameterSetName) {
        'FromFile' {
            Write-Host "Quitting PowerPoint and Releasing COM objects for FromFile parameter set."
            $pptApp.Quit()
            try {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($presentation) | Out-Null
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($pptApp) | Out-Null
            }
            catch {
                Write-Host "Error releasing COM objects: $_"
            }
        }
        'FromObject' {
            Write-Host "Releasing PowerPoint COM objects for FromObject parameter set. Not applicable."
#            $presentation = $InputObject
        }
    }
}
