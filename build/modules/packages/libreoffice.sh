#!/usr/bin/env bash

set -ouex pipefail

echo "::group:: === Installing LibreOffice Packages ==="

dnf5 install -y \
	libreoffice \
	libreoffice-kf6 \
	libreoffice-langpack-fr \
	libreoffice-langpack-en

echo "::endgroup:: === Installation completed ==="
