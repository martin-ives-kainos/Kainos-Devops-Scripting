# Requires Pester 5.x

BeforeDiscovery {
    $canRunWpf = (
        [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT -and
        [System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA'
    )
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'New-WpfEditConfigIni.ps1')
}

Describe -Tag 'Unit' 'New-WpfEditConfigIni validation' {
    It 'rejects an empty path' {
        { New-WpfEditConfigIni -Path '' } | Should -Throw
    }

    It 'rejects a null path' {
        { New-WpfEditConfigIni -Path $null } | Should -Throw
    }

    It 'requires the Path parameter' {
        $parameter = (Get-Command New-WpfEditConfigIni).Parameters['Path']
        $attribute = $parameter.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }

        $attribute.Mandatory | Should -BeTrue
    }

    It 'rejects execution outside STA mode' {
        if ([System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA') {
            Set-ItResult -Skipped -Because 'The current thread already uses STA.'
            return
        }

        {
            New-WpfEditConfigIni -Path (Join-Path $TestDrive 'config.ini')
        } | Should -Throw '*Run PowerShell in STA mode: pwsh -STA*'
    }
}

Describe -Tag 'Integration', 'WPF' 'New-WpfEditConfigIni dialog' -Skip:(-not $canRunWpf) {
    BeforeAll {
        Add-Type -AssemblyName PresentationFramework, System.Data

        $script:testXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Pester INI Editor"
        Width="600" Height="350"
        ShowInTaskbar="False">
    <DockPanel>
        <TextBlock x:Name="FileLabel" DockPanel.Dock="Top"/>
        <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal">
            <Button x:Name="AddButton" Content="Add"/>
            <Button x:Name="DeleteButton" Content="Delete"/>
            <Button x:Name="SaveButton" Content="Save"/>
            <Button x:Name="CancelButton" Content="Cancel"/>
        </StackPanel>
        <DataGrid x:Name="Entries"
                  AutoGenerateColumns="False"
                  CanUserAddRows="False"
                  CanUserDeleteRows="False"
                  SelectionMode="Extended"
                  SelectionUnit="FullRow">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Section"
                                    Binding="{Binding Section}" Width="*"/>
                <DataGridTextColumn Header="Key"
                                    Binding="{Binding Key}" Width="*"/>
                <DataGridTextColumn Header="Value"
                                    Binding="{Binding Value}" Width="*"/>
            </DataGrid.Columns>
        </DataGrid>
    </DockPanel>
</Window>
'@

        function Invoke-TestButton {
            param (
                [System.Windows.Window]$Window,
                [string]$Name
            )

            $button = $Window.FindName($Name)
            $button.RaiseEvent(
                [System.Windows.RoutedEventArgs]::new(
                    [System.Windows.Controls.Button]::ClickEvent
                )
            )
        }

        function Invoke-TestIniDialog {
            param (
                [string]$Path,
                [scriptblock]$Action
            )

            $state = @{
                Action = $Action
                Error  = $null
            }

            $timer = [System.Windows.Threading.DispatcherTimer]::new()
            $timer.Interval = [TimeSpan]::FromMilliseconds(50)

            $handler = {
                $dialog = $null

                foreach ($source in [System.Windows.PresentationSource]::CurrentSources) {
                    if (
                        $source.RootVisual -is [System.Windows.Window] -and
                        $source.RootVisual.Title -eq 'Pester INI Editor'
                    ) {
                        $dialog = $source.RootVisual
                        break
                    }
                }

                if ($null -eq $dialog) {
                    return
                }

                $timer.Stop()

                try {
                    & $state.Action $dialog
                }
                catch {
                    $state.Error = $_
                }
                finally {
                    if ($dialog.IsVisible) {
                        $dialog.Close()
                    }
                }
            }.GetNewClosure()

            $timer.Add_Tick($handler)

            try {
                $timer.Start()
                $result = New-WpfEditConfigIni -Path $Path

                if ($null -ne $state.Error) {
                    throw $state.Error
                }

                return $result
            }
            finally {
                $timer.Stop()
                $timer.Remove_Tick($handler)
            }
        }
    }

    BeforeEach {
        $script:iniPath = Join-Path $TestDrive 'config.ini'

        Mock Get-Content {
            $script:testXaml
        } -ParameterFilter {
            $Path -like '*New-WpfEditConfigIni.xml' -and $Raw
        }
    }

    It 'rejects a missing parent directory' {
        $path = Join-Path $TestDrive 'missing\config.ini'

        { New-WpfEditConfigIni -Path $path } |
            Should -Throw '*Directory does not exist:*'

        Should -Invoke Get-Content -Exactly 0
    }

    It 'reports unsupported syntax with its line number' {
        [System.IO.File]::WriteAllText(
            $script:iniPath,
            "[Application]`nValid=true`nunsupported"
        )

        { New-WpfEditConfigIni -Path $script:iniPath } |
            Should -Throw '*Unsupported INI syntax at line 3: unsupported*'

        Should -Invoke Get-Content -Exactly 0
    }

    It 'loads global entries, sections, empty values, and embedded equals signs' {
        [System.IO.File]::WriteAllText(
            $script:iniPath,
            @'
; Comment
# Another comment

Global=enabled
[ Application ]
 Name =example
Empty=
Token=a=b=c
'@
        )

        $result = Invoke-TestIniDialog -Path $script:iniPath -Action {
            param($window)

            $view = $window.FindName('Entries').ItemsSource

            $view.Count | Should -Be 4
            $view[0]['Section'] | Should -Be ''
            $view[0]['Key'] | Should -Be 'Global'
            $view[0]['Value'] | Should -Be 'enabled'
            $view[1]['Section'] | Should -Be 'Application'
            $view[1]['Key'] | Should -Be 'Name'
            $view[2]['Value'] | Should -Be ''
            $view[3]['Value'] | Should -Be 'a=b=c'

            $window.FindName('FileLabel').Text | Should -Be $script:iniPath

            Invoke-TestButton $window 'CancelButton'
        }

        $result | Should -BeNullOrEmpty
    }

    It 'adds an entry and creates a new INI file' {
        $result = Invoke-TestIniDialog -Path $script:iniPath -Action {
            param($window)

            $grid = $window.FindName('Entries')
            $grid.ItemsSource.Count | Should -Be 0

            Invoke-TestButton $window 'AddButton'

            $grid.ItemsSource.Count | Should -Be 1

            # Finish the automatically started edit before setting row values.
            [void]$grid.CommitEdit(
                [System.Windows.Controls.DataGridEditingUnit]::Cell, $true
            )
            [void]$grid.CommitEdit(
                [System.Windows.Controls.DataGridEditingUnit]::Row, $true
            )

            $row = $grid.ItemsSource[0]
            $row['Section'] = 'Application'
            $row['Key'] = 'Name'
            $row['Value'] = 'Example'

            Invoke-TestButton $window 'SaveButton'
        }

        $result | Should -Be $script:iniPath
        [System.IO.File]::ReadAllText($script:iniPath) |
            Should -Be (
                '[Application]',
                'Name=Example',
                '' -join [Environment]::NewLine
            )
    }

    It 'saves an edited value to an existing file' {
        [System.IO.File]::WriteAllText(
            $script:iniPath,
            "[Application]`nName=Before`n"
        )

        $result = Invoke-TestIniDialog -Path $script:iniPath -Action {
            param($window)

            $window.FindName('Entries').ItemsSource[0]['Value'] = 'After'
            Invoke-TestButton $window 'SaveButton'
        }

        $result | Should -Be $script:iniPath
        [System.IO.File]::ReadAllText($script:iniPath) |
            Should -Be (
                '[Application]',
                'Name=After',
                '' -join [Environment]::NewLine
            )

        @(Get-ChildItem -LiteralPath $TestDrive -File).Count | Should -Be 1
    }

    It 'deletes the selected entry and preserves other entries' {
        [System.IO.File]::WriteAllText(
            $script:iniPath,
            "[Application]`nRemove=one`nKeep=two`n"
        )

        $null = Invoke-TestIniDialog -Path $script:iniPath -Action {
            param($window)

            $grid = $window.FindName('Entries')
            $grid.SelectedItem = $grid.ItemsSource[0]

            Invoke-TestButton $window 'DeleteButton'

            $grid.ItemsSource.Count | Should -Be 1
            $grid.ItemsSource[0]['Key'] | Should -Be 'Keep'

            Invoke-TestButton $window 'SaveButton'
        }

        [System.IO.File]::ReadAllText($script:iniPath) |
            Should -Be (
                '[Application]',
                'Keep=two',
                '' -join [Environment]::NewLine
            )
    }

    It 'writes global entries before named sections' {
        [System.IO.File]::WriteAllText(
            $script:iniPath,
            "[Application]`nName=Example`n"
        )

        $null = Invoke-TestIniDialog -Path $script:iniPath -Action {
            param($window)

            $table = $window.FindName('Entries').ItemsSource.Table
            [void]$table.Rows.Add('', 'Global', 'enabled')

            Invoke-TestButton $window 'SaveButton'
        }

        [System.IO.File]::ReadAllText($script:iniPath) |
            Should -Be (
                'Global=enabled',
                '',
                '[Application]',
                'Name=Example',
                '' -join [Environment]::NewLine
            )
    }

    It 'does not persist edits when cancelled' {
        $original = "; Preserve this comment`r`n[Application]`r`nName=Before`r`n"
        [System.IO.File]::WriteAllText($script:iniPath, $original)

        $result = Invoke-TestIniDialog -Path $script:iniPath -Action {
            param($window)

            $window.FindName('Entries').ItemsSource[0]['Value'] = 'After'
            Invoke-TestButton $window 'CancelButton'
        }

        $result | Should -BeNullOrEmpty
        [System.IO.File]::ReadAllText($script:iniPath) |
            Should -BeExactly $original
    }

    It 'does not create a file when a new dialog is cancelled' {
        $result = Invoke-TestIniDialog -Path $script:iniPath -Action {
            param($window)

            Invoke-TestButton $window 'CancelButton'
        }

        $result | Should -BeNullOrEmpty
        Test-Path -LiteralPath $script:iniPath | Should -BeFalse
    }

    It 'saves an empty configuration' {
        $result = Invoke-TestIniDialog -Path $script:iniPath -Action {
            param($window)

            Invoke-TestButton $window 'SaveButton'
        }

        $result | Should -Be $script:iniPath
        [System.IO.File]::Exists($script:iniPath) | Should -BeTrue
        [System.IO.File]::ReadAllText($script:iniPath) |
            Should -BeExactly ''
    }
}