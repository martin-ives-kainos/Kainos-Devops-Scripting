$ErrorActionPreference = 'Stop'

foreach ($scope in @('classes', 'private', 'public')) {
    $scriptFiles = Get-ChildItem (Join-Path $PSScriptRoot $scope -Resolve) -Recurse -Filter '*.ps1'
    foreach ($scriptFile in $scriptFiles) {
        . ($scriptFile.FullName)
    }

    if ($scope -eq 'public') {
        Export-ModuleMember -Function ($scriptFiles | Select-Object -ExpandProperty BaseName)
    }
}
