# Changelog

## v0.1: the first release

TermOS v0.1 is based on **Fedora 45**.

- **Fedora + Ubuntu + Nix:** Fedora is the base system; Ubuntu software runs in
  a Distrobox container, and Nix is installed alongside `dnf`.
- **Run anything:** `termos-run` starts Windows apps (Wine), macOS apps
  (Darling), BSD apps (in a VM), Nix packages, Ubuntu `.deb` packages and Linux
  programs.
- **KDE Plasma** desktop, with Wine, Winetricks, Bottles, Lutris,
  Protontricks, Darling, QEMU/KVM, virt-manager, Flatpak and Flathub
  preinstalled.
- **Calamares installer** with TermOS branding and an install slideshow.
- **The look:** Matrix-rain wallpaper (desktop and phone sizes), Plymouth boot
  splash and GRUB theme, all with the TermOS logo.
- **`termos-fetch`:** the Matrix logo with real stats, or a termite whose stats
  are all fortunes (`fortune | termos-fetch`).
- **Easter eggs:** see the README.
