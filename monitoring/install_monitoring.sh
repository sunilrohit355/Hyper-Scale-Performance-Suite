#!/bin/bash
set -e

echo "[MONITORING] Installing Prometheus, Pushgateway, Grafana"

# ---------- Install packages ----------
sudo apt update -y
sudo apt install -y wget curl apt-transport-https software-properties-common

# ---------- Prometheus ----------
if ! command -v prometheus &>/dev/null; then
  sudo useradd --no-create-home --shell /bin/false prometheus || true
fi

# ---------- Pushgateway ----------
if ! ss -lnt | grep -q 9091; then
  wget -q https://github.com/prometheus/pushgateway/releases/download/v1.6.2/pushgateway-1.6.2.linux-amd64.tar.gz
  tar xf pushgateway-*.tar.gz
  nohup ./pushgateway-*/pushgateway --web.listen-address=":9091" &
fi

# ---------- Grafana ----------
if ! systemctl is-active --quiet grafana-server; then
  sudo apt install -y grafana
  sudo systemctl start grafana-server
  sudo systemctl enable grafana-server
fi

echo "[MONITORING] Monitoring stack ready"
