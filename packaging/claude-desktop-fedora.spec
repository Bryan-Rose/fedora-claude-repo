# Runtime dependencies that upstream's claude-desktop-unofficial RPM leaves out
# (it sets AutoReqProv: no and has no Requires). Mirrors the official .deb's
# Depends/Recommends recorded in deb-deps.txt; bump Version when the list changes.
Name:           claude-desktop-fedora
Version:        1.1
Release:        1
Summary:        Fedora runtime dependencies for claude-desktop-unofficial
License:        MIT
URL:            https://github.com/Bryan-Rose/fedora-claude-repo
BuildArch:      noarch

Requires:       claude-desktop-unofficial
# Debian Depends
Requires:       gtk3
Requires:       libnotify
Requires:       nss
Requires:       xdg-utils
Requires:       at-spi2-core
Requires:       libdrm
Requires:       mesa-libgbm
Requires:       libxcb
Requires:       libsecret
Requires:       (glib2 or trash-cli)
Requires:       glibc >= 2.34
Requires:       libXtst
Requires:       libuuid
Requires:       pipewire-libs
Requires:       xdg-desktop-portal
Requires:       (xdg-desktop-portal-gtk or xdg-desktop-portal-gnome or xdg-desktop-portal-kde)
# Debian Recommends (installed by default; Cowork needs the second group)
Recommends:     (alsa-lib or pipewire-alsa)
Recommends:     (libayatana-appindicator-gtk3 or libappindicator-gtk3)
Recommends:     ca-certificates
Recommends:     (gnome-keyring or kf6-kwallet)
Recommends:     bubblewrap
Recommends:     socat
Recommends:     openssh-clients
Recommends:     qemu-system-x86
Recommends:     edk2-ovmf
Recommends:     virtiofsd

%description
Metapackage that pulls in claude-desktop-unofficial together with the Fedora
equivalents of the official Claude Desktop .deb's runtime dependencies,
including Cowork's (bubblewrap, qemu, edk2-ovmf, virtiofsd).

Also keeps Chromium's sandbox on under Wayland: upstream's launcher passes
--no-sandbox there for an Ubuntu AppArmor issue that Fedora doesn't have.

Unofficial; not affiliated with or endorsed by Anthropic.

%install
# Read by the systemd user session at login; a user's own environment.d entry
# or an explicit CLAUDE_FORCE_SANDBOX= still overrides it.
install -d %{buildroot}%{_prefix}/lib/environment.d
echo 'CLAUDE_FORCE_SANDBOX=1' > %{buildroot}%{_prefix}/lib/environment.d/60-claude-desktop-fedora.conf

%files
%{_prefix}/lib/environment.d/60-claude-desktop-fedora.conf

%changelog
* Sun Nov 22 2026 fedora-claude-repo <noreply@github.com> - 1.1-1
- Keep Chromium's sandbox on under Wayland (CLAUDE_FORCE_SANDBOX=1 via environment.d)

* Sat Nov 21 2026 fedora-claude-repo <noreply@github.com> - 1.0-1
- Initial package
