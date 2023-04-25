# Jetson Orin Baseboard BSP

Copyright (c) 2023 [Antmicro](https://www.antmicro.com)


This repository contains BSP sources for Antmicro’s [open hardware Jetson Orin Baseboard rev. 1.1](https://github.com/antmicro/jetson-orin-baseboard), based on NVIDIA Jetson Linux 35.2.1 and Linux kernel 5.10 from the OE4T (OpenEmbedded for Tegra) project. It provides support for PCI-e x4 and x1 on two M.2 slots, one USB3.2 Type-C host and one device port, 4x OV5640 cameras on two Antmicro OV5640 Dual Camera boards, an I2C multiplexer and a GPIO expander, as well as user buttons and LEDs.
## Preparing the workspace directory
In this example, we will create a directory called `$WORK` in which all files will be downloaded, built and stored. 

```
export WORK=/home/foobar/l4t_job
mkdir -p $WORK
```
## Building the project
### Obtain the software

Download the required software: Jetson Linux BSP, rootfs and AArch64 gcc 9.3 toolchain:
```bash
mkdir -p $WORK/download
cd $WORK/download
wget --content-disposition 'https://developer.nvidia.com/downloads/jetson-linux-r3521-aarch64tbz2'
wget --content-disposition 'https://developer.nvidia.com/downloads/linux-sample-root-filesystem-r3521aarch64tbz2'
wget --content-disposition 'https://developer.nvidia.com/embedded/jetson-linux/bootlin-toolchain-gcc-93'
```
Unpack it:
```bash
cd $WORK
# note - sudo below is important, BSP is full of root-owned files
sudo tar -xvpf download/Jetson_Linux_R35.2.1_aarch64.tbz2
# ^^ unpacking the archive creates $WORK/Linux_for_Tegra directory
sudo tar -xvpf download/Tegra_Linux_Sample-Root-Filesystem_R35.2.1_aarch64.tbz2 -C ./Linux_for_Tegra/rootfs/
mkdir toolchain
tar -xvpf download/aarch64--glibc--stable-final.tar.gz -C ./toolchain
```
Clone the umbrella BSP git repository and update the submodules:
```bash
cd $WORK
git clone git@github.com:antmicro/jetson-orin-baseboard-bsp.git bsp
cd $WORK/bsp
git submodule update --init
```
### Install flash tool dependencies

Execute the commands below. Please note that it’s intended to be used with a Debian-like system. Other systems may require some changes in the script.
```bash
cd $WORK/Linux_for_Tegra
sudo ./tools/l4t_flash_prerequisites.sh
```
### Preload rootfs with NVIDIA utils

Execute following command:
```bash
cd $WORK/Linux_for_Tegra
sudo ./apply_binaries.sh
```

### Build the kernel

Set `env.vars` to point KBuild system to the location of the AArch64 toolchain:
```bash
export CROSS_COMPILE_AARCH64_PATH=$WORK/toolchain
export CROSS_COMPILE_AARCH64=$CROSS_COMPILE_AARCH64_PATH/bin/aarch64-buildroot-linux-gnu-
```
Build the kernel:
```bash
cd $WORK/bsp
./build_kernel.sh
```
The output binary files will be located out-of-tree in the `$WORK/bsp/out` directory:
```bash
# modules
ls -l $WORK/bsp/out/modules_install
# kernel image
ls -l $WORK/bsp/out/arch/arm64/boot/Image
# DTB files
ls -l $WORK/bsp/out/arch/arm64/boot/dts/*.dtb
```
### Patch the L4T BSP

Install the kernel compiled in the previous step, DTB, kernel modules, and board configuration for flash.sh and MB2 (BCT):
```bash
cd $WORK/bsp
# sudo is important here!
sudo ./update_bsp.sh $WORK/Linux_for_Tegra
```
## Flashing the board
### Debug UART
Make sure that the Debug USB port is connected to your host PC and the FTDI chip is enumerated:
```bash
lsusb -d 0403:
# Bus 001 Device 118: ID 0403:6015 Future Technology Devices International, Ltd Bridge(I2C/SPI/UART/FIFO)
sudo dmesg | grep FTDI
# [1740634.745814] usb 1-4: FTDI USB Serial Device converter now attached to ttyUSB0
```
Run the terminal, in this example picocom:
```
sudo picocom -b 115200 /dev/ttyUSB0
```
Keep picocom open in a separate terminal tab throughout the complete flashing process.

### Recovery mode
All NVIDIA flashing tools require the board to be in the Recovery Mode. Follow this procedure every time you need to enter recovery mode:

* Connect the Recovery USB port to your host PC
* Restart the Jetson board in the FORCE_RECOVERY mode:
	* Make sure the board is powered
	* Press and release the POWER button
* Press and hold the FORCE_RECOVERY (“RECOV”) button
* Press and release the RESET button
* Release the FORCE_RECOVERY button
* On the host PC, you should see the following USB device being detected (e.g. via `lsusb`):
```
vid 0955 pid 7323, NVIDIA Corp. APX
```
To verify if the flash.sh tool can communicate with the board in recovery mode, execute the following command:
```bash
cd $WORK/Linux_for_Tegra
sudo ./flash.sh -Z antmicro-job+p3767 internal
```
### Flashing the QSPI
Make sure that all SoC bootloaders and firmware files are up-to-date, and the UEFI configuration is reset to default.
Enter recovery mode.
Execute the following commands:
```bash
cd $WORK/Linux_for_Tegra
sudo ./flash.sh antmicro-job+p3767 internal
```
### Flashing the USB stick
Connect the USB stick (at least 16 GB, USB3.0) to the USB Host port on Jetson Orin Baseboard.
Enter the recovery mode.
Execute the following commands:
```bash
cd $WORK/Linux_for_Tegra
sudo ADDITIONAL_DTB_OVERLAY_OPT="BootOrderUsb.dtbo" \
	./tools/kernel_flash/l4t_initrd_flash.sh \
	--external-only \
	-c ./tools/kernel_flash/flash_l4t_external.xml \
	--external-device sda \
	antmicro-job+p3767 \
	internal
```
The board should reboot, show the UEFI prompt on Debug UART and execute the L4TLauncher bootloader, which should be followed by a successful kernel boot-up and a prompt asking you to run initial system configuration.

### Initial system configuration
Jetson Linux exposes the CDC ACM serial port USB Device on the Recovery USB port. It should be seen on your host PC as a new USB device.
Open picocom and follow NVIDIA’s wizard to configure the board (user credentials, time zone, Ethernet network, etc.):

```bash
sudo picocom /dev/ttyACM0
#
# System Configuration
# ...
```

After this, the board should fully boot and the cameras will be registered as ``/dev/video*`` nodes.
