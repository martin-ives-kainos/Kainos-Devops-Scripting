New-Module -Name Test-Helpers -ScriptBlock {
    function New-TestIniFile {
        param (
            [string]$Path
        )
        if ($Path -notmatch '\.ini$') {
            $Path += '.ini'
        }
        $FullPath = Join-Path $TestDrive (Split-Path $Path -Leaf)
        Get-Content $Path | Set-Content -Path $FullPath
        return $FullPath
    }
}