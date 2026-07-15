<#
.SYNOPSIS
    Idempotently create and configure the Azure SRE Agent for the demo.

.DESCRIPTION
    Automates everything that CAN be automated via the Microsoft.App/agents REST API
    (schema discovered from Azure/azure-resource-manager-schemas @ 2026-01-01):

      1. Create User-Assigned Managed Identity `sredemo-sre-agent-mi`
      2. Grant it Reader + Monitoring Reader on the resource group
      3. Create the SRE Agent (SystemAssigned + UserAssigned identities)
      4. PATCH logConfiguration -> App Insights (appId+connectionString) + LAW (workspaceId+sharedKey)
      5. PATCH knowledgeGraphConfiguration -> RG scope + MI identity
      6. Print the portal URL and the list of MANUAL steps that still require OAuth
         (GitHub Code connection + Knowledge Files upload)

    Safe to re-run: existing resources are detected and re-used.

.PARAMETER SubscriptionId
    Target Azure subscription. Defaults to the currently selected sub.

.PARAMETER ResourceGroup
    Resource group where the demo lives. Default: rg-sredemo-swe

.PARAMETER Location
    Azure region. Default: swedencentral (must be a SRE Agent-supported region)

.PARAMETER AgentName
    Name of the SRE Agent resource. Default: sredemo-sre-agent

.PARAMETER AppInsightsName
    App Insights resource name. Default: sredemo-mim-ai

.PARAMETER LogAnalyticsName
    Log Analytics Workspace name. Default: sredemo-mim-law

.PARAMETER DryRun
    Print what would happen without making changes.

.EXAMPLE
    .\scripts\setup-sre-agent.ps1
    .\scripts\setup-sre-agent.ps1 -DryRun
    .\scripts\setup-sre-agent.ps1 -AgentName my-other-agent -Location uksouth
