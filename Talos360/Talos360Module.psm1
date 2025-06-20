# Talos360.psm1

# Define repository paths
$global:RepoTalos = "A:\Mapped\talos"
$global:RepoTalosATS = "A:\Mapped\talosats"

function Invoke-Merge {
    param (
        [string]$RepoPath,
        [string]$SourceBranch,
        [string]$TargetBranch
    )

    Write-Host "Processing merge in $RepoPath" -ForegroundColor Cyan
    Set-Location $RepoPath

    git checkout $SourceBranch
    git pull

    git checkout $TargetBranch
    git pull

    $mergeOutput = git merge $SourceBranch 2>&1

    if ($LASTEXITCODE -ne 0) {
        if ($mergeOutput -match "CONFLICT") {
            Write-Host "❌ Merge conflict detected!" -ForegroundColor Red
            Write-Host "$SourceBranch -> $TargetBranch" -ForegroundColor Yellow
        } else {
            Write-Host "⚠️ Merge failed with unknown error." -ForegroundColor Red
        }

        Write-Output "`nGit output:`n$mergeOutput"
        git merge --abort
        return
    }

    Write-Host "✅ Merge successful: $SourceBranch -> $TargetBranch" -ForegroundColor Green

    Write-Host "⏫ Pushing $TargetBranch to remote..." -ForegroundColor Cyan
    git push origin $TargetBranch

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Push successful." -ForegroundColor Green
    } else {
        Write-Host "❌ Push failed." -ForegroundColor Red
    }
}

function Merge-TalosRepo {
    param (
        [string]$SourceBranch,
        [string]$TargetBranch
    )

    Invoke-Merge -RepoPath $RepoTalos -SourceBranch $SourceBranch -TargetBranch $TargetBranch
}

function Merge-TalosATSRepo {
    param (
        [string]$SourceBranch,
        [string]$TargetBranch
    )

    Invoke-Merge -RepoPath $RepoTalosATS -SourceBranch $SourceBranch -TargetBranch $TargetBranch
}

function Talos360 {
    param (
        [switch]$MergeHotfix,
        [switch]$MergeUAT,
        [switch]$MergeJSP
    )

    if ($MergeHotfix) {
        # MVC Project
        Merge-TalosRepo -SourceBranch "Talos-Hotfix" -TargetBranch "Talos-JSP"
        Merge-TalosRepo -SourceBranch "Talos-Hotfix" -TargetBranch "Talos-UAT"
        Merge-TalosRepo -SourceBranch "Talos-Hotfix" -TargetBranch "Talos-Live"
        # APIs Project
        Merge-TalosATSRepo -SourceBranch "TalosATS-Hotfix" -TargetBranch "TalosATS-UAT"
        Merge-TalosATSRepo -SourceBranch "TalosATS-Hotfix" -TargetBranch "TalosATS-Live"
    } elseif ($MergeUAT) {
        # MVC Project
        Merge-TalosRepo -SourceBranch "Talos-UAT" -TargetBranch "Talos-JSP"
        Merge-TalosRepo -SourceBranch "Talos-UAT" -TargetBranch "Talos-Hotfix"
        Merge-TalosRepo -SourceBranch "Talos-UAT" -TargetBranch "Talos-Live"
        # APIs Project
        Merge-TalosATSRepo -SourceBranch "TalosATS-UAT" -TargetBranch "TalosATS-Hotfix"
        Merge-TalosATSRepo -SourceBranch "TalosATS-UAT" -TargetBranch "TalosATS-Live"
    } elseif ($MergeJSP) {
        Merge-TalosRepo -SourceBranch "Talos-JSP" -TargetBranch "Talos-UAT"
        Merge-TalosRepo -SourceBranch "Talos-JSP" -TargetBranch "Talos-Hotfix"
        Merge-TalosRepo -SourceBranch "Talos-JSP" -TargetBranch "Talos-Live"
    } else {
        Write-Host "Usage: Talos360 [-MergeHotfix | -MergeUAT | -MergeJSP ]" -ForegroundColor Yellow
    }
}
