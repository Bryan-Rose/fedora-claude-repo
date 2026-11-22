#!/usr/bin/env bash
# Sign new RPMs into the gh-pages tree and regenerate signed repo metadata.
# The only job that sees the signing key; runs no upstream code (design D11).
# Usage: ci/publish.sh <site-dir> <rpm-dir> <build-key>
# Env:   RPM_GPG_PRIVATE_KEY (armored secret key), RPM_GPG_NAME (its UID)
set -euo pipefail
site=$(realpath "$1"); rpms=$(realpath "$2"); build_key=$3
: "${RPM_GPG_PRIVATE_KEY:?}" "${RPM_GPG_NAME:?}"
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

mkdir -p "$site/rpm"
cp "$rpms"/*.rpm "$site/rpm/"
# Sign everything present: new builds, plus older ones after a key rotation.
# rpmsign skips packages that already carry this key's signature.
rpmsign --addsign "$site"/rpm/*.rpm >/dev/null

# Retention: newest $keep builds per package name, by build time.
for f in "$site"/rpm/*.rpm; do
	printf '%s %s\n' "$(rpm -qp --qf '%{NAME} %{BUILDTIME}' "$f" 2>/dev/null)" "$f"
done | sort -k1,1 -k2,2nr | awk -v keep="$keep" '++seen[$1] > keep {print $3}' | xargs -r rm -v --

createrepo_c --quiet --update "$site/rpm"
rm -f "$site/rpm/repodata/repomd.xml.asc"
gpg --batch --yes --local-user "$RPM_GPG_NAME" --detach-sign --armor "$site/rpm/repodata/repomd.xml"

gpg --armor --export "$RPM_GPG_NAME" > "$site/RPM-GPG-KEY"
n=$(gpg --show-keys --with-colons "$site/RPM-GPG-KEY" | grep -c '^pub:')
(( n == 1 )) || { echo "RPM-GPG-KEY holds $n keys, expected 1" >&2; exit 1; }

printf '%s\n' "$build_key" > "$site/LAST_VERSION"
touch "$site/.nojekyll"
