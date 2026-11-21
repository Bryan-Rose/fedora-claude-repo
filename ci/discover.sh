#!/usr/bin/env bash
# Find the newest official claude-desktop amd64 .deb, verifying the APT chain:
# InRelease (gpgv, committed Anthropic key) -> Packages (sha256 from InRelease).
# Prints shell assignments: deb_version=, deb_filename=, deb_sha256=
# Usage: ci/discover.sh [keyring]   (default keys/anthropic-apt.gpg)
set -euo pipefail

base=${APT_BASE:-https://downloads.claude.ai/claude-desktop/apt/stable}
keyring=$(realpath "${1:-keys/anthropic-apt.gpg}")
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cd "$tmp"

curl -fsSL --retry 3 -o InRelease "$base/dists/stable/InRelease"
# --output writes only the signed payload, so nothing unsigned is parsed below.
gpgv --keyring "$keyring" --output Release InRelease 2>gpgv.log \
	|| { cat gpgv.log >&2; echo 'InRelease signature check failed' >&2; exit 1; }

want=$(awk '/^SHA256:/{f=1; next} /^[^ ]/{f=0} f && $3=="main/binary-amd64/Packages"{print $1}' Release)
[[ -n $want ]] || { echo 'No SHA256 for main/binary-amd64/Packages in InRelease' >&2; exit 1; }

curl -fsSL --retry 3 -o Packages "$base/dists/stable/main/binary-amd64/Packages"
echo "$want  Packages" | sha256sum -c --quiet - \
	|| { echo 'Packages hash does not match InRelease' >&2; exit 1; }

version=$(awk '/^Package:/{p=$2} /^Version:/ && p=="claude-desktop"{print $2}' Packages | sort -V | tail -n1)
[[ -n $version ]] || { echo 'No claude-desktop entry in Packages' >&2; exit 1; }

# Pick the stanza for that exact version.
read -r filename sha256 < <(awk -v RS= -v v="$version" '
	$0 ~ "(^|\n)Package: claude-desktop\n" && $0 ~ "\nVersion: " v "\n" {
		n = split($0, l, "\n")
		for (i = 1; i <= n; i++) {
			if (l[i] ~ /^Filename: /) f = substr(l[i], 11)
			if (l[i] ~ /^SHA256: /)   s = substr(l[i], 9)
		}
		print f, s; exit
	}' Packages)
[[ $filename == pool/* && $sha256 =~ ^[0-9a-f]{64}$ ]] \
	|| { echo "Bad Packages stanza for $version" >&2; exit 1; }

printf 'deb_version=%s\ndeb_filename=%s\ndeb_sha256=%s\n' "$version" "$filename" "$sha256"
