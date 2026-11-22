#!/usr/bin/env bash
# Install the built RPMs into this (clean Fedora) container and verify them.
# Usage: ci/install-test.sh [dir]   (default ./out)
set -euo pipefail
dir=${1:-out}
dnf -y -q install "$dir"/*.rpm
rpm -V claude-desktop-unofficial claude-desktop-fedora
rpm -q claude-desktop-unofficial claude-desktop-fedora
# Fedora ships Node as nodejs22/nodejs24/..., so check the file, not the package name.
! rpm -q --whatprovides /usr/bin/node >/dev/null || { echo "Node.js got pulled in: $(rpm -q --whatprovides /usr/bin/node)" >&2; exit 1; }
