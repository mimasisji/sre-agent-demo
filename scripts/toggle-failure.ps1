<#
.SYNOPSIS
    Toggle ENABLE_FAILURE_MODE or ENABLE_DB_TIMEOUT on the SRE Agent Demo app.

.DESCRIPTION
    - Fetches ADMIN_TOKEN from Azure App Service configuration
    - POSTs to /admin/failure-mode or /admin/db-timeout with X-Admin-Token header
    - Updates the Azure App Setting so the flag survives restarts
    - Prints current flag state after the toggle

.PARAMETER FailureMode
    Set ENABLE_FAILURE_MODE. Use $true to enable, $false to disable.
    Cannot be combined with -DbTimeout in the same call.

.PARAMETER DbTimeout
    Set ENABLE_DB_TIMEOUT. Use $true to enable, $false to disable.
    Cannot be combined with -FailureMode in the same call.

.EXAMPLE
    .\scripts\toggle-failure.ps1 -FailureMode $true
    .\scripts\toggle-failure.ps1 -FailureMode $false
    .\scripts\toggle-failure.ps1 -DbTimeout $true
    .\scripts\toggle-failure.ps1 -DbTimeout $false
#>
[CmdletBinding()]
param(
    [Parameter(ParameterSetName = "Failure")]
    [bool]$FailureMode,

    [Parameter(ParameterSetName = "DbTimeout")]
    [bool]$DbTimeout
)

$ErrorActionPreference = "Stop"

# ── Configuration ─────────────────────────────────────────────────────────────
$ResourceGroup = "rg-sredemo-swe"
$AppName       = "sredemo-mim-app"
$BaseUrl       = "https://$AppName.azurewebsites.net"

function Log { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Cyan }
function LogOk { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Green }
function LogWarn { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Yellow }

if ($PSCmdlet.ParameterSetName -eq "") {
    Write-Error "Specify either -FailureMode `$true/`$false or -DbTimeout `$true/`$false"
    exit 1
}

# ── Fetch ADMIN_TOKEN ─────────────────────────────────────────────────────────
Log "Fetching ADMIN_TOKEN from $AppName..."
$Token = az webapp config appsettings list `
    -g $ResourceGroup -n $AppName `
    --query "[?name=='ADMIN_TOKEN'].value" -o tsv 2>$null

if ([string]::IsNullOrEmpty($Token)) {
    throw "Could not retrieve ADMIN_TOKEN. Make sure you are logged in to Azure CLI and have access to $ResourceGroup."
}
LogOk "  Token retrieved ($($Token.Substring(0,8))...)"

# ── Determine endpoint and value ──────────────────────────────────────────────
if ($PSCmdlet.ParameterSetName -eq "Failure") {
    $Endpoint    = "$BaseUrl/admin/failure-mode"
    $SettingName = "ENABLE_FAILURE_MODE"
    $Value       = $FailureMode
} else {
    $Endpoint    = "$BaseUrl/admin/db-timeout"
    $SettingName = "ENABLE_DB_TIMEOUT"
    $Value       = $DbTimeout
}

$ValueStr = if ($Value) { "true" } else { "false" }
Log "Setting $SettingName = $ValueStr..."

# ── POST to admin endpoint ────────────────────────────────────────────────────
$Body = @{ enabled = $Value } | ConvertTo-Json
$Headers = @{ "X-Admin-Token" = $Token; "Content-Type" = "application/json" }

try {
    $Response = Invoke-RestMethod -Uri $Endpoint -Method Post -Body $Body -Headers $Headers -TimeoutSec 15
    LogOk "  API toggle successful."
} catch {
    $StatusCode = $_.Exception.Response?.StatusCode
    if ($StatusCode -eq 401) {
        throw "HTTP 401 Unauthorized — ADMIN_TOKEN mismatch. Re-fetch the token and retry."
    }
    throw "API call failed: $_"
}

# ── Update App Setting (survives restarts) ────────────────────────────────────
Log "Persisting $SettingName=$ValueStr to App Service configuration..."
az webapp config appsettings set `
    -g $ResourceGroup -n $AppName `
    --settings "$SettingName=$ValueStr" `
    --output none
LogOk "  App setting updated."

# ── Print current state ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "Current flag state:" -ForegroundColor White
Write-Host "  failureMode : $($Response.failureMode)" -ForegroundColor $(if ($Response.failureMode) { "Red" } else { "Green" })
Write-Host "  dbTimeout   : $($Response.dbTimeout)"   -ForegroundColor $(if ($Response.dbTimeout)   { "Red" } else { "Green" })
Write-Host ""
