#!/usr/bin/env bash
# Report build-relevant upstream changes after the reviewed pin (upstream-watch spec).
# Exit 0 and print nothing if none; otherwise print a Markdown summary.
# Usage: ci/watch.sh [upstream-clone-dir]
set -euo pipefail
source upstream.env
dir=${1:-$(mktemp -d)/upstream}
[[ -d $dir/.git ]] || git clone -q --filter=blob:none --no-checkout "$UPSTREAM_REPO" "$dir"
git -C "$dir" fetch -q origin main
head=$(git -C "$dir" rev-parse origin/main)
paths=(build.sh scripts/ ':(exclude)*.md')
# -I drops hunks whose changed lines all match: upstream's .deb version pin bumps.
if git -C "$dir" diff --quiet -I'^OFFICIAL_DEB_' "$UPSTREAM_REF" "$head" -- "${paths[@]}"; then
	exit 0
fi
base=${UPSTREAM_REPO%.git}
cat <<MD
Upstream changed build-relevant code since the reviewed pin. Review it, then bump \`upstream.env\` (see \`docs/pin-bump.md\`).

- Pin: \`$UPSTREAM_TAG\` (\`${UPSTREAM_REF:0:12}\`)
- Upstream main: \`${head:0:12}\`
- Compare: $base/compare/$UPSTREAM_REF...$head
- Skipped patches at the pin: \`${UPSTREAM_SKIP_PATCHES:-none}\`

Changed files (excluding version-pin-only edits):
\`\`\`
$(git -C "$dir" diff --stat=100 -I'^OFFICIAL_DEB_' "$UPSTREAM_REF" "$head" -- "${paths[@]}")
\`\`\`
MD
