#!/bin/bash

set -ouex pipefail

trap '[[ $BASH_COMMAND != printf* ]] && [[ $BASH_COMMAND != log* ]] && printf "+ $BASH_COMMAND"' DEBUG

printf "::group:: === Installing Bazzite-DX Packages ==="

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

printf "::endgroup:: === Finished Bazzite-DX Packages ==="

printf "::group:: === Installing Personal Dev Packages ==="

dnf5 install -y \
	wireshark \
	foundry

printf "::group:: === Installing LibreOffice Packages ==="

dnf5 install -y \
	libreoffice \
	libreoffice-langpack-fr \
	libreoffice-langpack-en

printf "::endgroup:: === Finished installing LibreOffice Packages ==="

printf "::group:: === Installing Helium ==="

dnf5 copr enable imput/helium
dnf5 install helium-bin

printf "::endgroup:: === Finished installing Helium ==="

printf "::group:: === Removing Unnecessary Packages ==="

dnf5 remove -y \
	waydroid \
	bazzite-portal \
	kate

printf "::group:: === Enabling Services ==="

systemctl enable docker.socket
systemctl enable podman.socket
systemctl enable ublue-system-setup.service
systemctl --global enable ublue-user-setup.service
systemctl enable bazzite-dx-groups.service

printf "::endgroup:: === Done enabling services ==="

printf "::group:: === Starting /opt directory fix ==="

# Move directories from /var/opt to /usr/lib/opt
for dir in /var/opt/*/; do
	[ -d "$dir" ] || continue
	dirname=$(basename "$dir")
	mv "$dir" "/usr/lib/opt/$dirname"
	printf "L+ /var/opt/$dirname - - - - /usr/lib/opt/$dirname" >>/usr/lib/tmpfiles.d/opt-fix.conf
done

printf "::endgroup:: === Fix completed ==="

printf "::group:: === Building initramfs ==="

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

printf "::endgroup:: === Build completed ==="

printf "::group:: === Starting system cleanup ==="

# Remove unnecessary repositories, except for the fedora ones
find /etc/yum.repos.d/ -maxdepth 1 -type f -name '*.repo' ! -name 'fedora.repo' ! -name 'fedora-updates.repo' ! -name 'fedora-updates-testing.repo' -exec rm -f {} +

# Clean package manager cache
dnf5 clean all

# Clean temporary files
rm -rf /tmp/* || true
rm -rf /var/log/dnf5.log || true
rm -rf /boot/* || true
rm -rf /boot/.* || true

# Cleanup the entirety of `/var`.
# None of these get in the end-user system and bootc lints get super mad if anything is in there
rm -rf /var
mkdir -p /var

# Commit and lint container
bootc container lint

printf "::endgroup:: === Cleanup completed ==="
