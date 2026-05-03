#!/usr/bin/env bash

set -ouex pipefail

echo "::group:: === Installing the Zed Package through terra ==="

dnf5 install -y zed

echo "::endgroup:: === Installation completed ==="
