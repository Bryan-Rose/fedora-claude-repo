# Design

## Context

- Anthropic publishes `claude-desktop` at `https://downloads.claude.ai/claude-desktop/apt/stable`. `dists/stable/InRelease` is clearsigned and lists SHA256s for uncompressed and gzipped `Packages` files for amd64 and arm64. `Packages` holds every historical version in ascending order (72 versions as of 2026-11-21). This URL was found in upstream's code and must still be confirmed against Anthropic's install docs.
- At any given commit, upstream `aaddrick/claude-desktop-debian` hardcodes one official `.deb` version and SHA256 in `scripts/setup/official-deb.sh`. Upstream bumps that roughly three times a week and tags each wrapper release (`v3.3.18+claude6.28899.2`). `build.sh` accepts `--deb <file>` to skip that pin, and `--release-tag <tag>` to put the wrapper version into the RPM Release.
- Upstream's patches fail the build when they become no-ops (since commit `afdc242`). Existing patches break on Anthropic releases about once a month, and upstream usually repairs them within days.
- Upstream's RPM sets `AutoReqProv: no` and declares no `Requires`. Cowork firmware paths are resolved in `%post` on the installing host, so the RPM does not depend on which Fedora release built it.
- Constraints from the user: trust Anthropic's builds without per-version review; run only aaddrick code that has been reviewed; never propose changes upstream; no Node.js on the desktop; x86_64 only.

## Goals / Non-Goals

**Goals:**
- Updates land without the user doing anything, as long as the reviewed patches still apply.
- Review is needed only when upstream's build-relevant code changes, and reviews can be batched.
- Every failure is visible as an issue and never reaches the desktop.

**Non-Goals:**
- Fixing broken patches ourselves (we wait for upstream, review, and bump the pin).
- Keeping the 60-day scheduled-workflow disable from happening. The user accepted this risk and will handle it if it occurs.
- Launching the app in CI (no display); `--doctor` runs on the desktop.

## Decisions

### D1. Anthropic's APT index decides what to build; the upstream pin decides how
The build feeds the newest verified `.deb` to upstream at the pin via `--deb`.
- *Rejected: build whatever upstream's pinned `.deb` is.* That needs a review for every app release (about three a week).
- *Rejected: repackage without upstream.* Cowork needs the sandbox and VM patches.
- *Rejected: vendor the patches.* Same review effort, but we'd own a build harness around them.
- Trade-off: reviewed patches run against newer app versions than upstream tested. Because no-op patches fail the build, the failure mode is a red build, not a silently broken package. D13 is the escape hatch when a non-essential patch breaks.

### D2. Verify like apt does, with an isolated keyring
`gpgv --keyring ./keys/anthropic-apt.gpg InRelease` → `sha256sum` of `Packages` against InRelease → `sha256sum` of the `.deb` against the Packages entry. Anthropic's key is committed to the repo (its fingerprint confirmed from Anthropic's docs) and is never imported into the signing keyring. This keeps it out of the exported `RPM-GPG-KEY`.

### D3. Rebuild key and package version
`LAST_VERSION` on gh-pages stores `<deb version>+<upstream SHA>`. The pin is expressed in the workflow as both `UPSTREAM_REF` (SHA) and `UPSTREAM_TAG`, and the build checks that the tag resolves to the SHA before building. Passing `--release-tag $UPSTREAM_TAG` yields Version `<deb version>`, Release `<wrapper version>.fc44`, so a pin-only bump still upgrades. Pins must therefore point at tagged commits.

### D4. Build once on Fedora 44, install-test on 44 and 45
One build job in `fedora:44`, followed by a matrix of install-test jobs (`fedora:44`, `fedora:45`) that run `dnf install ./*.rpm` and `rpm -V`. Publishing depends on all test jobs passing. Separate per-release builds were rejected because they produce identical files and would force `$releasever`-split repos. A new Fedora release is added to the test matrix by hand.

### D5. Companion package `claude-desktop-fedora`
A noarch spec in this repo (`packaging/claude-desktop-fedora.spec`). It requires `claude-desktop-unofficial` and the Fedora names of the `.deb` Depends (alternatives expressed as rich `(a or b)` dependencies), and recommends the Recommends: bubblewrap, socat, openssh-clients, qemu-system-x86, edk2-ovmf, virtiofsd, alsa-lib, libayatana-appindicator-gtk3, and a keyring. Its version is set in the spec and bumped by hand when the list changes. It is rebuilt and re-signed on every publish. Patching upstream's spec or rewriting its RPM was rejected (no upstream edits; too fragile).

### D6. Dependency drift check
`packaging/deb-deps.txt` records the `.deb`'s `Depends:` and `Recommends:` lines. Each build diffs the new `.deb`'s control fields against it. On a difference it opens or updates one "dependencies changed" issue and continues.

### D7. Signing
A dedicated RSA-4096 signing key, with no passphrase, generated on the desktop and stored only in Actions secrets `RPM_GPG_PRIVATE_KEY` and `RPM_GPG_NAME`, then deleted locally. Without a passphrase, no loopback-pinentry setup is needed in CI; anyone who could read one secret could read a passphrase secret too. `rpmsign --addsign` uses `%_gpg_name`. `repomd.xml` is detach-signed with `--armor`. The key is exported as `gpg --armor --export "$RPM_GPG_NAME"`.

