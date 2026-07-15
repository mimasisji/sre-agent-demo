<#
.SYNOPSIS
    Rebuild the entire SRE Agent Demo from scratch after a teardown.

.DESCRIPTION
    Automates every step that CAN be automated. Prints the two OAuth-only
    manual steps at the end (GitHub Code connection + Knowledge files upload).

    Sequence (all idempotent, safe to re-run):
      1. Create the resource group (if missing)
      2. Deploy Bicep infrastructure (App Service, App Insights, LAW, alerts, action group)
      3. Publish and deploy the .NET app to App Service
      4. Create the SRE Agent, wire log/knowledge/identity config
      5. Print the manual portal steps

.PARAMETER ResourceGroup
    Resource group name. Default: rg-sredemo-swe

.PARAMETER Location
    Azure region (must support both App Service F1 quota AND SRE Agent). Default: swedencentral

.PARAMETER SkipAppDeploy
    Skip the app deployment step. Use if the infra is already up and only the agent needs to be recreated.

.EXAMPLE
    .\scripts\rebuild.ps1

.EXAMPLE
    # After a teardown, this brings the entire demo back in ~10 minutes automated + ~5 minutes manual
    .\scripts\rebuild.ps1
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup = "rg-sredemo-swe",
    [string]$Location      = "swedencentral",
    [switch]$SkipAppDeploy
)

$ErrorActionPreference = "Stop"

function Log     { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Cyan }
function LogOk   { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Green }
function LogWarn { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Yellow }
function LogStep { param([string]$N, [string]$Msg) Write-Host ""; Write-Host "══ Step $N — $Msg " -ForegroundColor Magenta -NoNewline; Write-Host ("═" * [Math]::Max(1, 68 - $Msg.Length)) -ForegroundColor Magenta }

# ── Pre-flight ────────────────────────────────────────────────────────────────
$sub = az account show --query "{name:name, id:id}" -o json | ConvertFrom-Json
if (-not $sub) { throw "Not signed in. Run 'az login' first." }
Log "Subscription : $($sub.name) ($($sub.id))"
Log "Target RG    : $ResourceGroup in $Location"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot
Log "Repo root    : $RepoRoot"

# ── Step 1: Resource group ────────────────────────────────────────────────────
LogStep "1/4" "Ensure resource group $ResourceGroup"

$exists = az group exists --name $ResourceGroup
if ($exists -eq "true") {
    LogOk "  Already exists"
} else {
    az group create --name $ResourceGroup --location $Location -o none
    LogOk "  Created in $Location"
}

# ── Step 2: Bicep infrastructure ──────────────────────────────────────────────
LogStep "2/4" "Deploy Bicep infrastructure (~5-10 min)"

az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "$RepoRoot\infra\main.bicep" `
    --parameters "$RepoRoot\infra\main.parameters.json" `
    --name rebuild-$(Get-Date -Format 'yyyyMMdd-HHmmss') `
    -o none

if ($LASTEXITCODE -ne 0) { throw "Bicep deployment failed" }
LogOk "  Infrastructure deployed"

# ── Step 3: Deploy the app ────────────────────────────────────────────────────
LogStep "3/4" "Publish and deploy the .NET app"

if ($SkipAppDeploy) {
    LogWarn "  -SkipAppDeploy set, leaving App Service empty"
} else {
    & "$RepoRoot\scripts\deploy.ps1"
    if ($LASTEXITCODE -ne 0) { throw "App deploy failed" }
    LogOk "  App deployed and healthy"
}

# ── Step 4: Recreate the SRE Agent ────────────────────────────────────────────
LogStep "4/4" "Create and configure the SRE Agent"

& "$RepoRoot\scripts\setup-sre-agent.ps1" -ResourceGroup $ResourceGroup -Location $Location

# ── Manual steps reminder ─────────────────────────────────────────────────────
# setup-sre-agent.ps1 already prints the manual portal steps at the end.
# Nothing more to do here — its output is authoritative.

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " REBUILD COMPLETE " -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host " Automated steps done. Only the 2 OAuth-based portal steps remain" -ForegroundColor White
Write-Host " (Code connection + Knowledge files upload) — see the block above." -ForegroundColor White
Write-Host ""
Write-Host " After finishing the portal steps, verify with:" -ForegroundColor White
Write-Host "   Invoke-RestMethod https://sredemo-mim-app.azurewebsites.net/health" -ForegroundColor Cyan
Write-Host ""
