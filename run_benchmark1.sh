# #!/bin/bash
# set -e

# echo "=== HPC-Bench: Full Pipeline Start ==="

# VENV_DIR=".venv"

# echo "[0] Checking system dependencies and setting up Python venv..."

# # 0a. Check and install 'python3-venv' if necessary
# if ! dpkg -l | grep -q python3-venv; then
#   echo "    Missing package 'python3-venv'. Attempting installation via apt..."
#   sudo apt update
#   sudo apt install -y python3-venv
# fi

# # --- NEW: FORCE CLEANUP STEP ---
# if [ -d "$VENV_DIR" ]; then
#     echo "    Found existing but possibly corrupted venv. Deleting $VENV_DIR..."
#     rm -rf "$VENV_DIR"
# fi
# # ------------------------------

# # 0b. Create venv
# echo "    Creating new Python virtual environment in $VENV_DIR..."
# # Adding '&& echo "Venv creation finished successfully."' for debug confirmation
# python3 -m venv "$VENV_DIR" && echo "    Venv creation finished successfully."

# # 0c. Verify existence before activation (Debugging)
# if [ ! -f "$VENV_DIR/bin/activate" ]; then
#     echo "!!! ERROR: The 'activate' script was NOT created in $VENV_DIR/bin."
#     echo "!!! Environment setup failed. Exiting."
#     exit 1
# fi

# # 0d. Activate the venv
# echo "    Activating Python venv..."
# # The line below is line 30 in this new version:
# source "$VENV_DIR/bin/activate"

# # 0e. Upgrade pip and install core tools inside the venv
# echo "    Upgrading pip and installing core dependencies..."
# pip install --upgrade pip setuptools wheel


# echo "[1/5] Environment setup..."
# bash setup/env_setup.sh



# # ... rest of the script ...
# echo "[3/5] Loading env vars..."
# source setup/env_vars.sh

# echo "[4/5] Validating environment..."
# python3 setup/validate_env.sh

# bash setup/setup_grafana.sh

# bash setup/setup_prometheus.sh


# echo "[2/5] Installing tools..."
# bash setup/install_tools.sh

# bash monitoring/import_dashboard.sh

# curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
#   -H "Content-Type: application/json" \
#   -d @monitoring/grafana_dashboard.json




# # ==============================
# # MONITORING AUTOMATION
# # ==============================
# source "$PROJECT_ROOT/monitoring/setup_monitoring.sh"

# setup_monitoring_stack
# push_metrics_to_pushgateway
# open_dashboard


# # echo "=== HPC-Bench: Completed. Check results.json (or output directory). ==="



#!/bin/bash

# Exit immediately if a command exits with a non-zero status
# 'pipefail' ensures that if a pipeline fails, the whole command fails
set -eo pipefail

# --- CONFIGURATION ---
PROJECT_ROOT=$(pwd)
VENV_DIR="$PROJECT_ROOT/.venv"
LOG_FILE="$PROJECT_ROOT/benchmark_build.log"

# Define a simple cleanup/error handler
trap 'echo "!!! Error occurred at line $LINENO. Check $LOG_FILE for details. !!!"; exit 1' ERR

echo "=== HPC-Bench: Full Pipeline Start ==="
echo "Logging output to $LOG_FILE"

# [0] PRE-FLIGHT CHECKS & VENV SETUP
echo "[0/5] Checking system dependencies and setting up Python venv..."

# 0a. Check for python3-venv (Debian/Ubuntu specific)
if ! dpkg -l | grep -q python3-venv; then
    echo "    Missing package 'python3-venv'. Attempting installation..."
    sudo apt update && sudo apt install -y python3-venv
fi

# 0b. Clean and Create Venv
if [ -d "$VENV_DIR" ]; then
    echo "    Cleaning up old virtual environment..."
    rm -rf "$VENV_DIR"
fi

echo "    Creating new Python virtual environment..."
python3 -m venv "$VENV_DIR"

# 0c. Activation and Pip Upgrade
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
echo "    Upgrading core python tools..."
pip install --upgrade pip setuptools wheel 

# [1/5] ENVIRONMENT INITIALIZATION
echo "[1/5] Loading environment variables..."
if [ -f "setup/env_vars.sh" ]; then
    source setup/env_vars.sh
else
    # Fallback if env_vars doesn't exist yet
    export PROJECT_ROOT=$PROJECT_ROOT
fi

# [2/5] INSTALLATION PHASE
echo "[2/5] Installing core tools and monitoring stack..."
bash setup/env_setup.sh 
bash setup/install_tools1.sh 
bash setup/setup_prometheus.sh 
bash setup/setup_grafana.sh 

# [3/5] VALIDATION
echo "[3/5] Validating environment..."
# Running the python script within the activated venv
python3 setup/validate_env.sh

# [4/5] MONITORING CONFIGURATION
echo "[4/5] Importing Grafana Dashboards..."
# Ensure Grafana is up before curling (simple sleep or retry logic)
sleep 5 
bash monitoring/import_dashboard.sh 

# Direct API call to push the JSON dashboard
curl -s -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @monitoring/grafana_dashboard.json > /dev/null

# [5/5] EXECUTION
echo "[5/5] Starting Monitoring Automation..."
# shellcheck source=/dev/null
source "$PROJECT_ROOT/monitoring/setup_monitoring.sh"

setup_monitoring_stack
push_metrics_to_pushgateway
open_dashboard

echo "------------------------------------------------"
echo "=== HPC-Bench: Setup Completed Successfully ==="
echo "Check results.json for benchmark data."
