function New-WpfEditConfigIni {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Function is only used internally')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
        throw 'Run PowerShell in STA mode: pwsh -STA'
    }

    Add-Type -AssemblyName PresentationFramework, System.Data

    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $directory = [System.IO.Path]::GetDirectoryName($fullPath)

    if (-not [System.IO.Directory]::Exists($directory)) {
        throw "Directory does not exist: $directory"
    }

    $table = [System.Data.DataTable]::new()
    foreach ($name in 'Section', 'Key', 'Value') {
        [void]$table.Columns.Add($name, [string])
    }

    if ([System.IO.File]::Exists($fullPath)) {
        $section = ''
        $lineNumber = 0

        foreach ($line in [System.IO.File]::ReadAllLines($fullPath)) {
            $lineNumber++
            $trimmed = $line.Trim()

            if (-not $trimmed -or $trimmed -match '^[;#]') {
                continue
            }

            if ($trimmed -match '^\[([^\[\]]+)\]\s*$') {
                $section = $Matches[1].Trim()
                continue
            }

            if ($line -match '^\s*([^=]+?)\s*=(.*)$') {
                [void]$table.Rows.Add($section, $Matches[1].Trim(), $Matches[2])
                continue
            }

            throw "Unsupported INI syntax at line ${lineNumber}: $line"
        }
    }

    [xml]$xaml = Get-Content -Path ($PSCommandPath -replace '\.ps1$', '.xml') -Raw

    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    try {
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }

    $grid = $window.FindName('Entries')
    $grid.ItemsSource = $table.DefaultView
    $window.FindName('FileLabel').Text = $fullPath
    $state = @{ Saved = $false }

    $window.FindName('AddButton').Add_Click({
            [void]$grid.CommitEdit(
                [System.Windows.Controls.DataGridEditingUnit]::Row, $true
            )

            $row = $table.NewRow()
            $row.Section = ''
            $row.Key = ''
            $row.Value = ''
            $table.Rows.Add($row)

            $item = $table.DefaultView[$table.DefaultView.Count - 1]
            $grid.SelectedItem = $item
            $grid.ScrollIntoView($item)
            $grid.CurrentCell = [System.Windows.Controls.DataGridCellInfo]::new(
                $item, $grid.Columns[1]
            )
            [void]$grid.Focus()
            [void]$grid.BeginEdit()
        })

    $window.FindName('DeleteButton').Add_Click({
            [void]$grid.CommitEdit(
                [System.Windows.Controls.DataGridEditingUnit]::Row, $true
            )

            foreach ($item in @($grid.SelectedItems)) {
                if ($item -is [System.Data.DataRowView]) {
                    $table.Rows.Remove($item.Row)
                }
            }
        })

    $window.FindName('SaveButton').Add_Click({
            try {
                if (-not $grid.CommitEdit(
                        [System.Windows.Controls.DataGridEditingUnit]::Cell, $true
                    )) {
                    throw 'Finish editing the current cell before saving.'
                }

                if (-not $grid.CommitEdit(
                        [System.Windows.Controls.DataGridEditingUnit]::Row, $true
                    )) {
                    throw 'Finish editing the current row before saving.'
                }

                $entries = [System.Collections.Generic.List[object]]::new()
                $keys = [System.Collections.Generic.HashSet[string]]::new(
                    [System.StringComparer]::OrdinalIgnoreCase
                )

                foreach ($row in $table.Rows) {
                    $section = ([string]$row.Section).Trim()
                    $key = ([string]$row.Key).Trim()
                    $value = [string]$row.Value

                    if ($section -match '[\[\]\r\n]') {
                        throw "Invalid section: $section"
                    }

                    if (-not $key -or $key -match '[=\r\n]' -or $key -match '^[;#\[]') {
                        throw "Invalid or empty key in section '$section'."
                    }

                    if ($value -match '[\r\n]') {
                        throw "Value for '$key' must be on one line."
                    }

                    if (-not $keys.Add("$section`0$key")) {
                        throw "Duplicate key '$key' in section '$section'."
                    }

                    $entries.Add([pscustomobject]@{
                            Section = $section
                            Key     = $key
                            Value   = $value
                        })
                }

                $lines = [System.Collections.Generic.List[string]]::new()

                # Global entries must appear before named sections.
                foreach ($entry in $entries) {
                    if ($entry.Section -eq '') {
                        $lines.Add("$($entry.Key)=$($entry.Value)")
                    }
                }

                $sections = [System.Collections.Generic.HashSet[string]]::new(
                    [System.StringComparer]::OrdinalIgnoreCase
                )

                foreach ($entry in $entries) {
                    if ($entry.Section -eq '' -or -not $sections.Add($entry.Section)) {
                        continue
                    }

                    if ($lines.Count -gt 0) {
                        $lines.Add('')
                    }

                    $lines.Add("[$($entry.Section)]")

                    foreach ($sectionEntry in $entries) {
                        if ($sectionEntry.Section -eq $entry.Section) {
                            $lines.Add("$($sectionEntry.Key)=$($sectionEntry.Value)")
                        }
                    }
                }

                $text = $lines -join [Environment]::NewLine
                if ($lines.Count -gt 0) {
                    $text += [Environment]::NewLine
                }

                # Write a temporary file first to avoid truncating the original.
                $temporaryPath = Join-Path $directory ([System.IO.Path]::GetRandomFileName())
                try {
                    [System.IO.File]::WriteAllText(
                        $temporaryPath,
                        $text,
                        [System.Text.UTF8Encoding]::new($false)
                    )

                    if ([System.IO.File]::Exists($fullPath)) {
                        [System.IO.File]::Replace($temporaryPath, $fullPath, $null)
                    }
                    else {
                        [System.IO.File]::Move($temporaryPath, $fullPath)
                    }
                }
                finally {
                    if ([System.IO.File]::Exists($temporaryPath)) {
                        [System.IO.File]::Delete($temporaryPath)
                    }
                }

                $state.Saved = $true
                $window.Close()
            }
            catch {
                [void][System.Windows.MessageBox]::Show(
                    $window,
                    $_.Exception.Message,
                    'Unable to save',
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Error
                )
            }
        })

    $window.FindName('CancelButton').Add_Click({
            $window.Close()
        })

    [void]$window.ShowDialog()

    if ($state.Saved) {
        $fullPath
    }
}