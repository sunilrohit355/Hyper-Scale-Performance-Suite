install_grafana() {
    if command -v grafana-server &>/dev/null; then
        echo "[OK] Grafana already installed"
        return
    fi

    echo "[INSTALL] Installing Grafana..."
    sudo apt update
    sudo apt install -y software-properties-common
    sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
    wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
    sudo apt update
    sudo apt install -y grafana

    sudo systemctl enable grafana-server
    sudo systemctl start grafana-server

    sudo sed -i 's/^;admin_password = .*/admin_password = admin/' \/etc/grafana/grafana.ini

     sudo systemctl restart grafana-server

}


