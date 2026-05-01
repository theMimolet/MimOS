#!/bin/bash

set -ouex pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

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

echo "::group:: === Setting up Ublue Setup Services ==="

dnf5 install --enable-repo="copr:copr.fedorainfracloud.org:ublue-os:packages" -y \
	ublue-setup-services

echo "::endgroup:: === Setup completed ==="

echo "::group:: === Installing Docker  ==="

docker_pkgs=(
	containerd.io
	docker-buildx-plugin
	docker-ce
	docker-ce-cli
	docker-compose-plugin
)
dnf5 config-manager addrepo --from-repofile="https://download.docker.com/linux/fedora/docker-ce.repo"
dnf5 config-manager setopt docker-ce-stable.enabled=0
dnf5 install -y --enable-repo="docker-ce-stable" "${docker_pkgs[@]}" || {
	# Use test packages if docker pkgs is not available for f42
	if (($(lsb_release -sr) == 42)); then
		echo "::info::Missing docker packages in f42, falling back to test repos..."
		dnf5 install -y --enablerepo="docker-ce-test" "${docker_pkgs[@]}"
	fi
}

mkdir -p /etc/modules-load.d && cat >>/etc/modules-load.d/ip_tables.conf <<EOF
iptable_nat
EOF

echo 'g docker -' >/usr/lib/sysusers.d/docker.conf

echo "::endgroup:: === Installation completed ==="

echo "::group:: === Installing Personal Dev Packages ==="

dnf5 install -y \
	fish \
	shfmt \
	wireshark \
	foundry

echo "::endgroup:: === Installation completed ==="

echo "::group:: === Installing LibreOffice Packages ==="

dnf5 install -y \
	libreoffice-kf6 \
	libreoffice-langpack-fr \
	libreoffice-langpack-en

echo "::endgroup:: === Installation completed ==="

echo "::group:: === Installing Helium ==="

mkdir -p /var/opt/helium

dnf5 copr enable -y imput/helium
dnf5 install -y helium-bin

echo "::endgroup:: === Installation completed ==="

echo "::group:: === Removing Unnecessary Packages ==="

dnf5 remove -y \
	waydroid \
	bazzite-portal \
	kate

echo "::endgroup:: === Removal completed ==="

echo "::group:: === Enabling Services ==="

systemctl enable docker.socket
systemctl enable podman.socket
systemctl enable ublue-system-setup.service
systemctl --global enable ublue-user-setup.service
systemctl enable bazzite-dx-groups.service

echo "::endgroup:: === Done enabling services ==="

echo "::group:: === Starting /opt directory fix ==="

# Move directories from /var/opt to /usr/lib/opt
for dir in /var/opt/*/; do
	[ -d "$dir" ] || continue
	dirname=$(basename "$dir")
	mv "$dir" "/usr/lib/opt/$dirname"
	echo "L+ /var/opt/$dirname - - - - /usr/lib/opt/$dirname" >>/usr/lib/tmpfiles.d/opt-fix.conf
done

echo "::endgroup:: === Fix completed ==="

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

echo "::group:: === Starting system cleanup ==="

# Remove unnecessary repositories, except for the fedora ones
find /etc/yum.repos.d/ -maxdepth 1 -type f -name '*.repo' ! -name 'fedora.repo' ! -name 'fedora-updates.repo' ! -name 'fedora-updates-testing.repo' -exec rm -f {} +

# Clean package manager cache
dnf5 clean all

# Remove runtime files that may have been generated during the build process
rm -rf /run/dnf /run/gluster /run/selinux-policy

# Clean temporary files
rm -rf /tmp/* || true
rm -rf /var/log/dnf5.log* || true
rm -rf /var/log/firebird/ || true
rm -rf /boot/* || true
rm -rf /boot/.* || true

# Remove all directories in /var except for cache and log - which will be delt with by the container build process
find /var -mindepth 1 -maxdepth 1 \
	! -name 'cache' \
	! -name 'log' \
	-exec rm -rf {} +

echo "::endgroup:: === Cleanup completed ==="

# Lint container
bootc container lint
