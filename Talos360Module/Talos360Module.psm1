# Talos360Module.psm1

# Define repository paths
$global:RepoPaths = @{
    Talos        = "A:\Mapped\talos"
    TalosATS     = "A:\Mapped\talosats"
    Onboarding   = "A:\Mapped\onboarding-portal"
    CareersSites = "A:\Mapped\careers-pages"
}

# Ensure UTF-8 output for proper emoji display
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

function Invoke-Merge {
    param (
        [string]$RepoPath,
        [string]$SourceBranch,
        [string]$TargetBranch
    )

    Write-Host "📁 Processing merge in $RepoPath" -ForegroundColor Cyan
    Set-Location $RepoPath

    Write-Host "🔄 Switching to source branch: $SourceBranch" -ForegroundColor Cyan
    git checkout $SourceBranch
    git pull

    Write-Host "🔄 Switching to target branch: $TargetBranch" -ForegroundColor Cyan
    git checkout $TargetBranch
    git pull

    Write-Host "🔄 Merging: $SourceBranch -> $TargetBranch..." -ForegroundColor Cyan
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

function Invoke-MergePlan {
    param (
        [string]$Type,
        [string[]]$Repos
    )

    switch ($Type) {
        "UAT" {
            foreach ($repo in $Repos) {
                $path = $RepoPaths[$repo]
                if (-not $path) {
                    Write-Host "⚠️ Unknown repository: $repo" -ForegroundColor Yellow
                    continue
                }
                Invoke-Merge -RepoPath $path -SourceBranch "$repo-UAT" -TargetBranch "$repo-Hotfix"
                Invoke-Merge -RepoPath $path -SourceBranch "$repo-UAT" -TargetBranch "$repo-Live"
            }
        }
        "Hotfix" {
            foreach ($repo in $Repos) {
                $path = $RepoPaths[$repo]
                if (-not $path) {
                    Write-Host "⚠️ Unknown repository: $repo" -ForegroundColor Yellow
                    continue
                }
                Invoke-Merge -RepoPath $path -SourceBranch "$repo-Hotfix" -TargetBranch "$repo-UAT"
                Invoke-Merge -RepoPath $path -SourceBranch "$repo-Hotfix" -TargetBranch "$repo-Live"
            }
        }
        "JSP" {
            $path = $RepoPaths["Talos"]
            if ($path) {
                Invoke-Merge -RepoPath $path -SourceBranch "Talos-JSP" -TargetBranch "Talos-UAT"
                Invoke-Merge -RepoPath $path -SourceBranch "Talos-JSP" -TargetBranch "Talos-Hotfix"
            } else {
                Write-Host "⚠️ 'Talos' repository path not found." -ForegroundColor Yellow
            }
        }
        default {
            Write-Host "❓ Unknown merge type: $Type" -ForegroundColor Red
        }
    }
}

function Talos360 {
    param (
        [switch]$MergeUAT,
        [switch]$MergeHotfix,
        [switch]$MergeJSP,
        [switch]$Talos,
        [switch]$TalosATS,
        [switch]$Onboarding,
        [switch]$CareersSites
    )

    if ($MergeJSP) {
        Invoke-MergePlan -Type "JSP"
        return
    }

    $selectedRepos = @()
    if ($Talos)        { $selectedRepos += "Talos" }
    if ($TalosATS)     { $selectedRepos += "TalosATS" }
    if ($Onboarding)   { $selectedRepos += "Onboarding" }
    if ($CareersSites) { $selectedRepos += "CareersSites" }

    if (-not $selectedRepos) {
        Write-Host "⚠️ Please specify at least one repository." -ForegroundColor Yellow
        return
    }

    if ($MergeUAT)     { Invoke-MergePlan -Type "UAT"    -Repos $selectedRepos }
    if ($MergeHotfix)  { Invoke-MergePlan -Type "Hotfix" -Repos $selectedRepos }

    if (-not ($MergeUAT -or $MergeHotfix)) {
        Write-Host "⚠️ Please specify a merge operation: -MergeUAT or -MergeHotfix" -ForegroundColor Yellow
    }
}
