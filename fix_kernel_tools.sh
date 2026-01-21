#!/bin/bash
# Fix kernel header tools for native ARM64 compilation
# Consolidated script combining effective approaches from v1, v2, and v3

KERNEL_SRC=$PWD/Linux_for_Tegra/kernel/linux-headers-5.15.148-tegra-linux_x86_64/3rdparty/canonical/linux-jammy/kernel-source/

echo "Rebuilding kernel tools for ARM64..."
echo ""

# Step 1: Comprehensive build of all scripts 
echo "[1/3] Building all kernel scripts..."
make -C "${KERNEL_SRC}" HOSTCC=gcc HOSTLD=ld scripts

# Step 2: Targeted rebuild of critical tools
echo ""
echo "[2/3] Rebuilding critical tools individually..."
cd "${KERNEL_SRC}"

echo "  - Building scripts/basic..."
make HOSTCC=gcc HOSTLD=ld scripts/basic

echo "  - Building scripts/mod..."
make HOSTCC=gcc HOSTLD=ld scripts/mod

echo "  - Building additional tools..."
make HOSTCC=gcc HOSTLD=ld scripts/genksyms/genksyms 2>/dev/null || true
make HOSTCC=gcc HOSTLD=ld scripts/kallsyms 2>/dev/null || true
make HOSTCC=gcc HOSTLD=ld scripts/recordmcount 2>/dev/null || true

# Step 3: Verification 
echo ""
echo "[3/3] Verification:"
if [ -f scripts/basic/fixdep ]; then
    file scripts/basic/fixdep | grep -q "ARM aarch64" && echo "  ✓ fixdep: ARM64" || echo "  ✗ fixdep: NOT ARM64"
else
    echo "  ✗ fixdep: NOT FOUND"
fi

if [ -f scripts/mod/modpost ]; then
    file scripts/mod/modpost | grep -q "ARM aarch64" && echo "  ✓ modpost: ARM64" || echo "  ✗ modpost: NOT ARM64"
else
    echo "  ✗ modpost: NOT FOUND"
fi

echo ""
echo "Done! Kernel tools have been rebuilt for ARM64."
