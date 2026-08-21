function ConvertTo-Hashtable {
    <#
        .SYNOPSIS
            Converts a custom object into a hashtable
        .DESCRIPTION
            Converts a custom object into a hashtable
        .PARAMETER InputObject
            Object to convert.
    #>
    [CmdletBinding()]
    [OutputType('hashtable')]
    param (
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Object to convert.")]
        [ValidateNotNullOrEmpty()]
        [object]
        $InputObject
    )
    begin {
        $funcName = (Get-PSCallStack)[0].FunctionName.Replace('<Begin>', '')
        Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} STARTED' -f (Get-Date), $funcName)

        <#  Return null if the input is null. This can happen when calling the function
            recursively and a property is null #>
        if ($null -eq $InputObject) {
            return $null
        }

    }
    process {
        <#  Check if the input is an array or collection. If so, we also need to convert
            those types into hash tables as well. This function will convert all child
            objects into hash tables (if applicable) #>
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) {
                    ConvertTo-Hashtable -InputObject $object
                }
            )

            <# Return the array but don't enumerate it because the object may be pretty complex #>
            Write-Output -NoEnumerate $collection
        } elseif ($InputObject -is [psobject]) {
            <#  If the object has properties that need enumeration Convert it to its own hash table and return it #>
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            }
            $hash
        } else {
            <#  If the object isn't an array, collection, or other object, it's already a hash table
                So just return it. #>
            $InputObject
        }

    }
    end {
        Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} ENDED' -f (Get-Date), $funcName)
    }
}