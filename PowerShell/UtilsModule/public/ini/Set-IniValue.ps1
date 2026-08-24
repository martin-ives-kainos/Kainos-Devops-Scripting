function Set-IniValue {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Section,

        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Value
    )

    $ini = if (Test-Path $Path) {
        Get-IniContent -Path $Path
    }
    else {
        @{}
    }

    if (-not $ini.ContainsKey($Section)) {
        $ini[$Section] = @{}
    }

    $ini[$Section][$Key] = $Value

    $output = foreach ($sec in $ini.Keys) {
        "[$sec]"
        foreach ($k in $ini[$sec].Keys) {
            "$k=$($ini[$sec][$k])"
        }
        ""
    }

    Set-Content -Path $Path -Value $output -Encoding UTF8
}