### D8. Two workflows
- `build.yml`: daily cron plus `workflow_dispatch` (with a `force` input that bypasses the skip check, for key rotation and edits that don't change the build key, such as the companion spec or skip list). Stages run in order: discover → skip check → fetch → build → test matrix → publish. Publishing does retention (three newest per package name), `createrepo_c --update`, signing `repomd.xml`, and writing `LAST_VERSION`, all in one gh-pages commit.
- `upstream-watch.yml`: daily cron plus `workflow_dispatch`. It does a treeless clone of upstream and runs `git diff --quiet -I'^OFFICIAL_DEB_' "$UPSTREAM_REF" origin/main -- build.sh scripts/ ':!*.md'`. It then creates, updates, or closes the single labelled issue with `gh`.

Both workflows read the pin from one place (`upstream.env` in the repo) so a bump is a one-file commit.

### D9. Issues as the alerting channel
Failures, dependency drift, and upstream changes each use a distinct label (`build-failure`, `deps-drift`, `upstream-review`). Each label has at most one open issue, which gets updated rather than duplicated. Workflows need `issues: write` along with `contents: write`.

### D10. Container git hygiene
Set `git config --global --add safe.directory '*'` immediately after installing git and before any checkout, because git runs as root in the container on a runner-owned workspace.

### D11. Secrets live only in the publish job
The build runs code we did not write: upstream scripts at the pin, Anthropic's `.deb`, and npm's `@electron/asar` fetched at build time. So the job layout isolates secrets and write access:

```
 build    : no secrets, contents: read          --> unsigned RPMs as job artifacts
 test(N)  : no secrets, contents: read          --> install test on 44 / 45
 publish  : RPM_GPG_* secrets, contents: write, issues: write
            runs only this repo's own script; never executes upstream code
```

A compromised build input can then produce a bad unsigned RPM, but cannot read the signing key or push to `gh-pages`. (The publish job would still sign that RPM; this limits blast radius, not content.) The workflow-level default is `permissions: {}`, and each job declares only what it needs. Reporting jobs get `issues: write` only.
- *Rejected: a single job (the handoff draft).* Every build step could read the signing key.

### D12. Repository hardening
- Workflows trigger only on `schedule` and `workflow_dispatch`. **Never add `pull_request_target`** (or `pull_request` jobs with secrets); fork PRs must not run anything privileged.
- Only GitHub-owned actions are allowed, pinned by full commit SHA (enforced in repo settings since 2026-11-21).
- Rolling-issue lookup matches label **and** author `github-actions[bot]`, so an issue a stranger opens can't take the place of ours.
- Wiki and Projects are disabled; the repo description and README carry an "unofficial, not affiliated with Anthropic" disclaimer. The packages are publicly installable by design.

### D13. Per-pin patch skip list
`upstream.env` may set `UPSTREAM_SKIP_PATCHES` to a space-separated list of upstream patch function names. Before running `build.sh`, the build removes exactly those entries from `active_patches` in `scripts/patches/app-asar.sh` **in the local checkout only**. If a listed name is not currently an entry, the build fails, so a stale or mistyped skip can't pass silently. The skip list is reviewed and committed together with the pin, and cleared when a pin bump brings upstream's fix. This is the stopgap upstream's own error message recommends. It is the only local edit to upstream code we allow, and nothing is ever sent upstream.
- First use (2026-11-21): `patch_tray_icon_env_override` fails on `.deb` 6.28899.2; upstream's own CI is red on the same commit. It only makes `CLAUDE_TRAY_USE_DARK_ICON` work (Cinnamon dark panels); on KDE the result is Anthropic's default tray-icon selection.
- *Rejected: wait for upstream.* No package for an unknown number of days.
- *Rejected: pin an older tag and build its `.deb`.* That contradicts D1.

## Risks / Trade-offs

- [An Anthropic release breaks a patch, so the build stays red until upstream fixes it and the user reviews the fix] → The desktop keeps the last good version; the `build-failure` and `upstream-review` issues show both sides of it.
- [`git diff -I` might not hide every shape of upstream version-bump commit] → The first watcher runs are checked by hand against recent bump commits; widen the filter if needed.
- [Fedora package names in the companion spec are unverified] → The install tests on 44 and 45 fail on any wrong name before anything is published.
- [Anthropic changes their APT layout or key] → Verification fails closed and opens an issue.
- [The official `claude-desktop` and this package share `~/.config/Claude`] → Documented; don't install both.
- [Scheduled workflows are disabled after 60 days of inactivity] → Accepted by the user; no mitigation.
- [The build uses Fedora's `nodejs` in CI] → If it is older than v22.12, `build.sh` downloads its own (with checksum); either way only in CI.

## Migration Plan

New system, nothing to migrate. Rollout: confirm the APT URL and key → audit upstream and set the pin → generate the key and secrets → run `build.yml` manually and check gh-pages → run it again to confirm the early exit → configure the desktop and install `claude-desktop-fedora` → run `--doctor`. Rollback: disable the workflows; the desktop keeps the installed version, and `dnf downgrade` can use the three retained builds.
