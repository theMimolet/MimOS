#!/usr/bin/env bash

set -ouex pipefail

echo "::group:: === Installing Docker  ==="

docker_pkgs=(
	containerd.io
	docker-buildx-plugin
	docker-ce
	docker-ce-cli
	docker-compose-plugin
)
dnf5 config-manager addrepo --from-repofile="https://download.docker.com/linux/fedora/docker-ce.repo"
dnf5 config-manager setopt docker-ce-stable.enabled=0
dnf5 install -y --enable-repo="docker-ce-stable" "${docker_pkgs[@]}" || {
	# Use test packages if docker pkgs is not available for f42
	if (($(lsb_release -sr) == 42)); then
		echo "::info::Missing docker packages in f42, falling back to test repos..."
		dnf5 install -y --enablerepo="docker-ce-test" "${docker_pkgs[@]}"
	fi
}

mkdir -p /etc/modules-load.d && cat >>/etc/modules-load.d/ip_tables.conf <<EOF
iptable_nat
EOF

echo 'g docker -' >/usr/lib/sysusers.d/docker.conf

echo "::endgroup:: === Installation completed ==="
