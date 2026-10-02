function Get-DateFromString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$InputString,

        [string[]]$Formats = @(
            'd Mmm',
            'd Mmmm',
            'd MMM',
            'd MMMM',
            'dd Mmm',
            'dd Mmmm',
            'dd MMM',
            'dd MMMM',
            'yyyy-MM-dd',
            'dd/MM/yyyy',
            'MM/dd/yyyy',
            'dd-MM-yyyy',
            'yyyyMMdd',
            'dd MMM yyyy',
            'dd-MMM-yyyy',
            'yyyy-MM-dd HH:mm:ss',
            'dd/MM/yyyy HH:mm:ss',
            'yyyy-MM-ddTHH:mm:ss',
            'yyyy-MM-ddTHH:mm:ssZ'
        ),

        [System.Globalization.CultureInfo]$Culture = [System.Globalization.CultureInfo]::InvariantCulture
    )

    # Remove ordinal suffixes (st, nd, rd, th) from the input string
    $cleanString = $InputString -replace '\b(\d{1,2})(st|nd|rd|th)\b', '$1'



    foreach ($format in $Formats) {
        Write-Host "Trying format: $format - with input string: $cleanString"
        $parsedDate = [datetime]::MinValue()

        if ([datetime]::TryParseExact(
                $cleanString,
                $format,
                $Culture,
                [System.Globalization.DateTimeStyles]::AllowWhiteSpaces,
                [ref]$parsedDate
            )) {

            return [PSCustomObject]@{
                Success = $true
                Date    = $parsedDate
                Format  = $format
            }
        }
    }

    # Fallback to standard parsing
        Write-Host "Trying format: Standard Parsing with input string: $cleanString"
    $parsedDate = [datetime]::MinValue

    if ([datetime]::TryParse(
            $cleanString,
            $Culture,
            [System.Globalization.DateTimeStyles]::AllowWhiteSpaces,
            [ref]$parsedDate
        )) {

        return [PSCustomObject]@{
            Success = $true
            Date    = $parsedDate
            Format  = 'AutoDetected'
        }
    }

    return [PSCustomObject]@{
        Success = $false
        Date    = $null
        Format  = $null
    }
}

<#

function Get-DateFromText {
param(
[string]$Text
)

$patterns = @(
'\d{4}-\d{2}-\d{2}',
'\d{2}/\d{2}/\d{4}',
'\d{2}-\w{3}-\d{4}',
'\d{8}'
)

foreach ($pattern in $patterns) {
$match = :Match($Text, $pattern)

if ($match.Success) {
return Get-DateFromString -InputString $match.Value
}
}

return $null
}
#>