#>
[CmdletBinding()]
param(
    [string]$SubscriptionId,
    [string]$ResourceGroup    = "rg-sredemo-swe",
    [string]$Location         = "swedencentral",
    [string]$AgentName        = "sredemo-sre-agent",
    [string]$AppInsightsName  = "sredemo-mim-ai",
    [string]$LogAnalyticsName = "sredemo-mim-law",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# ── Helpers ───────────────────────────────────────────────────────────────────
function Log     { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Cyan }
function LogOk   { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Green }
function LogWarn { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Yellow }
function LogStep { param([string]$N, [string]$Msg) Write-Host ""; Write-Host "── Step $N — $Msg " -ForegroundColor Magenta -NoNewline; Write-Host ("─" * [Math]::Max(1, 70 - $Msg.Length)) -ForegroundColor Magenta }

# API constants
$AgentApiVersion = "2026-01-01"
$MiName          = "$AgentName-mi"

# ── Pre-flight ────────────────────────────────────────────────────────────────
if (-not $SubscriptionId) { $SubscriptionId = az account show --query id -o tsv }
if (-not $SubscriptionId) { throw "Not signed in. Run 'az login' first." }

Log "Subscription : $SubscriptionId"
Log "Resource Grp : $ResourceGroup"
Log "Location     : $Location"
Log "Agent name   : $AgentName"
if ($DryRun) { LogWarn "DRY RUN — no changes will be made." }

$AgentUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.App/agents/${AgentName}?api-version=$AgentApiVersion"
$RgScope  = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup"

# ── Step 1: User-Assigned Managed Identity ────────────────────────────────────
LogStep "1/6" "Ensuring User-Assigned Managed Identity: $MiName"

$existingMi = az identity show --name $MiName --resource-group $ResourceGroup -o json 2>$null | ConvertFrom-Json
if ($existingMi) {
    LogOk "  Already exists (principalId=$($existingMi.principalId))"
    $mi = $existingMi
} else {
    if ($DryRun) {
        LogWarn "  [DryRun] Would create MI $MiName"
        $mi = $null
    } else {
        Log "  Creating..."
        $mi = az identity create --name $MiName --resource-group $ResourceGroup --location $Location -o json | ConvertFrom-Json
        LogOk "  Created (principalId=$($mi.principalId))"
        Log "  Waiting 10s for identity propagation..."
        Start-Sleep -Seconds 10
    }
}

# ── Step 2: Role assignments for the MI ───────────────────────────────────────
LogStep "2/6" "Granting Reader + Monitoring Reader on $ResourceGroup"

if (-not $DryRun -and $mi) {
    foreach ($role in @("Reader", "Monitoring Reader")) {
        $existing = az role assignment list --assignee $mi.principalId --scope $RgScope --role $role -o json | ConvertFrom-Json
        if ($existing) {
            LogOk "  $role already assigned"
        } else {
            az role assignment create --assignee-object-id $mi.principalId --assignee-principal-type ServicePrincipal --role $role --scope $RgScope -o none
            LogOk "  $role assigned"
        }
    }
} elseif ($DryRun) {
    LogWarn "  [DryRun] Would assign Reader + Monitoring Reader"
}

# ── Step 3: Create or update the SRE Agent ────────────────────────────────────
LogStep "3/6" "Ensuring SRE Agent: $AgentName"

$existingAgent = az rest --method GET --url $AgentUrl -o json 2>$null | ConvertFrom-Json
if ($existingAgent) {
    LogOk "  Already exists (provisioningState=$($existingAgent.properties.provisioningState))"
} else {
    if ($DryRun) {
        LogWarn "  [DryRun] Would PUT agent with SystemAssigned identity"
    } else {
        $createBody = @{
            location = $Location
            identity = @{ type = "SystemAssigned" }
            properties = @{}
        } | ConvertTo-Json -Depth 5
        $tmp = New-TemporaryFile
        $createBody | Out-File $tmp.FullName -Encoding utf8 -NoNewline
        az rest --method PUT --url $AgentUrl --body "@$($tmp.FullName)" --headers "Content-Type=application/json" -o none
        Remove-Item $tmp.FullName
        LogOk "  Created — polling until provisioningState=Succeeded"
        $elapsed = 0
        do {
            Start-Sleep -Seconds 15
            $elapsed += 15
            $state = (az rest --method GET --url $AgentUrl -o json | ConvertFrom-Json).properties.provisioningState
            Log "    [${elapsed}s] provisioningState=$state"
        } while ($state -eq "InProgress" -and $elapsed -lt 600)
        if ($state -ne "Succeeded") { throw "Agent creation failed. Final state: $state" }
        LogOk "  Provisioned in ${elapsed}s"
    }
}

# ── Step 4: Attach UserAssigned MI to the agent ───────────────────────────────
LogStep "4/6" "Attaching UserAssigned MI to the agent"

if ($DryRun -or -not $mi) {
    LogWarn "  [DryRun] Would attach MI $MiName to agent identity"
} else {
    $identityPatch = @{
        identity = @{
            type = "SystemAssigned,UserAssigned"
            userAssignedIdentities = @{ "$($mi.id)" = @{} }
        }
    } | ConvertTo-Json -Depth 5
    $tmp = New-TemporaryFile
    $identityPatch | Out-File $tmp.FullName -Encoding utf8 -NoNewline
    az rest --method PATCH --url $AgentUrl --body "@$($tmp.FullName)" --headers "Content-Type=application/json" -o none
    Remove-Item $tmp.FullName
    LogOk "  Attached"
    Log "  Waiting 15s for identity attach to settle before next PATCH..."
    Start-Sleep -Seconds 15
}

# ── Step 5: logConfiguration + knowledgeGraphConfiguration ────────────────────
LogStep "5/6" "PATCH: logConfiguration + knowledgeGraphConfiguration"

if ($DryRun) {
    LogWarn "  [DryRun] Would fetch AI + LAW credentials and PATCH agent"
} else {
    Log "  Fetching App Insights details..."
    $aiUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Insights/components/${AppInsightsName}?api-version=2020-02-02"
    $ai = az rest --method GET --url $aiUrl -o json | ConvertFrom-Json

    Log "  Fetching Log Analytics Workspace details..."
    $lawUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/${LogAnalyticsName}?api-version=2023-09-01"
    $law = az rest --method GET --url $lawUrl -o json | ConvertFrom-Json

    Log "  Fetching LAW primary shared key..."
    $keysUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/${LogAnalyticsName}/sharedKeys?api-version=2020-08-01"
    $keys = az rest --method POST --url $keysUrl -o json | ConvertFrom-Json

    Log "  Building PATCH payload (only schema-valid fields)..."
    $patchBody = @{
        properties = @{
            logConfiguration = @{
                applicationInsightsConfiguration = @{
                    appId            = $ai.properties.AppId
                    connectionString = $ai.properties.ConnectionString
                }
                logAnalyticsConfiguration = @{
                    workspaceId = $law.properties.customerId
                    sharedKey   = $keys.primarySharedKey
                }
            }
            knowledgeGraphConfiguration = @{
                identity         = $mi.id
                managedResources = @($RgScope)
            }
        }
    } | ConvertTo-Json -Depth 10

    $tmp = New-TemporaryFile
    $patchBody | Out-File $tmp.FullName -Encoding utf8 -NoNewline
    az rest --method PATCH --url $AgentUrl --body "@$($tmp.FullName)" --headers "Content-Type=application/json" -o none
    Remove-Item $tmp.FullName
    LogOk "  Configuration applied"
}

# ── Step 6: Final verification ────────────────────────────────────────────────
LogStep "6/6" "Verification"

if (-not $DryRun) {
    $agent = az rest --method GET --url $AgentUrl -o json | ConvertFrom-Json

    $aiAppId = $agent.properties.logConfiguration.applicationInsightsConfiguration.appId
    $lawId   = $agent.properties.logConfiguration.logAnalyticsConfiguration.workspaceId
    $kgId    = $agent.properties.knowledgeGraphConfiguration.identity
    $kgRes   = $agent.properties.knowledgeGraphConfiguration.managedResources

    Write-Host ""
    Write-Host "  provisioningState             : " -NoNewline; Write-Host $agent.properties.provisioningState -ForegroundColor Green
    Write-Host "  runningState                  : " -NoNewline; Write-Host $agent.properties.runningState -ForegroundColor Green
    Write-Host "  identity type                 : " -NoNewline; Write-Host $agent.identity.type -ForegroundColor Green
    Write-Host "  App Insights appId            : " -NoNewline; Write-Host $(if ($aiAppId) { "✅ $aiAppId" } else { "❌ missing" }) -ForegroundColor $(if ($aiAppId) { "Green" } else { "Red" })
    Write-Host "  Log Analytics workspaceId     : " -NoNewline; Write-Host $(if ($lawId) { "✅ $lawId" } else { "❌ missing" }) -ForegroundColor $(if ($lawId) { "Green" } else { "Red" })
    Write-Host "  KnowledgeGraph identity       : " -NoNewline; Write-Host $(if ($kgId) { "✅ set" } else { "❌ missing" }) -ForegroundColor $(if ($kgId) { "Green" } else { "Red" })
    Write-Host "  KnowledgeGraph managed scope  : " -NoNewline; Write-Host $(if ($kgRes) { "✅ $($kgRes -join ', ')" } else { "❌ missing" }) -ForegroundColor $(if ($kgRes) { "Green" } else { "Red" })
    Write-Host ""
    Write-Host "  Note: connectionString and sharedKey are stored but not returned by GET (secrets hidden)." -ForegroundColor DarkGray
}

# ── Manual steps that require portal (OAuth) ─────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host " MANUAL STEPS REMAINING (portal only — OAuth flows) " -ForegroundColor Yellow
Write-Host "══════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host " Portal URL:" -ForegroundColor White
Write-Host "   https://portal.azure.com/#resource/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.App/agents/$AgentName/overview" -ForegroundColor Cyan
Write-Host ""
Write-Host " 1. CODE — connect the GitHub repository" -ForegroundColor White
Write-Host "    In the agent blade -> Code -> + Add -> select your GitHub repo" -ForegroundColor Gray
Write-Host "    (requires OAuth to GitHub App; not exposed in Microsoft.App/agents API schema)" -ForegroundColor DarkGray
Write-Host ""
Write-Host " 2. KNOWLEDGE FILES — upload documentation" -ForegroundColor White
Write-Host "    In the agent blade -> Knowledge files -> + Add -> upload from your machine:" -ForegroundColor Gray
$repoRoot = Split-Path -Parent $PSScriptRoot
$docsPath = Join-Path $repoRoot "docs"
# Only upload files meant to teach the SRE Agent about the system.
# Deliberately EXCLUDE: demo-script.md, kql-queries.md, demo-backup-screenshots/*
$knowledgeFiles = @()
foreach ($rel in @("architecture.md", "slo-runbook.md", "known-issues.md")) {
    $p = Join-Path $docsPath $rel
    if (Test-Path $p) { $knowledgeFiles += $p }
}
$incidentsDir = Join-Path $docsPath "historical-incidents"
if (Test-Path $incidentsDir) {
    $knowledgeFiles += (Get-ChildItem -Path $incidentsDir -Filter incident-*.md).FullName
}
if ($knowledgeFiles.Count -gt 0) {
    $knowledgeFiles | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkCyan }
} else {
    Write-Host "      (docs not found — run this from the repo root)" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host " 3. Once both are attached, test the agent with the demo prompts in:" -ForegroundColor White
Write-Host "    docs\demo-script.md" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
LogOk "SRE Agent setup complete."
