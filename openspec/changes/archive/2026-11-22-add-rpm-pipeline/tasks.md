# Tasks

## 1. Confirm inputs

- [x] 1.1 Confirm the APT base URL and the Anthropic signing key's URL and fingerprint from Anthropic's Linux install docs (not from upstream's code). Verify with `gpgv --keyring` that `dists/stable/InRelease` checks out against that key.
- [x] 1.2 Commit the key as `keys/anthropic-apt.gpg`, with its fingerprint and source URL in `keys/README.md`. Verify that `gpg --show-keys keys/anthropic-apt.gpg` prints the documented fingerprint.
- [x] 1.3 Audit upstream at its latest tag: `build.sh`, `scripts/` (patches, launcher, doctor, `packaging/rpm.sh`, setup). Write `docs/upstream-audit.md` covering network access, writes outside the build directory, and app changes beyond the documented patches. Verify the doc names the reviewed tag and SHA.
- [x] 1.4 Create `upstream.env` with `UPSTREAM_REPO`, `UPSTREAM_TAG` and `UPSTREAM_REF` from the audit. Verify that `git ls-remote` shows the tag resolves to the SHA.
- [x] 1.5 Add `UPSTREAM_SKIP_PATCHES=patch_tray_icon_env_override` to `upstream.env` with a comment giving the reason and the clear-when condition. Verify `docs/upstream-audit.md` records the skip.

## 2. Signing key and secrets

- [x] 2.1 Generate a dedicated RSA-4096 signing key with no passphrase, named for this repo, on the desktop. Store it as the Actions secrets `RPM_GPG_PRIVATE_KEY` and `RPM_GPG_NAME`, then delete the local private key. Verify that `gh secret list` shows both secrets.
- [x] 2.2 Document key rotation and revocation in `docs/signing.md`. Verify the doc lists the secret names and the steps for re-importing the key on the desktop.

## 3. Companion package

- [x] 3.1 Record the current `.deb` Depends and Recommends lines in `packaging/deb-deps.txt`. Verify the file matches the control fields of the newest `.deb`.
- [x] 3.2 Write `packaging/claude-desktop-fedora.spec` (noarch), mapping the Depends to `Requires` and the Recommends to `Recommends`, with alternatives as rich dependencies. Verify that `rpmbuild -bb` in a `fedora:44` container produces the package.

## 4. Build workflow

- [x] 4.0 Lay out `build.yml` jobs per design D11/D12: top-level `permissions: {}`, `schedule` + `workflow_dispatch` triggers only, GitHub-owned actions pinned by SHA, signing secrets referenced only in the `publish` job. Verify `grep -n 'secrets\.' .github/workflows/build.yml` hits only the publish job and the workflow has no `pull_request*` trigger.
- [x] 4.1 Add `.github/workflows/build.yml` with the discovery stage: verify InRelease, check the Packages hash, and select the highest version. Verify that a `workflow_dispatch` run logs the same version as the top `sort -V` entry.
- [x] 4.2 Add the skip check against `LAST_VERSION` (`<deb version>+<UPSTREAM_REF>`). Verify by temporarily writing the expected key to gh-pages and confirming the run exits early.
- [x] 4.3 Add the fetch and build stages: check the `.deb` hash, check that the tag matches the SHA, apply `UPSTREAM_SKIP_PATCHES` (design D13; fail on an unknown name), run `build.sh --build rpm --clean yes --deb <file> --release-tag $UPSTREAM_TAG`, build the companion package, and run the dependency-drift diff. Verify that the run's artifacts contain both RPMs and that `rpm -qp --qf '%{VERSION}-%{RELEASE}'` shows the deb version and wrapper release.
- [x] 4.4 Add an install-test matrix (`fedora:44`, `fedora:45`) running `dnf install ./*.rpm` and `rpm -V`. Verify both jobs pass, and that a deliberately wrong dependency name makes them fail.
- [x] 4.5 Add the publish stage, gated on the tests: sign the RPMs, keep the three newest per package name, upload new RPMs to the `packages` release, run `createrepo_c --baseurl` (design D14), write the armored `repomd.xml.asc`, export `RPM-GPG-KEY` by name, write `LAST_VERSION`, push one gh-pages commit, then prune release assets the metadata no longer lists. Verify `rpm -K` on the published RPMs, `gpg --verify` on `repomd.xml.asc`, and that `RPM-GPG-KEY` contains exactly one key.
- [x] 4.6 Add failure and drift reporting: one rolling issue per label (`build-failure`, `deps-drift`), matched by label and author `github-actions[bot]`, with the stage and a run link. Verify by forcing a failure, for example with a bad `.deb` hash: an issue opens, gh-pages is unchanged, and a second failure updates the same issue.

## 5. Upstream watch workflow

- [x] 5.1 Add `.github/workflows/upstream-watch.yml` running `git diff -I'^OFFICIAL_DEB_'` from `UPSTREAM_REF` to upstream `main` over `build.sh` and `scripts/`, excluding Markdown, and maintaining one `upstream-review` issue (matched by label and bot author) with a compare link, using `permissions: {contents: read, issues: write}` and no secrets. Verify that a run with an old pin opens the issue and a run with the pin at `main` closes it.
- [x] 5.2 Check the filter against upstream's recent "Update Claude Desktop to version …" commits. Verify that a diff spanning only such commits reports no change.
- [x] 5.3 Document the review-and-bump procedure in `docs/pin-bump.md`. Verify it covers reading the compare link, updating `upstream.env`, reviewing and clearing `UPSTREAM_SKIP_PATCHES`, and the rebuild that follows.

## 6. Desktop setup

- [x] 6.1 Write `docs/desktop-setup.md` covering `/etc/yum.repos.d/claude-desktop.repo` (`gpgcheck=1`, `repo_gpgcheck=1`), the key import, `sudo dnf install claude-desktop-fedora`, and the shared-`~/.config/Claude` warning. Verify each command in it runs as written on the desktop.
- [x] 6.2 Install on the desktop and run `claude-desktop-unofficial --doctor`. Verify that it reports no blocking issues, that Cowork's runtime packages are installed, and that no package provides `/usr/bin/node` because of these packages (CI: `rpm -q --whatprovides /usr/bin/node`; Fedora names Node `nodejs24` etc., so `rpm -q nodejs` proves nothing).

## 7. Integration checks

- [x] 7.1 Run `build.yml` manually twice with no upstream change. Verify the first run publishes and the second exits early without pushing.
- [ ] 7.2 Bump `upstream.env` to a newer upstream tag with the same `.deb` version. Verify a rebuild publishes and `sudo dnf upgrade` on the desktop picks it up. _Moved to #6; not done in this change._
