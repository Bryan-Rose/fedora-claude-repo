# Repository signing key

- **UID:** `fedora-claude-repo RPM signing key` (no email, because the public key is published)
- **Fingerprint:** `5DAB838BDB269D9E0A1F5F63BB2FAD090BCEB63D`
- **Type:** RSA-4096, signing only, no expiry, no passphrase (design D7)
- **Created:** 2026-11-22 (rotated from `7383AC1F9C19B3D4F33791D407E09944D89204D2`, created 2026-11-21, when the secrets moved to the `release` environment)

## Where it lives

| Item | Location |
|---|---|
| Private key (armored) | `release` environment secret `RPM_GPG_PRIVATE_KEY`, plus an offline backup kept by the owner outside the repo |
| Key name for `%_gpg_name` | `release` environment secret `RPM_GPG_NAME` (the UID above) |
| Public key | `RPM-GPG-KEY` on the Pages site, exported by name, containing only this key |
| Revocation certificate | Offline, kept by the owner outside the repo. Never commit it. |

Only the workflow's `publish` job reads these secrets (design D11). It runs in the `release` environment, whose deployments are limited to `main`, so a workflow on any other branch gets empty values. Never add them as repo-level secrets.

## Rotating the key (planned, or if the secret may have leaked)

1. Generate a new key in a throwaway `GNUPGHOME` (`gpg --quick-gen-key "<new uid>" rsa4096 sign never`, no passphrase). Keep the new revocation certificate from `$GNUPGHOME/openpgp-revocs.d/`.
2. Upload it: `gpg --armor --export-secret-keys "<new uid>" | gh secret set RPM_GPG_PRIVATE_KEY --env release`, then `printf '%s' "<new uid>" | gh secret set RPM_GPG_NAME --env release`. Back up the armored private key offline, then delete the throwaway `GNUPGHOME`.
3. Run `build.yml` with `workflow_dispatch`. Publishing re-signs the retained RPMs and `repomd.xml` and replaces `RPM-GPG-KEY`.
4. Update the fingerprint in this file.
5. On the desktop, re-import the key (below).

## Revoking (if the key is compromised)

1. Rotate first (above), so a trusted key is already in place.
2. On the desktop, remove the old key from rpm's keyring: `rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE} %{SUMMARY}\n'`, find the `fedora-claude-repo` entry, then `sudo rpm -e gpg-pubkey-<version>-<release>`.
3. Optionally publish the revocation: `gpg --import <revocation.asc>` onto a copy of the old public key, and publish that copy.

## Re-importing on the desktop

```bash
sudo rpm --import https://bryan-rose.github.io/fedora-claude-repo/RPM-GPG-KEY
sudo dnf clean metadata && sudo dnf makecache
```

dnf also offers to import the key from the repo file's `gpgkey=` the first time it sees a signature it doesn't know. Check the fingerprint above before accepting.
