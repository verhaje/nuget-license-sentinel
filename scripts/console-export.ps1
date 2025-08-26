
function Convert-MarkdownToConsole {
    param([string]$Markdown)

    # Convert headers
    $mdLines = $Markdown -split "`r?`n"
    $md = @()
    foreach ($line in $mdLines) {
        $headerMatch = [regex]::Match($line, '^(\#+)\s*(.+)$')
        if ($headerMatch.Success) {
            $level = $headerMatch.Groups[1].Value.Length
            $text = $headerMatch.Groups[2].Value
            if ($level -eq 1) {
                $md += "`n$($text.ToUpper())`n"
            } elseif ($level -eq 2) {
                $md += "`n$($text)`n" + ('-' * $text.Length)
            } else {
                $md += "`n$($text)`n"
            }
        } else {
            $md += $line
        }
    }
    $md = $md -join "`n"
    
    # Convert tables
    $lines = $md -split "`r?`n"
    $output = @()
    $inTable = $false
    $tableRows = @()
    foreach ($line in $lines) {
        if ($line -match '^\s*\|.*\|\s*$') {
            $inTable = $true
            $tableRows += ,($line.Trim('|').Split('|').ForEach({ $_.Trim() }))
        } elseif ($inTable -and ($line -notmatch '^\s*\|.*\|\s*$')) {
            # Output table
            if ($tableRows.Count -gt 0) {
                $colWidths = @()
                foreach ($col in 0..($tableRows[0].Count-1)) {
                    $colWidths += ($tableRows | ForEach-Object { $_[$col].Length } | Measure-Object -Maximum).Maximum
                }
                foreach ($row in $tableRows) {
                    $rowStr = ""
                    for ($i=0; $i -lt $row.Count; $i++) {
                        $rowStr += $row[$i].PadRight($colWidths[$i]) + " | "
                    }
                    $output += $rowStr.TrimEnd(' | ')
                }
                $output += ""
            }
            $tableRows = @()
            $inTable = $false
            $output += $line
        } else {
            $output += $line
        }
    }
    # Output any remaining table
    if ($tableRows.Count -gt 0) {
        $colWidths = @()
        foreach ($col in 0..($tableRows[0].Count-1)) {
            $colWidths += ($tableRows | ForEach-Object { $_[$col].Length } | Measure-Object -Maximum).Maximum
        }
        foreach ($row in $tableRows) {
            $rowStr = ""
            for ($i=0; $i -lt $row.Count; $i++) {
                $rowStr += $row[$i].PadRight($colWidths[$i]) + " | "
            }
            $output += $rowStr.TrimEnd(' | ')
        }
        $output += ""
    }

    # Convert bold and italics
    $output = $output | ForEach-Object {
        $_ -replace '\*\*(.+?)\*\*', { $args[0] -replace '\*\*(.+?)\*\*', '$1'; $regexMatch = [regex]::Match($args[0], '\*\*(.+?)\*\*'); if ($regexMatch.Success) { $regexMatch.Groups[1].Value.ToUpper() } else { $args[0] } } `
           -replace '\*(.+?)\*', { $args[0] -replace '\*(.+?)\*', '$1'; $customMatches = [regex]::Match($args[0], '\*(.+?)\*'); if ($customMatches.Success) { $customMatches.Groups[1].Value } else { $args[0] } }
    }

    # Convert lists
    $output = $output | ForEach-Object {
        $_ -replace '^\s*-\s+', '• '
    }

    # Remove all code between < and >
    $output = $output | ForEach-Object {
        $_ -replace '<[^>]*>', ''
    }

    return $output -join "`n"
}