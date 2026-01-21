#!/bin/bash
# Allied Vision Alvium CSI-2 Driver Build Script
# This script is a wrapper around the Makefile for convenience

set -e  # Exit on error

echo "Allied Vision Alvium CSI-2 Driver Build System"
echo "=============================================="
echo ""

# Check if setup is needed
if [ ! -f "Linux_for_Tegra/kernel/linux-headers-5.15.148-tegra-linux_x86_64/3rdparty/canonical/linux-jammy/kernel-source/Makefile" ]; then
    echo "Kernel headers not found. Running setup..."
    make setup
else
    echo "Kernel headers found. Skipping setup."
fi

echo ""
echo "Building modules..."
make all

echo ""
echo "Build complete! Run './install.sh' to install the modules."
