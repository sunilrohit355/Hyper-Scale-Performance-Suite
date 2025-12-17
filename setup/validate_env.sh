import os
import shutil
import subprocess

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TOOLS_ROOT = os.path.join(PROJECT_ROOT, "tools")

TOOLS = {
    "stream": "stream",
    "fio": "fio",
    "iperf3": "iperf3",
    "ior": "ior",
    "mdtest": "mdtest",
    "osu_bw": "osu_bw",
    "osu_latency": "osu_latency",
    "hpl": "xhpl",
    "hpcg": "xhpcg",
    "hpcc": "hpcc",
    "imb": "IMB-MPI1",
    "NPmpi": "NPmpi",
    "lat_mem_rd": "lat_mem_rd",
    "graph500_mpi_simple": "graph500_mpi_simple"}


def check_binary(name):
    path = shutil.which(name)
    if path:
        print(f"[OK] {name} found at {path}")
        return True
    else:
        print(f"[MISSING] {name} not found in PATH")
        return False

def check_mpi():
    try:
        out = subprocess.check_output("mpirun --version", shell=True).decode()
        print("[OK] MPI detected:", out.splitlines()[0])
    except Exception:
        print("[ERROR] MPI not installed or not in PATH")

def check_cuda():
    try:
        subprocess.check_output("nvidia-smi", shell=True, stderr=subprocess.DEVNULL)
        print("[OK] NVIDIA GPU detected")
    except Exception:
        print("[INFO] No NVIDIA GPU detected")

def check_rdma():
    try:
        subprocess.check_output("ibv_devinfo", shell=True, stderr=subprocess.DEVNULL)
        print("[OK] RDMA/Infiniband detected")
    except Exception:
        print("[INFO] RDMA not detected")

def main():
    print("==============================================")
    print("        HPC Environment Validation")
    print("==============================================")
    print("Project root:", PROJECT_ROOT)
    print("Tools root:  ", TOOLS_ROOT)
    print()

    check_mpi()
    check_cuda()
    check_rdma()

    print("\n=== Checking Benchmark Tools in PATH ===")
    for logical, binary in TOOLS.items():
        check_binary(binary)

    print("\nValidation complete.")

if __name__ == "__main__":
    main()
