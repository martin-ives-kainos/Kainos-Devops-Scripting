function ConvertFrom-Ini {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $ini = @{}
    $section = '_Global'

    Get-Content $Path | ForEach-Object {

        $line = $_.Trim()

        # Skip blank lines and comments
        if ($line -match '^(?:;|#|$)') {
            return
        }

        # Section header
        if ($line -match '^\[(?<Section>[^\]]+)\]$') {
            $section = $Matches.Section.Trim()

            if (-not $ini.ContainsKey($section)) {
                $ini[$section] = @{}
            }
            return
        }

        # Key=value pair
        if ($line -match '^(?<Key>[^=]+?)\s*=\s*(?<Value>.*)$') {
            $key = $Matches.Key.Trim()
            $value = $Matches.Value.Trim()

            if (-not $ini.ContainsKey($section)) {
                $ini[$section] = @{}
            }

            # Check for environment variable references and expand them
            # regex pattern to match environment variable references like %VAR_NAME%
            if ($value.Contains("%")) {
                $envVarPattern = '%(?<VarName>[^%]+)%'
                foreach ($match in [regex]::Matches($value, $envVarPattern)) {
                    $value = [System.Environment]::ExpandEnvironmentVariables($value)
                }
            }

            $ini[$section][$key] = $value
        }
    }

    return $ini
}