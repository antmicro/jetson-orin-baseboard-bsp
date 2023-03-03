#!/bin/bash

# Copyright (c) 2019-2021, NVIDIA CORPORATION. All rights reserved.
# Copyright (c) 2023, Antmicro. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# NOTE: this script is based on nvbuild.sh from NVidia

set -e

# shellcheck disable=SC2046
SCRIPT_DIR="$(dirname $(readlink -f "${0}"))"
SCRIPT_NAME="$(basename "${0}")"

# warning: below file is under PROPRIETARY license
source "${SCRIPT_DIR}/nvcommon_build.sh"

function usage {
	cat <<EOM
Usage: ./${SCRIPT_NAME} [OPTIONS]
This script builds kernel sources in specified directory (by default it's './out')
It supports following options.
OPTIONS:
	-h		Displays this help
	-o <outdir>	Creates kernel build output in <outdir>
	-m		Runs menuconfig and exits afterwards (use to verify defconfig changes)
EOM
}

# parse input parameters

function parse_input_param {
	while [ $# -gt 0 ]; do
		case ${1} in
			-h)
				usage
				exit 0
				;;
			-o)
				KERNEL_OUT_DIR="${2}"
				shift 2
				;;
			-m)
				MENUCONFIG=1
				shift 1
				;;
			*)
				echo "Error: Invalid option ${1}"
				usage
				exit 1
				;;
			esac
	done
}

function build_arm64_kernel_sources {
	kernel_version="${1}"
	echo "Building kernel-${kernel_version} sources"

	# execute building steps
	source_dir="${SCRIPT_DIR}/kernel/"
	config_file="p3767_antmicro_job_defconfig"
	tegra_kernel_out="${source_dir}"

	# shellcheck disable=SC2236
	if [ ! -z "${KERNEL_OUT_DIR}" ] ; then
		O_OPT=(O="${KERNEL_OUT_DIR}")
		tegra_kernel_out="${KERNEL_OUT_DIR}"
	else
		O_OPT=()
	fi

    set -x

	"${MAKE_BIN}" -C "${source_dir}" ARCH=arm64 \
		LOCALVERSION="-tegra" \
		CROSS_COMPILE="${CROSS_COMPILE_AARCH64}" \
		"${O_OPT[@]}" "${config_file}"

	if [ $MENUCONFIG -gt 0 ]; then
		echo "Executing menuconfig..." 1>&2
		"${MAKE_BIN}" -C "${source_dir}" ARCH=arm64 \
			LOCALVERSION="-tegra" \
			CROSS_COMPILE="${CROSS_COMPILE_AARCH64}" \
			"${O_OPT[@]}" menuconfig
		echo "Menuconfig done. Exiting." 1>&2
		exit 0
	fi

	"${MAKE_BIN}" -C "${source_dir}" ARCH=arm64 \
		LOCALVERSION="-tegra" \
		CROSS_COMPILE="${CROSS_COMPILE_AARCH64}" \
		"${O_OPT[@]}" -j"${NPROC}" \
		--output-sync=target Image

	"${MAKE_BIN}" -C "${source_dir}" ARCH=arm64 \
		LOCALVERSION="-tegra" \
		CROSS_COMPILE="${CROSS_COMPILE_AARCH64}" \
		"${O_OPT[@]}" -j"${NPROC}" \
		--output-sync=target dtbs

	"${MAKE_BIN}" -C "${source_dir}" ARCH=arm64 \
		LOCALVERSION="-tegra" \
		CROSS_COMPILE="${CROSS_COMPILE_AARCH64}" \
		"${O_OPT[@]}" -j"${NPROC}" \
		--output-sync=target modules

	"${MAKE_BIN}" -C "${source_dir}" ARCH=arm64 \
		LOCALVERSION="-tegra" \
		CROSS_COMPILE="${CROSS_COMPILE_AARCH64}" \
		INSTALL_MOD_PATH="${KERNEL_OUT_DIR}/modules_install" \
		"${O_OPT[@]}" -j"${NPROC}" \
		--output-sync=target modules_install

    set +x

	image="${tegra_kernel_out}/arch/arm64/boot/Image"
	if [ ! -f "${image}" ]; then
		echo "Error: Missing kernel image ${image}"
		exit 1
	fi
	echo "Kernel sources compiled successfully."
}


MENUCONFIG=0
KERNEL_OUT_DIR=$SCRIPT_DIR/out
# shellcheck disable=SC2068
parse_input_param $@

# Compile kernel sources for "arm64"
build_arm64_kernel_sources "5.10"

echo "Done. Compiled kernel, modules and DTB are located in '$KERNEL_OUT_DIR'."
