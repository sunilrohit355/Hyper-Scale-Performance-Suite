# #!/bin/bash
# set -e

# # ====================================================
# # USER CONFIGURATION
# # ====================================================
# # --- REQUIRED: Replace with your Pushgateway URL ---
# PUSHGATEWAY_URL="http://<PUSHGATEWAY_HOST_IP>:9091/metrics/job/hpc_benchmarks"

# # --- Optional: Define a unique label for this system/job ---
# SYSTEM_LABEL="local_hpc_system"
# # ====================================================

# # --- Configuration & Logging ---
# echo "===================================================="
# echo "           HPC BENCHMARK UTILITY (Installer + Runner)"
# echo "===================================================="

# # Define environment variables and results array
# PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# TOOLS_DIR="${PROJECT_ROOT}/tools"
# ARCH_NAME="Linux"
# export ARCH_NAME

# # Global associative array to store extracted numeric results
# declare -A KPI_RESULTS
# KPI_RESULTS[timestamp]="$(date +%s)" # Unix timestamp for Prometheus

# # Ensure tools directory exists
# mkdir -p "$TOOLS_DIR"

# log() {
#     echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
# }

# fatal_error() {
#     echo "[FATAL] $1" >&2
#     exit 1
# }

# check_cmd() {
#     command -v "$1" &> /dev/null
# }

# # ----------------------------------------------------
# # Utility and Dependency Functions
# # ----------------------------------------------------

# install_dialog() {
#     if ! check_cmd "dialog"; then
#         log "[SETUP] Installing 'dialog' utility..."
#         sudo apt update -y && sudo apt install -y dialog
#         if ! check_cmd "dialog"; then log "[FATAL] Failed to install 'dialog'."; return 1; fi
#     fi
#     return 0
# }

# install_curl() {
#     if ! check_cmd "curl"; then
#         log "[SETUP] Installing 'curl' utility for pushing metrics..."
#         sudo apt update -y && sudo apt install -y curl
#         if ! check_cmd "curl"; then log "[FATAL] Failed to install 'curl'."; return 1; fi
#     fi
#     return 0
# }

# ensure_build_deps() {
#     log "[INFO] Ensuring common build dependencies..."
#     if check_cmd "mpicc"; then
#         log "[INFO] Core dependencies (MPI, compilers) appear installed. Skipping build dependency install."
#         return 0
#     fi
#     sudo apt update -y
#     sudo apt install -y \
#         build-essential git cmake autoconf automake libtool pkg-config \
#         libaio-dev libopenblas-dev liblapack-dev libscalapack-mpi-dev \
#         libibverbs-dev rdma-core mpi-default-bin mpi-default-dev \
#         libmpich-dev mpich wget curl file
# }

# install_apt_tool() {
#     local pkg="$1"
#     local cmd="$2"
#     if ! check_cmd "$cmd"; then
#         log "[INSTALL] Installing $pkg..."
#         sudo apt update -y && sudo apt install -y "$pkg"
#     fi
# }

# # --- Installation Functions (Truncated for brevity, assuming existing logic is fine) ---

# install_stream() {
#     local target="${TOOLS_DIR}/stream"; local bin="${target}/stream"
#     if [[ -x "$bin" ]]; then log "[OK] STREAM already installed"; return; fi
#     log "[INSTALL] Installing STREAM..."
#     mkdir -p "$target"; cd "$target"
#     if [[ ! -f "stream.c" ]]; then curl -O https://www.cs.virginia.edu/stream/FTP/Code/stream.c; fi
#     gcc -O3 -fopenmp -march=native stream.c -o stream
#     log "[OK] STREAM installed at $bin"
# }

# install_ior() {
#     local target="${TOOLS_DIR}/ior"; local bin="${target}/src/ior"
#     if [[ -x "$bin" ]]; then log "[OK] IOR already installed"; return; fi
#     log "[INSTALL] Installing IOR..."; mkdir -p "$target"; cd "$target"
#     if [[ ! -d ".git" ]]; then git clone https://github.com/hpc/ior.git .; fi
#     ./bootstrap || true; ./configure --with-mpi; make -j"$(nproc)"
#     log "[OK] IOR installed at $bin"
# }

# install_osu() {
#     local target="${TOOLS_DIR}/osu-micro-benchmarks"; local version="7.3"; local src_dir="osu-micro-benchmarks-${version}"; local full_src_dir="${target}/${src_dir}"
#     if [[ -d "$full_src_dir" && -x "${full_src_dir}/c/mpi/pt2pt/standard/.libs/osu_bw" ]]; then log "[OK] OSU Microbenchmarks appears installed."; return; fi
#     log "[INFO] Preparing OSU installation directory: $target"; mkdir -p "$target"; cd "$target"
#     wget -N "http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-${version}.tar.gz" -O "osu-micro-benchmarks-${version}.tar.gz" || fatal_error "Failed to download OSU"
#     tar -xzf "osu-micro-benchmarks-${version}.tar.gz" || fatal_error "Failed to extract OSU"
#     cd "$src_dir" || fatal_error "OSU source directory missing"
#     sed -i '/ac_fn_c_check_lib "$LINKS_FOR_PAPI" "PAPI_library_init" "" "papi_lib_found" "$lineno"/c\papi_lib_found=yes' configure
#     log "[INFO] Configuring OSU..."; ./configure CC=mpicc CXX=mpicxx --disable-papi --disable-shmem --disable-upc --disable-cuda --disable-gdr --enable-pt2pt --enable-collective --enable-one-sided || fatal_error "OSU configure failed"
#     log "[INFO] Building OSU..."; make -j"$(nproc)" || fatal_error "OSU build failed"
#     log "[OK] OSU installed successfully"
# }

# # (HPL installation functions like generate_hpl_makefile, generate_hpl_dat, install_hpl remain unchanged here)

