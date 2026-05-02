#!/usr/bin/env bash

set -ouex pipefail

shopt -s nullglob

echo "::group:: === Building initramfs ==="

# Get kernel version and build initramfs
KERNEL_VERSION="$(rpm -q --queryformat='%{evr}.%{arch}' kernel)"
/usr/bin/dracut \
	--no-hostonly \
	--kver "$KERNEL_VERSION" \
	--reproducible \
	--zstd \
	-v \
	--add ostree \
	-f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

chmod 0600 "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

echo "::endgroup:: === Build completed ==="
