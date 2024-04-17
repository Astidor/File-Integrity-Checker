Function Calculate-FileChecksum($filePath) {
    $checksum = Get-FileHash -Path $filePath -Algorithm SHA512
    return $checksum
}

Function RemoveExistingBaseline() {
    $baselineExists = Test-Path -Path .\baseline.txt

    if ($baselineExists) {
        # Remove the existing baseline file
        Remove-Item -Path .\baseline.txt
    }
}

Function CreateBackup($filePath) {
    $backupFolder = ".\Backups"
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $backupPath = Join-Path -Path $backupFolder -ChildPath "$timestamp-$($filePath | Split-Path -Leaf)"

    if (-not (Test-Path -Path $backupFolder)) {
        New-Item -Path $backupFolder -ItemType Directory | Out-Null
    }

    Copy-Item -Path $filePath -Destination $backupPath
    Write-Host "Backup created: $backupPath" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "What would you like to do?"
Write-Host ""
Write-Host "    A) Collect new Baseline?"
Write-Host "    B) Begin monitoring files with saved Baseline?"
Write-Host ""
$response = Read-Host -Prompt "Please enter 'A' or 'B'"
Write-Host ""

if ($response -eq "A".ToUpper()) {
    # Remove existing baseline.txt if it already exists
    RemoveExistingBaseline

    # Calculate checksums for target files and store in baseline.txt
    # Collect all files in the target folder
    $targetFiles = Get-ChildItem -Path .\Files

    # For each file, calculate the checksum and write to baseline.txt
    foreach ($file in $targetFiles) {
        $checksum = Calculate-FileChecksum $file.FullName
        Add-Content -Path .\baseline.txt -Value "$($checksum.Path)|$($checksum.Hash)"
    }
    
    Write-Host "Baseline created successfully." -ForegroundColor Green
}

elseif ($response -eq "B".ToUpper()) {
    $baselineFile = ".\baseline.txt"
    
    if (-not (Test-Path -Path $baselineFile)) {
        Write-Host "Baseline file not found. Please create a baseline first (option A)." -ForegroundColor Yellow
        Exit
    }

    $baselineChecksums = @{}
    $filePathsAndChecksums = Get-Content -Path $baselineFile
    
    foreach ($fileInfo in $filePathsAndChecksums) {
         $baselineChecksums[$fileInfo.Split("|")[0]] = $fileInfo.Split("|")[1]
    }

    # Begin continuously monitoring files with saved baseline
    while ($true) {
        Start-Sleep -Seconds 1
        
        $currentFiles = Get-ChildItem -Path .\Files

        # For each file, calculate the checksum
        foreach ($file in $currentFiles) {
            $currentChecksum = Calculate-FileChecksum $file.FullName

            # Notify if a new file has been created
            if (-not $baselineChecksums.ContainsKey($currentChecksum.Path)) {
                Write-Host "$($currentChecksum.Path) has been created!" -ForegroundColor Green
                $baselineChecksums[$currentChecksum.Path] = $currentChecksum.Hash
                CreateBackup $currentChecksum.Path
                # Update baseline
                Add-Content -Path .\baseline.txt -Value "$($currentChecksum.Path)|$($currentChecksum.Hash)"
            }
            # Notify if a file has been changed
            elseif ($baselineChecksums[$currentChecksum.Path] -ne $currentChecksum.Hash) {
                if (-not $baselineChecksums[$currentChecksum.Path + "_Notified"]) {
                    Write-Host "$($currentChecksum.Path) has changed!!!" -ForegroundColor Yellow
                    $baselineChecksums[$currentChecksum.Path + "_Notified"] = $true
                }
            }
        }

# Check for deleted files
foreach ($baselinePath in $baselineChecksums.GetEnumerator() | ForEach-Object { $_.Key }) {
    if ($baselinePath -notlike "*_Notified" -and -not (Test-Path -Path $baselinePath)) {
        Write-Host "$($baselinePath) has been deleted!" -ForegroundColor DarkRed -BackgroundColor Gray
        # Update baseline
        $baselineChecksums.Remove($baselinePath)
        Set-Content -Path .\baseline.txt -Value ($baselineChecksums.GetEnumerator() | ForEach-Object { "$($_.Key)|$($_.Value)" })
    }
        }
    }
}
