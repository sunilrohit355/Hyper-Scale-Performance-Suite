#!/bin/bash
set -e

# ---------- Logging helpers ----------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PROMETHEUS] $*"
}

fatal_error() {
    echo "[FATAL] $1" >&2
    exit 1
}

# ---------- Auto-detect local system IP ----------
get_local_ip() {
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    [[ -n "$ip" ]] && { echo "$ip"; return; }
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -n "$ip" ]] && { echo "$ip"; return; }
    echo "127.0.0.1"
}

# ---------- Configuration ----------
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${PROJECT_ROOT}/tools"

PROM_DIR="${TOOLS_DIR}/prometheus"
PROM_BIN="${PROM_DIR}/prometheus"
CONFIG_FILE="${PROM_DIR}/prometheus.yml"

PROMETHEUS_VERSION="2.50.1"
ARCH="linux-amd64"
TARGET_IP="$(get_local_ip)"
PUSHGATEWAY_PORT="9091"

setup_prometheus() {
    log "Checking Prometheus installation..."

    # ✅ Already installed
    if [[ -x "$PROM_BIN" ]]; then
        log "Prometheus already installed."

        if pgrep -f "$PROM_BIN" >/dev/null; then
            log "Prometheus already running. Skipping start."
            return 0
        else
            log "Prometheus installed but not running. Starting..."
        fi
    else
        log "Prometheus not found. Installing..."

        mkdir -p "$PROM_DIR"
        cd "$PROM_DIR"

        local TAR="prometheus-${PROMETHEUS_VERSION}.${ARCH}.tar.gz"
        local URL="https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/${TAR}"

        log "Downloading Prometheus v${PROMETHEUS_VERSION}..."
        wget -q "$URL" || fatal_error "Failed to download Prometheus"

        log "Extracting Prometheus..."
        tar xzf "$TAR" --strip-components=1
        rm -f "$TAR"
    fi

    # ---------- Generate config ----------
    log "Generating prometheus.yml..."
    cat > "$CONFIG_FILE" <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['${TARGET_IP}:9090']

  - job_name: 'pushgateway'
    static_configs:
      - targets: ['${TARGET_IP}:${PUSHGATEWAY_PORT}']
    honor_labels: true
EOF

    # ---------- Start Prometheus ----------
    log "Starting Prometheus..."
    nohup "$PROM_BIN" \
        --config.file="$CONFIG_FILE" \
        --web.listen-address=":9090" \
        > "${PROM_DIR}/prometheus.log" 2>&1 &

    sleep 5

    # ---------- Verify ----------
    if curl -s "http://${TARGET_IP}:9090/-/ready" | grep -q "ready"; then
        log "✅ Prometheus running at http://${TARGET_IP}:9090"
        log "Targets: http://${TARGET_IP}:9090/targets"
    else
        fatal_error "Prometheus failed. Check ${PROM_DIR}/prometheus.log"
    fi
}
