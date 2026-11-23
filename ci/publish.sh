#!/usr/bin/env bash
# Sign RPMs into the 'packages' release and regenerate signed repo metadata in the gh-pages tree.
# RPMs are release assets because git rejects files over 100 MB; gh-pages holds only metadata (design D14).
# The only job that sees the signing key; runs no upstream code (design D11).
# Usage: ci/publish.sh <site-dir> <rpm-dir> <pool-dir> <build-key>
#   pool-dir ends up holding exactly the retained, signed RPMs; prune release assets not in it
#   only after the new metadata is pushed.
# Env:   RPM_GPG_PRIVATE_KEY (armored secret key), RPM_GPG_NAME (its UID), GH_TOKEN, GH_REPO (owner/name)
set -euo pipefail
shopt -s nullglob
site=$(realpath "$1"); rpms=$(realpath "$2"); pool=$3; build_key=$4
: "${RPM_GPG_PRIVATE_KEY:?}" "${RPM_GPG_NAME:?}" "${GH_TOKEN:?}" "${GH_REPO:?}"
tag=packages
keep=3

GNUPGHOME=$(mktemp -d); export GNUPGHOME
trap 'gpgconf --kill gpg-agent 2>/dev/null || true; rm -rf "$GNUPGHOME"' EXIT
printf '%s\n' "$RPM_GPG_PRIVATE_KEY" | gpg --batch --quiet --import
n=$(gpg --with-colons --list-secret-keys | grep -c '^sec:')
(( n == 1 )) || { echo "Expected exactly one secret key, found $n" >&2; exit 1; }
cat > "$HOME/.rpmmacros" <<MACROS
%_gpg_name $RPM_GPG_NAME
%_openpgp_sign_id $RPM_GPG_NAME
MACROS

# Current packages: whatever the release holds.
if ! gh release view "$tag" >/dev/null 2>&1; then
	gh release create "$tag" --latest=false --title "RPM packages (unofficial)" \
		--notes "Signed RPMs served to dnf via https://bryan-rose.github.io/fedora-claude-repo/. Unofficial build of Claude Desktop, not affiliated with or endorsed by Anthropic. Install via the dnf repository, not from here; see README."
fi
mkdir -p "$pool"; pool=$(realpath "$pool")
# Plain assignment so a failed API call stops the script instead of reading as "no assets",
# which would drop every retained build from the metadata and the prune step.
n=$(gh release view "$tag" --json assets --jq '[.assets[].name | select(endswith(".rpm"))] | length')
if (( n > 0 )); then
	gh release download "$tag" --pattern '*.rpm' --dir "$pool" --clobber
fi
before=$(mktemp)
for f in "$pool"/*.rpm; do sha256sum "$f"; done > "$before"

cp "$rpms"/*.rpm "$pool/"
# Sign everything present: new builds, plus older ones after a key rotation.
# rpmsign skips packages that already carry this key's signature.
rpmsign --addsign "$pool"/*.rpm >/dev/null

# Retention: newest $keep builds per package name, by build time.
for f in "$pool"/*.rpm; do
	printf '%s %s\n' "$(rpm -qp --qf '%{NAME} %{BUILDTIME}' "$f" 2>/dev/null)" "$f"
done | sort -k1,1 -k2,2nr | awk -v keep="$keep" '++seen[$1] > keep {print $3}' | xargs -r rm -v --

# Upload new or re-signed files before the metadata that references them goes live.
upload=()
for f in "$pool"/*.rpm; do
	# GitHub silently renames assets with other characters, which would break the metadata's hrefs.
	[[ $(basename "$f") =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Unsafe asset name: $f" >&2; exit 1; }
	grep -qxF "$(sha256sum "$f")" "$before" || upload+=("$f")
done
# shortcut: --clobber replaces a same-named asset (the companion) in place, so for a few seconds the
# live metadata's checksum for it is stale; dnf fails that download and succeeds on retry.
if (( ${#upload[@]} )); then gh release upload "$tag" "${upload[@]}" --clobber; fi

mkdir -p "$site/rpm"
rm -rf "$site/rpm/repodata"
createrepo_c --quiet --baseurl "https://github.com/$GH_REPO/releases/download/$tag/" \
	--outputdir "$site/rpm" "$pool"
gpg --batch --yes --local-user "$RPM_GPG_NAME" --detach-sign --armor "$site/rpm/repodata/repomd.xml"

gpg --armor --export "$RPM_GPG_NAME" > "$site/RPM-GPG-KEY"
n=$(gpg --show-keys --with-colons "$site/RPM-GPG-KEY" | grep -c '^pub:')
(( n == 1 )) || { echo "RPM-GPG-KEY holds $n keys, expected 1" >&2; exit 1; }

printf '%s\n' "$build_key" > "$site/LAST_VERSION"
touch "$site/.nojekyll"