# # ----------------------------------------------------
# # Benchmarking Execution Functions (MODIFIED FOR KPI CAPTURE)
# # ----------------------------------------------------

# run_sysbench_cpu() {
#     local key="sysbench_cpu_events_per_sec"
#     log "--- Running Sysbench CPU Test ---"
#     install_apt_tool "sysbench" "sysbench" || { KPI_RESULTS[$key]=0; log "[ERROR] Sysbench not runnable."; return 1; }
#     local log_file="${TOOLS_DIR}/sysbench_cpu_$(date +%F_%H%M%S).log"
    
#     if ! sysbench cpu --cpu-max-prime=20000 --threads=$(nproc) run | tee "$log_file"; then
#         KPI_RESULTS[$key]=0; log "[ERROR] Sysbench execution failed."; return 1;
#     fi

#     local events_per_sec=$(grep 'events per second:' "$log_file" | awk '{print $NF}')
    
#     KPI_RESULTS[$key]="${events_per_sec:-0}"
#     log "--- Sysbench Summary ---"; grep 'events per second:' "$log_file"; log "------------------------"
# }

# run_fio_disk_rw() {
#     local key_iops="fio_randrw_iops"
#     local key_bw="fio_randrw_bw_mbps"
#     log "--- Running Fio Random Read/Write Test ---"
#     install_apt_tool "fio" "fio" || { KPI_RESULTS[$key_iops]=0; return 1; }
#     local log_file="${TOOLS_DIR}/fio_rw_$(date +%F_%H%M%S).log"
    
#     if ! fio --name=rand_rw_test --rw=randrw --bs=4k --numjobs=1 --iodepth=16 --size=1G --runtime=10s --ioengine=libaio --direct=1 --group_reporting | tee "$log_file"; then
#         KPI_RESULTS[$key_iops]=0; KPI_RESULTS[$key_bw]=0; log "[ERROR] FIO execution failed."; return 1;
#     fi

#     # Read IOPS (last iops= line for read)
#     local read_iops=$(grep 'iops=' "$log_file" | tail -n 2 | head -n 1 | sed 's/.*iops=\([0-9.]\+\)k?/\1/g' | tr -d 'k')
#     local read_bw=$(grep 'BW=' "$log_file" | tail -n 2 | head -n 1 | sed 's/.*BW=\([0-9.]\+\)MiB\/s/\1/g')
    
#     KPI_RESULTS[fio_read_iops]="${read_iops:-0}"
#     KPI_RESULTS[fio_read_bw]="${read_bw:-0}"

#     log "--- FIO Summary (IOPS) ---"; grep 'iops=' "$log_file" | tail -n 2; log "--------------------------"
# }

# run_stream_memory() {
#     local key="stream_triad_bw_mbps"
#     log "--- Running STREAM Memory Bandwidth Test ---"
#     local bin="${TOOLS_DIR}/stream/stream"
#     if [[ ! -x "$bin" ]]; then install_stream || { KPI_RESULTS[$key]=0; return 1; }; fi
#     local log_file="${TOOLS_DIR}/stream_$(date +%F_%H%M%S).log"

#     OMP_NUM_THREADS=$(nproc) "$bin" | tee "$log_file"

#     local triad_bw=$(grep 'Triad:' "$log_file" | awk '{print $2}')
    
#     KPI_RESULTS[$key]="${triad_bw:-0}"
#     log "--- STREAM Summary (Triad Bandwidth) ---"; grep 'Triad:' "$log_file" | tail -n 1; log "----------------------------------------"
# }

# run_ior_parallel_io() {
#     local key_read="ior_parallel_read_mbps"
#     local key_write="ior_parallel_write_mbps"
#     local bin="${TOOLS_DIR}/ior/src/ior"
#     if [[ ! -x "$bin" ]]; then install_ior || { KPI_RESULTS[$key_read]=0; return 1; }; fi
#     local log_file="${TOOLS_DIR}/ior_$(date +%F_%H%M%S).log"
    
#     mpirun -np 4 "$bin" -t 1m -b 100m -k | tee "$log_file"

#     local max_write=$(grep 'write' "$log_file" | grep -A 1 'Max(MiB)' | head -n 1 | awk '{print $2}')
#     local max_read=$(grep 'read' "$log_file" | grep -A 1 'Max(MiB)' | tail -n 1 | awk '{print $2}')

#     KPI_RESULTS[$key_write]="${max_write:-0}"
#     KPI_RESULTS[$key_read]="${max_read:-0}"

#     log "--- IOR Summary (Max Read/Write MiB/s) ---"; grep 'Max' "$log_file" | tail -n 2; log "------------------------------------------"
# }

# run_hpl_linpack() {
#     local key="hpl_linpack_gflops"
#     local HPL_VERSION="2.3"; local hpl_root="${TOOLS_DIR}/hpl/hpl-${HPL_VERSION}"; local bin="${hpl_root}/bin/${ARCH_NAME}/xhpl"; local bin_dir="$(dirname "$bin")"; local executable="$(basename "$bin")"
    
#     if [[ ! -x "$bin" ]]; then install_hpl || { KPI_RESULTS[$key]=0; return 1; }; fi
    
#     log "[EXEC] Running HPL with mpirun -np 16. Results may take time."
#     local test_output
#     if ! test_output=$(cd "${bin_dir}" && mpirun -np 16 --oversubscribe ./"${executable}" 2>&1 | tee /dev/tty); then log "[FATAL] HPL mpirun command exited with non-zero status."; KPI_RESULTS[$key]=0; return 1; fi
    
#     if echo "$test_output" | grep -q "PASSED"; then
#         local gflops_value=$(echo "$test_output" | grep "Gflops" | tail -n 1 | awk '{print $NF}')
#         KPI_RESULTS[$key]="${gflops_value:-0}"
#         log "[OK] HPL test succeeded."; log "[RESULT] HPL Final Result: "$gflops_value" Gflops"; return 0
#     else
#         log "[FATAL] HPL test FAILED."; KPI_RESULTS[$key]=0; return 1
#     fi
# }

