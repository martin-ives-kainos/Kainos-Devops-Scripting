function Get-WpfDate {
    [CmdletBinding()]
    param (
        [datetime]$DefaultDate = (Get-Date),
        [String]$Title
    )

Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Select Date"
        Height="150"
        Width="300"
        WindowStartupLocation="CenterScreen">
    <StackPanel Margin="10">
        <DatePicker Name="dpDate" />
        <Button Name="btnOK"
                Content="OK"
                Width="80"
                Margin="0,10,0,0"
                HorizontalAlignment="Right" />
    </StackPanel>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$window.Title = $Title

$dpDate = $window.FindName("dpDate")
$btnOK  = $window.FindName("btnOK")

# Default to today
$dpDate.SelectedDate = $DefaultDate

$selectedDate = $null

$btnOK.Add_Click({
    $window.DialogResult = $true
    $window.Close()
})

$window.ShowDialog() | Out-Null

if ($window.DialogResult -eq $true) {
    $selectedDate = $dpDate.SelectedDate
}
$selectedDate

<#     param (
#        [string]$DateFormat = 'yyyy-MM-dd'
    )

    Add-Type -AssemblyName PresentationFramework
    $datePicker = New-Object System.Windows.Controls.DatePicker
    $window = New-Object System.Windows.Window
    $window.Title = 'Select a Date:'
    $window.Content = $datePicker
    $window.SizeToContent = 'WidthAndHeight'
    $window.WindowStartupLocation = 'CenterScreen'
    $window.ShowDialog() | Out-Null

#    return $datePicker.SelectedDate.Value.ToString($DateFormat)
    return $datePicker.SelectedDate.Value #>
}