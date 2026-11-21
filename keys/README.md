# Keys

## `anthropic-apt.gpg`

Anthropic's APT repository signing key, as a binary keyring for `gpgv --keyring`. CI uses it **only** to verify `dists/stable/InRelease`. It is never imported into the signing keyring and never published in `RPM-GPG-KEY`.

- Fingerprint: `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`
- UID: `Anthropic Claude Code Release Signing <security@anthropic.com>`
- Source: https://downloads.claude.ai/claude-desktop/key.asc (converted with `gpg --dearmor`)
- Fingerprint published at: https://code.claude.com/docs/en/desktop-linux
- Retrieved and checked: 2026-11-21. `gpgv` reported a good signature on `InRelease`.

To check: `gpg --show-keys keys/anthropic-apt.gpg` should print only that fingerprint.