# run_osu_latency() {
#     local key="osu_latency_min_us"
#     log "--- Running OSU Microbenchmarks (Latency) ---"
#     local dir="${TOOLS_DIR}/osu-micro-benchmarks/osu-micro-benchmarks-7.3"; local bin="${dir}/c/mpi/pt2pt/standard/.libs/osu_latency" 
#     if [[ ! -x "$bin" ]]; then 
#         install_osu || { KPI_RESULTS[$key]=99999; return 1; }
#         bin="${dir}/c/mpi/pt2pt/standard/osu_latency" # Fallback check
#         if [[ ! -x "$bin" ]]; then log "[FATAL] OSU binary not found."; KPI_RESULTS[$key]=99999; return 1; fi
#     fi
#     local log_file="${TOOLS_DIR}/osu_latency_$(date +%F_%H%M%S).log"

#     mpirun -np 2 "$bin" | tee "$log_file"

#     # Find the latency for the smallest message size (e.g., 8 bytes)
#     local min_latency=$(grep '^8' "$log_file" | awk '{print $2}')
    
#     KPI_RESULTS[$key]="${min_latency:-99999}" # Use a high value for failure/not found
#     log "--- OSU Latency Summary (Smallest message size) ---"; grep '^8' "$log_file" | tail -n 1; log "----------------------------------------------------"
# }


# # ----------------------------------------------------
# # Prometheus Finalizer (NEW)
# # ----------------------------------------------------

# push_metrics_to_pushgateway() {
#     install_curl || return 1

#     local PUSH_URL="${PUSHGATEWAY_URL}/metrics/instance/${SYSTEM_LABEL}"
#     local payload_file="${TOOLS_DIR}/prometheus_metrics_payload.txt"
#     local timestamp="${KPI_RESULTS[timestamp]}"
    
#     log "[INFO] Generating Prometheus metric payload..."
    
#     # Start the payload file
#     # We use instance="${SYSTEM_LABEL}" and add it to the PromQL query structure

#     cat > "$payload_file" <<EOF
# # HELP hpc_benchmark_sysbench_events Sysbench CPU events per second.
# # TYPE hpc_benchmark_sysbench_events gauge
# hpc_benchmark_sysbench_events{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[sysbench_cpu_events_per_sec]} $timestamp

# # HELP hpc_benchmark_stream_triad_bw_mbps STREAM Triad Memory Bandwidth in MiB/s.
# # TYPE hpc_benchmark_stream_triad_bw_mbps gauge
# hpc_benchmark_stream_triad_bw_mbps{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[stream_triad_bw_mbps]} $timestamp

# # HELP hpc_benchmark_fio_read_iops FIO Random Read IOPS.
# # TYPE hpc_benchmark_fio_read_iops gauge
# hpc_benchmark_fio_read_iops{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[fio_read_iops]:-0} $timestamp

# # HELP hpc_benchmark_ior_write_mbps IOR Parallel File System Write BW in MiB/s.
# # TYPE hpc_benchmark_ior_write_mbps gauge
# hpc_benchmark_ior_write_mbps{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[ior_parallel_write_mbps]:-0} $timestamp

# # HELP hpc_benchmark_ior_read_mbps IOR Parallel File System Read BW in MiB/s.
# # TYPE hpc_benchmark_ior_read_mbps gauge
# hpc_benchmark_ior_read_mbps{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[ior_parallel_read_mbps]:-0} $timestamp

# # HELP hpc_benchmark_hpl_gflops HPL Linpack Gflops.
# # TYPE hpc_benchmark_hpl_gflops gauge
# hpc_benchmark_hpl_gflops{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[hpl_linpack_gflops]:-0} $timestamp

# # HELP hpc_benchmark_osu_latency_min_us OSU Minimum MPI Latency in microseconds.
# # TYPE hpc_benchmark_osu_latency_min_us gauge
# hpc_benchmark_osu_latency_min_us{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[osu_latency_min_us]:-0} $timestamp
# EOF

#     log "[INFO] Pushing metrics to Pushgateway: $PUSH_URL"
    
#     # Push the payload using HTTP POST
#     if curl --data-binary "@$payload_file" -H "Content-Type: text/plain" -X PUT "$PUSH_URL"; then
#         log "[OK] Metrics successfully pushed to Pushgateway."
#     else
#         log "[FATAL] Failed to push metrics to Pushgateway. Check connectivity to $PUSH_URL."
#         return 1
#     fi
# }


# # ----------------------------------------------------
# # Main Execution Logic (unchanged)
# # ----------------------------------------------------

# benchmark_tools=(
#     "sysbench_cpu" "CPU: Sysbench (Basic CPU/Thread Performance)" OFF
#     "stream_memory" "Memory: STREAM (Memory Bandwidth Test)" OFF
#     "fio_disk_rw" "I/O: FIO (Random Disk Read/Write Test)" OFF
#     "ior_parallel_io" "Parallel I/O: IOR (File System Scaling Test)" OFF
#     "hpl_linpack" "HPC: HPL (High-Performance Linpack - Gflops)" OFF
#     "osu_latency" "Network: OSU Latency (MPI Latency Check)" OFF
# )

# run_all_benchmarks() {
#     for tool_key in "sysbench_cpu" "stream_memory" "fio_disk_rw" "ior_parallel_io" "hpl_linpack" "osu_latency"; do
#         log ">>> Starting forced execution of $tool_key <<<"
#         "run_${tool_key}"
#         echo ""
#     done
# }

# show_multi_select_menu() {
#     install_dialog || return 1
#     local menu_items=("${benchmark_tools[@]}" "run_all" "RUN ALL TESTS" OFF)
#     local selection
#     selection=$(dialog --checklist "Select benchmarks to run (Spacebar to select/deselect, Enter to confirm)" 20 80 15 "${menu_items[@]}" 2>&1 >/dev/tty)
    
