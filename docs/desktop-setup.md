# Desktop setup (Fedora, x86_64)

> Don't install Anthropic's official `claude-desktop` alongside this package. Both use `~/.config/Claude`, so run only one of them at a time.

## 1. Add the repository

```bash
sudo tee /etc/yum.repos.d/claude-desktop.repo >/dev/null <<'EOF'
[claude-desktop-local]
name=Claude Desktop (self-built, unofficial)
baseurl=https://bryan-rose.github.io/fedora-claude-repo/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://bryan-rose.github.io/fedora-claude-repo/RPM-GPG-KEY
EOF
```

## 2. Check and import the signing key

Download the key once into a private directory, then check that same file before rpm trusts it:

```bash
d=$(mktemp -d)
curl -fsSLo "$d/RPM-GPG-KEY" https://bryan-rose.github.io/fedora-claude-repo/RPM-GPG-KEY
gpg --show-keys "$d/RPM-GPG-KEY"
```

The fingerprint must be `5DAB838BDB269D9E0A1F5F63BB2FAD090BCEB63D` (see `docs/signing.md`), and it must be the **only** key listed. If either check fails, stop. Only then import it, in the same shell:

```bash
sudo rpm --import "$d/RPM-GPG-KEY"
rm -rf "$d"
```

## 3. Install

```bash
sudo dnf install claude-desktop-fedora
```

This pulls in `claude-desktop-unofficial` plus its runtime dependencies, including Cowork's recommended packages (bubblewrap, qemu-system-x86, edk2-ovmf, virtiofsd). Updates then arrive through `sudo dnf upgrade`.

## 4. Check

```bash
claude-desktop-unofficial --doctor
rpm -q --whatprovides /usr/bin/node    # "no package provides" = no Node.js. CI checks that these packages never pull it in;
                                       # a package listed here came from something else you installed.
```

## Removing

```bash
sudo dnf remove claude-desktop-fedora claude-desktop-unofficial
sudo rm /etc/yum.repos.d/claude-desktop.repo
```

Your data in `~/.config/Claude` and the launcher's cache in `~/.cache/claude-desktop-debian` are left in place.
