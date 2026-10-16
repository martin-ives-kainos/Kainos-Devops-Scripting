# Requires Pester 5.x

BeforeDiscovery {
    $helperPath = $PSScriptRoot
    while (-not (Test-Path (Join-Path $helperPath 'PesterHelperModule.ps1'))) {
        $helperPath = Join-Path $helperPath '..' -Resolve
    }
    . (Join-Path $helperPath 'PesterHelperModule.ps1' -Resolve)
    SetUpGlobalTestVariables -VarName 'pester_temp_RunDate' -VarValue (Get-Date)
    SetUpGlobalTestVariables -VarName 'pester_temp_WpfCanRun' -VarValue (Test-WpfCanRun)
}

BeforeAll {
    . (Find-ScriptFile -TestScriptFile $PSCommandPath)
}
AfterAll {
    CleanUpTemporaryGlobalVariables
}

Describe -Tag 'Unit' 'D010: New-WpfEditConfigIni validation' {
    It 'D010-I010: rejects an empty path' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
        { New-WpfEditConfigIni -Path '' } | Should -Throw
    }

    It 'D010-I020: rejects a null path' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
        { New-WpfEditConfigIni -Path $null } | Should -Throw
    }

    It 'D010-I030: requires the Path parameter' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
        $parameter = (Get-Command New-WpfEditConfigIni).Parameters['Path']
        $attribute = $parameter.Attributes |
        Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }

        $attribute.Mandatory | Should -BeTrue
    }

    It 'D010-I040: rejects execution outside STA mode' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
        if ([System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA') {
            Set-ItResult -Skipped -Because 'The current thread already uses STA.'
            return
        }

        { New-WpfEditConfigIni -Path (Join-Path $TestDrive 'config.ini') } | Should -Throw '*Run PowerShell in STA mode: pwsh -STA*'
    }
}

Describe -Tag 'Integration', 'WPF' 'D020: New-WpfEditConfigIni dialog' -Skip:(-not ($Global:pester_temp_WpfCanRun)) {
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
            Write-Host ('[New-WpfEditConfigIni.tests] [Invoke-TestButton] START Invoking button: {0}' -f $Name) -ForegroundColor Cyan
            $button = $Window.FindName($Name)
            $button.RaiseEvent(
                [System.Windows.RoutedEventArgs]::new(
                    [System.Windows.Controls.Button]::ClickEvent
                )
            )
            Write-Host ('[New-WpfEditConfigIni.tests] [Invoke-TestButton] END Invoking button: {0}' -f $Name) -ForegroundColor Cyan
        }

        function Invoke-TestIniDialog {
            param (
                [string]$Path,
                [scriptblock]$Action
            )
            Write-Host ('[New-WpfEditConfigIni.tests] [Invoke-TestIniDialog] START Invoking INI dialog for path: {0}' -f $Path) -ForegroundColor Cyan
            $state = @{
                Action = $Action
                Error  = $null
            }

            $timer = [System.Windows.Threading.DispatcherTimer]::new()
            $timer.Interval = [TimeSpan]::FromMilliseconds(50)

            $handler = {
                $dialog = $null

                foreach ($source in [System.Windows.PresentationSource]::CurrentSources) {
                    if ( $source.RootVisual -is [System.Windows.Window] -and $source.RootVisual.Title -eq 'Pester INI Editor' ) {
                        $dialog = $source.RootVisual
                        break
                    }
                }

                if ($null -eq $dialog) {
                    Write-Host ('[New-WpfEditConfigIni.tests] [Invoke-TestIniDialog] END: null dialog found. Invoking INI dialog for path: {0}' -f $Path) -ForegroundColor Cyan
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
                    Write-Host ('[New-WpfEditConfigIni.tests] [Invoke-TestIniDialog] END: Error occurred. Invoking INI dialog for path: {0}' -f $Path) -ForegroundColor Cyan
                    throw $state.Error
                }
                Write-Host ('[New-WpfEditConfigIni.tests] [Invoke-TestIniDialog] END: Success. Invoking INI dialog for path: {0}' -f $Path) -ForegroundColor Cyan

                return $result
            }
            finally {
                $timer.Stop()
                $timer.Remove_Tick($handler)
            }
        }
        Write-Host ('[New-WpfEditConfigIni.tests] [Invoke-TestIniDialog] END: No dialog found. Invoking INI dialog for path: {0}' -f $Path) -ForegroundColor Cyan
    }

    BeforeEach {
        $script:iniPath = Join-Path $TestDrive 'config.ini'

        Mock Get-Content {
            $script:testXaml
        } -ParameterFilter {
            $Path -like '*New-WpfEditConfigIni.xml' -and $Raw
        }
    }

    It 'D020-I010: rejects a missing parent directory' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
        $path = Join-Path $TestDrive 'missing\config.ini'

        { New-WpfEditConfigIni -Path $path } |
        Should -Throw '*Directory does not exist:*'

        Should -Invoke Get-Content -Exactly 0
    }

    It 'D020-I020: reports unsupported syntax with its line number' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
        [System.IO.File]::WriteAllText(
            $script:iniPath,
            "[Application]`nValid=true`nunsupported"
        )

        { New-WpfEditConfigIni -Path $script:iniPath } |
        Should -Throw '*Unsupported INI syntax at line 3: unsupported*'

        Should -Invoke Get-Content -Exactly 0
    }

    It 'D020-I030: loads global entries, sections, empty values, and embedded equals signs' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
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

    It 'D020-I040: adds an entry and creates a new INI file' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
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

    It 'D020-I050: saves an edited value to an existing file' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
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

    It 'D020-I060: deletes the selected entry and preserves other entries' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
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

    It 'D020-I070: writes global entries before named sections' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
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

    It 'D020-I080: does not persist edits when cancelled' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
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

    It 'D020-I090: does not create a file when a new dialog is cancelled' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
        $result = Invoke-TestIniDialog -Path $script:iniPath -Action {
            param($window)

            Invoke-TestButton $window 'CancelButton'
        }

        $result | Should -BeNullOrEmpty
        Test-Path -LiteralPath $script:iniPath | Should -BeFalse
    }

    It 'D020-I100: saves an empty configuration' {
        Write-Host ('[New-WpfEditConfigIni.tests] {0}' -f $____Pester.CurrentTest.Name) -ForegroundColor Magenta
        $result = Invoke-TestIniDialog -Path $script:iniPath -Action {
            param($window)

            Invoke-TestButton $window 'SaveButton'
        }

        $result | Should -Be $script:iniPath
        [System.IO.File]::Exists($script:iniPath) | Should -BeTrue
        [System.IO.File]::ReadAllText($script:iniPath) | Should -BeExactly ''
    }
}