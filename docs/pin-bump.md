# Reviewing upstream and bumping the pin

The `upstream-watch` workflow keeps one open **upstream-review** issue whenever upstream's build-relevant code (`build.sh`, `scripts/`, excluding Markdown and upstream's own `.deb` version-pin lines) has moved past `upstream.env`.

## 1. Review

1. Open the issue's **Compare** link (`…/compare/<pin>...<main>`) and read the diff for `build.sh` and `scripts/`. Look out for:
   - new network access (`curl`, `wget`, `npm`, URLs) or new downloads;
   - writes outside the build directory, new `%post`/`%postun` root scriptlets in `scripts/packaging/rpm.sh`;
   - launcher (`scripts/launcher-common.sh`) or doctor changes that run on your desktop;
   - new entries in `active_patches` (`scripts/patches/app-asar.sh`) and what each one changes.
2. Pick the **newest tag** at or before the commit you're happy with. Pins must be tagged commits, because the tag becomes the RPM Release:
   ```bash
   git ls-remote --tags https://github.com/aaddrick/claude-desktop-debian.git | tail
   ```

## 2. Update `upstream.env`

```bash
UPSTREAM_TAG=<new tag>
UPSTREAM_REF=<commit the tag points to>   # the line ending in ^{} from: git ls-remote <repo> "refs/tags/<tag>^{}"
UPSTREAM_NPM_BEFORE=<review date, YYYY-MM-DD>   # npm only resolves versions published before it
```

Then review `UPSTREAM_SKIP_PATCHES`:
- If the bump brings a fix for a skipped patch, **remove it from the list**. An entry stays only while that patch still fails against the current `.deb`.
- If a newly broken, non-essential patch blocks the build, you may add it, with a comment giving the reason and the clear-when condition (design D13).
- The build fails if a listed name is no longer in `active_patches`, so stale entries surface on their own.

Update `docs/upstream-audit.md` with the new tag/SHA and anything notable from the review.

## 3. Commit and rebuild

```bash
git commit -am "Bump upstream pin to <tag>"
git push
gh workflow run build.yml
```

The build key includes `UPSTREAM_REF`, so the next run rebuilds even if Anthropic's `.deb` hasn't changed. The new tag raises the RPM Release, so `sudo dnf upgrade` picks it up. The next `upstream-watch` run closes the review issue once nothing build-relevant remains.

## Changes that need a forced build

Changes to `UPSTREAM_SKIP_PATCHES` alone (same pin) or to `packaging/claude-desktop-fedora.spec` don't change the build key. Run `gh workflow run build.yml -f force=true` after committing them, and bump the companion's `Version` so dnf upgrades it.
