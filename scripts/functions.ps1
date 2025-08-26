function ContainsPackage {
    param(
        [string]$packageName,
        [string]$packageVersion,
        [array]$packages
    )

    if (-not $packageName -or -not $packageVersion -or -not $packages) {
        return $false
    }

    foreach ($package in $packages) {
        if ($package.name -eq $packageName) {
            $minVersion = $package.minVersion
            $maxVersion = $package.maxVersion

            if (-not [string]::IsNullOrEmpty($minVersion) -and [version]$packageVersion -lt [version]$minVersion) {
                return $false
            }
            if (-not [string]::IsNullOrEmpty($maxVersion) -and [version]$packageVersion -gt [version]$maxVersion) {
                return $false
            }
            return $true
        }
    }
    return $false
}

function Get-SpdxLicensesFromExpression {
        param(
            [string]$expression
        )
        
        # Return empty array if expression is empty
        if ([string]::IsNullOrWhiteSpace($expression)) {
            return @()
        }
        
        # Remove parentheses
        $expressionWithoutParentheses = $expression -replace '\(|\)', ''
        
        # Split by 'AND' and 'OR' operators, handling case insensitivity
        $licenses = $expressionWithoutParentheses -split '(?i)\s+(?:AND|OR)\s+'
        
        # Remove '+' (later version indicator) and trim whitespace
        $cleanedLicenses = $licenses | ForEach-Object { $_.Trim() -replace '\+$', '' }
        
        # Return unique licenses
        return $cleanedLicenses | Select-Object -Unique
}
