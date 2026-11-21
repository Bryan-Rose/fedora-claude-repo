# Spec Delta

## Purpose

Publishes the built packages as a GPG-signed dnf repository on GitHub Pages, so a Fedora desktop can install and upgrade them with signature and metadata checks enabled.

## ADDED Requirements

### Requirement: Signed packages
Every published RPM SHALL be signed with the dedicated signing key for this repository. That key SHALL NOT be used for anything else.

#### Scenario: Signature check on install
- **WHEN** dnf installs a package from the repository with `gpgcheck=1`
- **THEN** the signature verifies against the repository's published public key

### Requirement: Signed repository metadata
The repository's `repomd.xml` SHALL have an ASCII-armored detached signature made with the same key, regenerated on every publish.

#### Scenario: Metadata check
- **WHEN** dnf refreshes the repository with `repo_gpgcheck=1`
- **THEN** the metadata signature verifies

### Requirement: Public key contains only the repository key
The published `RPM-GPG-KEY` SHALL contain exactly one public key, the repository's own signing key. Keys used only for verifying inputs (such as Anthropic's APT key) SHALL NOT appear in it.

#### Scenario: Importing the key
- **WHEN** the user imports `RPM-GPG-KEY` on the desktop
- **THEN** exactly one key, the repository signing key, becomes trusted

### Requirement: Retention
The repository SHALL keep the three newest RPMs of each package name and remove older ones, and its metadata SHALL list only the RPMs present.

#### Scenario: Fourth build
- **WHEN** a fourth `claude-desktop-unofficial` build is published
- **THEN** the oldest `claude-desktop-unofficial` RPM is removed and the `claude-desktop-fedora` RPMs are unaffected

### Requirement: GitHub Pages layout
The repository SHALL be served from the `gh-pages` branch at `https://bryan-rose.github.io/fedora-claude-repo/`, with packages and metadata under `rpm/` and the public key at `RPM-GPG-KEY`.

#### Scenario: Client configuration
- **WHEN** the desktop's repo file sets `baseurl` to `<pages-url>/rpm` and `gpgkey` to `<pages-url>/RPM-GPG-KEY` with `gpgcheck=1` and `repo_gpgcheck=1`
- **THEN** `sudo dnf install claude-desktop-fedora` succeeds

### Requirement: Atomic publish
A publish SHALL update packages, metadata, metadata signature, and the recorded build pair together in a single commit to `gh-pages`. It SHALL NOT leave a state where the metadata and its signature disagree.

#### Scenario: Push failure
- **WHEN** pushing to `gh-pages` fails
- **THEN** the previously published repository stays intact and the run is reported as failed
