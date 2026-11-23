# Upstream audit: aaddrick/claude-desktop-debian

- **Reviewed tag:** `v3.3.18+claude6.28899.2`
- **Reviewed SHA:** `f7dd9c8441f0da7b50e5ba4c713134eef1bdbb0b` (the tag resolves to this commit; it was also upstream `main` at review time)
- **Date:** 2026-11-21
- **Scope:** `build.sh` and the `scripts/` files used by `--build rpm` (setup, patches, `packaging/rpm.sh`, launcher, doctor, Cowork fallback daemon). About 16.6k lines. The review searched for network access, privileged writes, and runtime behaviour. It did not trace every line. The patch scripts change minified JavaScript, which can only be fully judged by reading each patch's diff against the bundle.

## Build time (CI only, build job with no secrets)

| What | Where | Notes |
|---|---|---|
| Downloads the official `.deb` | `scripts/setup/official-deb.sh` | Skipped: we pass `--deb` with a file we verified ourselves. |
| May download Node.js | `scripts/setup/dependencies.sh:193-208` | Only if the system Node is older than v22.12. The SHA256 is checked against `SHASUMS256.txt` from the same host (nodejs.org), so this is integrity checking, not a signature. |
| `npm install @electron/asar@4.3.1` | `scripts/setup/dependencies.sh:262`, `scripts/_common.sh:114` | The top-level version is pinned, but there is **no lockfile**, so transitive dependencies resolve at build time. This is the least controlled input: asar repacks the shipped `app.asar`, so its output is signed, even though design D11 keeps the tool itself away from the signing key. `ci/build.sh` limits npm to versions published before the review date (`UPSTREAM_NPM_BEFORE` in `upstream.env`, exported as `npm_config_before`) and turns off install scripts (`npm_config_ignore_scripts`). |
| May `dnf install` missing build tools as root | `scripts/setup/dependencies.sh:57+` | A no-op if the workflow preinstalls the tools. Only the throwaway container is affected. |
| Writes | build work dir, `rpmbuild` topdir | Nothing else outside the checkout was found. |

## What ends up in the RPM

- `/usr/lib/claude-desktop-unofficial/`: Anthropic's `usr/lib/claude-desktop` tree, with **`app.asar` patched**. It also contains `launcher-common.sh`, `doctor.sh`, and `resources/cowork-vm-service.js`.
- `/usr/bin/claude-desktop-unofficial` (launcher), the `.desktop` file, AppStream metainfo, and icons.
- `chrome-sandbox` set to mode **4755 (setuid root)**. The official `.deb` ships the same bit; upstream restores it because its extraction strips it.
- `AutoReqProv: no` and no `Requires` (handled by our companion package).

### Active patches (`scripts/patches/app-asar.sh:61`)
`patch_quick_window`, `patch_org_plugins_path`, `patch_virtiofsd_probe`, `patch_cowork_firmware_probe`, `patch_cowork_bwrap`, `patch_tray_icon_env_override`, `patch_terminal_da_reply`. Each fails the build if it changes no bytes (no silent skips).

### Root scriptlets on the desktop
- `%post`: runs `update-desktop-database`. If none of the Debian-layout OVMF paths exist, it symlinks a matching edk2/qemu firmware pair into `/usr/share/OVMF/`. It removes a stale link of its own from older versions.
- `%postun` (erase only): removes only symlinks that no package owns and that point into `/usr/share/edk2` or `/usr/share/qemu`.

## Runtime behaviour of upstream code on the desktop

- **Launcher** (`launcher-common.sh`): makes no network calls. It writes:
  - logs and backups of `~/.config/Claude` JSON stores (five rotated copies) to `~/.cache/claude-desktop-debian/`;
  - a qemu shim under that cache directory, and a temporary fifo under `$TMPDIR`.
  It also repairs autostart and file-manager `.desktop` entries and the portal app-id entry in the user's directories, and kills stale or orphaned Claude helper and Cowork-daemon processes.
- **Doctor** (`--doctor`): one optional `curl` to Anthropic's APT `Packages` index to check for version drift.
- **Cowork fallback daemon** (`cowork-vm-service.js`): a Unix-socket server that spawns bwrap/qemu/virtiofsd. It does nothing unless launched with `COWORK_VM_BACKEND=bwrap`.

## Beyond the documented patches

Found: the launcher's config-backup, desktop-entry repair, and process-cleanup behaviour, and the setuid sandbox bit. All are documented in upstream's own docs and comments, and none touch the network. Not found: telemetry, update checks other than doctor's, or writes outside the user's home, `$TMPDIR`, and the firmware symlinks.

## Verdict

Acceptable to pin. Bump the pin only after reviewing `git diff <old>..<new> -- build.sh scripts/` (see `docs/pin-bump.md`).

## Skipped patches at this pin

- `patch_tray_icon_env_override`: its anchor (the `TrayIconLinux` ternary) is missing in `.deb` 6.28899.2, so the build fails. Upstream CI fails on the same commit. Skipping it only disables the `CLAUDE_TRAY_USE_DARK_ICON` override, which the launcher sets automatically only on Cinnamon. On KDE you get Anthropic's default tray-icon selection. Clear the skip when a pin bump brings a working patch. See design D13.
