# #!/bin/bash

# echo "=============================================="
# echo "   HPC Environment Bootstrap (Smart Mode)"
# echo "=============================================="

# # ---------------------------------------------------------
# # Helper Functions
# # ---------------------------------------------------------

# check_pkg() {
#     dpkg -l | grep -qw "$1"
# }

# install_pkg() {
#     if check_pkg "$1"; then
#         echo "[OK] $1 already installed"
#     else
#         echo "[INSTALL] Installing $1 ..."
#         sudo apt install -y "$1"
#     fi
# }

# echo ""
# echo "=== Step 1: Updating System ==="
# sudo apt update -y

# # ---------------------------------------------------------
# # Core Build Tools
# # ---------------------------------------------------------
# echo ""
# echo "=== Step 2: Checking Core Build Tools ==="

# CORE_PKGS=(
#     build-essential gcc g++ gfortran make cmake autoconf automake libtool pkg-config
# )

# for pkg in "${CORE_PKGS[@]}"; do
#     install_pkg "$pkg"
# done

# # ---------------------------------------------------------
# # Essential System Libraries
# # ---------------------------------------------------------
# echo ""
# echo "=== Step 3: Checking Essential System Libraries ==="

# LIB_PKGS=(
#     libaio-dev libnuma-dev libopenmpi-dev libssl-dev zlib1g-dev libhwloc-dev
# )

# for pkg in "${LIB_PKGS[@]}"; do
#     install_pkg "$pkg"
# done

# # ---------------------------------------------------------
# # MPI Stack
# # ---------------------------------------------------------
# echo ""
# echo "=== Step 4: Checking MPI Stack ==="

# MPI_PKGS=(
#     mpich mpich-doc libmpich-dev
# )

# for pkg in "${MPI_PKGS[@]}"; do
#     install_pkg "$pkg"
# done

# # ---------------------------------------------------------
# # Python Build Dependencies
# # ---------------------------------------------------------
# echo ""
# echo "=== Step 5: Checking Python Build Dependencies ==="

# PY_PKGS=(
#     python3-dev python3-venv python3-pip python3-wheel python3-setuptools
# )

# for pkg in "${PY_PKGS[@]}"; do
#     install_pkg "$pkg"
# done

# # ---------------------------------------------------------
# # GPU / CUDA Detection & Setup
# # ---------------------------------------------------------
# echo ""
# echo "=== Step 6: Checking GPU / CUDA Environment ==="

# GPU_COUNT=$(lspci | grep -i nvidia | wc -l)

# if [ "$GPU_COUNT" -gt 0 ]; then
#     echo "[OK] NVIDIA GPU hardware detected ($GPU_COUNT GPU(s))"

#     if command -v nvidia-smi &> /dev/null; then
#         echo "[OK] NVIDIA driver installed"
#         nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
#     else
#         echo "[MISSING] NVIDIA driver not installed"
#         echo "[INFO] Install NVIDIA drivers before CUDA toolkit"
#     fi

#     if command -v nvcc &> /dev/null; then
#         echo "[OK] CUDA toolkit installed"
#         nvcc --version | grep "release"
#     else
#         echo "[MISSING] CUDA toolkit not installed"
#         echo "[INSTALL] Installing CUDA toolkit..."
#         sudo apt install -y nvidia-cuda-toolkit
#     fi

# else
#     echo "[WARN] No NVIDIA GPU hardware detected"
#     echo "[INFO] Skipping CUDA setup"
# fi

# # ---------------------------------------------------------
# # Network Utilities
# # ---------------------------------------------------------
# echo ""
# echo "=== Step 7: Checking Network Utilities ==="

# NET_PKGS=(
#     net-tools iputils-ping ethtool dnsutils openssh-client openssh-server
# )

# for pkg in "${NET_PKGS[@]}"; do
#     install_pkg "$pkg"
# done

# # ---------------------------------------------------------
# # Storage Utilities
# # ---------------------------------------------------------
# echo ""
# echo "=== Step 8: Checking Storage Utilities ==="

# STORAGE_PKGS=(
#     smartmontools nvme-cli hdparm
# )

# for pkg in "${STORAGE_PKGS[@]}"; do
#     install_pkg "$pkg"
# done

# # ---------------------------------------------------------
# # HPL / HPCG Prerequisites
# # ---------------------------------------------------------
# echo ""
# echo "=== Step 9: Installing HPL / HPCG Prerequisites ==="

# HPL_PKGS=(
#     libblas-dev liblapack-dev libscalapack-mpi-dev libopenblas-dev
# )

# for pkg in "${HPL_PKGS[@]}"; do
#     install_pkg "$pkg"
# done

# # ---------------------------------------------------------
# # OSU Microbenchmark Prerequisites
# # ---------------------------------------------------------
# echo ""
# echo "=== Step 10: Installing OSU Microbenchmark Prerequisites ==="

# OSU_PKGS=(
#     rdma-core libibverbs-dev ibutils perftest
# )

# for pkg in "${OSU_PKGS[@]}"; do
#     install_pkg "$pkg"
# done

# echo ""
# echo "=============================================="
# echo "   Environment prerequisites setup complete"
# echo "=============================================="


#!/bin/bash

echo "=============================================="
echo "   HPC Environment Bootstrap (Smart Mode)"
echo "=============================================="

# ---------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------

