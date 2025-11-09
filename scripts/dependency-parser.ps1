
function Get-NugetCacheLicenseInfo($packageName, $packageVersion) {
    if ($IsWindows) {
        $nugetCache = Join-Path $env:USERPROFILE ".nuget\packages\$packageName\$packageVersion"
    } else {
        $nugetCache = Join-Path $env:HOME ".nuget/packages/$($packageName.ToLower())/$packageVersion"
    }
    
    $nuspecPath = Get-ChildItem -Path $nugetCache -Filter *.nuspec -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($nuspecPath) {
        [xml]$nuspecXml = Get-Content $nuspecPath.FullName
        $licenseUrl = $nuspecXml.package.metadata.licenseUrl
        $licenseType = $nuspecXml.package.metadata.license.InnerText

        # Get dependencies from nuspec

        $dependencies = @()

        # Handle grouped dependencies
        if ($nuspecXml.package.metadata.dependencies.group) {
            foreach ($group in $nuspecXml.package.metadata.dependencies.group) {
            if ($group.dependency) {
                foreach ($dep in $group.dependency) {
                $dependencies += [PSCustomObject]@{
                    Name    = $dep.id
                    Version = $dep.version
                }
                }
            }
            }
        }
        
        # Handle direct dependencies (not in a group)
        elseif ($nuspecXml.package.metadata.dependencies.dependency) {
            foreach ($dep in $nuspecXml.package.metadata.dependencies.dependency) {
            $dependencies += [PSCustomObject]@{
                Name    = $dep.id
                Version = $dep.version
            }
            }
        }

        if ($nuspecXml.package.metadata.dependencies.dependency) {
            foreach ($dep in $nuspecXml.package.metadata.dependencies.dependency) {
                $dependencies += [PSCustomObject]@{
                    Name    = $dep.id
                    Version = $dep.version
                }
            }
        }
        if ($licenseUrl -or $licenseType) {
            return [PSCustomObject]@{
                Package      = $packageName
                Version      = $packageVersion
                LicenseUrl   = $licenseUrl
                LicenseType  = $licenseType
                Source       = "Cache"
                Dependencies = $dependencies
            }
        }
    }
    return $null
}

function Get-LicenseInfoWithCache($packageName, $packageVersion) {
    $cacheInfo = Get-NugetCacheLicenseInfo $packageName $packageVersion
    if ($cacheInfo) {
        return $cacheInfo
    } else {
        # $serverInfo = Get-LicenseInfo $packageName $packageVersion
        return [PSCustomObject]@{
            Package      = $packageName
            Version      =  $packageVersion
            LicenseUrl   = "Not found"
            LicenseType  = "Not found"
        }
    }
}

function Get-ProjectFiles($slnPath) {
    # Check if it's a .slnx file
    if ($slnPath -like "*.slnx") {
        return Get-SlnxProjectFiles $slnPath
    }
    
    # Process regular .sln files
    Select-String -Path $slnPath -Pattern 'Project\(' | ForEach-Object {
        $_.Line -match '",\s*"([^"]+\.csproj)"' | Out-Null
        Join-Path (Split-Path $slnPath) $matches[1]
    }
}

function Get-SlnxProjectFiles($slnxPath) {
    try {
        [xml]$xml = Get-Content $slnxPath
        $projects = @()

        # Get all .csproj files from the solution
        $xml.SelectNodes("//Project") | 
            Where-Object { $_.Path -like "*.csproj" } |
            ForEach-Object {
                $csprojPath = $_.Path
                
                # Convert relative paths to absolute
                if (-not [System.IO.Path]::IsPathRooted($csprojPath)) {
                    $csprojPath = Join-Path (Split-Path $slnxPath) $csprojPath
                }
                
                # Normalize path and add to results if file exists
                $normalizedPath = [System.IO.Path]::GetFullPath($csprojPath)
                if (Test-Path $normalizedPath) {
                    $projects += $normalizedPath
                } else {
                    Write-Warning "Project file not found: $normalizedPath"
                }
            }
        
        return $projects
    }
    catch {
        Write-Error "Failed to parse .slnx file: $_"
        return @()
    }
}

