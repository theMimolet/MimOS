ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite-nvidia-open:stable"
FROM ${BASE_IMAGE}

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
# Installing packages
# =============================================

# Docker
RUN dnf5 config-manager addrepo --from-repofile="https://download.docker.com/linux/fedora/docker-ce.repo" && \
    dnf5 config-manager setopt docker-ce-stable.enabled=0 && \
    dnf5 install -y --enable-repo="docker-ce-stable" \
        containerd.io \
        docker-buildx-plugin \
        docker-ce \
        docker-ce-cli \
        docker-compose-plugin && \
    mkdir -p /etc/modules-load.d /usr/lib/sysusers.d && \
    printf "iptable_nat\n" >> /etc/modules-load.d/ip_tables.conf && \
    printf "g docker -\n" > /usr/lib/sysusers.d/docker.conf

# Bazzite DX experience
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
        waypipe && \
    dnf5 --setopt=install_weak_deps=False install -y \
        qemu \
        libvirt \
        qemu-kvm \
        virt-manager \
        edk2-ovmf \
        guestfs-tools

# Own packages (COPR: helium, zed)
RUN mkdir -p /var/opt/helium && \
    dnf5 copr enable -y imput/helium && \
    dnf5 copr enable -y myriad-sun/zed && \
    dnf5 install -y \
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
# System files
# =============================================

COPY system /

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
	ublue-setup-services && \
    systemctl enable docker.socket podman.socket ublue-system-setup.service bazzite-dx-groups.service && \
    systemctl --global enable ublue-user-setup.service

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

RUN find /etc/yum.repos.d/ -maxdepth 1 -type f -name '*.repo' \
        ! -name 'fedora.repo' \
        ! -name 'fedora-updates.repo' \
        ! -name 'fedora-updates-testing.repo' \
        -exec rm -f {} + && \
    rm -rf \
        /run/dnf /run/gluster /run/selinux-policy \
        /tmp/* \
        /var/log/dnf5.log* \
        /var/log/firebird/ \
        /boot/.* \
        || true && \
    find /var -mindepth 1 -maxdepth 1 \
        ! -name 'cache' \
        ! -name 'log' \
        -exec rm -rf {} +

# =============================================
# Lint container
# =============================================

RUN bootc container lint
