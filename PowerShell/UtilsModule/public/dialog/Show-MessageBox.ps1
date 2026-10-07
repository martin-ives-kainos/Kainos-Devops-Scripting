function Show-MessageBox {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Title = "Information",

        [ValidateSet("OK","OKCancel","YesNo","YesNoCancel")]
        [string]$Buttons = "OK"
    )

    if ($IsWindows) {
        try {
            Add-Type -AssemblyName PresentationFramework -ErrorAction Stop

            $buttonType = [System.Windows.MessageBoxButton]::$Buttons

            $result = [System.Windows.MessageBox]::Show(
                $Message,
                $Title,
                $buttonType
            )

            return $result.ToString()
        }
        catch {
            # Fall through to console version
        }
    }

    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
    Write-Host $Message
    Write-Host ""

    switch ($Buttons) {

        "OK" {
            Read-Host "Press Enter to continue"
            return "OK"
        }

        "OKCancel" {
            $r = Read-Host "[O]K / [C]ancel"
            if ($r -match '^c') { return "Cancel" }
            return "OK"
        }

        "YesNo" {
            $r = Read-Host "[Y]es / [N]o"
            if ($r -match '^y') { return "Yes" }
            return "No"
        }

        "YesNoCancel" {
            $r = Read-Host "[Y]es / [N]o / [C]ancel"

            switch -Regex ($r) {
                '^y' { return "Yes" }
                '^n' { return "No" }
                default { return "Cancel" }
            }
        }
    }
}