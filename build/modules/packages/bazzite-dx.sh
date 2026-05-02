#!/usr/bin/env bash

set -ouex pipefail

echo "::group:: === Installing Bazzite-DX Packages ==="

dnf5 install -y \
	android-tools \
	bcc \
	bpftop \
	bpftrace \
	ccache \
	flatpak-builder \
	git-subtree \
	nicstat \
	numactl \
	podman-machine \
	podman-tui \
	python3-ramalama \
	restic \
	rclone \
	sysprof \
	tiptop \
	usbmuxd \
	waypipe

dnf5 remove -y \
	mesa-libOpenCL

dnf5 --setopt=install_weak_deps=False install -y \
	rocm-hip \
	rocm-opencl \
	rocm-clinfo \
	rocm-smi \
	qemu \
	libvirt \
	qemu-kvm \
	virt-manager \
	edk2-ovmf \
	guestfs-tools

echo "::endgroup:: === Installation completed ==="