function Get-PackageReferences($csprojPath) {
    [xml]$xml = Get-Content $csprojPath
    $packageReferences = @()

    # Check for PackageReference nodes (used in SDK-style projects)
    if ($xml.Project.ItemGroup.PackageReference) {
        $packageReferences += $xml.Project.ItemGroup.PackageReference | ForEach-Object {
            [PSCustomObject]@{
                Name    = $_.Include
                Version = $_.Version
            }
        }
    }

    # Check for packages.config (used in full .NET Framework projects)
    $packagesConfigPath = Join-Path (Split-Path $csprojPath) "packages.config"
    if (Test-Path $packagesConfigPath) {
        [xml]$packagesConfigXml = Get-Content $packagesConfigPath
        $packageReferences += $packagesConfigXml.packages.package | ForEach-Object {
            [PSCustomObject]@{
                Name    = $_.id
                Version = $_.version
            }
        }
    }

    return $packageReferences | Sort-Object Name, Version -Unique
}

function Get-LicenseInfo($packageName, $packageVersion) {
    $url = "https://api.nuget.org/v3/registration5-semver1/$packageName/$packageVersion.json"
    try {
        $response = Invoke-RestMethod -Uri $url -ErrorAction Stop
        $licenseUrl = $response.licenseUrl
        $licenseType = $response.licenseExpression
        [PSCustomObject]@{
            Package      = $packageName
            Version      = $packageVersion
            LicenseUrl   = $licenseUrl
            LicenseType  = $licenseType
        }
    } catch {
        [PSCustomObject]@{
            Package      = $packageName
            Version      = $packageVersion
            LicenseUrl   = "Not found"
            LicenseType  = "Not found"
        }
    }
}

function Get-LicensesFromSolution($solutionPath) {
    # Look for both .sln and .slnx files
    $slnFile = Get-ChildItem -Path $SolutionPath -Filter *.sln | Select-Object -First 1
    if (-not $slnFile) {
        $slnFile = Get-ChildItem -Path $SolutionPath -Filter *.slnx | Select-Object -First 1
    }
    if (-not $slnFile) {
        Write-Error "No solution file (.sln or .slnx) found in $SolutionPath"
        exit 1
    }

    $projects = Get-ProjectFiles $slnFile.FullName
    $output = @{
        projects = @()
    }

    foreach ($proj in $projects) {
        if (Test-Path $proj) {
            $projectName = [System.IO.Path]::GetFileNameWithoutExtension($proj)
            $packageRefs = Get-PackageReferences $proj

            $licensesMap = @{}

            $i = 0
            while ($i -lt $packageRefs.Count) {
                $pkg = $packageRefs[$i]

                if (-not $pkg.Name) {
                    $i++
                    continue
                }
                $licenseInfo = Get-LicenseInfoWithCache $pkg.Name $pkg.Version

                # Add dependencies to $packageRefs if not already present
                # foreach ($dep in $licenseInfo.Dependencies) {
                #     if ($dep.Name -and ($packageRefs | Where-Object { $_.Name -eq $dep.Name -and $_.Version -eq $dep.Version }).Count -eq 0) {
                #         $packageRefs += [PSCustomObject]@{
                #             Name    = $dep.Name
                #             Version = $dep.Version
                #         }
                #     }
                # }

                $expression = $licenseInfo.LicenseType
                if (-not $expression -or $expression -eq "Not found") {
                    $expression = $licenseInfo.LicenseUrl
                }
                if (-not $expression) {
                    $expression = "Unknown"
                }

                if (-not $licensesMap.ContainsKey($expression)) {
                    $licensesMap[$expression] = @{
                        expression = $expression
                        count = 0
                        packages = @()
                        isDeprecatedType = $false
                    }
                }

                $licensesMap[$expression].count++
                $licensesMap[$expression].packages += @{
                    name = $pkg.Name
                    version = $pkg.Version
                    url = $licenseInfo.LicenseUrl
                    displayName = "$($pkg.Name)@$($pkg.Version)"
                }

                # Mark deprecated if licenseUrl is used instead of license expression
                if ($licenseInfo.LicenseUrl -and (-not $licenseInfo.LicenseType -or $licenseInfo.LicenseType -eq "Not found")) {
                    $licensesMap[$expression].isDeprecatedType = $true
                }
                $i++
            }

            $output.projects += @{
                projectName = $projectName
                licenses = $licensesMap.Values
            }
        }
    }

    return $output
}
