FROM ghcr.io/ublue-os/bazzite-nvidia-open:stable

COPY system /
COPY build /build

RUN --mount=type=tmpfs,dst=/tmp \
  --mount=type=cache,dst=/var/cache \
  --mount=type=cache,dst=/var/log \
  bash /build/build.sh

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

# Lint container
RUN bootc container lint
