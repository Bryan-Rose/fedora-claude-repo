# Proposal

## Why

Anthropic ships Claude Desktop for Linux only as a `.deb`, so there is no supported way to install and update it on Fedora through `dnf`. We want a self-built, GPG-signed RPM published as a dnf repository, so updates arrive through a normal `sudo dnf upgrade`. Node.js must never be needed on the desktop, and no third-party code may ship unless it has been reviewed.

## What Changes

- Add a GitHub Actions pipeline, running in Fedora containers, that checks Anthropic's APT repository every day for a new Claude Desktop release. It verifies the release through the repository's signed chain (`InRelease` → `Packages` → `.deb`) and builds it only when the version or the reviewed upstream pin changes.
- Build the RPM with the community `aaddrick/claude-desktop-debian` tooling at a commit we have reviewed (the pin), feeding it the verified `.deb` (`--deb`) and the pinned upstream tag (`--release-tag`). That way a bump of the pin alone also gives dnf an upgrade.
- Add a companion `claude-desktop-fedora` noarch package that declares the runtime dependencies (Required and Recommended, including Cowork's) that the upstream RPM leaves out. The user installs this package.
- Install-test each build on Fedora 44 and Fedora 45 before publishing.
- Publish a signed dnf repository on GitHub Pages (`gh-pages`), using a dedicated signing key used only for this repository.
- Add a daily watcher that opens one rolling issue when upstream changes code that affects the build after our pin, so the user can review it and bump the pin.
- Open an issue on any failure, and when the `.deb`'s declared dependencies change. Never publish a partial or failed build.
- Document the one-time setup: signing key and secrets, and the desktop's repo file.

## Capabilities

### New Capabilities
- `rpm-build-pipeline`: discovering and verifying the official `.deb`, deciding when to rebuild, building the RPM and the companion dependency package, install-testing them, and reporting failures and dependency drift.
- `dnf-repo-publishing`: signing packages and repository metadata, retaining old builds, exporting the public key, and publishing to GitHub Pages so `dnf` on the desktop accepts the repository with GPG checks on.
- `upstream-watch`: detecting upstream changes after the reviewed pin that affect the build, and showing them to the user for review.

### Modified Capabilities

None. There are no existing specs.

## Impact

- New: `.github/workflows/` (build and watcher workflows), the companion package spec, the pinned Anthropic APT key file, the recorded `.deb` dependency fields, and setup docs.
- GitHub: the `gh-pages` branch content, Actions secrets `RPM_GPG_PRIVATE_KEY` and `RPM_GPG_NAME`, and issues opened by the workflows.
- Desktop: `/etc/yum.repos.d/claude-desktop.repo`, the imported public key, and the `claude-desktop-fedora` and `claude-desktop-unofficial` packages. No Node.js.
- External, read-only: Anthropic's APT repo (`downloads.claude.ai`) and `aaddrick/claude-desktop-debian`. We never send changes upstream.
- Out of scope: arm64, COPR, Flatpak/AppImage, and editing upstream code.