#     if [[ $? -ne 0 ]]; then log "User cancelled the selection. Exiting."; exit 0; fi
#     local selected_keys=($selection)

#     if [[ " ${selected_keys[*]} " =~ " run_all " ]]; then
#         log "Run All option selected."
#         run_all_benchmarks
#     else
#         for key in "${selected_keys[@]}"; do
#             if [[ "$key" != "run_all" ]]; then
#                 log ">>> Starting selected benchmark: $key <<<"
#                 "run_${key}"
#                 echo ""
#             fi
#         done
#     fi
# }

# # --- Script Entry Point ---
# log "[SETUP] Running initial environment check for build tools..."
# ensure_build_deps

# log "[SETUP] Starting interactive multi-select menu."
# show_multi_select_menu

# # --- FINAL STEP: PUSH METRICS ---
# log "Metrics collection finished. Pushing results to dashboard..."
# push_metrics_to_pushgateway

# log "Benchmark execution finished. Goodbye!"


#!/bin/bash
set -e

# ====================================================
# USER CONFIGURATION
# ====================================================
# --- REQUIRED: PUSHGATEWAY HOST/IP ---
# If kept as '<PUSHGATEWAY_HOST_IP>', the script will auto-detect the local IP.
# If Pushgateway is on a different machine, replace this with its fixed IP/hostname.
PUSHGATEWAY_IP="192.168.82.158" 
PUSHGATEWAY_PORT="9091"
PUSHGATEWAY_URL="" # Resolved at runtime

# --- Optional: Define a unique label for this system/job ---
SYSTEM_LABEL="local_hpc_system"
# ====================================================

# --- Configuration & Logging ---
echo "===================================================="
echo "           HPC BENCHMARK UTILITY (Installer + Runner)"
echo "===================================================="

# Define environment variables and results array
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${PROJECT_ROOT}/tools"
ARCH_NAME="Linux"
export ARCH_NAME

# Global associative array to store extracted numeric results
declare -A KPI_RESULTS
KPI_RESULTS[timestamp]="$(date +%s)" # Unix timestamp for Prometheus

# Ensure tools directory exists
mkdir -p "$TOOLS_DIR"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

fatal_error() {
    echo "[FATAL] $1" >&2
    exit 1
}

check_cmd() {
    command -v "$1" &> /dev/null
}

# ----------------------------------------------------
# Utility and Dependency Functions (IP Detection ADDED)
# ----------------------------------------------------

install_dialog() {
    if ! check_cmd "dialog"; then
        log "[SETUP] Installing 'dialog' utility..."
        sudo apt update -y && sudo apt install -y dialog
        if ! check_cmd "dialog"; then log "[FATAL] Failed to install 'dialog'."; return 1; fi
    fi
    return 0
}

install_curl() {
    if ! check_cmd "curl"; then
        log "[SETUP] Installing 'curl' utility for pushing metrics..."
        sudo apt update -y && sudo apt install -y curl
        if ! check_cmd "curl"; then log "[FATAL] Failed to install 'curl'."; return 1; fi
    fi
    return 0
}

ensure_build_deps() {
    log "[INFO] Ensuring common build dependencies..."
    if check_cmd "mpicc"; then
        log "[INFO] Core dependencies (MPI, compilers) appear installed. Skipping build dependency install."
        return 0
    fi
    sudo apt update -y
    sudo apt install -y \
        build-essential git cmake autoconf automake libtool pkg-config \
        libaio-dev libopenblas-dev liblapack-dev libscalapack-mpi-dev \
        libibverbs-dev rdma-core mpi-default-bin mpi-default-dev \
        libmpich-dev mpich wget curl file
}

install_apt_tool() {
    local pkg="$1"
    local cmd="$2"
    if ! check_cmd "$cmd"; then
        log "[INSTALL] Installing $pkg..."
        sudo apt update -y && sudo apt install -y "$pkg"
    fi
}

# ----------------------------------------------------
# Auto-detect local machine IP (robust & safe)
# ----------------------------------------------------
get_local_ip() {
    local ip

    # Preferred: IP used for default route
    ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
    fi

    # Fallback: hostname
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
    fi

    # Last resort
    echo "127.0.0.1"
}


# ----------------------------------------------------
# Installation Functions (IOR ADDED AND CORRECTED)
# ----------------------------------------------------

install_stream() {
    local target="${TOOLS_DIR}/stream"; local bin="${target}/stream"
    if [[ -x "$bin" ]]; then log "[OK] STREAM already installed"; return; fi
    log "[INSTALL] Installing STREAM..."
    mkdir -p "$target"; cd "$target"
    if [[ ! -f "stream.c" ]]; then curl -O https://www.cs.virginia.edu/stream/FTP/Code/stream.c; fi
    gcc -O3 -fopenmp -march=native stream.c -o stream
    log "[OK] STREAM installed at $bin"
}

install_ior() {
    local target="${TOOLS_DIR}/ior"
    # Set the path to the expected installed binary location
    local bin="${target}/install/bin/ior" 
    
    if [[ -x "$bin" ]]; then 
        log "[OK] IOR already installed at $bin"; 
        return 0; 
    fi
    
    log "[INSTALL] Installing IOR from source..."
    mkdir -p "$target"
    
    # Clone repository if it doesn't exist
    if [[ ! -d "$target/.git" ]]; then 
        log "[INFO] Cloning IOR repository...";
        git clone https://github.com/hpc/ior.git "$target" || fatal_error "Failed to clone IOR repository."
    fi
    
    cd "$target"
    
    # Generate configure script 
    log "[INFO] Running bootstrap to generate configure script..."
    ./bootstrap || fatal_error "IOR bootstrap failed."
    
    # Configure using MPI and install prefix
    log "[INFO] Configuring IOR with MPI..."
    ./configure --with-mpi --prefix="$target/install" || fatal_error "IOR configure failed."
    
    # Compile IOR
    log "[INFO] Building IOR using $(nproc) threads..."
    make -j"$(nproc)" || fatal_error "IOR build failed."
    
    # Install the binaries
    log "[INFO] Installing IOR binaries..."
    make install || fatal_error "IOR install failed."
    
    if [[ -x "$bin" ]]; then
        log "[OK] IOR successfully installed at $bin"
    else
        fatal_error "IOR installation completed, but the final executable was not found at $bin"
    fi
}

