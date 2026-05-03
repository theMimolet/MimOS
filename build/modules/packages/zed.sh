#!/usr/bin/env bash

set -ouex pipefail

echo "::group:: === Installing the Zed Package through terra ==="

dnf5 install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release

dnf5 install -y zed

echo "::endgroup:: === Installation completed ==="
