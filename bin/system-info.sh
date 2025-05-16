#!/bin/bash

# OS and kernel
OS=$(lsb_release -d | cut -f2)
KERNEL=$(uname -r)
ARCH=$(uname -m)

# CPU info
CPU_MODEL=$(lscpu | grep "Model name" | sed 's/Model name:[ \t]*//')
VENDOR=$(cat /sys/devices/virtual/dmi/id/sys_vendor)
MODEL=$(cat /sys/devices/virtual/dmi/id/product_name)

# GPU info
GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)

# RAM
RAM=$(free -h --giga | awk '/^Mem:/ {print $2 "GB"}')

# Output
echo "Operating System: $OS"
echo "          Kernel: Linux $KERNEL"
echo "    Architecture: $ARCH"
echo " Hardware Vendor: $VENDOR"
echo "  Hardware Model: $MODEL"
echo "  	     CPU: $CPU_MODEL"
echo "  	     GPU: $GPU"
echo "  	     RAM: $RAM"
