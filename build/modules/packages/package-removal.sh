#!/usr/bin/env bash

set -ouex pipefail

echo "::group:: === Removing Unnecessary Packages ==="

dnf5 remove -y \
	waydroid \
	bazzite-portal \
	webapp-manager \
	kate

echo "::endgroup:: === Removal completed ==="
