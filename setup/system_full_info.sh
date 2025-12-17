#!/bin/bash

echo "===================================================="
echo "           FULL SYSTEM INFORMATION REPORT"
echo "===================================================="

timestamp=$(date)
echo "Generated on: $timestamp"
echo ""

# ----------------------------------------------------
# 1. OS & Kernel
# ----------------------------------------------------
echo "=== 1. OS & Kernel Information ==="
uname -a
echo ""
cat /etc/os-release
echo ""
lsb_release -a 2>/dev/null

# ----------------------------------------------------
# 2. CPU Information
# ----------------------------------------------------
echo ""
echo "=== 2. CPU Information ==="
lscpu
echo ""
echo "CPU Topology (hwloc):"
lstopo-no-graphics 2>/dev/null || echo "hwloc not installed"

# ----------------------------------------------------
# 3. Memory Information
# ----------------------------------------------------
echo ""
echo "=== 3. Memory Information ==="
free -h
echo ""
cat /proc/meminfo

# ----------------------------------------------------
# 4. GPU Information
# ----------------------------------------------------
echo ""
echo "=== 4. GPU Information ==="
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi -q
else
    echo "No NVIDIA GPU detected"
fi

# ----------------------------------------------------
# 5. CUDA Information
# ----------------------------------------------------
echo ""
echo "=== 5. CUDA Information ==="
if command -v nvcc &> /dev/null; then
    nvcc --version
else
    echo "CUDA toolkit not installed"
fi

# ----------------------------------------------------
# 6. PCI Devices
# ----------------------------------------------------
echo ""
echo "=== 6. PCI Devices ==="
lspci -vvv

# ----------------------------------------------------
# 7. Storage Information
# ----------------------------------------------------
echo ""
echo "=== 7. Storage Information ==="
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE
echo ""
df -hT
echo ""
echo "NVMe Devices:"
nvme list 2>/dev/null || echo "nvme-cli not installed"

# ----------------------------------------------------
# 8. Disk Health (SMART)
# ----------------------------------------------------
echo ""
echo "=== 8. Disk Health (SMART) ==="
sudo smartctl --scan | awk '{print $1}' | while read disk; do
    echo ""
    echo "SMART info for $disk:"
    sudo smartctl -H $disk
done

# ----------------------------------------------------
# 9. Network Information
# ----------------------------------------------------
echo ""
echo "=== 9. Network Interfaces ==="
ip -br addr
echo ""
echo "Interface Details:"
ip addr show
echo ""
echo "Network Speeds:"
for iface in $(ls /sys/class/net | grep -v lo); do
    echo "---- $iface ----"
    ethtool $iface 2>/dev/null | grep -E "Speed|Duplex|Auto-negotiation"
done

# ----------------------------------------------------
# 10. RDMA / Infiniband
# ----------------------------------------------------
echo ""
echo "=== 10. RDMA / Infiniband Information ==="
if command -v ibv_devinfo &> /dev/null; then
    ibv_devinfo
else
    echo "RDMA/IB tools not installed"
fi

# ----------------------------------------------------
# 11. MPI Information
# ----------------------------------------------------
echo ""
echo "=== 11. MPI Information ==="
if command -v mpirun &> /dev/null; then
    mpirun --version
else
    echo "MPI not installed"
fi

# ----------------------------------------------------
# 12. Installed Benchmark Tools
# ----------------------------------------------------
echo ""
echo "=== 12. Installed Benchmark Tools ==="
tools=(fio iperf3 ior osu-micro-benchmarks stream hpl hpcg)
for tool in "${tools[@]}"; do
    if command -v $tool &> /dev/null; then
        echo "[OK] $tool installed"
    else
        echo "[MISSING] $tool"
    fi
done

# ----------------------------------------------------
# 13. Python Environment
# ----------------------------------------------------
echo ""
echo "=== 13. Python Environment ==="
python3 --version
pip3 --version
echo ""
pip3 list

# ----------------------------------------------------
# 14. System Limits
# ----------------------------------------------------
echo ""
echo "=== 14. System Limits (ulimit) ==="
ulimit -a

# ----------------------------------------------------
# 15. Running Services
# ----------------------------------------------------
echo ""
echo "=== 15. Running Services ==="
systemctl list-units --type=service --state=running

# ----------------------------------------------------
# 16. Environment Variables
# ----------------------------------------------------
echo ""
echo "=== 16. Environment Variables ==="
printenv

# ----------------------------------------------------
# 17. Kernel Modules
# ----------------------------------------------------
echo ""
echo "=== 17. Loaded Kernel Modules ==="
lsmod

# ----------------------------------------------------
# 18. Security Settings
# ----------------------------------------------------
echo ""
echo "=== 18. Security Settings ==="
getenforce 2>/dev/null || echo "SELinux not installed"
aa-status 2>/dev/null || echo "AppArmor not installed"

# ----------------------------------------------------
# 19. System Logs
# ----------------------------------------------------
echo ""
echo "=== 19. System Logs (last 100 lines) ==="
journalctl -n 100 --no-pager

# ----------------------------------------------------
# 20. Hardware Sensors
# ----------------------------------------------------
echo ""
echo "=== 20. Hardware Sensors ==="
sensors 2>/dev/null || echo "lm-sensors not installed"

# ----------------------------------------------------
# 21. CPU Frequency Scaling
# ----------------------------------------------------
echo ""
echo "=== 21. CPU Frequency Scaling ==="
cpupower frequency-info 2>/dev/null || echo "cpupower not installed"

# ----------------------------------------------------
# 22. Hugepages
# ----------------------------------------------------
echo ""
echo "=== 22. Hugepages ==="
grep -i huge /proc/meminfo

# ----------------------------------------------------
# 23. Filesystem Mount Options
# ----------------------------------------------------
echo ""
echo "=== 23. Filesystem Mount Options ==="
mount | column -t

# ----------------------------------------------------
# 24. Boot Performance
# ----------------------------------------------------
echo ""
echo "=== 24. System Boot Performance ==="
systemd-analyze 2>/dev/null
systemd-analyze blame 2>/dev/null

# ----------------------------------------------------
# 25. Routing & DNS
# ----------------------------------------------------
echo ""
echo "=== 25. Routing Table ==="
ip route
echo ""
echo "=== 26. DNS Configuration ==="
cat /etc/resolv.conf

echo ""
echo "===================================================="
echo "        SYSTEM INFORMATION REPORT COMPLETE"
echo "===================================================="
