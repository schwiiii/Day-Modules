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

$map = @{
    "Live"   = @{ Id="8a40e48a-aeec-4fa6-9da7-1d1561eaeca1"; Tenant="c575db86-1704-4250-9f5c-5d9f4927081e" }
    "UAT"    = @{ Id="c6ccf98f-499b-45c1-9611-f0d225a5a37a"; Tenant="c575db86-1704-4250-9f5c-5d9f4927081e" }
    "Engage" = @{ Id="6554a5aa-e7ee-4c58-b248-d419af390c32"; Tenant="c575db86-1704-4250-9f5c-5d9f4927081e" }
}


function Ensure-AzLogin {
    param([string]$TenantId)

    $context = Get-AzContext -ErrorAction SilentlyContinue
    if ($null -eq $context) {
        Write-Host "No Az login found. Logging in..."
        if ($TenantId) {
            Connect-AzAccount -Tenant $TenantId -UseDeviceAuthentication
        } else {
            Connect-AzAccount -UseDeviceAuthentication
        }
    } else {
        Write-Host "Using cached Az session for tenant $($context.Tenant.Id)"
    }
}

function Ensure-AzCliLogin {
    # Check if Azure CLI is logged in
    $subscriptions = az account list --query "[].id" -o tsv 2>$null
    if (-not $subscriptions) {
        Write-Host "Logging in to Azure CLI..."
        az login
    } else {
        Write-Host "Using cached Azure CLI session"
    }
}

<#
.SYNOPSIS
Logs into Azure using both the Az PowerShell module and Azure CLI.

.DESCRIPTION
Logs into Azure using the Az PowerShell module and Azure CLI. If a TenantId is provided, it will be used for the Az PowerShell login.

.PARAMETER TenantId
The Azure Tenant ID to use for the Az PowerShell login.

.EXAMPLE
Ensure-AzureLogin -TenantId "12345-12345-12345-12345-12345"
#>
function Ensure-AzureLogin {
    param(
        [string]$TenantId,
        [string]$SubscriptionId
    )

    Write-Host "Logging in to tenant $TenantId..."
    Connect-AzAccount -Tenant $TenantId -UseDeviceAuthentication

    if ($SubscriptionId) {
        Write-Host "Setting active subscription to: $SubscriptionId"
        Set-AzContext -Subscription $SubscriptionId | Out-Null
        az account set --subscription $SubscriptionId | Out-Null
    }
}

<#
.SYNOPSIS
Performs a Git merge from a source branch into one or more target branches within a specified repository path.

.DESCRIPTION
Checks out the source branch, pulls the latest changes, and then iteratively checks out each target branch to merge the source into it.
Conflicts are handled by stopping the process and reporting which merge failed.

.PARAMETER RepoPath
The file system path to the Git repository.

.PARAMETER SourceBranch
The name of the branch to merge from.

.PARAMETER TargetBranches
An array of branch names to merge into.

.EXAMPLE
Invoke-Merge -RepoPath "A:\Mapped\talos" -SourceBranch "Talos-UAT" -TargetBranches @("Talos-Hotfix", "Talos-Live")
#>
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
    Write-Host "🔄 Pulling latest" -ForegroundColor Cyan
    git pull

    Write-Host "🔄 Switching to target branch: $TargetBranch" -ForegroundColor Cyan
    git checkout $TargetBranch
    Write-Host "🔄 Pulling latest" -ForegroundColor Cyan
    git pull

    Write-Host "🔄 Merging: $SourceBranch -> $TargetBranch..." -ForegroundColor Cyan
    $mergeOutput = git merge --no-ff $SourceBranch 2>&1

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

<#
.SYNOPSIS
Executes a predefined merge strategy across multiple repositories.

.DESCRIPTION
Loops through a set of repositories and performs merges based on the source and target branch suffixes (e.g., UAT → Hotfix, Live).
Special-case logic is included for the Talos repository to also merge into Talos-JSP.

.PARAMETER SourceSuffix
The suffix of the source branch (e.g., "UAT" or "Hotfix").

.PARAMETER TargetSuffixes
An array of suffixes representing the target branches.

.PARAMETER SelectedRepos
A hashtable mapping repository names (e.g., "Talos") to their local file system paths.

.EXAMPLE
Invoke-MergePlan -SourceSuffix "UAT" -TargetSuffixes @("Hotfix", "Live") -SelectedRepos @{ "Talos" = "A:\Mapped\talos" }
#>
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
                if($repo -eq "Talos") {
                    Invoke-Merge -RepoPath $path -SourceBranch "$repo-UAT" -TargetBranch "$repo-JSP"
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
                if($repo -eq "Talos") {
                    Invoke-Merge -RepoPath $path -SourceBranch "$repo-Hotfix" -TargetBranch "$repo-JSP"
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
                Invoke-Merge -RepoPath $path -SourceBranch "Talos-JSP" -TargetBranch "Talos-Live"
            } else {
                Write-Host "⚠️ 'Talos' repository path not found." -ForegroundColor Yellow
            }
        }
        default {
            Write-Host "❓ Unknown merge type: $Type" -ForegroundColor Red
        }
    }
}

<#
.SYNOPSIS
Main entry point for the Talos360 CLI module. 

.DESCRIPTION
Looks for parameters to log into Azure or to perform merges.
Accepts parameters to specify which type of merge to run (e.g., -MergeUAT, -MergeHotfix, -MergeJsp) and which repositories
to apply the merge to (e.g., -Talos, -TalosATS, -Onboarding, -CareersSites). Calls into merge planning and execution logic accordingly.

.PARAMETER Login
If specified, logs into Azure using the Az PowerShell module and Azure CLI for the selected subscription.

.PARAMETER Subscription
The target subscription for Azure login. Valid values are "Live", "UAT", and "Engage". Defaults to "Live".

.PARAMETER MergeUAT
Merges UAT branches into Hotfix and Live (and JSP for Talos only).

.PARAMETER MergeHotfix
Merges Hotfix branches into UAT, Live (and JSP for Talos only).

.PARAMETER MergeJsp
(Deprecated/simplified use) Merges Talos-JSP with appropriate source.

.PARAMETER Talos
Indicates the merge should apply to the Talos repository.

.PARAMETER TalosATS
Indicates the merge should apply to the TalosATS repository.

.PARAMETER Onboarding
Indicates the merge should apply to the Onboarding repository.

.PARAMETER CareersSites
Indicates the merge should apply to the CareersSites repository.

.EXAMPLE
Talos360 -MergeUAT -Talos -TalosATS

.EXAMPLE
Talos360 -MergeHotfix -Onboarding
#>
function Talos360 {
    param (
        [switch]$Login,
        [ValidateSet("Live","UAT","Engage")]
        [string]$Subscription = "Live",
        [switch]$MergeUAT,
        [switch]$MergeHotfix,
        [switch]$MergeJSP,
        [switch]$Talos,
        [switch]$TalosATS,
        [switch]$Onboarding,
        [switch]$CareersSites
    )

    if ($Login) {
        $sub = $map[$Subscription] 
        Ensure-AzureLogin -TenantId $sub.Tenant -SubscriptionId $sub.Id
        return
    }


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
