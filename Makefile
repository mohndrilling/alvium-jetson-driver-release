# Allied Vision Alvium CSI-2 Driver Build System
# For NVIDIA Jetson with L4T r36.4.3

MAKEFILE_DIR := $(abspath $(shell dirname $(lastword $(MAKEFILE_LIST))))
NVIDIA_CONFTEST ?= $(MAKEFILE_DIR)/out/nvidia-conftest

# L4T Version Configuration
L4T_VERSION := 36.4.3
L4T_RELEASE := r36_release_v4.3
L4T_BASE_URL := https://developer.nvidia.com/downloads/embedded/l4t/$(L4T_RELEASE)/release

# File names
L4T_DRIVER_PACKAGE := Jetson_Linux_r$(L4T_VERSION)_aarch64.tbz2
L4T_ROOTFS_PACKAGE := Tegra_Linux_Sample-Root-Filesystem_r$(L4T_VERSION)_aarch64.tbz2

# Paths
L4T_DIR := $(MAKEFILE_DIR)/Linux_for_Tegra
KERNEL_HEADERS_DIR := $(L4T_DIR)/kernel/linux-headers-5.15.148-tegra-linux_x86_64
KERNEL_SRC := $(KERNEL_HEADERS_DIR)/3rdparty/canonical/linux-jammy/kernel-source

# Build configuration (exported to sub-makes)
export ARCH := arm64
export CROSS_COMPILE := /usr/bin/aarch64-linux-gnu-
export KERNEL_SRC
export INSTALL_MOD_PATH ?= /

# Detect if we're running on ARM64
HOST_ARCH := $(shell uname -m)
ifeq ($(HOST_ARCH),aarch64)
NEED_KERNEL_TOOLS_FIX := 1
endif

.PHONY: all install clean help
.PHONY: download-l4t extract-l4t setup prepare-kernel-headers fix-kernel-tools
.PHONY: nvidia-oot-conftest nvidia-hwpm-modules nvidia-oot-modules nvidia-nvgpu-modules
.PHONY: alvium-driver-modules nvidia-modules-install alvium-driver-modules-install

# Default target
all: check-setup nvidia-nvgpu-modules nvidia-oot-modules alvium-driver-modules

# Help target
help:
	@echo "Allied Vision Alvium CSI-2 Driver Build System"
	@echo ""
	@echo "Main targets:"
	@echo "  make setup          - Download and extract L4T if needed"
	@echo "  make all            - Build all modules (default)"
	@echo "  make install        - Install all modules (requires sudo)"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make distclean      - Remove downloaded and extracted L4T files"
	@echo ""
	@echo "Individual targets:"
	@echo "  make download-l4t   - Download L4T packages"
	@echo "  make extract-l4t    - Extract L4T packages"
	@echo "  make fix-kernel-tools - Fix kernel tools for ARM64"
	@echo ""
	@echo "Configuration:"
	@echo "  L4T Version: $(L4T_VERSION)"
	@echo "  Architecture: $(ARCH)"
	@echo "  Cross compiler: $(CROSS_COMPILE)"
	@echo "  Kernel source: $(KERNEL_SRC)"
	@echo "  Host architecture: $(HOST_ARCH)"

git-submodule-pull:
	git submodule update --init --recursive
# Check if setup is complete
check-setup:
	@if [ ! -f "$(KERNEL_SRC)/Makefile" ]; then \
		echo "ERROR: Kernel headers not found. Run 'make setup' first."; \
		exit 1; \
	fi
ifdef NEED_KERNEL_TOOLS_FIX
	@if [ ! -f "$(KERNEL_SRC)/scripts/basic/fixdep" ]; then \
		echo "ERROR: Kernel tools not built. Run 'make fix-kernel-tools' first."; \
		exit 1; \
	fi
	@if ! file "$(KERNEL_SRC)/scripts/basic/fixdep" | grep -q "ARM aarch64"; then \
		echo "ERROR: Kernel tools are not ARM64. Run 'make fix-kernel-tools' first."; \
		exit 1; \
	fi
endif

# Complete setup: download and extract L4T
setup: git-submodule-pull extract-l4t prepare-kernel-headers
ifdef NEED_KERNEL_TOOLS_FIX
	@$(MAKE) fix-kernel-tools
endif
	@echo ""
	@echo "Setup complete! You can now run 'make all' to build the modules."

# Download L4T packages
download-l4t: $(L4T_DRIVER_PACKAGE)

$(L4T_DRIVER_PACKAGE):
	@echo "Downloading L4T driver package..."
	wget $(L4T_BASE_URL)/$(L4T_DRIVER_PACKAGE)
	@echo "Download complete: $(L4T_DRIVER_PACKAGE)"

# Extract L4T driver package and apply binaries
extract-l4t: $(L4T_DIR)/nv_tegra_release

