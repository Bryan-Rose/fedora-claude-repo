#!/usr/bin/env bash
# discover.sh must pick the stanza whose Version equals the newest version
# exactly (issue #5): a '+' or '.' in it is not a regex.
set -euo pipefail
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
repo=$tmp/repo/dists/stable
mkdir -p "$tmp/bin" "$repo/main/binary-amd64"
# gpgv stub: the signature chain is not under test, only the stanza pick.
cat > "$tmp/bin/gpgv" <<'STUB'
#!/bin/sh
cp "$5" "$4"
STUB
chmod +x "$tmp/bin/gpgv"
a=$(printf 'a%.0s' {1..64}) b=$(printf 'b%.0s' {1..64}) c=$(printf 'c%.0s' {1..64})
cat > "$repo/main/binary-amd64/Packages" <<EOT
Package: other
Version: 6.3+1
Filename: pool/other.deb
SHA256: $c

Package: claude-desktop
Version: 6.3
Filename: pool/claude-desktop_6.3_amd64.deb
SHA256: $a

Package: claude-desktop
Version: 6.3+1
Filename: pool/claude-desktop_6.3+1_amd64.deb
SHA256: $b
EOT
printf 'SHA256:\n %s 1 main/binary-amd64/Packages\n' \
	"$(sha256sum "$repo/main/binary-amd64/Packages" | cut -d' ' -f1)" > "$repo/InRelease"
touch "$tmp/keyring"

got=$(PATH=$tmp/bin:$PATH APT_BASE=file://$tmp/repo ci/discover.sh "$tmp/keyring")
want="deb_version=6.3+1
deb_filename=pool/claude-desktop_6.3+1_amd64.deb
deb_sha256=$b"
[[ $got == "$want" ]] || { printf 'got:\n%s\nwant:\n%s\n' "$got" "$want" >&2; exit 1; }
