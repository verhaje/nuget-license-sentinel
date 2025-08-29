# NuGet License Sentinel 🛡️

[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-NuGet%20License%20Sentinel-blue.svg?colorA=24292e&colorB=0366d6&style=flat&longCache=true&logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAM6wAADOsB5dZE0gAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAERSURBVCiRhZG/SsMxFEafKoEIFkti7UJGIlYHpz0RnQsOjg5Od2fp4nJD6fYrPAAfwCdwcGx4A4dyPYGF0xkqWm1HyG8xBqNQNMVjzjnfN99/DPCAGj5DGKdppJEpPUoEQiwfCJfwBVyZGLpEgn2C5AEkIowMyYo8J2lCg4x8bLgR9nNGp0+2+3sGgAjrggQMKQOgAQG+1clyYjYnJrXOzDUU2z+4bnj7j5U9YQcVCeKVlM4r1gq6V9bT7a7JV67tARkRZe9WFCOGHFKgxdKhGdXnHp/OCBK9nJ/MkE1f9N71DPQvNOvF1JjGvTjdDH5f6cEyv7eeOdq38zD2AgF5DyqoH9ztgEAAAAAAAElFTkSuQmCC)](https://github.com/marketplace/actions/nuget-license-sentinel)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🔍 Overview

**NuGet License Sentinel** is a powerful GitHub Action that automatically analyzes and validates the licenses of NuGet packages in your .NET projects. Ensure your dependencies comply with your organization's licensing policies and avoid legal complications.

## ✨ Features

- 🔍 **Comprehensive License Analysis** - Scans all NuGet packages for license information
- ⚖️ **Policy Enforcement** - Validates licenses against customizable allowed/disallowed lists
- 📊 **Detailed Reporting** - Generates beautiful GitHub job summaries with compliance status
- 🎯 **Package-Level Control** - Fine-grained control over specific packages and versions
- 🚨 **Configurable Failure** - Option to fail workflows on license violations
- 🏷️ **Multiple License Support** - Handles complex SPDX license expressions

## 📥 Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `working-directory` | The working directory where your .NET project is located | No | `.` |
| `fail-on-invalid-licenses` | Whether to fail the workflow when invalid licenses are found | No | `false` |
| `license-rules-path` | Path to the license-rules.json configuration file | No | `./license-rules.json` |

## 📤 Outputs

| Name | Description |
|------|-------------|
| `non-compliant-packages` | Json with packages with non-compliant licenses |

## 🚀 Quick Start

### Basic Usage

Make sure the solution and the nuget packages are restored before running this action. 

```yaml
name: License Check

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  license-check:
    runs-on: ubuntu-latest
    name: Check NuGet License Compliance
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Restore dependencies
        run: dotnet restore

      - name: NuGet License Check
        uses: verhaje/license-check-gha@v1
        with:
          working-directory: './src'
          fail-on-invalid-licenses: 'true'
```

### Advanced Usage with Custom Rules

```yaml
      - name: NuGet License Check with Custom Rules
        uses: verhaje/license-check-gha@v1
        with:
          working-directory: './MyProject'
          license-rules-path: './custom-license-rules.json'
          fail-on-invalid-licenses: 'true'
```

## ⚙️ Configuration

The action looks for a `license-rules.json` file in your project directory to customize license validation. 

### Configuration Schema

```json
{
  "allowedLicenses": ["MIT", "Apache-2.0", "BSD-3-Clause"],
  "disallowedPackages": [
    {
      "name": "PackageName",
      "minVersion": "1.0.0",
      "maxVersion": "2.0.0"
    }
  ],
  "allowedPackages": [
    {
      "name": "ExceptionPackage",
      "minVersion": "1.0.0"
    }
  ]
}
```

### Configuration Options

- **`allowedLicenses`** 📋  
  Array of SPDX license identifiers that are permitted. Packages with these licenses will be considered compliant.

- **`disallowedPackages`** ❌  
  Array of package objects that are explicitly forbidden, regardless of their license. Supports version range filtering:
  - `name`: Package name (required)
  - `minVersion`: Minimum version to block (optional)
  - `maxVersion`: Maximum version to block (optional)

- **`allowedPackages`** ✅  
  Array of package objects that are always allowed, even if their license is not in `allowedLicenses`. Useful for internal packages or special exceptions. Supports version range filtering:
  - `name`: Package name (required)
  - `minVersion`: Minimum version to allow (optional)
  - `maxVersion`: Maximum version to allow (optional)

### Example Configuration

```json
{
  "allowedLicenses": [
    "MIT", 
    "Apache-2.0", 
    "BSD-3-Clause",
    "Microsoft Software License",
    "Project References"
  ],
  "disallowedPackages": [
    {
      "name": "Moq",
      "minVersion": "4.20.0",
      "comment": "Versions 4.20+ have licensing issues"
    },
    {
      "name": "ProblematicPackage"
    }
  ],
  "allowedPackages": [
    {
      "name": "CompanyInternalLibrary"
    },
    {
      "name": "SixLabors.ImageSharp",
      "comment": "Special license agreement in place"
    }
  ]
}
```

## 📋 Sample Output

The action generates comprehensive reports in your GitHub workflow:

### Job Summary Features:
- ✅ **Visual Status Indicators** - Clear pass/fail status with emoji indicators
- 📊 **Detailed Metrics** - Count of compliant vs non-compliant packages
- 🔍 **Expandable Details** - Project-by-project license breakdown
- ⚠️ **Violation Highlights** - Clear identification of problematic packages

## 🔧 Requirements

- .NET project with NuGet packages
- GitHub Actions runner with PowerShell support

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. 🍴 **Fork the repository**
2. 🌟 **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. 💡 **Make your changes**
4. ✅ **Run tests** (`./scripts/test.ps1`)
5. 📝 **Commit your changes** (`git commit -m 'Add amazing feature'`)
6. 🚀 **Push to the branch** (`git push origin feature/amazing-feature`)
7. 🎯 **Open a Pull Request**

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## 📄 License

This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.

## 🐛 Support & Issues

- 📋 **Found a bug?** [Open an issue](https://github.com/your-username/license-check-gha/issues)
- 💡 **Have a feature request?** [Start a discussion](https://github.com/your-username/license-check-gha/discussions)
- 📚 **Need help?** Check out our [documentation](https://github.com/your-username/license-check-gha/wiki)

## 🌟 Show Your Support

If this action helped you, please:
- ⭐ Star this repository
- 🐦 Share it on social media
- 📝 Write a blog post about it

## 🔗 Related Projects

- [GitHub Actions Marketplace](https://github.com/marketplace?type=actions) - Discover more GitHub Actions

---

<p align="center">
  <strong>Made with ❤️ for the .NET community</strong>
</p>
