# Claude Desktop RPM Pipeline — Claude Code Handoff

## Goal

Set up an automated pipeline that builds Claude Desktop as a signed RPM for my Fedora desktop and publishes it as a dnf repository, so updates arrive through a normal `sudo dnf upgrade`.

## Decisions already made

- **Format:** RPM (not AppImage, not Flatpak).
- **Build tooling:** the community project `aaddrick/claude-desktop-debian` (https://github.com/aaddrick/claude-desktop-debian). Its `build.sh` downloads Anthropic's official Linux `.deb`, unpacks it with ar + tar, applies a small set of Linux-gap patches to `app.asar`, adds a launcher and a `--doctor` tool, and repackages it. Build with `./build.sh --build rpm`.
- **Trust model:** build the RPM myself rather than use the project's prebuilt DNF repo. Pin the upstream repo to a specific commit that I have reviewed, and only bump the pin after reviewing changes.
- **Host hygiene:** Node.js and npm must not be installed on my host. They are build-time only (the app bundles its own Electron runtime), so all building happens in CI inside a Fedora container.
- **CI:** GitHub Actions.
- **Distribution:** a self-hosted dnf repo on GitHub Pages (gh-pages branch), with GPG-signed RPMs and signed repo metadata. COPR was considered and not chosen.

## Background facts

- Anthropic ships an official Claude Desktop Linux beta only as a `.deb` (amd64 and arm64) from its own APT repo. There is no official RPM.
- The community project names its package `claude-desktop-unofficial`. Its config lives at `~/.config/Claude/`.
- The build needs Node.js v22.12+. If the system Node is missing or too old, `build.sh` downloads a local copy into `build/`, and it npm-installs `@electron/asar` there too.
- Release cadence of the official `.deb` is unknown, so the workflow should check for a new version daily and only build when it changes.
- Build docs: https://github.com/aaddrick/claude-desktop-debian/blob/main/docs/building.md

## Tasks

1. **Audit upstream.** Clone `aaddrick/claude-desktop-debian`, read `build.sh`, the patch scripts and the launcher, and summarize anything that touches the network, writes outside the build directory, or changes the app beyond the documented patches. Record the reviewed commit SHA.
2. **Find the version source.** Locate Anthropic's official APT repo URL from their Linux install docs, and work out how to read the latest `claude-desktop` version from its `Packages` index. Do not guess this URL.
3. **Create the GitHub repo** that holds the workflow, with an orphan `gh-pages` branch, and enable GitHub Pages on that branch.
4. **Generate a dedicated RPM signing GPG key** (not my personal key). Store the private key and key name as Actions secrets: `RPM_GPG_PRIVATE_KEY` and `RPM_GPG_NAME`.
5. **Write the workflow** (draft below) and test it with `workflow_dispatch` before relying on the schedule.
6. **Configure my desktop.** Add `/etc/yum.repos.d/claude-desktop.repo` pointing at the Pages URL, import the public key, install the package, and run `claude-desktop-unofficial --doctor`.

## Draft workflow (starting point — verify and fix)

Runs daily in a `fedora:latest` container. Checks the latest upstream version against `LAST_VERSION` on gh-pages and exits early if unchanged. Otherwise it clones upstream at the pinned SHA, runs `./build.sh --build rpm --clean yes`, signs the RPM with `rpmsign`, copies it into `site/rpm/`, keeps the three newest builds, runs `createrepo_c --update`, detach-signs `repomd.xml`, exports the public key to `RPM-GPG-KEY`, writes `LAST_VERSION`, and pushes to gh-pages.

```yaml
name: claude-desktop-rpm
on:
  schedule:
    - cron: "0 9 * * *"
  workflow_dispatch: {}
permissions:
  contents: write
env:
  UPSTREAM_REPO: https://github.com/aaddrick/claude-desktop-debian.git
  UPSTREAM_REF: <commit-sha-you-audited>
  APT_PACKAGES_URL: <anthropic-apt-repo>/dists/stable/main/binary-amd64/Packages
jobs:
  build:
    runs-on: ubuntu-latest
    container: fedora:latest
    steps:
      - name: Install tools
        run: |
          dnf install -y git curl gzip nodejs rpm-build rpm-sign \
            createrepo_c gnupg2 binutils tar xz
      - name: Check latest upstream version
        id: ver
        run: |
          latest=$(curl -fsSL "$APT_PACKAGES_URL" \
            | awk '/^Package: claude-desktop$/{f=1} f&&/^Version:/{print $2; exit}')
          echo "latest=$latest" >> "$GITHUB_OUTPUT"
      - uses: actions/checkout@v4
        with:
          ref: gh-pages
          path: site
      - name: Skip if already built
        id: skip
        run: |
          if [ "$(cat site/LAST_VERSION 2>/dev/null)" = "${{ steps.ver.outputs.latest }}" ]; then
            echo "skip=true" >> "$GITHUB_OUTPUT"
          fi
      - name: Build RPM from pinned upstream
        if: steps.skip.outputs.skip != 'true'
        run: |
          git clone "$UPSTREAM_REPO" upstream
          cd upstream && git checkout "$UPSTREAM_REF"
          ./build.sh --build rpm --clean yes
      - name: Sign RPM
        if: steps.skip.outputs.skip != 'true'
        env:
          GPG_KEY: ${{ secrets.RPM_GPG_PRIVATE_KEY }}
          GPG_NAME: ${{ secrets.RPM_GPG_NAME }}
        run: |
          echo "$GPG_KEY" | gpg --batch --import
          echo "%_gpg_name $GPG_NAME" > ~/.rpmmacros
          rpmsign --addsign $(find upstream -name '*.rpm')
      - name: Update repo and publish
        if: steps.skip.outputs.skip != 'true'
        run: |
          mkdir -p site/rpm
          cp $(find upstream -name '*.rpm') site/rpm/
          ls -t site/rpm/*.rpm | tail -n +4 | xargs -r rm
          createrepo_c --update site/rpm
          gpg --batch --yes --detach-sign --armor site/rpm/repodata/repomd.xml
          gpg --armor --export > site/RPM-GPG-KEY
          echo "${{ steps.ver.outputs.latest }}" > site/LAST_VERSION
          cd site
          git config user.name "ci"; git config user.email "ci@users.noreply.github.com"
          git config --global --add safe.directory "$PWD"
          git add -A && git commit -m "claude-desktop ${{ steps.ver.outputs.latest }}" && git push
```

Client repo file (`/etc/yum.repos.d/claude-desktop.repo`):

```ini
[claude-desktop-local]
name=Claude Desktop (self-built)
baseurl=https://<you>.github.io/<repo>/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://<you>.github.io/<repo>/RPM-GPG-KEY
```

## Known risks to check

- The APT `Packages` index may be gzipped or at a different path. Confirm the real layout.
- `rpmsign` may need `gpg-agent` or loopback pinentry settings in a non-interactive container.
- The gh-pages checkout inside a container may need `safe.directory` set before git commands, not only before the push.
- The workflow only checks the upstream `.deb` version. A pin bump in `UPSTREAM_REF` alone won't trigger a rebuild. Add a manual override or include the SHA in the version key.
- The official `claude-desktop` and `claude-desktop-unofficial` share `~/.config/Claude`, so only one should run at a time.

## Done when

- A manual workflow run produces a signed RPM and a signed repo on GitHub Pages.
- A second run with no upstream change exits early.
- On my desktop, `sudo dnf install claude-desktop-unofficial` works with GPG checks on, the app launches, and `--doctor` reports no blocking issues.
- Node.js is not installed on the host.
