#!/usr/bin/env bash
# publish.sh must stop when counting the release's assets fails (issue #3),
# not treat the release as empty and drop the retained builds.
set -euo pipefail
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin" "$tmp/rpms" "$tmp/home"
touch "$tmp/rpms/claude-desktop-1-1.x86_64.rpm"
cat > "$tmp/bin/gpg" <<'STUB'
#!/bin/sh
case "$*" in *--import*) cat >/dev/null ;; esac  # drain stdin so publish.sh's printf can't hit EPIPE
case "$*" in *--list-secret-keys*) echo 'sec:u:255:22:X:::::::scESC:' ;; esac
STUB
cat > "$tmp/bin/gh" <<STUB
#!/bin/sh
echo "gh \$*" >> "$tmp/gh.log"
case "\$*" in *--json*) exit 1 ;; esac
STUB
for c in gpgconf rpmsign rpm createrepo_c; do printf "#!/bin/sh\n" > "$tmp/bin/$c"; done
chmod +x "$tmp/bin"/*

if HOME=$tmp/home PATH=$tmp/bin:$PATH RPM_GPG_PRIVATE_KEY=k RPM_GPG_NAME=n GH_TOKEN=t GH_REPO=o/r \
	ci/publish.sh "$tmp/site" "$tmp/rpms" "$tmp/pool" key 2>/dev/null; then
	echo "publish.sh succeeded although the asset count failed" >&2; exit 1
fi
# Without this the test passes when publish.sh fails earlier for an unrelated reason.
if ! grep -q -- '--json assets' "$tmp/gh.log"; then
	echo "publish.sh never reached the asset count:" >&2; cat "$tmp/gh.log" >&2; exit 1
fi
if grep -qE 'download|upload' "$tmp/gh.log"; then
	echo "publish.sh went on past the failed asset count:" >&2; cat "$tmp/gh.log" >&2; exit 1
fi
