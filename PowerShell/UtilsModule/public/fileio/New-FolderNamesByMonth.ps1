function New-FolderNamesByMonth {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param ([string]$RootPath)
    $monthFolders = @{}

    $daysPerMonth = (Get-MonthDays)

    for ($i = 1; $i -le 12; $i++) {
        $tMonth = [pscustomobject]@{
            FullName        = (Get-Culture).DateTimeFormat.GetMonthName($i)
            AbbreviatedName = (Get-Culture).DateTimeFormat.GetAbbreviatedMonthName($i)
            MaximumDays     = $daysPerMonth[$i].MaximumDays
        }
        if (-not [string]::IsNullOrWhiteSpace($RootPath) -and (Test-Path -Path $RootPath -PathType Container)) {
            $tMonth | Add-Member -MemberType NoteProperty -Name Path -Value (Join-Path -Path $RootPath -ChildPath ('{0:00} {1}' -f $i, $tMonth.FullName))
            if (-not (Test-Path -Path $tMonth.Path -PathType Container)) {
                New-Item -Path $tMonth.Path -ItemType Directory | Out-Null
            }
        }
        $monthFolders.Add($i, $tMonth)
    }
    return $monthFolders
}