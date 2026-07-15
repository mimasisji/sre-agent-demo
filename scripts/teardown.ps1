<#
.SYNOPSIS
    Tear down the entire SRE Agent Demo — deletes the resource group and all resources inside it.

.DESCRIPTION
    Safe, explicit teardown. Prompts for confirmation before deleting anything.
    After running this you pay zero for the demo (all Azure resources gone).

    To bring the demo back later, run: .\scripts\rebuild.ps1

.PARAMETER ResourceGroup
    Resource group to delete. Default: rg-sredemo-swe

.PARAMETER Force
    Skip the confirmation prompt. Use for automation.

.EXAMPLE
    .\scripts\teardown.ps1
    .\scripts\teardown.ps1 -Force
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup = "rg-sredemo-swe",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Log     { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Cyan }
function LogOk   { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Green }
function LogWarn { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Yellow }
function LogErr  { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Red }

# ── Pre-flight ────────────────────────────────────────────────────────────────
$sub = az account show --query "{name:name, id:id}" -o json | ConvertFrom-Json
Log "Subscription : $($sub.name) ($($sub.id))"
Log "Target RG    : $ResourceGroup"

$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "false") {
    LogWarn "Resource group '$ResourceGroup' does not exist. Nothing to do."
    exit 0
}

# ── Show what's going to be deleted ───────────────────────────────────────────
Log "Fetching current resources in $ResourceGroup..."
$resources = az resource list -g $ResourceGroup --query "[].{name:name, type:type}" -o json | ConvertFrom-Json
Write-Host ""
Write-Host "Resources that will be PERMANENTLY DELETED:" -ForegroundColor Yellow
$resources | ForEach-Object { Write-Host "  - $($_.name)  ($($_.type))" -ForegroundColor Gray }
Write-Host ""
Write-Host "Total: $($resources.Count) resources" -ForegroundColor Yellow

# ── Confirm ───────────────────────────────────────────────────────────────────
if (-not $Force) {
    Write-Host ""
    $confirmation = Read-Host "Type 'DELETE' (uppercase) to confirm teardown"
    if ($confirmation -ne "DELETE") {
        LogWarn "Aborted. Nothing was deleted."
        exit 0
    }
}

# ── Delete ────────────────────────────────────────────────────────────────────
Log "Starting async teardown of $ResourceGroup..."
az group delete --name $ResourceGroup --yes --no-wait
LogOk "Teardown initiated. Azure will complete deletion in the background (~5-15 min)."
Log "Check status with:  az group exists --name $ResourceGroup"
Write-Host ""
Write-Host "Next time you want to bring the demo back, run: .\scripts\rebuild.ps1" -ForegroundColor Cyan
