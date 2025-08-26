param(
    [string]$workingDir = "$(Get-Location)",
    [bool]$failOnViolations = $false,
    [string]$licenseRulesPath = ""
)

. "$PSScriptRoot/functions.ps1"
. "$PSScriptRoot/dependency-parser.ps1"
. "$PSScriptRoot/console-export.ps1"

Write-Output "Project: $($workingDir)"

# Check if the dotnet application has been built, else build it
$sanitizedWorkingDir = $workingDir -replace '"', ''
if (-not (Test-Path -Path $sanitizedWorkingDir -PathType Container)) {
    Write-Output "Directory '$sanitizedWorkingDir' does not exist. Exiting."
    [Environment]::Exit(1)
}

$root = Get-LicensesFromSolution $sanitizedWorkingDir

# Default allowed licenses
$allowedLicenses = @("MIT", "Project References", "Apache-2.0", "EULA.md", "Microsoft Software License", "BSD-3-Clause")

# Load SPDX licenses metadata from JSON file
$spdxLicensesPath = Join-Path -Path $PSScriptRoot -ChildPath "./data/spdx-licenses.json"
if (Test-Path $spdxLicensesPath) {
    Write-Output "Loading SPDX licenses from $($spdxLicensesPath)"
    $spdxLicenses = Get-Content $spdxLicensesPath -Raw | ConvertFrom-Json
} else {
    Write-Output "SPDX licenses file not found at $($spdxLicensesPath)."
}

# Read license and package rules from a JSON file
if ($licenseRulesPath -and (Test-Path $licenseRulesPath)) {
    $rulesPath = $licenseRulesPath
}
else {
    $rulesPath = Join-Path -Path $sanitizedWorkingDir -ChildPath "license-rules.json"
}
if (Test-Path $rulesPath) {
    Write-Output "Loaded configuration from $($rulesPath)"
    $rulesJson = Get-Content $rulesPath -Raw | ConvertFrom-Json

    $allowedLicenses = $rulesJson.allowedLicenses
    $allowedPackages = $rulesJson.allowedPackages
    $disallowedPackages = $rulesJson.disallowedPackages | ForEach-Object {       
        [PSCustomObject]@{
            name       = $_.name
            minVersion = $_.minVersion
            maxVersion = $_.maxVersion
        }
    }
    $allowedPackages = $rulesJson.allowedPackages | ForEach-Object {
        [PSCustomObject]@{
            name       = $_.name
            minVersion = $_.minVersion
            maxVersion = $_.maxVersion
        }
    }
}

$allowedLicenseCount = 0
$disallowedLicenseCount = 0
$disallowedPackageCount = 0
$allowedPackagesCount = 0
$licensesMarkdown = ""

Write-Output $rootJson

$disallowedPackagesList = @()

Write-Output "📦 Analyzing NuGet packages..."
foreach ($project in $root.projects) {
    $projectName = $project.projectName
    foreach ($license in $project.licenses) {
        $expressions = Get-SpdxLicensesFromExpression $license.expression
        foreach ($expression in $expressions) {
            if ($allowedLicenses -contains $expression) {
                $disallowedLicenseMarkdown = ""
                $hasAtLeastOneAllowedPackage = $false
                $disallowedLicenseMarkdown += "### $($projectName): $($expression)`n"
                $disallowedLicenseMarkdown += "Not allowed licenses found in these packages:`n"
                foreach ($package in $license.packages) {
                    $packageName = $package.name
                    $packageVersion = $package.version
                    $isDisallowed = ContainsPackage -packageName $packageName -packageVersion $packageVersion -packages $disallowedPackages
                    if ($isDisallowed) {
                        $disallowedPackageCount += 1
                        $matchingDisallowedPackage = $disallowedPackages | Where-Object {
                            $_.name -eq $packageName -and 
                            ($_.minVersion -le $packageVersion -or [string]::IsNullOrEmpty($_.minVersion)) -and 
                            ($_.maxVersion -ge $packageVersion -or [string]::IsNullOrEmpty($_.maxVersion))
                        }
                        $comment = $matchingDisallowedPackage.comment
                        Write-Host $matchingDisallowedPackage

                        $disallowedPackagesList += [PSCustomObject]@{
                            PackageName    = $packageName
                            PackageVersion = $packageVersion
                            ProjectName    = $projectName
                            License        = $expression
                            Comment        = $comment
                        }
                    }
                    else {
                        $hasAtLeastOneAllowedPackage = $true
                        $allowedPackagesCount += 1
                    }
                }

                if ($hasAtLeastOneAllowedPackage) {
                    $allowedLicenseCount += 1
                }
            }
            # Licenses that are not in the allowed list
            else {
                # Check here if the licenses contains allowed packages
                foreach ($package in $license.packages) {
                    $packageName = $package.name
                    $packageVersion = $package.version
                    $isAllowedPackage = ContainsPackage -packageName $packageName -packageVersion $packageVersion -packages $allowedPackages
                    if ($isAllowedPackage) {
                        $allowedPackagesCount += 1
                    }
                    else {
                        $disallowedPackagesList += [PSCustomObject]@{
                            PackageName    = $packageName
                            PackageVersion = $packageVersion
                            ProjectName    = $projectName
                            License        = $expression
                            Comment        = "License not allowed"
                        }
                        $disallowedPackageCount += 1
                    }
                    $disallowedLicenseCount += 1
                }
            }
        }
    }
}