install_osu() {
    local target="${TOOLS_DIR}/osu-micro-benchmarks"; local version="7.3"; local src_dir="osu-micro-benchmarks-${version}"; local full_src_dir="${target}/${src_dir}"
    if [[ -d "$full_src_dir" && -x "${full_src_dir}/c/mpi/pt2pt/standard/.libs/osu_bw" ]]; then log "[OK] OSU Microbenchmarks appears installed."; return; fi
    log "[INFO] Preparing OSU installation directory: $target"; mkdir -p "$target"; cd "$target"
    wget -N "http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-${version}.tar.gz" -O "osu-micro-benchmarks-${version}.tar.gz" || fatal_error "Failed to download OSU"
    tar -xzf "osu-micro-benchmarks-${version}.tar.gz" || fatal_error "Failed to extract OSU"
    cd "$src_dir" || fatal_error "OSU source directory missing"
    sed -i '/ac_fn_c_check_lib "$LINKS_FOR_PAPI" "PAPI_library_init" "" "papi_lib_found" "$lineno"/c\papi_lib_found=yes' configure
    log "[INFO] Configuring OSU..."; ./configure CC=mpicc CXX=mpicxx --disable-papi --disable-shmem --disable-upc --disable-cuda --disable-gdr --enable-pt2pt --enable-collective --enable-one-sided || fatal_error "OSU configure failed"
    log "[INFO] Building OSU..."; make -j"$(nproc)" || fatal_error "OSU build failed"
    log "[OK] OSU installed successfully"
}



# (HPL installation functions remain unchanged here)

# ----------------------------------------------------
# Benchmarking Execution Functions (IOR CORRECTED)
# ----------------------------------------------------
# ----------------------------------------------------
# HPL (High Performance Linpack) Installation & Setup
# ----------------------------------------------------

install_hpl() {
    local HPL_VERSION="2.3"
    local hpl_root="${TOOLS_DIR}/hpl/hpl-${HPL_VERSION}"
    local tarball="hpl-${HPL_VERSION}.tar.gz"
    local url="https://www.netlib.org/benchmark/hpl/${tarball}"
    local arch="Linux_x86_64"

    # Final binary path
    local bin="${hpl_root}/bin/${arch}/xhpl"

    if [[ -x "$bin" ]]; then
        log "[OK] HPL already installed at $bin"
        return 0
    fi

    log "[INSTALL] Installing HPL ${HPL_VERSION}..."

    mkdir -p "${TOOLS_DIR}/hpl"
    cd "${TOOLS_DIR}/hpl" || fatal_error "Failed to enter HPL directory"

    # Download
    if [[ ! -f "$tarball" ]]; then
        log "[INFO] Downloading HPL..."
        wget "$url" || fatal_error "HPL download failed"
    fi

    # Extract
    tar -xzf "$tarball" || fatal_error "HPL extraction failed"
    cd "hpl-${HPL_VERSION}" || fatal_error "HPL source dir missing"

    # Generate Makefile & HPL.dat
    generate_hpl_makefile "$arch"
    generate_hpl_dat

    # Build
    log "[INFO] Building HPL..."
    make arch="$arch" || fatal_error "HPL build failed"

    if [[ -x "$bin" ]]; then
        log "[OK] HPL successfully built at $bin"
    else
        fatal_error "HPL build finished but xhpl not found"
    fi
}

generate_hpl_makefile() {
    local arch="$1"
    local makefile="Make.${arch}"

    log "[INFO] Generating HPL Makefile: $makefile"

    cat > "$makefile" <<EOF
SHELL        = /bin/sh
CD           = cd
CP           = cp
LN_S         = ln -s
MKDIR        = mkdir
RM           = rm -f

ARCH         = ${arch}
TOPdir       = \$(PWD)
INCdir       = \$(TOPdir)/include
BINdir       = \$(TOPdir)/bin/\$(ARCH)
LIBdir       = \$(TOPdir)/lib/\$(ARCH)

HPL_INCLUDES = -I\$(INCdir)
HPL_LIBS     =

MPdir        =
MPinc        =
MPlib        = -lmpi

LAdir        =
LAinc        =
LAlib        = -lopenblas

CC           = mpicc
CCFLAGS      = -O3 -march=native -fomit-frame-pointer
LINKER       = mpicc
LINKFLAGS    = -O3

ARCHIVER     = ar
ARFLAGS      = r
RANLIB       = ranlib
EOF
}

generate_hpl_dat() {
    log "[INFO] Generating HPL.dat"

    # Estimate memory: use ~80% of RAM
    local mem_kb
    mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_mb=$((mem_kb / 1024))
    local usable_mb=$((mem_mb * 80 / 100))

    # N ≈ sqrt(memory_bytes / 8)
    local n
    n=$(awk -v m="$usable_mb" 'BEGIN { printf "%d", sqrt(m*1024*1024/8) }')

    cat > HPL.dat <<EOF
HPLinpack benchmark input file
Innovative Computing Laboratory, University of Tennessee
1            # of problems sizes
$n           Ns
1            # of NBs
256          NBs
0            PMAP process mapping (0=Row-,1=Column-major)
1            # of process grids
1            Ps
$(nproc)     Qs
16.0         threshold
1            # of panel fact
2            PFACTs (0=left, 1=Crout, 2=Right)
1            # of recursive stopping criterium
4            NBMINs
1            # of panels in recursion
2            NDIVs
1            # of recursive panel fact.
2            RFACTs
1            # of broadcast
1            BCASTs
1            # of lookahead depth
1            DEPTHs
2            SWAP (0=bin-exch,1=long,2=mix)
64           swapping threshold
0            L1 in (0=transposed,1=no-transposed) form
0            U  in (0=transposed,1=no-transposed) form
1            Equilibration (0=no,1=yes)
8            memory alignment in double (> 0)
EOF
}

