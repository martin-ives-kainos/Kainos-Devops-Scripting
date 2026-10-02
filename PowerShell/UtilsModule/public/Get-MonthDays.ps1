function Get-MonthDays {
    [CmdletBinding()]
    param ()

    $returnTable = @{}
    1..12 | ForEach-Object {
        $returnTable[$_] = [PSCustomObject]@{
            Month       = (Get-Culture).DateTimeFormat.GetMonthName($_)
            MaximumDays = switch ($_) {
                2 { 29 }
                { $_ -in 4, 6, 9, 11 } { 30 }
                default { 31 }
            }
        }
    }
    return $returnTable
}

<#
1..12 | ForEach-Object {
    [PSCustomObject]@{
        Month       = (Get-Culture).DateTimeFormat.GetMonthName($_)
        MaximumDays = switch ($_) {
            2 { 29 }
            {$_ -in 4,6,9,11} { 30 }
            default { 31 }
        }
    }
}
#>