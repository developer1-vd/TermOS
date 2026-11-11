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
- **Anaconda installer** (Fedora's own) with its web UI, as **Install TermOS** on
  the live desktop.
- **The look:** Matrix-rain wallpaper (desktop and phone sizes), Plymouth boot
  splash and GRUB theme, all with the TermOS logo.
- **`termos-fetch`:** the Matrix logo with real stats, or a termite whose stats
  are all fortunes (`fortune | termos-fetch`).
- **Easter eggs:** see the README.
- **Editions for more hardware:**
  - **PC** (x86-64 ISO): PCs, laptops and x86-64 boards like the Radxa X4.
  - **ARM64** (aarch64 ISO): UEFI machines such as Snapdragon laptops, ARM
    servers and the Radxa Dragon Q6A/Q8B (with a boot entry for Qualcomm
    boards). Windows and macOS apps aren't available on ARM (no Wine or
    Darling there); FEX runs x86-64 Linux programs.
  - **ARM64 board** (disk image): Raspberry Pi 3/4/5, Radxa ROCK Pi 4 and other
    U-Boot boards.
  - **Phone:** Nura (formerly postmarketOS) with KDE Plasma Mobile and the TermOS
    look, for the OnePlus 6/6T, Pixel 3a, Fairphone 4, PinePhone, Librem 5,
    Galaxy S9, Poco F1, several Redmi Notes and more (see `phone/devices.txt`).
