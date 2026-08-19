# ```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot ("..\public\{0}.ps1" -f ($MyInvocation.MyCommand.Name -replace '\.Tests\.ps1$', '')))
}

Describe "Update-UserEnvPath" {
    BeforeEach {
        $script:originalPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
        $script:originalPSModulePath = [Environment]::GetEnvironmentVariable("PSModulePath", [System.EnvironmentVariableTarget]::User)
    }

    AfterEach {
        if ($null -ne $script:originalPath) {
            [Environment]::SetEnvironmentVariable("Path", $script:originalPath, [System.EnvironmentVariableTarget]::User)
        }
        else {
            [Environment]::SetEnvironmentVariable("Path", $null, [System.EnvironmentVariableTarget]::User)
        }

        if ($null -ne $script:originalPSModulePath) {
            [Environment]::SetEnvironmentVariable("PSModulePath", $script:originalPSModulePath, [System.EnvironmentVariableTarget]::User)
        }
        else {
            [Environment]::SetEnvironmentVariable("PSModulePath", $null, [System.EnvironmentVariableTarget]::User)
        }
    }

    It "adds a new path for Path when the path is not already present" {
        $userPath = "C:\Temp\Existing;C:\Windows\System32"
        [Environment]::SetEnvironmentVariable("Path", $userPath, [System.EnvironmentVariableTarget]::User)

        $newPath = "C:\Custom\Tools"
        Update-UserEnvPath -VariableName "Path" -NewPath $newPath

        $updatedValue = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
        ($updatedValue -split ';') -contains $newPath | Should -BeTrue
    }

    It "adds a new path for PSModulePath when the path is not already present" {
        $userPSModulePath = "C:\Users\Public\Documents\WindowsPowerShell\Modules"
        [Environment]::SetEnvironmentVariable("PSModulePath", $userPSModulePath, [System.EnvironmentVariableTarget]::User)

        $newPath = "C:\Custom\Modules"
        Update-UserEnvPath -VariableName "PSModulePath" -NewPath $newPath

        $updatedValue = [Environment]::GetEnvironmentVariable("PSModulePath", [System.EnvironmentVariableTarget]::User)
        ($updatedValue -split ';') -contains $newPath | Should -BeTrue
    }

    It "does not duplicate an existing path" {
        $newPath = "C:\Custom\Tools"
        $userPath = "C:\Temp\Existing;$newPath;C:\Windows\System32"
        [Environment]::SetEnvironmentVariable("Path", $userPath, [System.EnvironmentVariableTarget]::User)

        Update-UserEnvPath -VariableName "Path" -NewPath $newPath

        $updatedValue = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
        (($updatedValue -split ';') | Where-Object { $_ -eq $newPath }).Count | Should -Be 1
    }

    It "creates a user env var when it is currently empty" {
        [Environment]::SetEnvironmentVariable("Path", $null, [System.EnvironmentVariableTarget]::User)

        $newPath = "C:\Custom\Tools"
        Update-UserEnvPath -VariableName "Path" -NewPath $newPath

        $updatedValue = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
        $updatedValue | Should -Be $newPath
    }

    It "validates the variable name" {
        { Update-UserEnvPath -VariableName "Bogus" -NewPath "C:\Custom\Tools" } | Should -Throw
    }
}
```

This is a Pester 5 test script and it covers add, no-duplicate, empty-value, and validation scenarios.