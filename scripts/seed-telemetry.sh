#!/usr/bin/env bash
# seed-telemetry.sh — Generate historical telemetry in Application Insights
# Run this 3 days before the executive demo to seed real failure patterns
# that Azure SRE Agent can query during the live investigation.
#
# Usage:
#   ./scripts/seed-telemetry.sh \
#     --resource-group rg-sredemo-swe \
#     --app-name sredemo-mim-app \
#     --cycles 3
#
# Requirements:
#   - Azure CLI logged in with Contributor on the resource group
#   - App must be deployed and healthy before running

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
RESOURCE_GROUP="rg-sredemo-swe"
APP_NAME="sredemo-mim-app"
CYCLES=3
FAILURE_DURATION_SECONDS=600    # 10 minutes of failure per cycle
RECOVERY_DURATION_SECONDS=1800  # 30 minutes of recovery per cycle

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --app-name)       APP_NAME="$2";       shift 2 ;;
    --cycles)         CYCLES="$2";         shift 2 ;;
    --failure-mins)   FAILURE_DURATION_SECONDS=$(($2 * 60)); shift 2 ;;
    --recovery-mins)  RECOVERY_DURATION_SECONDS=$(($2 * 60)); shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

BASE_URL="https://${APP_NAME}.azurewebsites.net"

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"; }

set_flag() {
  local flag=$1 value=$2
  az webapp config appsettings set \
    -g "$RESOURCE_GROUP" -n "$APP_NAME" \
    --settings "${flag}=${value}" \
    --output none
  log "Set ${flag}=${value}"
}

health_check() {
  curl -sf "${BASE_URL}/health" > /dev/null && echo "healthy" || echo "unreachable"
}

wait_with_status() {
  local seconds=$1 label=$2
  log "Waiting ${seconds}s for: ${label}"
  local elapsed=0
  while [ $elapsed -lt $seconds ]; do
    sleep 30
    elapsed=$((elapsed + 30))
    remaining=$((seconds - elapsed))
    status=$(health_check)
    log "  [${elapsed}s elapsed, ${remaining}s remaining] health=${status}"
  done
}

# ── Pre-flight check ──────────────────────────────────────────────────────────
log "=== Azure SRE Agent Demo — Telemetry Seeder ==="
log "Resource Group : $RESOURCE_GROUP"
log "App Name       : $APP_NAME"
log "App URL        : $BASE_URL"
log "Cycles         : $CYCLES"
log "Failure window : ${FAILURE_DURATION_SECONDS}s per cycle"
log "Recovery window: ${RECOVERY_DURATION_SECONDS}s per cycle"
echo ""

# Verify app is reachable
log "Pre-flight: checking app health..."
if ! curl -sf "${BASE_URL}/health" > /dev/null; then
  log "ERROR: App is not reachable at ${BASE_URL}/health"
  log "       Deploy the app first before seeding telemetry."
  exit 1
fi
log "Pre-flight: OK — app is healthy"
echo ""

# Reset flags before starting
set_flag "ENABLE_FAILURE_MODE" "false"
set_flag "ENABLE_DB_TIMEOUT" "false"
log "Flags reset to OFF. Starting seeding cycles..."
echo ""

# ── Seeding cycles ────────────────────────────────────────────────────────────
for cycle in $(seq 1 $CYCLES); do
  log "=== CYCLE ${cycle}/${CYCLES} ==="

  # Step 1: Enable failure mode
  log "Enabling FAILURE MODE..."
  set_flag "ENABLE_FAILURE_MODE" "true"

  # Step 2: Wait — generate failure telemetry
  wait_with_status $FAILURE_DURATION_SECONDS "accumulating failure telemetry (~$(($FAILURE_DURATION_SECONDS / 60))m)"

  # Step 3: Disable failure mode
  log "Disabling FAILURE MODE — starting recovery..."
  set_flag "ENABLE_FAILURE_MODE" "false"

  # Step 4: Wait — generate recovery telemetry
  wait_with_status $RECOVERY_DURATION_SECONDS "recovery window (~$(($RECOVERY_DURATION_SECONDS / 60))m)"

  log "Cycle ${cycle} complete."
  echo ""
done

# ── Final cycle: DB timeout pattern ──────────────────────────────────────────
log "=== FINAL CYCLE: DB Timeout Pattern ==="
log "Enabling DB TIMEOUT..."
set_flag "ENABLE_DB_TIMEOUT" "true"

wait_with_status $FAILURE_DURATION_SECONDS "accumulating DB timeout + retry telemetry"

log "Disabling DB TIMEOUT..."
set_flag "ENABLE_DB_TIMEOUT" "false"

wait_with_status 600 "short recovery after DB timeout cycle"

# ── Summary ───────────────────────────────────────────────────────────────────
log "=== Seeding Complete ==="
log ""
log "VERIFY telemetry in Application Insights (Log Analytics):"
log ""
log "  # Error spikes (should show $CYCLES distinct spikes)"
log "  requests"
log "  | where success == false"
log "  | summarize count() by bin(timestamp, 1h)"
log "  | order by timestamp asc"
log ""
log "  # DB retry events"
log "  traces"
log "  | where message contains 'Retry'"
log "  | summarize count() by bin(timestamp, 1h)"
log ""
log "NEXT STEPS:"
log "  1. Run SRE Agent investigation (all 6 prompts) and capture screenshots"
log "  2. Save screenshots to docs/demo-backup-screenshots/"
log "  3. Reset flags (already done): ENABLE_FAILURE_MODE=false, ENABLE_DB_TIMEOUT=false"
log "  4. Run the demo!"
