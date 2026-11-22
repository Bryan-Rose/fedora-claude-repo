#!/usr/bin/env bash
# Install the built RPMs into this (clean Fedora) container and verify them.
# Usage: ci/install-test.sh [dir]   (default ./out)
set -euo pipefail
dir=${1:-out}
dnf -y -q install "$dir"/*.rpm
rpm -V claude-desktop-unofficial claude-desktop-fedora
rpm -q claude-desktop-unofficial claude-desktop-fedora
! rpm -q nodejs >/dev/null || { echo 'nodejs got pulled in' >&2; exit 1; }
