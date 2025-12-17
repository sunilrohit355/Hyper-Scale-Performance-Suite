#!/bin/bash
set -e

safe_metric () {
  local name="$1"
  local value="$2"

  value=$(echo "$value" | grep -oE '[0-9]+(\.[0-9]+)?' | head -n 1)
  [ -z "$value" ] && value=0

  echo "$name $value"
}


GRAFANA_URL="http://localhost:3000"
PROM_URL="http://localhost:9090"
AUTH="admin:admin"

setup_monitoring_stack() {
    install_prometheus
    install_pushgateway
    install_grafana
    setup_grafana_datasource
    import_grafana_dashboard
}

install_prometheus() {
    pgrep prometheus && return
    nohup prometheus \
      --config.file="$PROJECT_ROOT/monitoring/prometheus.yml" \
      --web.listen-address=":9090" \
      >/tmp/prometheus.log 2>&1 &
}

install_pushgateway() {
    pgrep pushgateway && return
    nohup pushgateway \
      --web.listen-address=":9091" \
      >/tmp/pushgateway.log 2>&1 &
}

install_grafana() {
    systemctl is-active grafana-server &>/dev/null && return
    sudo systemctl start grafana-server
    sleep 5
}

setup_grafana_datasource() {
    curl -s -X POST "$GRAFANA_URL/api/datasources" \
        -u "$AUTH" \
        -H "Content-Type: application/json" \
        -d '{
          "name":"Prometheus",
          "type":"prometheus",
          "url":"http://localhost:9090",
          "access":"proxy",
          "isDefault":true
        }' || true
}

import_grafana_dashboard() {
    curl -s -X POST "$GRAFANA_URL/api/dashboards/db" \
        -u "$AUTH" \
        -H "Content-Type: application/json" \
        -d @"$PROJECT_ROOT/monitoring/grafana_dashboard.json"
}

open_dashboard() {
    local ip
    ip=$(hostname -I | awk '{print $1}')
    xdg-open "http://${ip}:3000/d/hpc-bench/hpc-benchmark-dashboard" \
        >/dev/null 2>&1 || true
}

push_metrics_to_pushgateway() {
    echo "[INFO] Cleaning old Pushgateway metrics..."
    curl -X DELETE http://localhost:9091/metrics/job/hpc_benchmarks || true

    echo "[INFO] Pushing MINIMAL safe metrics..."

    cat <<EOF | curl --data-binary @- \
http://localhost:9091/metrics/job/hpc_benchmarks/instance/$(hostname)
hpc_benchmark_sysbench_events 1
EOF

    echo "[INFO] Minimal push completed"
}

