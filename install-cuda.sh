#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "========================================================"
echo " Starting Native Ubuntu 26.04 CUDA Installation"
echo "========================================================"

# 1. Architecture Check
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo "ERROR: This script only supports x86_64 architecture."
    exit 1
fi

# 2. Update System Repositories
echo "Updating native package indexes..."
sudo apt-get update

# 3. Install Baseline Header Tools and Development Dependencies
echo "Installing kernel headers and prerequisite packages..."
sudo apt-get install -y build-essential dkms freeglut3-dev libxmu-dev libxi-dev linux-headers-$(uname -r)

# 4. Install the Recommended NVIDIA Proprietary Driver
echo "Detecting and installing the optimized NVIDIA driver..."
sudo ubuntu-drivers install

# 5. Install the Native CUDA Toolkit distributed by Ubuntu
echo "Installing the system-integrated NVIDIA CUDA Toolkit..."
sudo apt-get install -y nvidia-cuda-toolkit

echo "========================================================"
echo " Setup Completed Successfully! "
echo " Please REBOOT your system using: sudo reboot"
echo " After rebooting, run: nvidia-smi"
echo "========================================================"
