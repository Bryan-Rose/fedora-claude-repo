# fedora-claude-repo

Self-built, GPG-signed Claude Desktop RPMs for Fedora, published as a dnf repository on GitHub Pages.

> [!WARNING]
> **Unofficial, with no affiliation to Anthropic.** This repository and its packages are not made, endorsed, or supported by Anthropic. Claude Desktop is Anthropic's proprietary software; these packages repackage Anthropic's official Linux `.deb` using the community [`aaddrick/claude-desktop-debian`](https://github.com/aaddrick/claude-desktop-debian) tooling at a reviewed commit.
>
> It is a personal build, published as-is with no warranty, no support, and no guarantee of updates. If you install from this repository you are trusting this repository's signing key and build. Use at your own risk. Please don't report problems with these packages to Anthropic or upstream.

## Status

The build, publish and upstream-watch pipeline is running. Its requirements are in [`openspec/specs/`](openspec/specs/); the original design and task list are archived in [`openspec/changes/archive/2026-11-22-add-rpm-pipeline/`](openspec/changes/archive/2026-11-22-add-rpm-pipeline/). Open work is tracked in [issues](https://github.com/Bryan-Rose/fedora-claude-repo/issues).
