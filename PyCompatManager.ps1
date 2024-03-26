# param(
#     [Parameter(Mandatory = $false, Position = 0)]
#     [string]$PackageName,

#     [Parameter(Mandatory = $false, Position = 1, ParameterSetName = "Named")]
#     [string]$PackageNameNamed
# )

# # If the named parameter is used, it overrides the positional one.
# if ($null -ne $PackageNameNamed) {
#     $PackageName = $PackageNameNamed
# }

# if ($null -eq $PackageName) {
#     Write-Host "Usage: .\PyCompatManager.ps1 [-PackageName] <your-package-name>"
#     exit
# }




# The Python version to match or find a slightly lower version for
$targetPythonVersion = [version](python --version 2>&1 | ForEach-Object { $_ -replace '^Python\s', '' } | ForEach-Object { ($_.Split('.')[0..1]) -join '.' })
$pythonPath = (Get-Command python).Source
function Get-Json {
    param (
        [Parameter(mandatory = $true)]
        [string]$PackageName
    )

    $url = "https://pypi.org/pypi/$PackageName/json"
    try {
        $response = Invoke-RestMethod -Uri $url
    }
    catch {
        Write-Error "Failed to fetch data: $_"
        return $null
    }
    
    return $response
}


# Function to check if a version satisfies the requirement
function Test-VersionCompatibility {
    param (
        [Parameter(mandatory = $true)]
        [version]$requiredVersion,
        [Parameter(mandatory = $true)]
        [string]$requiresPython
    )

    $versionConstraints = $requiresPython -split ','

    foreach ($condition in $versionConstraints) {
        if ($condition -match '([23]\.\d+)') {
            $onlyVersion = [version]$Matches[1]
            if ($requiredVersion -eq $onlyVersion) {
                return $true
            }
        }
        if ($condition -match '>=?([23]\.\d+)') {
            $minVersion = [version]$Matches[1]
            if ($requiredVersion -lt $minVersion) {
                return $false
            }
        }
        if ($condition -match '<=?([23]\.\d+)') {
            $maxVersion = [version]$Matches[1]
            if ($requiredVersion -gt $maxVersion) {
                return $false
            }
        }
        if ($condition -match '!=?([23]\.\d+)') {
            $notVersion = [version]$Matches[1]
            if ($requiredVersion -eq $notVersion) {
                return $false
            }
        }
        # Add more conditions here for other specifiers like ~=, >, <
    }

    return $true
}


function Get-Latest {
    param (
        [Parameter(mandatory = $true)]
        [version]$requiredVersion,
        [Parameter(mandatory = $true)]
        [string]$PackageName
    )

    $jsonContent = Get-Json -PackageName $PackageName

    # Iterate through releases in reverse chronological order
    foreach ($release in ($jsonContent.releases.PSObject.Properties | Sort-Object Name -Descending)) {
        foreach ($package in $release.Value) {
            if ($null -ne $package.requires_python -and 
                (Test-VersionCompatibility -requiredVersion $requiredVersion -requiresPython $package.requires_python)) {
                # Write-Output $package
                if ($package.filename -match '\.(zip|tar\.gz)$') {
                    return $package.url  # Return the URL string directly
                }
            }
        }
    }

    # Return null or empty string if no compatible release found
    return $null
}




