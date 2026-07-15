<#
.SYNOPSIS
    Build, publish, and deploy SreAgentDemo.Api to Azure App Service.

.DESCRIPTION
    1. dotnet publish (Release)
    2. Zip the publish folder
    3. az webapp deploy (zip deploy)
    4. Update DEPLOYMENT_VERSION app setting to current git SHA
    5. Smoke-test /health endpoint
    6. Clean up local zip

.PARAMETER DryRun
    Print what would be done without actually deploying.

.EXAMPLE
    .\scripts\deploy.ps1
    .\scripts\deploy.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# ── Configuration ─────────────────────────────────────────────────────────────
$ResourceGroup = "rg-sredemo-swe"
$AppName       = "sredemo-mim-app"
$ProjectPath   = "src/SreAgentDemo.Api/SreAgentDemo.Api.csproj"
$PublishDir    = "./publish"
$ZipPath       = "./publish.zip"
$HealthUrl     = "https://$AppName.azurewebsites.net/health"

# ── Helpers ───────────────────────────────────────────────────────────────────
function Log { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Cyan }
function LogOk { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Green }
function LogWarn { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Yellow }

# ── Resolve repo root ─────────────────────────────────────────────────────────
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Log "Working directory: $RepoRoot"
if ($DryRun) { LogWarn "DRY RUN — no changes will be made to Azure." }

# ── Step 1: dotnet publish ─────────────────────────────────────────────────────
Log "Step 1/5 — dotnet publish (Release)..."
if (-not $DryRun) {
    & dotnet publish $ProjectPath -c Release -o $PublishDir --nologo
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed (exit $LASTEXITCODE)" }
    LogOk "  Build succeeded."
} else {
    LogWarn "  [DryRun] Would run: dotnet publish $ProjectPath -c Release -o $PublishDir"
}

# ── Step 2: Zip ────────────────────────────────────────────────────────────────
Log "Step 2/5 — Creating zip..."
if (-not $DryRun) {
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    Compress-Archive -Path "$PublishDir/*" -DestinationPath $ZipPath
    $SizeMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
    LogOk "  Created $ZipPath ($SizeMB MB)"
} else {
    LogWarn "  [DryRun] Would zip $PublishDir → $ZipPath"
}

# ── Step 3: az webapp deploy ───────────────────────────────────────────────────
Log "Step 3/5 — Deploying to $AppName..."
if (-not $DryRun) {
    az webapp deploy `
        --resource-group $ResourceGroup `
        --name $AppName `
        --src-path $ZipPath `
        --type zip `
        --async false `
        --output none
    if ($LASTEXITCODE -ne 0) { throw "az webapp deploy failed (exit $LASTEXITCODE)" }
    LogOk "  Deploy complete."
} else {
    LogWarn "  [DryRun] Would run: az webapp deploy -g $ResourceGroup -n $AppName --src-path $ZipPath"
}

# ── Step 4: Set DEPLOYMENT_VERSION ────────────────────────────────────────────
Log "Step 4/5 — Setting DEPLOYMENT_VERSION..."
$GitSha = (git rev-parse --short HEAD 2>$null).Trim()
if ([string]::IsNullOrEmpty($GitSha)) { $GitSha = "unknown" }
if (-not $DryRun) {
    az webapp config appsettings set `
        -g $ResourceGroup -n $AppName `
        --settings "DEPLOYMENT_VERSION=$GitSha" `
        --output none
    LogOk "  DEPLOYMENT_VERSION = $GitSha"
} else {
    LogWarn "  [DryRun] Would set DEPLOYMENT_VERSION=$GitSha"
}

# ── Step 5: Smoke test ────────────────────────────────────────────────────────
Log "Step 5/5 — Smoke test ($HealthUrl)..."
if (-not $DryRun) {
    $MaxRetries = 6
    $Delay = 10
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            $Response = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 15
            LogOk "  /health OK — status=$($Response.status) version=$($Response.version) failureMode=$($Response.flags.failureMode)"
            break
        } catch {
            if ($i -eq $MaxRetries) { throw "Health check failed after $MaxRetries attempts: $_" }
            LogWarn "  Attempt $i/$MaxRetries failed — waiting ${Delay}s..."
            Start-Sleep -Seconds $Delay
        }
    }
} else {
    LogWarn "  [DryRun] Would GET $HealthUrl"
}

# ── Cleanup ────────────────────────────────────────────────────────────────────
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
if (Test-Path $PublishDir) { Remove-Item $PublishDir -Recurse -Force }

LogOk ""
LogOk "Deploy complete. App is live at: https://$AppName.azurewebsites.net"
