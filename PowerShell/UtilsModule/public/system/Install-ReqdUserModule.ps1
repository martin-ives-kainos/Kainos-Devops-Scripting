function Install-ReqdUserModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'
    #
    # Find the latest version in PowerShell Gallery
    #
    $galleryModule = Find-Module -Name $Name -Repository PSGallery

    #
    # Return if latest version is already installed
    #
    $installedModule = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1

    if ($installedModule -and $installedModule.Version -ge $galleryModule.Version) {
        Write-Verbose "$Name version $($installedModule.Version) is already installed."
        return $installedModule
    }
    #
    # Find a writable user module path
    #
    $userModulePaths = [Environment]::GetEnvironmentVariable('PSModulePath','User') -split [IO.Path]::PathSeparator | Where-Object { $_ }

    $modulePath = $userModulePaths |
    Where-Object {
        try {
            New-Item -ItemType Directory -Path $_ -Force -ErrorAction Stop | Out-Null

            $testFileName = [guid]::NewGuid().ToString()
            $testFile = Join-Path $_ $testFileName

            Set-Content `
                -Path $testFile `
                -Value 'test' `
                -ErrorAction Stop

            Remove-Item $testFile -Force

            $true
        }
        catch {
            $false
        }
    } |
    Select-Object -First 1

    if (-not $modulePath) {
        throw 'No writable Current User PSModulePath location was found.'
    }
    #
    # Attempt normal Install-Module first
    #
    try {

        Write-Verbose 'Installing via Install-Module.'

        Install-Module `
            -Name $Name `
            -Repository PSGallery `
            -Scope CurrentUser `
            -Force `
            -AllowClobber `
            -ErrorAction Stop

        $installedModule = Get-Module -ListAvailable -Name $Name |
        Sort-Object Version -Descending |
        Select-Object -First 1

        if ($installedModule -and $installedModule.Version -ge $galleryModule.Version) {
            return $installedModule
        }

        throw 'Install-Module completed but the module is not available.'
    }
    catch {

        Write-Warning "Install-Module failed: $($_.Exception.Message)"
    }

    $tempFolderName = [guid]::NewGuid().ToString()
    $tempPath = Join-Path ([IO.Path]::GetTempPath()) $tempFolderName

    try {

        New-Item `
            -ItemType Directory `
            -Path $tempPath `
            -Force |
        Out-Null

        #
        # Fallback 1: Save-Module
        #
        try {

            Write-Verbose 'Attempting Save-Module fallback.'

            Save-Module `
                -Name $Name `
                -Repository PSGallery `
                -Path $tempPath `
                -Force `
                -ErrorAction Stop

            $savedModule = Get-ChildItem $tempPath -Directory |
            Select-Object -First 1

            if (-not $savedModule) {
                throw 'Module was not downloaded.'
            }

            $destination = Join-Path $modulePath $savedModule.Name

            if (Test-Path $destination) {
                Remove-Item $destination -Recurse -Force
            }

            Copy-Item `
                -Path $savedModule.FullName `
                -Destination $destination `
                -Recurse `
                -Force

            $installedModule = Get-Module -ListAvailable -Name $Name |
            Sort-Object Version -Descending |
            Select-Object -First 1

            if ($installedModule) {
                Import-Module $Name -Force -ErrorAction SilentlyContinue
                return $installedModule
            }

            throw 'Module copied but not discovered.'
        }
        catch {

            Write-Warning "Save-Module failed: $($_.Exception.Message)"
            Write-Verbose 'Attempting direct PSGallery package download.'
        }

        #
        # Fallback 2: Direct NuGet package download
        #
        $version = $galleryModule.Version.ToString()

        $packageUrl = "https://www.powershellgallery.com/api/v2/package/$Name/$version"

        $nupkgFile = Join-Path $tempPath "$Name.$version.nupkg"
        $extractPath = Join-Path $tempPath 'Expanded'

        Invoke-WebRequest `
            -Uri $packageUrl `
            -OutFile $nupkgFile `
            -ErrorAction Stop

        Expand-Archive `
            -Path $nupkgFile `
            -DestinationPath $extractPath `
            -Force

        #
        # Locate the module manifest
        #
        $manifest = Get-ChildItem `
            -Path $extractPath `
            -Recurse `
            -Filter *.psd1 |
        Where-Object {
            $_.BaseName -eq $Name
        } |
        Select-Object -First 1

        if (-not $manifest) {
            throw "Unable to locate $Name.psd1 in downloaded package."
        }

        $sourceModuleFolder = $manifest.Directory.FullName
        $destination = Join-Path $modulePath $Name

        if (Test-Path $destination) {
            Remove-Item $destination -Recurse -Force
        }

        New-Item `
            -ItemType Directory `
            -Path $destination `
            -Force |
        Out-Null

        Copy-Item `
            -Path (Join-Path $sourceModuleFolder '*') `
            -Destination $destination `
            -Recurse `
            -Force

        $installedModule = Get-Module -ListAvailable -Name $Name |
        Sort-Object Version -Descending |
        Select-Object -First 1

        if (-not $installedModule) {
            throw 'Direct package installation completed but the module was not discovered.'
        }

        Import-Module `
            -Name $Name `
            -Force `
            -ErrorAction SilentlyContinue

        return $installedModule
    }
    finally {

        if (Test-Path $tempPath) {
            Remove-Item `
                -Path $tempPath `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}