function Fetch-Package {
    param (
        [Parameter(mandatory = $true)]
        [string]$url,
        [Parameter(mandatory = $true)]
        [string]$tempDir
    )



    # Ensure the temporary directory exists
    if (-Not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir | Out-Null
    }

    # Download the file
    $localFilePath = Join-Path $tempDir (Split-Path $url -Leaf)
    # Check if the file already exists
    if (-Not (Test-Path $localFilePath)) {
        Invoke-WebRequest -Uri $url -OutFile $localFilePath
        Write-Output "Downloaded: $localFilePath"
    }
    else {
        Write-Output "File already exists: $localFilePath"
    }


    # Determine the expected directory name from the archive file name
    $expectedDirName = [System.IO.Path]::GetFileNameWithoutExtension($localFilePath)
    if ($expectedDirName.EndsWith('.tar')) {
        $expectedDirName = [System.IO.Path]::GetFileNameWithoutExtension($expectedDirName)
    }
    $expectedDirPath = Join-Path $tempDir $expectedDirName

    # Check if the directory already exists
    if (-Not (Test-Path $expectedDirPath)) {
        # Determine the file type and unpack accordingly
        if ($localFilePath.EndsWith('.zip')) {
            Expand-Archive -Path $localFilePath -DestinationPath $tempDir
        }
        elseif ($localFilePath.EndsWith('.tar.gz')) {
            # Requires tar command available in Windows 10 build 17063 and later
            tar -xzf $localFilePath -C $tempDir
        }
        Write-Output "Unpacked to: $expectedDirPath"
    }
    else {
        Write-Output "Directory already exists: $expectedDirPath"
    }




    # Change to the directory where the files are extracted
    # Assuming $url is the package download URL
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path -Leaf $url))

    # If the package is a .tar.gz, the directory name will typically match the filename without the .tar extension
    if ($fileName.EndsWith('.tar')) {
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    }

    # Find the directory that starts with the extracted filename
    $packageDir = Get-ChildItem $tempDir -Directory | Where-Object { $_.Name -like "$fileName*" } | Select-Object -First 1

    if ($null -eq $packageDir) {
        Write-Output "Failed to find unpacked directory for $fileName in $tempDir"
        exit
    }


    # Construct the absolute path to setup.py
    # $setupFilePath = Join-Path -Path $packageDir.FullName -ChildPath "setup.py"

    # Run the setup.py install command using the absolute path
    # & $pythonPath $setupFilePath install

    Write-Output $packageDir.FullName
    # Exit
    $setupDir = $packageDir.FullName

    # Change directory and run setup.py install within the same Python command
    # $cmd = "$pythonPath -c `"import os; os.chdir(r'$setupDir'); exec(open('setup.py').read())`" install"
    $cmd = "$pythonPath -c `"import os; __file__ = r'$setupDir\setup.py'; os.chdir(os.path.dirname(__file__)); exec(open(__file__).read())`" install"


    # Execute the command
    Invoke-Expression $cmd


}

function Install-Dependencies {
    param(
        [string]$PackageName
    )
    $details = Get-Json -PackageName $PackageName
    $dependencies = $details.info.requires_dist

    

    if ($dependencies) {
        foreach ($dependency in $dependencies) {
            # Parse and extract the package name and acceptable version from the dependency string
            $match = [regex]::Match($dependency, '^(?<name>[\w\.-]+)(?<version>(?:<|>|=|~|!|,|\^|\s)+[\w\.-]+)?')
            if ($match.Success) {
                $dependencyName = $match.Groups['name'].Value
                $versionConstraint = $match.Groups['version'].Value

                # Check if there is a version constraint and format it properly for pip installation
                if ($null -ne $versionConstraint) {
                    $dependencyName = "$dependencyName$versionConstraint"
                }

                # Write-Output $dependencyName
                # Break

                # Recursively install dependencies
                Install-Dependencies -PackageName $dependencyName
            }

        }
    }

    # Exit

    # Here you would call your function or logic to install the package
    # Attempt to install the package using pip
    try {
        $installCommand = "python -m pip install $PackageName"
        Invoke-Expression $installCommand
        Write-Host "$PackageName installed successfully."
    }
    catch {
        Write-Host "Failed to install $PackageName. Error: $_"
    }

}


$packageName = $args[0]

# Install-Dependencies -PackageName $PackageName
# Exit

# Assuming Get-Latest function is modified to return download URL
$downloadUrl = Get-Latest -requiredVersion $targetPythonVersion -PackageName $packageName
Write-Output $downloadUrl
# Exit


# Specify the temporary directory for downloading and unpacking
$tempDir = "C:\Temp\DownloadedPackages"

if (-not [string]::IsNullOrWhiteSpace($downloadUrl)) {
    Fetch-Package -url $downloadUrl -tempDir $tempDir
}
else {
    Write-Host "Download URL is empty or not a string."
}

