# Contributing

## Unit testing

Install pester with this command(tested with pester v5):

```
Install-Module -Name Pester -Force -SkipPublisherCheck
```

Run this command to run the unit tests. For the tests we use pester

```pwsh
Invoke-Pester -Path "scripts" -OutputFormat NUnitXml -OutputFile "/scripts/test-results.xml" -PassThru | Select-Object -Property Name, Result, Duration | Format-Table -AutoSize
```

## Test process script with the sample application

This script requires powershell(core). Run this command to install the latest powershell core.

```pwsh
winget install Microsoft.PowerShell
```

Run this command to run the licensing script

```pwsh
./scripts/process.ps1 -workingDir "./samples/basic/SimpleConsoleApplication"                          
```