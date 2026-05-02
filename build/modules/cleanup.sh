#!/usr/bin/env bash

set -ouex pipefail

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