check_pkg() {
    # Check if package is installed in dpkg list
    dpkg -l | grep -qw "$1"
}

install_pkg() {
    local pkg="$1"
    if check_pkg "$pkg"; then
        echo "[OK] $pkg already installed"
    else
        echo "[INSTALL] Installing $pkg ..."
        # Use || true to prevent the entire script from exiting if one dependency fails
        sudo apt install -y "$pkg" || echo "[ERROR] Failed to install $pkg. Check logs."
    fi
}

echo ""
echo "=== Step 1: Updating System ==="
sudo apt update -y

# ---------------------------------------------------------
# Core Build Tools
# ---------------------------------------------------------
echo ""
echo "=== Step 2: Checking Core Build Tools ==="

CORE_PKGS=(
    build-essential gcc g++ gfortran make cmake autoconf automake libtool pkg-config
)

for pkg in "${CORE_PKGS[@]}"; do
    install_pkg "$pkg"
done

# ---------------------------------------------------------
# Essential System Libraries (AIO added here)
# ---------------------------------------------------------
echo ""
echo "=== Step 3: Checking Essential System Libraries ==="

LIB_PKGS=(
    libaio-dev libnuma-dev libopenmpi-dev libssl-dev zlib1g-dev libhwloc-dev
)

for pkg in "${LIB_PKGS[@]}"; do
    install_pkg "$pkg"
done

# ---------------------------------------------------------
# MPI Stack
# ---------------------------------------------------------
echo ""
echo "=== Step 4: Checking MPI Stack ==="

MPI_PKGS=(
    mpich mpich-doc libmpich-dev
)

for pkg in "${MPI_PKGS[@]}"; do
    install_pkg "$pkg"
done

# ---------------------------------------------------------
# Python Build Dependencies
# ---------------------------------------------------------
echo ""
echo "=== Step 5: Checking Python Build Dependencies ==="

PY_PKGS=(
    python3-dev python3-venv python3-pip python3-wheel python3-setuptools
)

for pkg in "${PY_PKGS[@]}"; do
    install_pkg "$pkg"
done

# ---------------------------------------------------------
# GPU / CUDA Detection & Setup
# ---------------------------------------------------------
echo ""
echo "=== Step 6: Checking GPU / CUDA Environment ==="

GPU_COUNT=$(lspci | grep -i nvidia | wc -l)

if [ "$GPU_COUNT" -gt 0 ]; then
    echo "[OK] NVIDIA GPU hardware detected ($GPU_COUNT GPU(s))"

    if command -v nvidia-smi &> /dev/null; then
        echo "[OK] NVIDIA driver installed"
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
    else
        echo "[MISSING] NVIDIA driver not installed"
        echo "[INFO] Install NVIDIA drivers before CUDA toolkit"
    fi

    if command -v nvcc &> /dev/null; then
        echo "[OK] CUDA toolkit installed"
        nvcc --version | grep "release"
    else
        echo "[MISSING] CUDA toolkit not installed"
        echo "[INSTALL] Installing CUDA toolkit..."
        sudo apt install -y nvidia-cuda-toolkit
    fi

else
    echo "[WARN] No NVIDIA GPU hardware detected"
    echo "[INFO] Skipping CUDA setup"
fi

# ---------------------------------------------------------
# Network Utilities
# ---------------------------------------------------------
echo ""
echo "=== Step 7: Checking Network Utilities ==="

NET_PKGS=(
    net-tools iputils-ping ethtool dnsutils openssh-client openssh-server iperf3
)

for pkg in "${NET_PKGS[@]}"; do
    install_pkg "$pkg"
done

# ---------------------------------------------------------
# Storage Utilities (FIO/IOZONE added here)
# ---------------------------------------------------------
echo ""
echo "=== Step 8: Checking Storage/I/O Utilities ==="

STORAGE_PKGS=(
    smartmontools nvme-cli hdparm fio iozone3
)

for pkg in "${STORAGE_PKGS[@]}"; do
    install_pkg "$pkg"
done

# ---------------------------------------------------------
# HPL / HPCG Prerequisites
# ---------------------------------------------------------
echo ""
echo "=== Step 9: Installing HPL / HPCG Prerequisites (BLAS/LAPACK) ==="

HPL_PKGS=(
    libblas-dev liblapack-dev libscalapack-mpi-dev libopenblas-dev
)

for pkg in "${HPL_PKGS[@]}"; do
    install_pkg "$pkg"
done

# ---------------------------------------------------------
# OSU Microbenchmark Prerequisites (PAPI added here)
# ---------------------------------------------------------
echo ""
echo "=== Step 10: Installing OSU Microbenchmark Prerequisites (IB/PAPI) ==="

OSU_PKGS=(
    rdma-core libibverbs-dev ibutils perftest
    # CRITICAL ADDITION: PAPI is needed for many benchmarks (including OSU's checks)
    libpapi-dev libpfm4-dev 
)

for pkg in "${OSU_PKGS[@]}"; do
    install_pkg "$pkg"
done

# ---------------------------------------------------------
# Final Verification and Tools
# ---------------------------------------------------------
echo ""
echo "=== Step 11: Final Verification Tools ==="

FINAL_PKGS=(
    sysbench stress-ng wget curl
)

for pkg in "${FINAL_PKGS[@]}"; do
    install_pkg "$pkg"
done

echo ""
echo "=============================================="
echo "   Environment prerequisites setup complete"
echo "=============================================="