run_sysbench_cpu() {
    local key="sysbench_cpu_events_per_sec"
    log "--- Running Sysbench CPU Test ---"
    install_apt_tool "sysbench" "sysbench" || { KPI_RESULTS[$key]=0; log "[ERROR] Sysbench not runnable."; return 1; }
    local log_file="${TOOLS_DIR}/sysbench_cpu_$(date +%F_%H%M%S).log"
    if ! sysbench cpu --cpu-max-prime=20000 --threads=$(nproc) run | tee "$log_file"; then KPI_RESULTS[$key]=0; log "[ERROR] Sysbench execution failed."; return 1; fi
    local events_per_sec=$(grep 'events per second:' "$log_file" | awk '{print $NF}')
    KPI_RESULTS[$key]="${events_per_sec:-0}"
    log "--- Sysbench Summary ---"; grep 'events per second:' "$log_file"; log "------------------------"
}

run_fio_disk_rw() {
    local key_iops="fio_randrw_iops"; local key_bw="fio_randrw_bw_mbps"
    log "--- Running Fio Random Read/Write Test ---"
    install_apt_tool "fio" "fio" || { KPI_RESULTS[$key_iops]=0; return 1; }
    local log_file="${TOOLS_DIR}/fio_rw_$(date +%F_%H%M%S).log"
    if ! fio --name=rand_rw_test --rw=randrw --bs=4k --numjobs=1 --iodepth=16 --size=1G --runtime=10s --ioengine=libaio --direct=1 --group_reporting | tee "$log_file"; then KPI_RESULTS[$key_iops]=0; KPI_RESULTS[$key_bw]=0; log "[ERROR] FIO execution failed."; return 1; fi
    local read_iops=$(grep 'iops=' "$log_file" | tail -n 2 | head -n 1 | sed 's/.*iops=\([0-9.]\+\)k?/\1/g' | tr -d 'k')
    local read_bw=$(grep 'BW=' "$log_file" | tail -n 2 | head -n 1 | sed 's/.*BW=\([0-9.]\+\)MiB\/s/\1/g')
    KPI_RESULTS[fio_read_iops]="${read_iops:-0}"; KPI_RESULTS[fio_read_bw]="${read_bw:-0}"
    log "--- FIO Summary (IOPS) ---"; grep 'iops=' "$log_file" | tail -n 2; log "--------------------------"
}

run_stream_memory() {
    local key="stream_triad_bw_mbps"
    log "--- Running STREAM Memory Bandwidth Test ---"
    local bin="${TOOLS_DIR}/stream/stream"
    if [[ ! -x "$bin" ]]; then install_stream || { KPI_RESULTS[$key]=0; return 1; }; fi
    local log_file="${TOOLS_DIR}/stream_$(date +%F_%H%M%S).log"
    OMP_NUM_THREADS=$(nproc) "$bin" | tee "$log_file"
    local triad_bw=$(grep 'Triad:' "$log_file" | awk '{print $2}')
    KPI_RESULTS[$key]="${triad_bw:-0}"
    log "--- STREAM Summary (Triad Bandwidth) ---"; grep 'Triad:' "$log_file" | tail -n 1; log "----------------------------------------"
}

run_ior_parallel_io() {
    local key_read="ior_parallel_read_mbps"
    local key_write="ior_parallel_write_mbps"
    # Use the installed binary path
    local bin="${TOOLS_DIR}/ior/install/bin/ior" 
    
    log "--- Running IOR Parallel I/O Test (Read/Write) ---"
    
    if [[ ! -x "$bin" ]]; then 
        install_ior || { KPI_RESULTS[$key_read]=0; KPI_RESULTS[$key_write]=0; return 1; } 
    fi
    
    local log_file="${TOOLS_DIR}/ior_$(date +%F_%H%M%S).log"
    local test_file="${TOOLS_DIR}/ior_test_file.dat"
    local mpi_np=4 

    log "[EXEC] Running mpirun -np ${mpi_np} $bin -a POSIX -w -r -F -t 1m -b 100m -i 1 -o ${test_file}"
    
    if ! mpirun -np ${mpi_np} --oversubscribe "$bin" \
        -a POSIX \
        -w -r \
        -F \
        -t 1m \
        -b 100m \
        -i 1 \
        -o "${test_file}" | tee "$log_file"; 
    then
        KPI_RESULTS[$key_write]=0; KPI_RESULTS[$key_read]=0; 
        log "[ERROR] IOR execution failed."; 
        return 1;
    fi

    # Extract Metrics: Look for Write and Read lines in the summary
    local max_write=$(grep 'Write' "$log_file" | awk '{print $2}')
    local max_read=$(grep 'Read' "$log_file" | awk '{print $2}')

    KPI_RESULTS[$key_write]="${max_write:-0}"
    KPI_RESULTS[$key_read]="${max_read:-0}"

    log "--- IOR Summary ---"
    grep 'Max(MiB)' "$log_file" || true
    log "Max Write Bandwidth: ${max_write:-0} MiB/s"
    log "Max Read Bandwidth: ${max_read:-0} MiB/s"
    log "-------------------"
    
    rm -f "${test_file}"* || true
}

