#!/bin/bash

# Dynamically detect project root (no hardcoding)
export HPC_BENCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HPC_TOOLS_ROOT="$HPC_BENCH_ROOT/tools"

# Add ALL subdirectories of tools/ to PATH automatically
if [ -d "$HPC_TOOLS_ROOT" ]; then
  while IFS= read -r d; do
      export PATH="$d:$PATH"
  done < <(find "$HPC_TOOLS_ROOT" -type d)
fi

# Auto-detect MPI
if command -v mpirun &>/dev/null; then
    export MPI_HOME="$(dirname "$(dirname "$(command -v mpirun)")")"
    export PATH="$MPI_HOME/bin:$PATH"
    export LD_LIBRARY_PATH="$MPI_HOME/lib:$LD_LIBRARY_PATH"
fi

# Auto-detect CUDA
if command -v nvidia-smi &>/dev/null && [ -d "/usr/local/cuda" ]; then
    export CUDA_HOME="/usr/local/cuda"
    export PATH="$CUDA_HOME/bin:$PATH"
    export LD_LIBRARY_PATH="$CUDA_HOME/lib64:$LD_LIBRARY_PATH"
fi

# Auto-detect OpenBLAS/LAPACK common location
if ldconfig -p 2>/dev/null | grep -qi openblas; then
    export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
fi

echo "[env_vars] HPC-Bench environment loaded."
echo "Project root: $HPC_BENCH_ROOT"
echo "Tools root:   $HPC_TOOLS_ROOT"
