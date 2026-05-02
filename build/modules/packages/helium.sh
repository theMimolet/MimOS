#!/usr/bin/env bash

set -ouex pipefail

echo "::group:: === Installing Helium ==="

mkdir -p /var/opt/helium

dnf5 copr enable -y imput/helium
dnf5 install -y helium-bin

echo "::endgroup:: === Installation completed ==="
