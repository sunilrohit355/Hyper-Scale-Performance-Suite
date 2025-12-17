#!/bin/bash

echo "=============================================="
echo "   SMART HPC ENVIRONMENT INSTALLER"
echo "=============================================="

check_version() {
    local cmd=$1
    local required=$2

    if ! command -v $cmd &> /dev/null; then
        echo "[MISSING] $cmd"
        return 1
    fi

    installed=$($cmd --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+\.[0-9]+')

    if [[ "$installed" == "$required"* ]]; then
        echo "[OK] $cmd version $installed (required $required)"
        return 0
    else
        echo "[CONFLICT] $cmd version $installed (required $required)"
        return 2
    fi
}

smart_install() {
    local pkg=$1
    local cmd=$2
    local required_version=$3

    check_version $cmd $required_version
    status=$?

    if [[ $status -eq 0 ]]; then
        return
    fi

    if [[ $status -eq 2 ]]; then
        echo "[FIX] Removing conflicting version of $pkg..."
        sudo apt remove -y $pkg
    fi

    echo "[INSTALL] Installing $pkg..."
    sudo apt install -y $pkg
}

echo ""
echo "=== Updating System ==="
sudo apt update -y

echo ""
echo "=== Checking Compiler Versions ==="
smart_install "gcc" "gcc" "12"
smart_install "g++" "g++" "12"
smart_install "gfortran" "gfortran" "12"

echo ""
echo "=== Checking MPI ==="
smart_install "mpich" "mpirun" "4"

echo ""
echo "=== Checking CUDA ==="
if lspci | grep -i nvidia &>/dev/null; then
    echo "[GPU] NVIDIA GPU detected"

    if command -v nvcc &>/dev/null; then
        check_version "nvcc" "12"
        if [[ $? -eq 2 ]]; then
            echo "[FIX] Removing old CUDA"
            sudo apt remove -y nvidia-cuda-toolkit
            sudo apt install -y nvidia-cuda-toolkit
        fi
    else
        echo "[INSTALL] Installing CUDA toolkit..."
        sudo apt install -y nvidia-cuda-toolkit
    fi
else
    echo "[WARN] No NVIDIA GPU detected"
fi

echo ""
echo "=== Installing HPC Libraries ==="
sudo apt install -y libblas-dev liblapack-dev libscalapack-mpi-dev libopenblas-dev

echo ""
echo "=== Installing RDMA Tools ==="
sudo apt install -y rdma-core libibverbs-dev ibutils perftest

echo ""
echo "=============================================="
echo "   SMART ENVIRONMENT SETUP COMPLETE"
echo "=============================================="