BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\public\dialog\Get-WpfDate.ps1' -Resolve)

    $script:WpfDateTestSupported = $IsWindows -and
        [Threading.Thread]::CurrentThread.ApartmentState -eq [Threading.ApartmentState]::STA
    $script:WpfDateTestCreatedApplication = $false

    if ($script:WpfDateTestSupported) {
        Add-Type -AssemblyName PresentationFramework

        if ($null -eq [System.Windows.Application]::Current) {
            $script:WpfDateTestApplication = [System.Windows.Application]::new()
            $script:WpfDateTestApplication.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown
            $script:WpfDateTestCreatedApplication = $true
        }
    }

    function Invoke-WpfDateWithAutomation {
        param (
            [datetime]$DefaultDate,
            [datetime]$SelectedDate,
            [string]$Title,
            [bool]$Accept
        )

        $state = [hashtable]::Synchronized(@{
            DefaultDate = $null
            TimedOut    = $false
            Ticks       = 0
        })
        $timer = [System.Windows.Threading.DispatcherTimer]::new()
        $timer.Interval = [TimeSpan]::FromMilliseconds(50)
        $tickHandler = {
            $state.Ticks++
            $window = $null

            foreach ($candidate in [System.Windows.Application]::Current.Windows) {
                if ($candidate.Title -eq $Title) {
                    $window = $candidate
                    break
                }
            }

            if ($window) {
                $datePicker = $window.FindName('dpDate')
                $state.DefaultDate = $datePicker.SelectedDate

                if ($Accept) {
                    $datePicker.SelectedDate = $SelectedDate
                    $button = $window.FindName('btnOK')
                    $button.RaiseEvent(
                        [System.Windows.RoutedEventArgs]::new(
                            [System.Windows.Controls.Button]::ClickEvent
                        )
                    )
                }
                else {
                    $window.Close()
                }

                $timer.Stop()
            }
            elseif ($state.Ticks -ge 100) {
                $state.TimedOut = $true
                foreach ($candidate in [System.Windows.Application]::Current.Windows) {
                    $candidate.Close()
                }
                $timer.Stop()
            }
        }.GetNewClosure()

        $timer.Add_Tick($tickHandler)
        $timer.Start()

        try {
            $result = Get-WpfDate -DefaultDate $DefaultDate -Title $Title
        }
        finally {
            $timer.Stop()
            $timer.Remove_Tick($tickHandler)
        }

        [pscustomobject]@{
            Result      = $result
            DefaultDate = $state.DefaultDate
            TimedOut    = $state.TimedOut
        }
    }
}

AfterAll {
    if ($script:WpfDateTestCreatedApplication) {
        $script:WpfDateTestApplication.Shutdown()
    }
}

Describe 'Get-WpfDate' {
    It 'returns the selected date and initializes the picker with the default date' {
        if (-not $script:WpfDateTestSupported) {
            Set-ItResult -Skipped -Because 'WPF dialog tests require Windows and an STA runspace.'
            return
        }

        $defaultDate = [datetime]::new(2024, 5, 6)
        $selectedDate = [datetime]::new(2025, 11, 12)
        $result = Invoke-WpfDateWithAutomation `
            -DefaultDate $defaultDate `
            -SelectedDate $selectedDate `
            -Title 'Get-WpfDate accept test' `
            -Accept $true

        $result.TimedOut | Should -BeFalse
        $result.DefaultDate | Should -Be $defaultDate
        $result.Result | Should -Be $selectedDate
    }

    It 'returns null when the dialog is closed without accepting' {
        if (-not $script:WpfDateTestSupported) {
            Set-ItResult -Skipped -Because 'WPF dialog tests require Windows and an STA runspace.'
            return
        }

        $defaultDate = [datetime]::new(2024, 5, 6)
        $result = Invoke-WpfDateWithAutomation `
            -DefaultDate $defaultDate `
            -SelectedDate $defaultDate `
            -Title 'Get-WpfDate close test' `
            -Accept $false

        $result.TimedOut | Should -BeFalse
        $result.DefaultDate | Should -Be $defaultDate
        $result.Result | Should -BeNullOrEmpty
    }
}