run_hpl_linpack() {
    local key="hpl_linpack_gflops"
    local HPL_VERSION="2.3"; local hpl_root="${TOOLS_DIR}/hpl/hpl-${HPL_VERSION}"; local bin="${hpl_root}/bin/${ARCH_NAME}/xhpl"; local bin_dir="$(dirname "$bin")"; local executable="$(basename "$bin")"
    
    if [[ ! -x "$bin" ]]; then install_hpl || { KPI_RESULTS[$key]=0; return 1; }; fi
    
    log "[EXEC] Running HPL with mpirun -np 16. Results may take time."
    local test_output
    if ! test_output=$(cd "${bin_dir}" && mpirun -np 16 --oversubscribe ./"${executable}" 2>&1 | tee /dev/tty); then log "[FATAL] HPL mpirun command exited with non-zero status."; KPI_RESULTS[$key]=0; return 1; fi
    
    if echo "$test_output" | grep -q "PASSED"; then
        local gflops_value=$(echo "$test_output" | grep "Gflops" | tail -n 1 | awk '{print $NF}')
        KPI_RESULTS[$key]="${gflops_value:-0}"
        log "[OK] HPL test succeeded."; log "[RESULT] HPL Final Result: "$gflops_value" Gflops"; return 0
    else
        log "[FATAL] HPL test FAILED."; KPI_RESULTS[$key]=0; return 1
    fi
}

run_osu_latency() {
    local key="osu_latency_min_us"
    log "--- Running OSU Microbenchmarks (Latency) ---"
    local dir="${TOOLS_DIR}/osu-micro-benchmarks/osu-micro-benchmarks-7.3"; local bin="${dir}/c/mpi/pt2pt/standard/.libs/osu_latency" 
    if [[ ! -x "$bin" ]]; then 
        install_osu || { KPI_RESULTS[$key]=99999; return 1; }
        bin="${dir}/c/mpi/pt2pt/standard/osu_latency" # Fallback check
        if [[ ! -x "$bin" ]]; then log "[FATAL] OSU binary not found."; KPI_RESULTS[$key]=99999; return 1; fi
    fi
    local log_file="${TOOLS_DIR}/osu_latency_$(date +%F_%H%M%S).log"
    mpirun -np 2 "$bin" | tee "$log_file"
    local min_latency=$(grep '^8' "$log_file" | awk '{print $2}')
    KPI_RESULTS[$key]="${min_latency:-99999}" # Use a high value for failure/not found
    log "--- OSU Latency Summary (Smallest message size) ---"; grep '^8' "$log_file" | tail -n 1; log "----------------------------------------------------"
}


# ----------------------------------------------------
# Prometheus Finalizer (UPDATED FOR IP RESOLUTION)
# ----------------------------------------------------

# push_metrics_to_pushgateway() {
#     install_curl || return 1

#     # 1. Resolve PUSHGATEWAY_URL here
#     local target_ip="${PUSHGATEWAY_IP}"
#     if [[ "$target_ip" == "<PUSHGATEWAY_HOST_IP>" ]]; then
#         target_ip=$(get_local_ip)
#         log "[INFO] PUSHGATEWAY_IP auto-detected as: $target_ip"
#     fi
    
#     # Construct the final URL using the resolved IP/Host and configured port
#     PUSHGATEWAY_URL="http://${target_ip}:${PUSHGATEWAY_PORT}/metrics/job/hpc_benchmarks"
#     log "[INFO] Final PUSHGATEWAY_URL set to: $PUSHGATEWAY_URL"
    
#     local PUSH_URL="${PUSHGATEWAY_URL}/metrics/instance/${SYSTEM_LABEL}"
#     local payload_file="${TOOLS_DIR}/prometheus_metrics_payload.txt"
#     local timestamp="${KPI_RESULTS[timestamp]}"
    
#     log "[INFO] Generating Prometheus metric payload..."
    
#     # Start the payload file
#     cat > "$payload_file" <<EOF
# # HELP hpc_benchmark_sysbench_events Sysbench CPU events per second.
# # TYPE hpc_benchmark_sysbench_events gauge
# hpc_benchmark_sysbench_events{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[sysbench_cpu_events_per_sec]:-0} $timestamp

# # HELP hpc_benchmark_stream_triad_bw_mbps STREAM Triad Memory Bandwidth in MiB/s.
# # TYPE hpc_benchmark_stream_triad_bw_mbps gauge
# hpc_benchmark_stream_triad_bw_mbps{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[stream_triad_bw_mbps]:-0} $timestamp

# # HELP hpc_benchmark_fio_read_iops FIO Random Read IOPS.
# # TYPE hpc_benchmark_fio_read_iops gauge
# hpc_benchmark_fio_read_iops{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[fio_read_iops]:-0} $timestamp

# # HELP hpc_benchmark_ior_write_mbps IOR Parallel File System Write BW in MiB/s.
# # TYPE hpc_benchmark_ior_write_mbps gauge
# hpc_benchmark_ior_write_mbps{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[ior_parallel_write_mbps]:-0} $timestamp

# # HELP hpc_benchmark_ior_read_mbps IOR Parallel File System Read BW in MiB/s.
# # TYPE hpc_benchmark_ior_read_mbps gauge
# hpc_benchmark_ior_read_mbps{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[ior_parallel_read_mbps]:-0} $timestamp

# # HELP hpc_benchmark_hpl_gflops HPL Linpack Gflops.
# # TYPE hpc_benchmark_hpl_gflops gauge
# hpc_benchmark_hpl_gflops{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[hpl_linpack_gflops]:-0} $timestamp

# # HELP hpc_benchmark_osu_latency_min_us OSU Minimum MPI Latency in microseconds.
# # TYPE hpc_benchmark_osu_latency_min_us gauge
# hpc_benchmark_osu_latency_min_us{instance="${SYSTEM_LABEL}"} ${KPI_RESULTS[osu_latency_min_us]:-0} $timestamp
# EOF

#     log "[INFO] Pushing metrics to Pushgateway: $PUSH_URL"
    