$(L4T_DIR)/nv_tegra_release: $(L4T_DRIVER_PACKAGE)
	@echo "Extracting L4T driver package..."
	tar -xjf $(L4T_DRIVER_PACKAGE)
	@echo "L4T driver package extracted to $(L4T_DIR)"
	@echo ""
	@echo "Note: You may need to download rootfs and apply binaries manually:"
	@echo "  wget $(L4T_BASE_URL)/$(L4T_ROOTFS_PACKAGE)"
	@echo "  sudo tar -xjf $(L4T_ROOTFS_PACKAGE) -C $(L4T_DIR)/rootfs/"
	@echo "  sudo ./$(L4T_DIR)/apply_binaries.sh"

# Prepare kernel headers
prepare-kernel-headers: $(KERNEL_SRC)/Makefile

$(KERNEL_SRC)/Makefile: $(L4T_DIR)/nv_tegra_release
	@echo "Extracting kernel headers..."
	@if [ -f "$(L4T_DIR)/kernel/kernel_headers.tbz2" ]; then \
		cd $(L4T_DIR)/kernel && tar -xjf kernel_headers.tbz2; \
		echo "Kernel headers extracted successfully."; \
	else \
		echo "ERROR: kernel_headers.tbz2 not found in $(L4T_DIR)/kernel/"; \
		echo "The L4T package may be incomplete."; \
		exit 1; \
	fi

# Fix kernel tools for ARM64 native compilation
fix-kernel-tools: $(KERNEL_SRC)/Makefile
	@echo "Rebuilding kernel tools for ARM64..."
	bash fix_kernel_tools.sh

