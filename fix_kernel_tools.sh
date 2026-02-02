#!/bin/bash
# Fix kernel header tools for native ARM64 compilation
# Builds only the essential tools needed for module compilation (fixdep, modpost)
# Note: sorttable is skipped as it requires headers not included in kernel headers package

KERNEL_SRC=$PWD/Linux_for_Tegra/kernel/linux-headers-5.15.148-tegra-linux_x86_64/3rdparty/canonical/linux-jammy/kernel-source/

echo "Rebuilding kernel tools for ARM64..."
echo ""

cd "${KERNEL_SRC}"

# Step 1: Build fixdep (required for dependency tracking)
echo "[1/3] Building scripts/basic/fixdep..."
rm -f scripts/basic/fixdep
gcc -Wp,-MD,scripts/basic/.fixdep.d -Wall -Wmissing-prototypes -Wstrict-prototypes \
    -O2 -fomit-frame-pointer -std=gnu89 -o scripts/basic/fixdep scripts/basic/fixdep.c

if [ $? -eq 0 ]; then
    echo "  ✓ fixdep compiled successfully"
else
    echo "  ✗ fixdep compilation failed"
    exit 1
fi

# Step 2: Build modpost (required for module symbol processing)
echo ""
echo "[2/3] Building scripts/mod/modpost..."
rm -f scripts/mod/modpost scripts/mod/mk_elfconfig

# First build mk_elfconfig
gcc -Wp,-MD,scripts/mod/.mk_elfconfig.d -Wall -Wmissing-prototypes -Wstrict-prototypes \
    -O2 -fomit-frame-pointer -std=gnu89 -o scripts/mod/mk_elfconfig scripts/mod/mk_elfconfig.c

# Generate elfconfig.h if needed
if [ ! -f scripts/mod/elfconfig.h ] || [ scripts/mod/mk_elfconfig -nt scripts/mod/elfconfig.h ]; then
    ./scripts/mod/mk_elfconfig > scripts/mod/elfconfig.h 2>/dev/null || true
fi

# Build modpost
gcc -Wp,-MD,scripts/mod/.modpost.d -Wall -Wmissing-prototypes -Wstrict-prototypes \
    -O2 -fomit-frame-pointer -std=gnu89 \
    -I scripts/mod \
    -o scripts/mod/modpost \
    scripts/mod/modpost.c scripts/mod/file2alias.c scripts/mod/sumversion.c

if [ $? -eq 0 ]; then
    echo "  ✓ modpost compiled successfully"
else
    echo "  ✗ modpost compilation failed"
    exit 1
fi

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
echo "Done! Essential kernel tools have been rebuilt for ARM64."
