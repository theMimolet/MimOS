#!/bin/bash

set -ouex pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

modules=(
	"packages.package-removal"
	"packages.bazzite-dx"
	"packages.dev-tools"
	"packages.docker"
	"packages.libreoffice"
	"packages.helium"
	"packages.zed"
	"configs.services"
	"configs.opt-fix"
	"configs.os-release"
	"initramfs"
	"cleanup"
)

for mod in "${modules[@]}"; do
	path="/build/modules/${mod//./\/}.sh"
	echo "::group:: === $(basename "$path") ==="
	bash "$path"
	echo "::endgroup::"
done

# Lint container
bootc container lint
