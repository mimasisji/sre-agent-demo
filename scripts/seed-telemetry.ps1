<#
.SYNOPSIS
    Seed historical telemetry in Application Insights for the SRE Agent Demo.

.DESCRIPTION
    Generates realistic failure patterns that Azure SRE Agent can query during
    a live demo investigation. Run this 3 days before the executive demo.

    Per cycle:
    1. Enable FAILURE_MODE → accumulate ~50-100 failed requests
    2. Sleep (recovery period with clean requests)
    3. Enable DB_TIMEOUT → accumulate retry storms in dependency telemetry
    4. Sleep (recovery period)

    Uses toggle-failure.ps1 internally — avoids code duplication.

.PARAMETER Cycles
    Number of failure/recovery cycles to run (default: 3).

.PARAMETER Quick
    Short sleep durations for testing (2 min failure / 5 min recovery instead
    of 15 min / 30 min). Do not use this for actual pre-demo seeding.

.EXAMPLE
    # Real seeding — run 3 days before demo
    .\scripts\seed-telemetry.ps1 -Cycles 3

    # Quick smoke test (completes in ~21 minutes)
    .\scripts\seed-telemetry.ps1 -Cycles 1 -Quick
#>
[CmdletBinding()]
param(
    [int]$Cycles = 3,
    [switch]$Quick
)

$ErrorActionPreference = "Stop"

# ── Configuration ─────────────────────────────────────────────────────────────
$AppName  = "sredemo-mim-app"
$BaseUrl  = "https://$AppName.azurewebsites.net"
$Toggle   = Join-Path $PSScriptRoot "toggle-failure.ps1"

# Durations
if ($Quick) {
    $FailureMinutes  = 2
    $RecoveryMinutes = 5
} else {
    $FailureMinutes  = 15
    $RecoveryMinutes = 30
}

$FailureSecs  = $FailureMinutes  * 60
$RecoverySecs = $RecoveryMinutes * 60

function Log     { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Cyan }
function LogOk   { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Green }
function LogWarn { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Yellow }
function LogErr  { param([string]$Msg) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Msg" -ForegroundColor Red }

function Wait-WithProgress {
    param([int]$Seconds, [string]$Label)
    $End = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $End) {
        $Remaining = [int]($End - (Get-Date)).TotalSeconds
        Write-Progress -Activity $Label -Status "$Remaining seconds remaining" -SecondsRemaining $Remaining
        Start-Sleep -Seconds 10
    }
    Write-Progress -Activity $Label -Completed
}

function Send-TrafficBurst {
    param([string]$Phase, [int]$Requests = 20)
    Log "  Sending $Requests requests to generate telemetry ($Phase)..."
    $Endpoints = @("/products", "/orders", "/checkout", "/health")
    $Jobs = @()
    for ($i = 0; $i -lt $Requests; $i++) {
        $Ep = $Endpoints[$i % $Endpoints.Count]
        $Url = "$BaseUrl$Ep"
        $Jobs += Start-ThreadJob -ScriptBlock {
            param($u)
            try {
                if ($u -match "orders|checkout") {
                    Invoke-RestMethod -Uri $u -Method Post `
                        -Body '{"productId":1,"quantity":1}' `
                        -ContentType "application/json" `
                        -TimeoutSec 20 | Out-Null
                } else {
                    Invoke-RestMethod -Uri $u -TimeoutSec 20 | Out-Null
                }
            } catch { <# failures are expected during failure mode #> }
        } -ArgumentList $Url
    }
    $Jobs | Wait-Job | Out-Null
    $Jobs | Remove-Job
    LogOk "  Traffic burst complete."
}

# ── Verify app is healthy before starting ──────────────────────────────────────
Log "Verifying app health before seeding..."
try {
    $Health = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 10
    LogOk "  App is healthy — version=$($Health.version)"
} catch {
    throw "App at $BaseUrl is not reachable. Deploy first with .\scripts\deploy.ps1"
}

# ── Summary ───────────────────────────────────────────────────────────────────
$TotalMinutes = $Cycles * ($FailureMinutes + $RecoveryMinutes) * 2  # failure + recovery, x2 for db timeout cycle
Log ""
Log "Seeding configuration:"
Log "  Cycles   : $Cycles"
Log "  Mode     : $(if ($Quick) { 'Quick (testing)' } else { 'Full (pre-demo)' })"
Log "  Per phase: ${FailureMinutes}min failure + ${RecoveryMinutes}min recovery"
Log "  Estimated: ~$TotalMinutes minutes total"
Log ""

# ── Main loop ─────────────────────────────────────────────────────────────────
for ($Cycle = 1; $Cycle -le $Cycles; $Cycle++) {
    Log "══════════════════════════════════════════════"
    Log "CYCLE $Cycle of $Cycles"
    Log "══════════════════════════════════════════════"

    # ── Phase A: FAILURE_MODE ─────────────────────────────────────────────────
    Log "Phase A — FAILURE MODE (${FailureMinutes}min)"
    & $Toggle -FailureMode $true
    Send-TrafficBurst -Phase "failure-mode-start" -Requests 30
    Wait-WithProgress -Seconds $FailureSecs -Label "Cycle $Cycle — Failure Mode active"
    Send-TrafficBurst -Phase "failure-mode-end" -Requests 20

    Log "Phase A — Disabling FAILURE MODE (recovery: ${RecoveryMinutes}min)"
    & $Toggle -FailureMode $false
    Send-TrafficBurst -Phase "recovery-start" -Requests 20
    Wait-WithProgress -Seconds $RecoverySecs -Label "Cycle $Cycle — Recovery period"

    # ── Phase B: DB_TIMEOUT (final cycle only gets both, others get just failure) ──
    if ($Cycle -eq $Cycles) {
        Log "Phase B — DB TIMEOUT (${FailureMinutes}min) [final cycle]"
        & $Toggle -DbTimeout $true
        Send-TrafficBurst -Phase "db-timeout-start" -Requests 30
        Wait-WithProgress -Seconds $FailureSecs -Label "Cycle $Cycle — DB Timeout active"
        Send-TrafficBurst -Phase "db-timeout-end" -Requests 20

        Log "Phase B — Disabling DB TIMEOUT (recovery: ${RecoveryMinutes}min)"
        & $Toggle -DbTimeout $false
        Send-TrafficBurst -Phase "db-timeout-recovery" -Requests 20
        Wait-WithProgress -Seconds $RecoverySecs -Label "Cycle $Cycle — DB Timeout recovery"
    }

    LogOk "Cycle $Cycle complete."
}

# ── Final state verification ──────────────────────────────────────────────────
Log ""
Log "Verifying all flags are OFF after seeding..."
& $Toggle -FailureMode $false
& $Toggle -DbTimeout $false

$Health = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 10
LogOk "Final health check: status=$($Health.status) failureMode=$($Health.flags.failureMode) dbTimeout=$($Health.flags.dbTimeout)"

Log ""
LogOk "Seeding complete! Verify telemetry with this KQL query in Log Analytics:"
Write-Host @"

  requests
  | where success == false
  | summarize count() by bin(timestamp, 1h)
  | order by timestamp asc

"@ -ForegroundColor Yellow

LogOk "Expected: at least $Cycles distinct error spikes across the timeline."
LogOk "Wait 15–30 minutes for all telemetry to appear in Application Insights before the demo."
