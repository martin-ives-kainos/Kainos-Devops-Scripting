function ConvertTo-Ini {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$InputObject,
        [Parameter(Mandatory)]
        [ValidateScript({
            if ([string]::IsNullOrWhiteSpace($_)) {
                throw 'Path cannot be empty.'
            }
            try {
               [System.IO.Path]::GetFullPath($_) | Out-Null
               $true
            }
            catch {
               throw '$_ is not a valid path.'
            }
        })]
        [string]$Path
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

    if (!(Test-Path (Split-Path $Path -Parent) -PathType Container)) {
        New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    }
    $sb.ToString().TrimEnd() | Out-File -FilePath $Path -Encoding UTF8

}