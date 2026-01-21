#!/bin/bash
# Allied Vision Alvium CSI-2 Driver Installation Script
# This script is a wrapper around the Makefile for convenience

set -e  # Exit on error

echo "Allied Vision Alvium CSI-2 Driver Installation"
echo "=============================================="
echo ""

# Set installation path
export INSTALL_MOD_PATH=/

# Run make install
make install

echo ""
echo "Installation script completed!"