#     # Push the payload using HTTP PUT (preferred for replacement)
#     # TEMPORARY FIX: Change -X PUT to -X POST
# if curl --data-binary "@$payload_file" -H "Content-Type: text/plain" -X POST "$PUSH_URL"; then
#     log "[OK] Metrics successfully pushed to Pushgateway."
# # ...
#     else
#         log "[FATAL] Failed to push metrics to Pushgateway. Check connectivity to $PUSH_URL."
#         return 1
#     fi
# }
cleanup_pushgateway_job() {
    log "[INFO] Cleaning old Pushgateway metrics for job: hpc_benchmarks"
    # Use the configured IP and Port instead of hardcoded localhost
    local CLEAN_URL="http://${PUSHGATEWAY_IP}:${PUSHGATEWAY_PORT}/metrics/job/hpc_benchmarks"
    
    # DELETE request to clear the specific job group
    curl -s -X DELETE "$CLEAN_URL" || log "[WARN] Could not delete old metrics (might be empty)."
}
safe_val() {
        [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]] && echo "$1" || echo "0"
    }

push_metrics_to_pushgateway() {
    install_curl || return 1

    local JOB_NAME="hpc_benchmarks"
    # Using the IP and Port defined in your global config
    local PUSH_URL="http://${PUSHGATEWAY_IP}:${PUSHGATEWAY_PORT}/metrics/job/${JOB_NAME}/instance/${SYSTEM_LABEL}"
    local payload_file="/tmp/metrics_payload.txt"

    log "[INFO] Generating Prometheus metric payload..."

    # Create the payload file
    # Note: We do NOT put {instance="..."} here because it is defined in the URL path.
    cat > "$payload_file" <<EOF
# TYPE hpc_benchmark_sysbench_events gauge
hpc_benchmark_sysbench_events $(safe_val "${KPI_RESULTS[sysbench_cpu_events_per_sec]}")
# TYPE hpc_benchmark_stream_triad_bw_mbps gauge
hpc_benchmark_stream_triad_bw_mbps $(safe_val "${KPI_RESULTS[stream_triad_bw_mbps]}")
# TYPE hpc_benchmark_fio_read_iops gauge
hpc_benchmark_fio_read_iops $(safe_val "${KPI_RESULTS[fio_read_iops]}")
# TYPE hpc_benchmark_hpl_gflops gauge
hpc_benchmark_hpl_gflops $(safe_val "${KPI_RESULTS[hpl_linpack_gflops]}")
EOF

    # CRITICAL: Prometheus parser requires a trailing newline to avoid 400 Bad Request (Unexpected EOF)
    echo "" >> "$payload_file"

    log "[INFO] Pushing payload to $PUSH_URL"
    
    # --data-binary is used to preserve the newlines in the file
    if curl -sS --fail --data-binary "@$payload_file" "$PUSH_URL"; then
        log "[OK] Metrics successfully pushed to Pushgateway"
    else
        log "[ERROR] Failed to push metrics. Check connectivity to ${PUSHGATEWAY_IP}"
        return 1
    fi
}


# ----------------------------------------------------
# Auto-detect local machine IP (robust & safe)
# ----------------------------------------------------
# get_local_ip() {
#     local ip

#     # Preferred: IP used for default route
#     ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
#     if [[ -n "$ip" ]]; then
#         echo "$ip"
#         return 0
#     fi

#     # Fallback: hostname
#     ip=$(hostname -I 2>/dev/null | awk '{print $1}')
#     if [[ -n "$ip" ]]; then
#         echo "$ip"
#         return 0
#     fi

#     # Last resort
#     echo "127.0.0.1"
# }


# ----------------------------------------------------
# Main Execution Logic (unchanged)
# ----------------------------------------------------

benchmark_tools=(
    "sysbench_cpu" "CPU: Sysbench (Basic CPU/Thread Performance)" OFF
    "stream_memory" "Memory: STREAM (Memory Bandwidth Test)" OFF
    "fio_disk_rw" "I/O: FIO (Random Disk Read/Write Test)" OFF
    "ior_parallel_io" "Parallel I/O: IOR (File System Scaling Test)" OFF
    "hpl_linpack" "HPC: HPL (High-Performance Linpack - Gflops)" OFF
    "osu_latency" "Network: OSU Latency (MPI Latency Check)" OFF
)

run_all_benchmarks() {
    for tool_key in "sysbench_cpu" "stream_memory" "fio_disk_rw" "ior_parallel_io" "hpl_linpack" "osu_latency"; do
        log ">>> Starting forced execution of $tool_key <<<"
        "run_${tool_key}"
        echo ""
    done
}

show_multi_select_menu() {
    install_dialog || return 1
    local menu_items=("${benchmark_tools[@]}" "run_all" "RUN ALL TESTS" OFF)
    local selection
    selection=$(dialog --checklist "Select benchmarks to run (Spacebar to select/deselect, Enter to confirm)" 20 80 15 "${menu_items[@]}" 2>&1 >/dev/tty)
    
    if [[ $? -ne 0 ]]; then log "User cancelled the selection. Exiting."; exit 0; fi
    local selected_keys=($selection)

    if [[ " ${selected_keys[*]} " =~ " run_all " ]]; then
        log "Run All option selected."
        run_all_benchmarks
    else
        for key in "${selected_keys[@]}"; do
            if [[ "$key" != "run_all" ]]; then
                log ">>> Starting selected benchmark: $key <<<"
                "run_${key}"
                echo ""
            fi
        done
    fi
}

# --- Script Entry Point ---
log "[SETUP] Running initial environment check for build tools..."
ensure_build_deps

log "[SETUP] Starting interactive multi-select menu."
show_multi_select_menu

# --- FINAL STEP: PUSH METRICS ---
log "Metrics collection finished. Pushing results to dashboard..."
push_metrics_to_pushgateway

log "Benchmark execution finished."