# NVIDIA out-of-tree conftest
nvidia-oot-conftest: check-setup
	mkdir -p $(NVIDIA_CONFTEST)/nvidia
	cp -av $(MAKEFILE_DIR)/nvidia-oot/scripts/conftest/* $(NVIDIA_CONFTEST)/nvidia
	$(MAKE) -j $(shell nproc) ARCH=arm64 \
		src=$(NVIDIA_CONFTEST)/nvidia obj=$(NVIDIA_CONFTEST)/nvidia \
		CC=$(CROSS_COMPILE)gcc LD=$(CROSS_COMPILE)ld \
		NV_KERNEL_SOURCES=$(KERNEL_SRC) \
		NV_KERNEL_OUTPUT=$(KERNEL_SRC) \
		-f $(NVIDIA_CONFTEST)/nvidia/Makefile

# NVIDIA HWPM modules
nvidia-hwpm-modules: nvidia-oot-conftest
	$(MAKE) \
		CONFIG_TEGRA_OOT_MODULE=m \
		srctree.hwpm=$(MAKEFILE_DIR)/nvidia-hwpm \
		srctree.nvconftest=$(NVIDIA_CONFTEST) \
		M=$(MAKEFILE_DIR)/nvidia-hwpm/drivers/tegra/hwpm \
		-C $(KERNEL_SRC) \
		modules

nvidia-hwpm-modules-install: nvidia-hwpm-modules
	$(MAKE) \
		CONFIG_TEGRA_OOT_MODULE=m \
		srctree.hwpm=$(MAKEFILE_DIR)/nvidia-hwpm \
		srctree.nvconftest=$(NVIDIA_CONFTEST) \
		M=$(MAKEFILE_DIR)/nvidia-hwpm/drivers/tegra/hwpm \
		-C $(KERNEL_SRC) \
		modules_install

# NVIDIA out-of-tree modules
nvidia-oot-modules: nvidia-oot-conftest nvidia-hwpm-modules
	rm -rf $(MAKEFILE_DIR)/nvidia-oot/drivers/net/ethernet/nvidia/nvethernet/nvethernetrm
	cp -av $(MAKEFILE_DIR)/nvidia-nvethernetrm $(MAKEFILE_DIR)/nvidia-oot/drivers/net/ethernet/nvidia/nvethernet/nvethernetrm
	$(MAKE) \
		CONFIG_TEGRA_OOT_MODULE=m \
		srctree.nvidia-oot=$(MAKEFILE_DIR)/nvidia-oot \
		srctree.nvconftest=$(NVIDIA_CONFTEST) \
		srctree.hwpm=$(MAKEFILE_DIR)/nvidia-hwpm \
		KBUILD_EXTRA_SYMBOLS=$(MAKEFILE_DIR)/nvidia-hwpm/drivers/tegra/hwpm/Module.symvers \
		M=$(MAKEFILE_DIR)/nvidia-oot \
		-C $(KERNEL_SRC) \
		modules

nvidia-oot-modules-install: nvidia-oot-modules
	$(MAKE) \
		CONFIG_TEGRA_OOT_MODULE=m \
		srctree.nvidia-oot=$(MAKEFILE_DIR)/nvidia-oot \
		srctree.nvconftest=$(NVIDIA_CONFTEST) \
		srctree.hwpm=$(MAKEFILE_DIR)/nvidia-hwpm \
		KBUILD_EXTRA_SYMBOLS=$(MAKEFILE_DIR)/nvidia-hwpm/drivers/tegra/hwpm/Module.symvers \
		M=$(MAKEFILE_DIR)/nvidia-oot \
		-C $(KERNEL_SRC) \
		modules_install

# NVIDIA NVGPU modules
nvidia-nvgpu-modules: nvidia-oot-modules nvidia-oot-conftest
	$(MAKE) \
		CONFIG_TEGRA_OOT_MODULE=m \
		KBUILD_EXTRA_SYMBOLS=$(MAKEFILE_DIR)/nvidia-oot/Module.symvers \
		srctree.nvidia-oot=$(MAKEFILE_DIR)/nvidia-oot \
		srctree.nvidia=$(MAKEFILE_DIR)/nvidia-oot \
		srctree.nvconftest=$(NVIDIA_CONFTEST) \
		M=$(MAKEFILE_DIR)/nvidia-nvgpu/drivers/gpu/nvgpu \
		-C $(KERNEL_SRC) \
		modules

nvidia-nvgpu-modules-install: nvidia-nvgpu-modules
	$(MAKE) \
		CONFIG_TEGRA_OOT_MODULE=m \
		KBUILD_EXTRA_SYMBOLS=$(MAKEFILE_DIR)/nvidia-oot/Module.symvers \
		srctree.nvidia-oot=$(MAKEFILE_DIR)/nvidia-oot \
		srctree.nvidia=$(MAKEFILE_DIR)/nvidia-oot \
		srctree.nvconftest=$(NVIDIA_CONFTEST) \
		M=$(MAKEFILE_DIR)/nvidia-nvgpu/drivers/gpu/nvgpu \
		-C $(KERNEL_SRC) \
		modules_install

# Alvium driver modules
alvium-driver-modules: nvidia-oot-modules
	$(MAKE) \
		KBUILD_EXTRA_SYMBOLS=$(MAKEFILE_DIR)/nvidia-oot/Module.symvers \
		CONFIG_TEGRA_OOT_MODULE=y \
		srctree.nvidia-oot=$(MAKEFILE_DIR)/nvidia-oot \
		srctree.alvium-csi2-driver=$(MAKEFILE_DIR)/alvium-csi2-driver \
		M=$(MAKEFILE_DIR)/alvium-csi2-driver \
		-C $(KERNEL_SRC)

alvium-driver-modules-install: alvium-driver-modules
	$(MAKE) \
		KBUILD_EXTRA_SYMBOLS=$(MAKEFILE_DIR)/nvidia-oot/Module.symvers \
		CONFIG_TEGRA_OOT_MODULE=y \
		srctree.nvidia-oot=$(MAKEFILE_DIR)/nvidia-oot \
		KERNEL_SRC=$(KERNEL_SRC) \
		-C $(MAKEFILE_DIR)/alvium-csi2-driver install

# Install all modules
nvidia-modules-install: nvidia-nvgpu-modules-install nvidia-oot-modules-install nvidia-hwpm-modules-install

install: nvidia-modules-install alvium-driver-modules-install
	@echo ""
	@echo "Installation complete!"
	@echo ""
	@echo "Modules installed to: $(INSTALL_MOD_PATH)/lib/modules/5.15.148-tegra/updates/"
	@echo "Device tree overlays installed to: $(INSTALL_MOD_PATH)/boot/"
	@echo ""
	@echo "If INSTALL_MOD_PATH was set to /usr/lib, you need to copy files to system locations:"
	@echo "  sudo cp $(INSTALL_MOD_PATH)/lib/modules/5.15.148-tegra/updates/*.ko /lib/modules/5.15.148-tegra/updates/"
	@echo "  sudo depmod -a"
	@echo "  sudo mkdir -p /boot/dtb/overlays"
	@echo "  sudo cp $(INSTALL_MOD_PATH)/boot/*.dtbo /boot/dtb/overlays/"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Configure device tree using: sudo /opt/nvidia/jetson-io/jetson-io.py"
	@echo "  2. Reboot the system"
	@echo "  3. Verify camera detection: v4l2-ctl --list-devices"

# Clean build artifacts
clean:
	rm -rf out/
	@if [ -f "$(KERNEL_SRC)/Makefile" ]; then \
		$(MAKE) \
			srctree.nvidia-oot=$(MAKEFILE_DIR)/nvidia-oot \
			srctree.nvconftest=$(NVIDIA_CONFTEST) \
			srctree.hwpm=$(MAKEFILE_DIR)/nvidia-hwpm \
			M=$(MAKEFILE_DIR)/nvidia-oot -C $(KERNEL_SRC) clean; \
	fi

# Deep clean: remove downloaded and extracted L4T
distclean: clean
	rm -rf $(L4T_DIR)
	rm -f $(L4T_DRIVER_PACKAGE) $(L4T_ROOTFS_PACKAGE)
	@echo "Removed all downloaded and extracted L4T files."
