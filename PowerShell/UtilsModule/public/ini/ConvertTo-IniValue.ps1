function ConvertTo-IniValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [object]$Value,
        [string]$ArrayDelimiter = '|'
    )

    switch ($Value.GetType().Name) {
        'String' {
            # Quote strings if they contain special characters
            if ($Value -match '[=;#\r\n]') {
                return "`"$($Value.Replace('"', '""'))`""
            }
            else {
                return $Value
            }
        }

        'Boolean' {
            return ($Value.ToString().ToLower())
        }

        { $_ -in 'Int16', 'Int32', 'Int64', 'UInt16', 'UInt32', 'UInt64', 'Double', 'Decimal', 'Single' } {
            return ($Value.ToString([System.Globalization.CultureInfo]::InvariantCulture))
        }

        'DateTime' {
            return ($Value.ToString('o'))   # ISO-8601
        }

        'String[]' {
            return ($Value -join $ArrayDelimiter)
        }

        'Object[]' {
            return (($Value | Sort-Object) -join $ArrayDelimiter).ToString()
        }

        'Hashtable' {
            # JSON is a common way to persist complex values
            return ($Value | ConvertTo-Json -Depth 99 -Compress)
        }

        default {
            return $Value.ToString()
        }
    }

    return $null
}