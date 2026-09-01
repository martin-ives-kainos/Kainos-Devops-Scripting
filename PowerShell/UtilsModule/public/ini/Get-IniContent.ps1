function Get-IniContent {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $ini = @{}
    $section = ""

    foreach ($line in Get-Content $Path) {
        $line = $line.Trim()

        if ($line -match '^\[(.+)\]$') {
            $section = $matches[1]
            $ini[$section] = @{}
        }
        elseif ($line -match '^([^=]+)=(.*)$' -and $section) {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $ini[$section][$key] = $value
        }
    }

    return $ini
}
