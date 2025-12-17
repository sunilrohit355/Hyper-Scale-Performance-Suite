# ============================================================
# HPC-Bench Makefile
# Automates environment setup, tool installation, validation,
# and full benchmark execution.
# ============================================================

SHELL := /bin/bash

# ------------------------------------------------------------
# 1. Create Python environment + install requirements
# ------------------------------------------------------------
env:
    @echo "=== Creating Python virtual environment ==="
    python3 -m venv .venv
    @echo "=== Installing Python dependencies ==="
    source .venv/bin/activate && pip install -r requirements.txt
    @echo "=== Python environment ready ==="

# ------------------------------------------------------------
# 2. Install all benchmark tools
# ------------------------------------------------------------
tools:
    @echo "=== Installing HPC benchmark tools ==="
    bash setup/install_tools.sh
    @echo "=== Tools installed ==="

# ------------------------------------------------------------
# 3. Validate environment
# ------------------------------------------------------------
validate:
    @echo "=== Validating environment ==="
    source .venv/bin/activate && source setup/env_vars.sh && python3 setup/validate_env.py
    @echo "=== Validation complete ==="

# ------------------------------------------------------------
# 4. Run all benchmarks
# ------------------------------------------------------------
run:
    @echo "=== Running all benchmarks ==="
    source .venv/bin/activate && source setup/env_vars.sh && python3 orchestrator/orchestrator.py
    @echo "=== Benchmark run complete ==="

# ------------------------------------------------------------
# 5. Full pipeline (everything)
# ------------------------------------------------------------
all: env tools validate run
    @echo "=== HPC-Bench: Full pipeline completed successfully ==="

# ------------------------------------------------------------
# 6. Clean environment
# ------------------------------------------------------------
clean:
    @echo "=== Cleaning environment ==="
    rm -rf .venv
    rm -rf tools
    rm -f results.json
    @echo "=== Clean complete ==="
