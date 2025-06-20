function Expand-DownloadedArchives {
    $archives = Get-ChildItem -Path "." -File -Recurse | Where-Object { $_.Extension -in ".zip", ".rar" }

    foreach ($archive in $archives) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($archive.Name)
        $destinationPath = Join-Path -Path $archive.DirectoryName -ChildPath $baseName

        if (-not (Test-Path $destinationPath)) {
            New-Item -ItemType Directory -Path $destinationPath | Out-Null
        }

        if ($archive.Extension -eq ".zip") {
            Expand-Archive -Path $archive.FullName -DestinationPath $destinationPath -Force
            Write-Host "✅ Extracted ZIP: $archive.FullName → $destinationPath"
        }
        elseif ($archive.Extension -eq ".rar") {
            unrar x -o+ "$($archive.FullName)" "$destinationPath\" | Out-Null
            Write-Host "✅ Extracted RAR: $archive.FullName → $destinationPath"
        }

        Remove-Item -Path $archive.FullName -Force
        Write-Host "🗑️ Deleted archive: $archive.FullName"
    }
}

function Day {
    param (
        [ValidateSet("go", "cyber", "mediafire", "mega", "pixel", "ffmpeg", "cleanup")]
        [string]$Type,

        [string]$InputString,

        [int]$Start,
        [int]$End
    )

    if ($PSBoundParameters.Count -eq 0) {
        Write-Host "`n[Day CLI] Usage:"
        Write-Host "  Day -Type <go|cyber|mediafire|mega|pixel|ffmpeg|cleanup> -InputString <value>"
        Write-Host "`nExamples:"
        Write-Host "  Day -Type go -InputString 'www.downloadurl.com'"
        Write-Host "  Day -Type cleanup"
        return
    }

    # Enforce that InputString is required for certain types
    if ($Type -in @("go", "cyber", "mediafire") -and -not $InputString) {
        throw "InputString is required when using '$Type'"
    }

    switch ($Type) {
        "go" {
            $scriptPath = "D:\Users\Day\Spares\_Tools\gofile-downloader\gofile-downloader.py"
            python $scriptPath $InputString
            Expand-DownloadedArchives
        }
        "cyber" {
            $scriptPath = "D:\Users\Day\Spares\_Tools\CyberDrop2\Start Windows.bat"
            & $scriptPath $InputString
            Expand-DownloadedArchives
        }
        "mediafire" {
            mediafire-dl $InputString
            Expand-DownloadedArchives
        }
        "mega" {
            mega-get $InputString
            Expand-DownloadedArchives
        }
        "pixel" {
            $downloadUrl = "$InputString?download"
        
            $response = Invoke-WebRequest -Uri $downloadUrl -UseBasicParsing -MaximumRedirection 3
        
            $fileName = "downloaded_file"
            if ($response.Headers["Content-Disposition"] -match 'filename="?(.+?)"?(;|$)') {
                $fileName = $matches[1]
            }
        
            $fullPath = Join-Path -Path (Get-Location) -ChildPath $fileName
            Invoke-WebRequest -Uri $downloadUrl -OutFile $fullPath
        
            Write-Host "✅ Downloaded: $fileName"
            Expand-DownloadedArchives
        }
        "cleanup" {
            $scriptPath = 'D:\Users\Day\Spares\housekeeping.ps1'
            & $scriptPath
        }
    }
}
