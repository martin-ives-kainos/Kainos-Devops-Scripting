# Example WPF PowerShell Application

## Overview

This production-ready PowerShell WPF example demonstrates:

- Text input fields
- ComboBox dropdowns
- ListBox with multi-select
- DataGrid
- Buttons
- Labels
- Event handling
- Dynamic updates

This pattern is commonly used for:

- Administrative tools
- Deployment forms
- User management utilities
- Automation front-ends

## Features Demonstrated

| Control | Purpose |
|----------|---------|
| TextBox | User input |
| ComboBox | Single selection |
| ListBox | Multiple selections |
| DataGrid | Display collections |
| Button | Execute actions |
| MessageBox | Validation feedback |
| ObservableCollection | Live grid refresh |

## PowerShell WPF Example

```powershell
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore

[xml]$xaml = @"
<Window
 xmlns=" http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 xmlns:x=" http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Application Management"
 Height="600"
 Width="800"
 WindowStartupLocation="CenterScreen">

 <Grid Margin="10">

 <Grid.RowDefinitions>
 <RowDefinition Height="Auto"/>
 <RowDefinition Height="Auto"/>
 <RowDefinition Height=""/>
 <RowDefinition Height="Auto"/>
 </Grid.RowDefinitions>

 <!-- Input Section -->
 <GroupBox Header="User Details" Grid.Row="0" Margin="0,0,0,10">
 <Grid Margin="10">

 <Grid.ColumnDefinitions>
 <ColumnDefinition Width="120"/>
 <ColumnDefinition Width=""/>
 </Grid.ColumnDefinitions>

 <Grid.RowDefinitions>
 <RowDefinition Height="Auto"/>
 <RowDefinition Height="Auto"/>
 <RowDefinition Height="Auto"/>
 </Grid.RowDefinitions>

 <Label Grid.Row="0" Grid.Column="0">Name:</Label>
 <TextBox Name="txtName"
 Grid.Row="0"
 Grid.Column="1"
 Margin="5"/>

 <Label Grid.Row="1" Grid.Column="0">Email:</Label>
 <TextBox Name="txtEmail"
 Grid.Row="1"
 Grid.Column="1"
 Margin="5"/>

 <Label Grid.Row="2" Grid.Column="0">Department:</Label>
 <ComboBox Name="cmbDepartment"
 Grid.Row="2"
 Grid.Column="1"
 Margin="5"/>
 </Grid>
 </GroupBox>

 <!-- List Selection -->
 <GroupBox Header="Available Roles"
 Grid.Row="1"
 Margin="0,0,0,10">
 <Grid Margin="10">

 <ListBox Name="lstRoles"
 Height="120"
 SelectionMode="Extended"/>

 </Grid>
 </GroupBox>

 <!-- DataGrid -->
 <GroupBox Header="Current Users"
 Grid.Row="2"
 Margin="0,0,0,10">

 <DataGrid Name="dgUsers"
 AutoGenerateColumns="True"
 Margin="5"/>
 </GroupBox>

 <!-- Buttons -->
 <StackPanel Grid.Row="3"
 Orientation="Horizontal"
 HorizontalAlignment="Right">

 <Button Name="btnAdd"
 Content="Add User"
 Width="100"
 Margin="5"/>

 <Button Name="btnClear"
 Content="Clear"
 Width="100"
 Margin="5"/>

 <Button Name="btnClose"
 Content="Close"
 Width="100"
 Margin="5"/>

 </StackPanel>

 </Grid>
</Window>
"@

# Load Window
$reader = New-Object System.Xml.XmlNodeReader $xaml
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$txtName = $Window.FindName("txtName")
$txtEmail = $Window.FindName("txtEmail")
$cmbDepartment = $Window.FindName("cmbDepartment")
$lstRoles = $Window.FindName("lstRoles")
$dgUsers = $Window.FindName("dgUsers")
$btnAdd = $Window.FindName("btnAdd")
$btnClear = $Window.FindName("btnClear")
$btnClose = $Window.FindName("btnClose")

# Populate dropdown
@(
 "IT"
 "HR"
 "Finance"
 "Operations"
 "Sales"
) | ForEach-Object {
 [void]$cmbDepartment.Items.Add($)
}

# Populate role list
@(
 "Admin"
 "Developer"
 "Reader"
 "Operator"
 "Auditor"
) | ForEach-Object {
 [void]$lstRoles.Items.Add($)
}

# Data source
$Users = New-Object System.Collections.ObjectModel.ObservableCollection[object]

$dgUsers.ItemsSource = $Users

# Add button event
$btnAdd.Add_Click({

 if (:IsNullOrWhiteSpace($txtName.Text))
 {
 [System.Windows.MessageBox]::Show(
 "Please enter a name.",
 "Validation"
 )
 return
 }

 $SelectedRoles = (
 $lstRoles.SelectedItems |
 ForEach-Object { $_ }
 ) -join ", "

 $User = [PSCustomObject]@{
 Name = $txtName.Text
 Email = $txtEmail.Text
 Department = $cmbDepartment.Text
 Roles = $SelectedRoles
 }

 $Users.Add($User)
})

# Clear form
$btnClear.Add_Click({

 $txtName.Clear()
 $txtEmail.Clear()
 $cmbDepartment.SelectedIndex = -1
 $lstRoles.UnselectAll()
})

# Close form
$btnClose.Add_Click({
 $Window.Close()
})

# Display Form
$Window.ShowDialog() | Out-Null
````

## Recommended Structure for Larger Tools

For enterprise and administrative applications, split the code into separate components:

```text
App.ps1
├── XAML
├── ViewModel
├── Data Access
├── Event Handlers
└── Business Logic
```

### Example Project Layout

```text
WpfApp
│
├── Main.ps1
├── MainWindow.xaml
├── Modules
│   ├── Users.psm1
│   ├── Logging.psm1
│   └── Validation.psm1
└── Resources
    ├── Icons
    └── Themes
```

### Benefits

This follows an MVVM-style approach and scales much better for DevOps and administrative tooling than embedding all logic in a single script.

```
```
