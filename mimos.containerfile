#FROM ghcr.io/ublue-os/bazzite-nvidia-open:stable
FROM quay.io/fedora/fedora-bootc:44

# =============================================
# Prepares the directories
# =============================================

RUN mkdir -p /var/roothome /var/opt && \
    ln -sf /var/opt /opt && \
    dnf -y install dnf5-plugins

# =============================================
# Sets up extra repositories
# =============================================

RUN dnf5 install -y \
      https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
      https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm \
      && dnf5 clean all
RUN dnf5 config-manager addrepo --from-repofile="https://download.docker.com/linux/fedora/docker-ce.repo" && \
    dnf5 config-manager setopt docker-ce-stable.enabled=0 && \
    dnf5 install -y --enable-repo="docker-ce-stable"

RUN dnf5 copr enable -y bieszczaders/kernel-cachyos && \
    dnf5 copr enable -y bieszczaders/kernel-cachyos-addons && \
    dnf5 copr enable -y imput/helium && \
    dnf5 copr enable -y myriad-sun/zed

# =============================================
# Installs KDE Plasma
# =============================================

RUN dnf5 install -y \
    plasma-desktop \
    plasma-login-manager \
    plasma-workspace \
    plasma-workspace-wallpapers \
    kcm-plasmalogin \
    NetworkManager-config-connectivity-fedora \
    abrt-desktop \
    akonadi-server \
    akonadi-server-mysql \
    ark \
    audiocd-kio \
    aurorae \
    bluedevil \
    breeze-icon-theme \
    colord-kde \
    cups-pk-helper \
    dolphin \
    ffmpegthumbs \
    filelight \
    firewall-config \
    flatpak-kcm \
    fprintd-pam \
    glibc-all-langpacks \
    iwd \
    kaccounts-integration-qt6 \
    kaccounts-providers \
    kcharselect \
    kde-connect \
    kde-gtk-config \
    kde-inotify-survey \
    kde-partitionmanager \
    kde-settings-plasmalogin \
    kde-settings-pulseaudio \
    kdebugsettings \
    kdegraphics-thumbnailers \
    kdenetwork-filesharing \
    kdeplasma-addons \
    kdialog \
    kdnssd \
    kf6-baloo-file \
    kfind \
    kinfocenter \
    kio-admin \
    kio-gdrive \
    kjournald \
    kmenuedit \
    konsole \
    krdp \
    krfb \
    kscreen \
    kscreenlocker \
    ksshaskpass \
    kunifiedpush \
    kwalletmanager5 \
    kwin \
    kwrite \
    libappindicator-gtk3 \
    pam-kwallet \
    phonon-qt6-backend-vlc \
    pinentry-qt \
    plasma-breeze \
    plasma-disks \
    plasma-drkonqi \
    plasma-nm \
    plasma-nm-l2tp \
    plasma-nm-openconnect \
    plasma-nm-openswan \
    plasma-nm-openvpn \
    plasma-nm-pptp \
    plasma-nm-vpnc \
    plasma-pa \
    plasma-print-manager \
    plasma-systemmonitor \
    plasma-thunderbolt \
    plasma-vault \
    polkit-kde \
    samba-usershares \
    signon-kwallet-extension \
    spectacle \
    systemd-oomd-defaults \
    thermald \
    toolbox \
    udisks2 \
    vlc-plugin-gstreamer \
    xwaylandvideobridge && \
    dnf5 -y autoremove

# =============================================
# Installing CachyOS kernel
# =============================================

RUN dnf5 -y install \
    kernel-cachyos \
    kernel-cachyos-headers \
    scx-scheds \
    scx-tools && \
    dnf5 -y remove kernel kernel-core kernel-modules && \
    dnf5 -y autoremove

# =============================================
# Install Nvidia drivers
# =============================================

RUN dnf5 -y install \
      akmod-nvidia \
      xorg-x11-drv-nvidia \
      xorg-x11-drv-nvidia-cuda \
      xorg-x11-drv-nvidia-power \
      nvidia-vaapi-driver \
      libva-utils \
      vdpauinfo

# Force akmod to build NOW against the CachyOS kernel, then rebuild initramfs
RUN akmods --force && \
    dracut --force

# =============================================
# Installing Gaming Packages
# =============================================

RUN dnf5 -y install \
      steam \
      lutris \
      gamemode \
      gamescope \
      mangohud \
      wine \
      winetricks \
      protontricks \
      mesa-vulkan-drivers \
      mesa-dri-drivers \
      vulkan-tools \
      vulkan-loader \
      lib32-mesa-vulkan-drivers \
      lib32-gamemode \
      scx-scheds

# =============================================
# Installing Development Tools
# =============================================

RUN dnf5 -y install \
        ccache \
        containerd.io \
        docker-buildx-plugin \
        docker-ce \
        docker-ce-cli \
        docker-compose-plugin \
        git \
        greenboot \
        greenboot-default-health-checks \
        gum \
        fira-code-fonts \
        fish \
        flatpak-builder \
        sysprof \
        uupd && \
    dnf5 --setopt=install_weak_deps=False install -y \
        qemu \
        libvirt \
        qemu-kvm \
        virt-manager \
        edk2-ovmf \
        guestfs-tools && \
    mkdir -p /etc/modules-load.d /usr/lib/sysusers.d && \
    printf "iptable_nat\n" >> /etc/modules-load.d/ip_tables.conf && \
    printf "g docker -\n" > /usr/lib/sysusers.d/docker.conf

# =============================================
# Installing packages
# =============================================

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

# Own packages (COPRhelium, zed)
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
