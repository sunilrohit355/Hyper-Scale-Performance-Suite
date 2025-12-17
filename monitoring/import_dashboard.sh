#!/bin/bash
set -e

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
DASHBOARD_JSON="$(dirname "$0")/grafana_dashboard.json"

log() {
  echo "[GRAFANA] $*"
}

log "Importing Grafana dashboard..."

RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u ${GRAFANA_USER}:${GRAFANA_PASS} \
  ${GRAFANA_URL}/api/dashboards/db \
  -d @"${DASHBOARD_JSON}")

echo "$RESPONSE" | grep -q '"status":"success"' || {
  echo "[FATAL] Dashboard import failed"
  echo "$RESPONSE"
  exit 1
}

DASH_UID=$(echo "$RESPONSE" | jq -r '.uid')
DASH_URL="${GRAFANA_URL}/d/${DASH_UID}"

log "Dashboard available at: ${DASH_URL}"

# ✅ AUTO OPEN IN BROWSER
if command -v xdg-open >/dev/null; then
  xdg-open "$DASH_URL" >/dev/null 2>&1 &
elif command -v open >/dev/null; then
  open "$DASH_URL"
else
  log "Open manually: $DASH_URL"
fi
