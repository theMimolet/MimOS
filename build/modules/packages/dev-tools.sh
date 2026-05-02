#!/usr/bin/env bash

set -ouex pipefail

echo "::group:: === Installing Personal Dev Packages ==="

dnf5 install -y \
	shfmt \
	wireshark \
	foundry

echo "::endgroup:: === Installation completed ==="
