function ConvertTo-Ini {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$InputObject
    )

    $sb = [System.Text.StringBuilder]::new()

    foreach ($section in $InputObject.Keys) {

        if ($section -ne '_Global') {
            [void]$sb.AppendLine("[$section]")
        }

        foreach ($key in $InputObject[$section].Keys) {
            $value = $InputObject[$section][$key]
            [void]$sb.AppendLine("$key=$value")
        }

        [void]$sb.AppendLine()
    }

    $sb.ToString().TrimEnd()
}