BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
} 

Describe "Package Validation Functions" {   

    Context "Contains package" {
        It "Returns $true for a package within allowed version range" {
            $allowedPackages = @(
                @{
                    name = "TestPackage"
                    minVersion = "1.0.0"
                    maxVersion = "2.0.0"
                }
            )
            $result =  ContainsPackage -packageName "TestPackage" -packageVersion "1.5.0" -packages $allowedPackages
            $result | Should -Be $true
        }

        It "Returns $true for a package within allowed version range and only minVersion" {
            $allowedPackages = @(
                @{
                    name = "TestPackage"
                    minVersion = "1.0.0"
                }
            )
            $result =  ContainsPackage -packageName "TestPackage" -packageVersion "1.5.0" -packages $allowedPackages
            $result | Should -Be $true
        }

        It "Returns $true for a package within allowed version range and only minVersion" {
            $allowedPackages = @(
                @{
                    name = "TestPackage"
                    maxVersion = "2.0.0"
                }
            )
            $result =  ContainsPackage -packageName "TestPackage" -packageVersion "1.5.0" -packages $allowedPackages
            $result | Should -Be $true
        }

        It "Returns $false for a package below allowed version range" {
            $allowedPackages = @(
                @{
                    name = "TestPackage"
                    minVersion = "1.0.0"
                    maxVersion = "2.0.0"
                }
            )
            $result = ContainsPackage -packageName "TestPackage" -packageVersion "0.9.0" -packages $allowedPackages
            $result | Should -Be $false
        }

        It "Returns $true for a package when no range is defined" {
            $disallowedPackages = @(
                @{
                    name = "TestPackage"
                }
            )
            $result = ContainsPackage -packageName "TestPackage" -packageVersion "1.5.0" -packages $disallowedPackages
            $result | Should -Be $true
        }

        It "Returns $false for a package above allowed version range" {
            $allowedPackages = @(
                @{
                    name = "TestPackage"
                    minVersion = "1.0.0"
                    maxVersion = "2.0.0"
                }
            )
            $result = ContainsPackage -packageName "TestPackage" -packageVersion "2.1.0" -packages $allowedPackages
            $result | Should -Be $false
        }

        It "Returns $true for a package with exact maxVersion" {
            $allowedPackages = @(
                @{
                    name = "TestPackage"
                    minVersion = "1.0.0"
                    maxVersion = "2.0.0"
                }
            )
            $result = ContainsPackage -packageName "TestPackage" -packageVersion "2.0.0" -packages $allowedPackages
            $result | Should -Be $true
        }

        It "Returns $true for a package with exact minVersion" {
            $allowedPackages = @(
                @{
                    name = "TestPackage"
                    minVersion = "1.0.0"
                    maxVersion = "2.0.0"
                }
            )
            $result = ContainsPackage -packageName "TestPackage" -packageVersion "1.0.0" -packages $allowedPackages
            $result | Should -Be $true
        }
    }

    Context "Unlisted Packages" {
        It "Returns $false for a package not listed in allowed packages" {
            $allowedPackages = @()
            $result = ContainsPackage -packageName "UnlistedPackage" -packageVersion "1.0.0" -packages $allowedPackages
            $result | Should -Be $false
        }
    }
}

Describe "SPDX License Expression Parsing" {

    It "Returns empty array for null or empty expression" {
        Get-SpdxLicensesFromExpression -expression $null | Should -BeNullOrEmpty
        Get-SpdxLicensesFromExpression -expression "" | Should -BeNullOrEmpty
        Get-SpdxLicensesFromExpression -expression "   " | Should -BeNullOrEmpty
    }

    It "Returns single license for simple expression" {
        $result = Get-SpdxLicensesFromExpression -expression "MIT"
        $result | Should -HaveCount 1
        $result | Should -Contain "MIT"
    }

    It "Removes parentheses from expressions" {
        $result = Get-SpdxLicensesFromExpression -expression "(MIT)"
        $result | Should -HaveCount 1
        $result | Should -Contain "MIT"
    }

    It "Splits expressions with AND operator" {
        $result = Get-SpdxLicensesFromExpression -expression "MIT AND Apache-2.0"
        $result | Should -HaveCount 2
        $result | Should -Contain "MIT"
        $result | Should -Contain "Apache-2.0"
    }

    It "Splits expressions with OR operator" {
        $result = Get-SpdxLicensesFromExpression -expression "MIT OR GPL-3.0"
        $result | Should -HaveCount 2
        $result | Should -Contain "MIT"
        $result | Should -Contain "GPL-3.0"
    }

    It "Handles case insensitivity in operators" {
        $result = Get-SpdxLicensesFromExpression -expression "MIT and Apache-2.0 or GPL-3.0"
        $result | Should -HaveCount 3
        $result | Should -Contain "MIT"
        $result | Should -Contain "Apache-2.0"
        $result | Should -Contain "GPL-3.0"
    }

    It "Removes plus signs from license versions" {
        $result = Get-SpdxLicensesFromExpression -expression "GPL-3.0+"
        $result | Should -HaveCount 1
        $result | Should -Contain "GPL-3.0"
    }

    It "Deduplicates licenses in expressions" {
        $result = Get-SpdxLicensesFromExpression -expression "MIT OR MIT OR Apache-2.0"
        $result | Should -HaveCount 2
        $result | Should -Contain "MIT"
        $result | Should -Contain "Apache-2.0"
    }

    It "Handles complex expressions with multiple operators and parentheses" {
        $result = Get-SpdxLicensesFromExpression -expression "(MIT OR Apache-2.0) AND (GPL-3.0+ OR LGPL-3.0+)"
        $result | Should -HaveCount 4
        $result | Should -Contain "MIT"
        $result | Should -Contain "Apache-2.0"
        $result | Should -Contain "GPL-3.0"
        $result | Should -Contain "LGPL-3.0"
    }
}