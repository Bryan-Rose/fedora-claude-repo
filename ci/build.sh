#!/usr/bin/env bash
# Build claude-desktop-unofficial (upstream tooling at the reviewed pin, fed the
# verified official .deb) and the claude-desktop-fedora companion into ./out/.
# Runs in a throwaway Fedora container with no secrets (design D11).
# Needs env: deb_filename, deb_sha256 (from ci/discover.sh) and upstream.env.
# Writes out/deps-drift.diff if the .deb's Depends/Recommends changed.
set -euo pipefail

repo=$(pwd)
# shellcheck source=../upstream.env
source "$repo/upstream.env"
: "${deb_filename:?}" "${deb_sha256:?}"
base=${APT_BASE:-https://downloads.claude.ai/claude-desktop/apt/stable}
out="$repo/out"; work="$repo/work"
rm -rf "$out" "$work"; mkdir -p "$out" "$work"

echo "::group::Fetch official .deb"
deb="$work/${deb_filename##*/}"
curl -fsSL --retry 5 --retry-delay 15 -o "$deb" "$base/$deb_filename"
echo "$deb_sha256  $deb" | sha256sum -c - || { echo '.deb hash does not match verified Packages entry' >&2; exit 1; }
echo "::endgroup::"

echo "::group::Dependency drift check"
ar p "$deb" control.tar.xz | tar -xJO ./control | grep -E '^(Depends|Recommends):' > "$work/deb-deps.txt"
if ! diff -u "$repo/packaging/deb-deps.txt" "$work/deb-deps.txt" > "$out/deps-drift.diff"; then
	echo 'Dependencies changed (non-blocking):'; cat "$out/deps-drift.diff"
else
	rm -f "$out/deps-drift.diff"
fi
echo "::endgroup::"

echo "::group::Upstream at pinned commit"
git clone --quiet --filter=blob:none "$UPSTREAM_REPO" "$work/upstream"
cd "$work/upstream"
git checkout --quiet --detach "$UPSTREAM_REF"
tag_sha=$(git rev-parse "refs/tags/$UPSTREAM_TAG^{commit}")
[[ $tag_sha == "$UPSTREAM_REF" ]] \
	|| { echo "Tag $UPSTREAM_TAG -> $tag_sha, expected pinned $UPSTREAM_REF" >&2; exit 1; }
# Reviewed skip list (design D13): drop named entries from active_patches,
# failing on any name that isn't an entry. Local checkout only.
f=scripts/patches/app-asar.sh
for p in ${UPSTREAM_SKIP_PATCHES:-}; do
	[[ $p =~ ^[a-z_]+$ ]] || { echo "UPSTREAM_SKIP_PATCHES: bad name '$p'" >&2; exit 1; }
	sed -n '/^active_patches=(/,/^)/p' "$f" | grep -qxP "\s*\Q$p\E" \
		|| { echo "UPSTREAM_SKIP_PATCHES: '$p' is not in active_patches at $UPSTREAM_REF" >&2; exit 1; }
	sed -i "/^active_patches=(/,/^)/{/^[[:space:]]*${p}[[:space:]]*\$/d}" "$f"
	echo "Skipping upstream patch: $p"
done
echo "::endgroup::"

echo "::group::build.sh"
./build.sh --build rpm --clean yes --deb "$deb" --release-tag "$UPSTREAM_TAG"
shopt -s nullglob
rpms=(./claude-desktop-unofficial-*.rpm)
(( ${#rpms[@]} == 1 )) || { echo "Expected one RPM, found ${#rpms[@]}" >&2; exit 1; }
mv "${rpms[0]}" "$out/"
echo "::endgroup::"

echo "::group::Companion package"
cd "$repo"
rpmbuild -bb --quiet --define "_rpmdir $work/companion" packaging/claude-desktop-fedora.spec
mv "$work"/companion/noarch/*.rpm "$out/"
echo "::endgroup::"

for r in "$out"/*.rpm; do rpm -qp --qf '%{NAME} %{VERSION}-%{RELEASE}\n' "$r"; done
