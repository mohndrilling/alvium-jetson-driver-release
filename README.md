# Allied Vision Alvium CSI driver for Jetpack 6.2

## Compatibility

### SoMs + Carrier Boards 
- Jetson AGX Orin DevKit
- Jetson Orin Nano DevKit
- Jetson Orin NX + forecr DSBOARD-ORNX carrier
### Cameras
- All Alvium C cameras with Firmware 14 or newer

## Installation 
1. Download the debian package from the releases section to our target board
2. Install the packages by running:
    ```shell
    sudo apt install ./avt-nvidia-csi2-driver_<version>.deb
    ```
3. Configure the device tree
    1. Start the jetson-io tool
        ```shell
        sudo /opt/nvidia/jetson-io/jetson-io.py
        ```
    2. Select the CSI connector configuration
        - For AGX Orin: "Jetson AGX CSI Connector"
        - For Orin Nano / NX: "Jetson 24pin CSI Connector"
    3. Select "Configure for compatible hardware"
    4. Select the appropriate "* Alvium C Dual *" configuration
    5. Select "Save pin changes" 
    6. Select "Save and reboot to reconfigure pins"
4. After the board has rebooted the camera can be accessed with V4L2 and Vimba X

## Building
1. Clone this repository including all submodules
## Build Everything (One Command)
```bash
./build.sh
```
This automatically:
- Pulls the git submodules
- Downloads L4T r36.4.3 if needed
- Extracts kernel headers
- Builds all modules

### Install

```bash
./install.sh
```

### Or Use Makefile Directly

```bash
make setup    # First time only - downloads and prepares everything
make all      # Build modules
make install  # Install modules
make help     # See all available targets
```

## Post-Installation Configuration

```bash
sudo depmod -a
sudo mkdir -p /boot/dtb/overlays
sudo cp /usr/lib/boot/*.dtbo /boot/dtb/overlays/
```
Then configure device tree and reboot:

```bash
sudo /opt/nvidia/jetson-io/jetson-io.py
```


After reboot, verify camera:

```bash
v4l2-ctl --list-devices
dmesg | grep -i avt
```


## Makefile Targets

| Target | Description |
|--------|-------------|
| `make help` | Show all available targets |
| `make setup` | Download and extract L4T, prepare headers |
| `make all` | Build all modules (default) |
| `make install` | Install all modules |
| `make clean` | Clean build artifacts |
| `make distclean` | Remove downloaded L4T files |

## Troubleshooting

### "Exec format error" when building

If you see `scripts/basic/fixdep: Exec format error`:

```bash
make fix-kernel-tools
```
This rebuilds kernel tools for ARM64.

### Clean rebuild

```bash
make clean      # Clean build artifacts
make distclean  # Remove everything including L4T
make setup      # Start fresh
```
## Known limitations

- When using external triggers the NVIDIA v4l2 control  ```override_capture_timeout_ms``` has to be set a suitable timeout value or -1 for a infinite timeout. Otherwise incomplete buffers with the error flag set might be returned due to a timeout while waiting for the image. 
