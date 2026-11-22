# Spec Delta

## Purpose

Turns Anthropic's official Claude Desktop `.deb` into a verified, install-tested Fedora RPM, plus a companion dependency package, without ever running unreviewed third-party code.

## ADDED Requirements

### Requirement: Verified release discovery
The pipeline SHALL identify the newest x86_64 `claude-desktop` release by verifying Anthropic's signed APT `InRelease` against a public key file committed to this repository. It SHALL then check the `Packages` index against the SHA256 listed in `InRelease`, and choose the highest version by version-sort order.

#### Scenario: Newest version chosen from a multi-version index
- **WHEN** the `Packages` index lists many `claude-desktop` versions in ascending order
- **THEN** the pipeline selects the highest version, not the first entry

#### Scenario: Bad signature
- **WHEN** `InRelease` does not verify against the committed Anthropic key
- **THEN** the pipeline stops without building or publishing and reports the failure

#### Scenario: Tampered index
- **WHEN** the downloaded `Packages` file's SHA256 does not match the value in `InRelease`
- **THEN** the pipeline stops without building or publishing and reports the failure

### Requirement: Verified package download
The pipeline SHALL build only from a `.deb` whose SHA256 matches the value in the verified `Packages` index.

#### Scenario: Hash mismatch
- **WHEN** the downloaded `.deb`'s SHA256 differs from the verified index entry
- **THEN** the pipeline stops without building or publishing and reports the failure

### Requirement: Rebuild only on change
The pipeline SHALL build only when the pair (official `.deb` version, pinned upstream commit) differs from the pair recorded for the last successful publish. It SHALL record the pair only after a successful publish.

#### Scenario: Nothing changed
- **WHEN** a scheduled run finds the same `.deb` version and the same upstream pin as the last publish
- **THEN** the run exits early without building, signing, or pushing

#### Scenario: Pin bumped, same app version
- **WHEN** the upstream pin changes but the `.deb` version does not
- **THEN** the pipeline rebuilds and publishes

#### Scenario: Failed build is retried
- **WHEN** a build fails
- **THEN** the recorded pair is not updated, so the next scheduled run tries again

### Requirement: Build from reviewed upstream only
The pipeline SHALL build with the upstream tooling checked out at the pinned commit, and SHALL refuse to build if the pinned upstream tag does not resolve to the pinned commit SHA.

#### Scenario: Moved tag
- **WHEN** the pinned upstream tag points at a different commit than the pinned SHA
- **THEN** the pipeline stops without building and reports the mismatch

### Requirement: Reviewed patch skips
The pipeline SHALL omit an upstream patch only if that patch is named in the committed skip list alongside the pin. It SHALL fail the build if a listed name is not one of upstream's active patches at the pinned commit. Upstream code SHALL NOT be modified in any other way.

#### Scenario: Listed patch skipped
- **WHEN** the skip list names an active upstream patch
- **THEN** the build runs every other active patch and omits that one

#### Scenario: Stale skip entry
- **WHEN** the skip list names a patch that is not active at the pinned commit
- **THEN** the build stops without building and reports the unknown name

### Requirement: Upgradeable package versions
The produced `claude-desktop-unofficial` RPM SHALL carry a version-release that is higher than before whenever either the `.deb` version or the pinned upstream release increases, so `dnf upgrade` installs it.

#### Scenario: Wrapper-only bump
- **WHEN** the pin moves to a newer upstream release tag with the same `.deb` version
- **THEN** the new RPM's version-release compares greater than the previous one

### Requirement: Companion dependency package
The pipeline SHALL produce a noarch `claude-desktop-fedora` package. It SHALL require `claude-desktop-unofficial` and the Fedora equivalents of the official `.deb`'s Depends, and recommend the Fedora equivalents of its Recommends, including Cowork's runtime packages.

#### Scenario: One-command install
- **WHEN** the user runs `sudo dnf install claude-desktop-fedora` on a Fedora system with default weak-dependency settings
- **THEN** dnf installs `claude-desktop-unofficial` together with its required and recommended runtime packages

### Requirement: Install test before publish
Before publishing, the pipeline SHALL install both built packages in clean Fedora 44 and Fedora 45 environments and verify the installed files. It SHALL publish nothing if any of these checks fails.

#### Scenario: Dependency name missing on a release
- **WHEN** a package name required by `claude-desktop-fedora` does not exist on Fedora 45
- **THEN** the install test fails and nothing is published

### Requirement: Failure reporting
Any failure in discovery, verification, build, or install test SHALL open or update a GitHub issue that identifies the failed stage and links the run. The existing published repository SHALL remain unchanged.

#### Scenario: Patch no longer applies
- **WHEN** an upstream patch fails against a new `.deb`
- **THEN** an issue is opened or updated, and users keep the last good package

### Requirement: Dependency drift reporting
The pipeline SHALL compare the official `.deb`'s Depends and Recommends fields with a copy recorded in this repository, and open or update an issue when they differ. The difference SHALL NOT block the build.

#### Scenario: Anthropic adds a dependency
- **WHEN** a new `.deb` declares a Recommends entry missing from the recorded copy
- **THEN** an issue lists the difference and the build still proceeds

### Requirement: Host stays free of build tooling
Building SHALL happen only in CI containers. The desktop SHALL NOT need Node.js or any build tooling to install or update the app.

#### Scenario: Desktop install
- **WHEN** the user installs or upgrades from the repository
- **THEN** no Node.js package is installed on the desktop
