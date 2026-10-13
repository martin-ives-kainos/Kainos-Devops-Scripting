function Show-MessageBox {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Title = "Information",

        [ValidateSet("OK","OKCancel","YesNo","YesNoCancel")]
        [string]$Buttons = "OK",

        [ValidateSet("OK","Cancel","Yes","No")]
        [string]$Default,

        [ValidateRange(1, 4294967)]
        [int]$TimeoutSeconds
    )

    if (-not $PSBoundParameters.ContainsKey('Default')) {
        $Default = switch ($Buttons) {
            'OK' { 'OK' }
            'OKCancel' { 'OK' }
            'YesNo' { 'No' }
            'YesNoCancel' { 'Cancel' }
        }
    }

    $validDefaults = switch ($Buttons) {
        'OK' { @('OK') }
        'OKCancel' { @('OK', 'Cancel') }
        'YesNo' { @('Yes', 'No') }
        'YesNoCancel' { @('Yes', 'No', 'Cancel') }
    }
    if ($Default -notin $validDefaults) {
        throw "Default '$Default' is not available for the '$Buttons' button set."
    }
    $effectiveTimeoutSeconds = if ($PSBoundParameters.ContainsKey('TimeoutSeconds')) { $TimeoutSeconds } else { $null }

    if ($IsWindows) {
        try {
            Add-Type -AssemblyName PresentationFramework -ErrorAction Stop

            $buttonType = [System.Windows.MessageBoxButton]::$Buttons
            $defaultResult = [System.Windows.MessageBoxResult]::$Default

            if ($PSBoundParameters.ContainsKey('TimeoutSeconds')) {
                if (-not ('UtilsModule.NativeMessageBox' -as [type])) {
                    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace UtilsModule {
    public static class NativeMessageBox {
        [DllImport("user32.dll", EntryPoint = "MessageBoxTimeoutW", CharSet = CharSet.Unicode)]
        public static extern int Show(IntPtr window, string text, string caption, uint type, short languageId, uint milliseconds);
    }
}
'@ -ErrorAction Stop
                }

                $buttonFlag = switch ($Buttons) {
                    'OK' { 0 }
                    'OKCancel' { 1 }
                    'YesNo' { 4 }
                    'YesNoCancel' { 3 }
                }
                $defaultIndex = switch ($Buttons) {
                    { $_ -in 'OK', 'OKCancel' } { if ($Default -eq 'Cancel') { 1 } else { 0 } }
                    'YesNo' { if ($Default -eq 'No') { 1 } else { 0 } }
                    'YesNoCancel' {
                        switch ($Default) {
                            'Yes' { 0 }
                            'No' { 1 }
                            'Cancel' { 2 }
                        }
                    }
                }
                $nativeResult = [UtilsModule.NativeMessageBox]::Show(
                    [IntPtr]::Zero,
                    $Message,
                    $Title,
                    [uint32]($buttonFlag -bor ($defaultIndex * 256)),
                    [int16]0,
                    [uint32]($TimeoutSeconds * 1000)
                )

                if ($nativeResult -eq 32000) { return $Default }
                $result = switch ($nativeResult) {
                    1 { 'OK' }
                    2 { 'Cancel' }
                    6 { 'Yes' }
                    7 { 'No' }
                    default { $Default }
                }
                return $result
            }

            $result = [System.Windows.MessageBox]::Show(
                $Message,
                $Title,
                $buttonType,
                [System.Windows.MessageBoxImage]::None,
                $defaultResult
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
            $r = Read-MessageBoxResponse "Press Enter to continue" $effectiveTimeoutSeconds
            if ([string]::IsNullOrEmpty($r)) { return $Default }
            return "OK"
        }

        "OKCancel" {
            $r = Read-MessageBoxResponse "[O]K / [C]ancel" $effectiveTimeoutSeconds
            if ($r -match '^c') { return "Cancel" }
            if ($r -match '^o') { return "OK" }
            return $Default
        }

        "YesNo" {
            $r = Read-MessageBoxResponse "[Y]es / [N]o" $effectiveTimeoutSeconds
            if ($r -match '^y') { return "Yes" }
            if ($r -match '^n') { return "No" }
            return $Default
        }

        "YesNoCancel" {
            $r = Read-MessageBoxResponse "[Y]es / [N]o / [C]ancel" $effectiveTimeoutSeconds

            switch -Regex ($r) {
                '^y' { return "Yes" }
                '^n' { return "No" }
                '^c' { return "Cancel" }
                default { return $Default }
            }
        }
    }
}

function Read-MessageBoxResponse {
    param(
        [string]$Prompt,
        [Nullable[int]]$TimeoutSeconds
    )

    if (-not $TimeoutSeconds.HasValue) {
        return Read-Host $Prompt
    }

    try {
        Write-Host -NoNewline "$Prompt "
        $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds.Value)
        $response = ''
        while ([DateTime]::UtcNow -lt $deadline) {
            if ($Host.UI.RawUI.KeyAvailable) {
                $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                if ($key.VirtualKeyCode -eq 13) {
                    Write-Host ""
                    return $response
                }
                if ($key.VirtualKeyCode -eq 8) {
                    if ($response.Length -gt 0) {
                        $response = $response.Substring(0, $response.Length - 1)
                        Write-Host -NoNewline "`b `b"
                    }
                }
                elseif (-not [char]::IsControl($key.Character)) {
                    $response += $key.Character
                    Write-Host -NoNewline $key.Character
                }
            }
            Start-Sleep -Milliseconds 50
        }

        Write-Host ""
        return $null
    }
    catch {
        return $null
    }
}