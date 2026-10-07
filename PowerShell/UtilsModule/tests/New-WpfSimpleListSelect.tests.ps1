BeforeAll {
    $xamlPath = Join-Path $PSScriptRoot '..\public\dialog\New-WpfSimpleListSelect.xml' -Resolve
    [xml]$xaml = Get-Content -Path $xamlPath -Raw
}

Describe 'New-WpfSimpleListSelect XAML' {
    It 'contains the named controls required by the selection function' {
        $expectedControls = @{
            PickList    = 'ComboBox'
            OkButton    = 'Button'
            CancelButton = 'Button'
        }

        foreach ($name in $expectedControls.Keys) {
            $control = $xaml.SelectSingleNode("//*[@Name='$name']")

            $control | Should -Not -BeNullOrEmpty
            $control.LocalName | Should -Be $expectedControls[$name]
        }
    }
}