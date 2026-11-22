# Spec Delta

## Purpose

Tells the user when the upstream `aaddrick/claude-desktop-debian` code that affects the build has changed since the reviewed pin, so they can review it and bump the pin. Nothing is ever adopted automatically.

## ADDED Requirements

### Requirement: Detect build-relevant upstream changes
A daily check SHALL compare the pinned upstream commit with upstream `main`, limited to files that affect the build or the packaged output: `build.sh` and `scripts/`. It SHALL exclude `docs/`, `tests/`, `.github/`, and Markdown files.

#### Scenario: Patch changed upstream
- **WHEN** a commit after the pin modifies a file under `scripts/patches/`
- **THEN** the check reports a change

#### Scenario: Docs-only change
- **WHEN** commits after the pin touch only `docs/` or Markdown files
- **THEN** the check reports no change

### Requirement: Ignore upstream's app-version bumps
The check SHALL ignore commits where every changed line is part of upstream's pinned official `.deb` version block. Our pipeline supplies the `.deb` itself.

#### Scenario: Routine version bump
- **WHEN** the only upstream change after the pin updates the `OFFICIAL_DEB_*` lines
- **THEN** the check reports no change

### Requirement: One rolling review issue
When changes are found, the check SHALL keep exactly one open review issue. The issue SHALL be updated with the latest upstream commit and a compare link from the pin to that commit.

#### Scenario: Repeated daily detections
- **WHEN** the check finds changes on several consecutive days
- **THEN** one issue exists and shows the newest upstream commit and compare link

#### Scenario: Pin caught up
- **WHEN** the pin is bumped so that no build-relevant changes remain
- **THEN** the next check closes the review issue

### Requirement: No automatic adoption
The watcher SHALL NOT change the pin, the build, or the published repository, and SHALL NOT interact with the upstream project.

#### Scenario: Change detected
- **WHEN** the watcher finds upstream changes
- **THEN** the pin and builds stay unchanged until the user commits a new pin
