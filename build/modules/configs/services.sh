#!/usr/bin/env bash

set -ouex pipefail

echo "::group:: === Setting up Ublue Setup Services ==="

dnf5 install --enable-repo="copr:copr.fedorainfracloud.org:ublue-os:packages" -y \
	ublue-setup-services

echo "::endgroup:: === Setup completed ==="

echo "::group:: === Enabling Services ==="

systemctl enable docker.socket
systemctl enable podman.socket
systemctl enable ublue-system-setup.service
systemctl --global enable ublue-user-setup.service
systemctl enable bazzite-dx-groups.service

echo "::endgroup:: === Done enabling services ==="