Write-Output "🔬 Processing license analysis results..."

Write-Output "Allowed packages found: $($allowedPackagesCount) "
Write-Output "Not allowed packages found: $($disallowedPackageCount)"

# Write information to the GitHub job summary
$summaryFile = $env:GITHUB_STEP_SUMMARY

$result = $disallowedPackagesList.Count -eq 0 ? "✅" : "❌"
$summaryContent = "# [$($result)] 🛡 Licenses report"

if ($disallowedPackagesList.Count -gt 0) {
    $summaryContent += "`n## ⚠️ Violations`n"
    $groupedDisallowedPackages = $disallowedPackagesList | Group-Object -Property ProjectName
    $summaryContent += "| Project | Name | Version | License | Comment |`n"
    $summaryContent += "|---------|------|---------|---------|---------|`n"
    foreach ($group in $groupedDisallowedPackages) {
        foreach ($package in $group.Group) {
            $summaryContent += "| $($group.Name) | $($package.PackageName) | $($package.PackageVersion) | $($package.License) | $($package.Comment) |`n"
        }
    }
    if (-not [string]::IsNullOrEmpty($licensesMarkdown)) {
        $summaryContent += "`n$($licensesMarkdown)"
    }
}

# $summaryContent += "`n## Package details"
# foreach ($project in $root.projects) {
#     $summaryContent += "`n<details>`n"
#     $summaryContent += "`n<summary>$($project.projectName)</summary>`n"
#     foreach ($license in $project.licenses) {
#         $summaryContent += "`n- $($license.expression) [$($license.count) packages]`n"
#         foreach ($package in $license.packages) {
#             $packageName = $package.name
#             $packageVersion = $package.version
#             $summaryContent += "`n  - $($packageName) $($packageVersion)"
#         }
#     }
#     $summaryContent += "`n</details>`n"
# }

$summaryContent += "`n## 📊 License usage summary`n"
$summaryContent += "| License | Package Count | OSI approved | Deprecated |`n"
$summaryContent += "|---------|---------------|--------------|------------|`n"

$licenseUsage = @{}
foreach ($project in $root.projects) {
    foreach ($license in $project.licenses) {
        if (-not $licenseUsage.ContainsKey($license.expression)) {
            $licenseUsage[$license.expression] = @{}
        }
        foreach ($package in $license.packages) {
                $licenseUsage[$license.expression][$package.name] = $true
        }
    }
}

$licenseUsageSorted = $licenseUsage.Keys | Sort-Object -Property { $licenseUsage[$_].Count } -Descending
foreach ($license in $licenseUsageSorted) {
    $packageCount = $licenseUsage[$license].Count
    $spdxLicense = $spdxLicenses.licenses | Where-Object { $_.licenseId -eq $license }
    $osiVisual ="?"
    $deprecatedVisual = "?"
    if ($spdxLicense) {
        $osiVisual = $spdxLicense.isOsiApproved ? "✅" : "❌"
        $deprecatedVisual = $spdxLicense.isDeprecatedLicenseId ? "✅" : "❌"
    }

    $summaryContent += "| $license | $packageCount | $osiVisual | $deprecatedVisual |`n"
}


if (-not [string]::IsNullOrEmpty($summaryFile)) {
    Set-Content -Path $summaryFile -Value $summaryContent
}
else {
    $convertedMarkdown = Convert-MarkdownToConsole -Markdown $summaryContent
    Write-Host $convertedMarkdown
}

if ($failOnViolations -and $disallowedPackagesList.Count -gt 0) {
    [Environment]::Exit(1603)
}
Write-Output "🎉 NuGet License Sentinel analysis completed successfully!"