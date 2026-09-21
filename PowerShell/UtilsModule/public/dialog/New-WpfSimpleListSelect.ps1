function New-WpfSimpleListSelect {
    param (
        [string]$Title = "Simple List selection",
        [string[]]$Items = @("Option 1", "Option 2", "Option 3", "Option 4")
    )
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore

    # Demonstration of loading a list of required modules for local installation, by passing Admin privileges

    [xml]$xaml = (Get-Content -Path (Join-Path $PSScriptRoot "LocalSetup_SelectModuleForm.xml") -Raw)
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $pickList = $window.FindName("PickList")
    $okButton = $window.FindName("OkButton")
    $cancelButton = $window.FindName("CancelButton")
    $window.Title = $Title

    # Populate the pick list with sample values
    foreach ($item in $items) {
        [void]$pickList.Items.Add($item)
    }
    $pickList.SelectedIndex = 0

    $okButton.Add_Click({
            $window.DialogResult = $true
            $window.Close()
        })

    $cancelButton.Add_Click({
            $window.DialogResult = $false
            $window.Close()
        })

    $result = $window.ShowDialog()

    if ($result -eq $true) {
        return $($pickList.SelectedItem)
    }
    else {
        Write-Host "Dialog was cancelled."
        return $null
    }
}