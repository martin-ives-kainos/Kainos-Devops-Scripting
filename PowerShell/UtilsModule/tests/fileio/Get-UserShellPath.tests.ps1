BeforeAll {
    . (Join-Path $PSScriptRoot '..\..\public\fileio\Get-UserShellPath.ps1')
}

Describe "Get-UserShellPath" {
    BeforeEach {
        Mock Get-Item {
            [pscustomobject]@{ Property = @('Desktop', 'Personal') }
        }

        Mock Get-ItemProperty {
            [pscustomobject]@{ Desktop = 'C:\Users\Test\Desktop' }
        }
    }

    It "returns the path for a valid user shell folder" {
        Get-UserShellPath -FolderName 'Desktop' | Should -Be 'C:\Users\Test\Desktop'
    }

    It "throws when the folder name is not a valid user shell folder" {
        { Get-UserShellPath -FolderName 'InvalidFolder' } | Should -Throw 'InvalidFolder not a valid User Shell Folder'
    }

    It "does not query the folder path for an invalid folder name" {
        { Get-UserShellPath -FolderName 'InvalidFolder' } | Should -Throw

        Should -Not -Invoke Get-ItemProperty
    }

    It "rejects an empty folder name" {
        { Get-UserShellPath -FolderName '' } | Should -Throw
    }
}