FROM ghcr.io/ublue-os/bazzite-nvidia-open:stable

COPY system /

# =============================================
# Removing unnecessary packages
# =============================================

RUN dnf5 remove -y \
	mesa-libOpenCL \
  waydroid \
  bazzite-portal \
  webapp-manager \
  kate

# =============================================
# Installing Docker
# =============================================

RUN dnf5 config-manager addrepo --from-repofile="https://download.docker.com/linux/fedora/docker-ce.repo"
RUN dnf5 config-manager setopt docker-ce-stable.enabled=0
RUN dnf5 install -y --enable-repo="docker-ce-stable" \
	containerd.io \
	docker-buildx-plugin \
	docker-ce \
	docker-ce-cli \
	docker-compose-plugin
RUN mkdir -p /etc/modules-load.d && cat >>/etc/modules-load.d/ip_tables.conf <<EOF
iptable_nat
EOF
RUN mkdir -p /usr/lib/sysusers.d

COPY <<EOF /usr/lib/sysusers.d/docker.conf
g docker -
EOF

# =============================================
# Bazzite DX experience packages
# =============================================

RUN dnf5 install -y \
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
RUN dnf5 --setopt=install_weak_deps=False install -y \
	qemu \
	libvirt \
	qemu-kvm \
	virt-manager \
	edk2-ovmf \
	guestfs-tools

# =============================================
# Installing own packages
# =============================================

RUN mkdir -p /var/opt/helium
RUN dnf5 copr enable -y imput/helium
RUN dnf5 copr enable -y myriad-sun/zed
RUN dnf5 install -y \
	libreoffice \
	libreoffice-kf6 \
	libreoffice-langpack-fr \
	libreoffice-langpack-en \
  shfmt \
	wireshark \
	foundry \
  helium-bin \
  zed

# =============================================
# Opt directory fix
# =============================================

# Move directories from /var/opt to /usr/lib/opt
RUN for dir in /var/opt/*; do \
    if [ -d "$dir" ]; then \
        dirname=$(basename "$dir"); \
        mv "$dir" "/usr/lib/opt/$dirname" && \
        echo "L+ /var/opt/$dirname - - - - /usr/lib/opt/$dirname" >> /usr/lib/tmpfiles.d/opt-fix.conf; \
    fi; \
done

# =============================================
# Setting up services
# =============================================

RUN dnf5 install --enable-repo="copr:copr.fedorainfracloud.org:ublue-os:packages" -y \
	ublue-setup-services
RUN systemctl enable docker.socket podman.socket ublue-system-setup.service bazzite-dx-groups.service
RUN systemctl --global enable ublue-user-setup.service

# =============================================
# Generate initramfs
# =============================================

RUN KERNEL_VERSION="$(rpm -q --queryformat='%{evr}.%{arch}' kernel)" && \
	/usr/bin/dracut \
		--no-hostonly \
		--kver "$KERNEL_VERSION" \
		--reproducible \
		--zstd \
		-v \
		--add ostree \
		-f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img" && \
	chmod 0600 "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

# =============================================
# Clean up
# =============================================

# Remove unnecessary repositories, except for the fedora ones
RUN find /etc/yum.repos.d/ -maxdepth 1 -type f -name '*.repo' ! -name 'fedora.repo' ! -name 'fedora-updates.repo' ! -name 'fedora-updates-testing.repo' -exec rm -f {} +

# Clean package manager cache
RUN dnf5 clean all

# Remove temporary files, logs, and other unnecessary files
RUN rm -rf /run/dnf /run/gluster /run/selinux-policy && \
  rm -rf /tmp/* \
	|| true && \
  rm -rf /var/log/dnf5.log* \
	|| true && \
  rm -rf /var/log/firebird/ \
	|| true && \
  rm -rf /boot/.* \
	|| true

# Remove all directories in /var except for cache and log - which will be delt with by the container build process
RUN find /var -mindepth 1 -maxdepth 1 \
	! -name 'cache' \
	! -name 'log' \
	-exec rm -rf {} +

# =============================================
# Lint container
# =============================================

RUN bootc container lint
