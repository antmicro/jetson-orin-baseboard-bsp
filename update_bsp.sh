#!/bin/bash
#
# This script installs following items into BSP:
# - board configuration (conf, early bootloader DTS)
# - kernel image
# - kernel modules
# - kernel DTB file

set -e

SCRIPT_DIR="$(dirname $(readlink -f "${0}"))"
SCRIPT_NAME="$(basename "${0}")"

function usage {
	cat <<EOM
Usage: ./${SCRIPT_NAME} [OPTIONS] <BSP_DIR>
This script installs configuration files and kernel into specified L4T BSP directory
It supports following options.
OPTIONS:
	-h			Displays this help
	-k <kernel_out_dir>	By default kernel binaries are located in './out', this option overrides that path
EOM
}

function parse_input_param {
	while [ $# -gt 1 ]; do
		case ${1} in
			-h)
				usage
				exit 0
				;;
			-k)
				KERNEL_OUT_DIR="${2}"
				shift 2
				;;
			*)
				echo "Error: Invalid option ${1}"
				usage
				exit 1
				;;
		esac
	done
	BSP_DIR=$1
}

BSP_DIR=
KERNEL_OUT_DIR=$SCRIPT_DIR/out
OVL_DIR=$SCRIPT_DIR/bsp_overlay

parse_input_param $@

if [[ ! -d $BSP_DIR ]]; then
	echo "BSP_DIR '$BSP_DIR' is not a directory." 1>&2
	usage
	exit 1
fi
if [[ ! -d $KERNEL_OUT_DIR ]]; then
	echo "KERNEL_OUT_DIR '$KERNEL_OUT_DIR' is not a directory." 1>&2
	usage
	exit 1
fi
if [[ "$EUID" -ne 0 ]]; then
	echo "This script must be run with root rights" 1>&2
	exit 1
fi

KERNEL_OUT_DIR=$(realpath $KERNEL_OUT_DIR)
BSP_DIR=$(realpath $BSP_DIR)

echo "Updating L4T BSP in '$BSP_DIR'. Kernel taken from '$KERNEL_OUT_DIR'"
# ---
set -x
cp -rvf $OVL_DIR/* $BSP_DIR/
# Pack modules into tbz2 archive for BSP
(
    cd $KERNEL_OUT_DIR/modules_install
    BZIP=--fast tar --owner root --group root -cjvf $BSP_DIR/kernel/kernel_supplements.tbz2 lib/modules
)
cp -vf $KERNEL_OUT_DIR/arch/arm64/boot/dts/*.dtb $BSP_DIR/kernel/dtb/
cp -vf $KERNEL_OUT_DIR/arch/arm64/boot/dts/*.dtbo $BSP_DIR/kernel/dtb/
cp -vf $KERNEL_OUT_DIR/arch/arm64/boot/Image $BSP_DIR/kernel/Image
# ---
(
    cd $BSP_DIR
    ./apply_binaries.sh --target-overlay
)
# ---
set +x
echo "Done."
