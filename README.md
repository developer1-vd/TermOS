# TermOS

TermOS is a Linux distribution that combines **Fedora**, **Ubuntu** and **Nix**, and also runs **Windows**, **macOS** and **BSD** apps.

> The name doesn't mean anything. It's not a terminal OS. TermOS is just a cool name.

**Current release: TermOS v0.1**, the first release, based on **Fedora 45**.
See [CHANGELOG.md](CHANGELOG.md) for what's in it.

**Website:** https://developer1-vd.github.io/TermOS/ (the site's source is in `docs/`).

## Editions and hardware

Every edition is on the [releases page](https://github.com/developer1-vd/TermOS/releases).
Files over 2 GiB come in parts (`.part0`, `.part1`, ...): download them all and join
them with `cat`, as the release notes show.

| Edition | File | Runs on |
| ------- | ---- | ------- |
| **PC** (x86-64 live ISO) | `TermOS-0.1-x86_64.iso` | PCs and laptops (BIOS or UEFI), and x86-64 boards such as the **Radxa X4** and X2L, which are ordinary UEFI PCs: boot the ISO from USB and install to the board's eMMC or NVMe |
| **ARM64** (aarch64 live ISO) | `TermOS-0.1-aarch64.iso` | ARM machines with UEFI firmware: Snapdragon X laptops (as far as Fedora's kernel supports them), ARM servers and VMs, and boards that ship UEFI firmware, such as the **Radxa Dragon** series (see below) and **Radxa Orion O6** (or a ROCK 5 with Radxa's UEFI firmware) |
| **ARM64 board** (disk image) | `TermOS-0.1-aarch64-board.raw.xz` | Single-board computers that boot from an SD card or disk: **Raspberry Pi 3, 4, 400 and 5** (Pi 5 as far as Fedora supports it), **Radxa ROCK Pi 4** boards and other boards with U-Boot (put U-Boot in the board's SPI flash, as Fedora recommends for Rockchip boards) |
| **Phone** (Nura + Plasma Mobile) | `TermOS-0.1-phone-<codename>.tar.xz` | The phones in [`phone/devices.txt`](phone/devices.txt), such as the OnePlus 6/6T, Pixel 3a, Fairphone 4, PinePhone, Librem 5, Galaxy S9, Poco F1 and several **Redmi Notes** (4X, 5 Pro, 6 Pro, 7, 8 Pro, 9S/9 Pro, 10 Pro) |

**ARM editions** are the same TermOS (Fedora, KDE Plasma, Nix, Distrobox and the
TermOS look), minus what only exists for x86-64 PCs: Fedora doesn't build Wine for
ARM, so Windows apps need an x86-64 PC, and Darling (macOS apps) is x86-64 only.
FEX runs x86-64 Linux programs on ARM instead.

The **board image** has no installer: write it to an SD card or disk, and the first
boot asks for your user name and password (KDE's Plasma Setup):

```bash
xz -d TermOS-0.1-aarch64-board.raw.xz
```

```bash
sudo arm-image-installer --image=TermOS-0.1-aarch64-board.raw --media=/dev/sdX --resizefs
```

(`arm-image-installer` is Fedora's; Fedora Media Writer or `dd` work too, without
growing the root file system to fill the card.)

### Radxa Dragon series

The Dragon boards are Qualcomm boards with UEFI firmware (Radxa's "BIOS") on their
own flash chip, which passes the board's device tree to the OS. TermOS boots on them
like on a PC:

| Board | Chip | Status |
| ----- | ---- | ------ |
| **Dragon Q6A** | Qualcomm QCS6490 | Supported: Fedora's kernel has this board's device tree (`qcs6490-radxa-dragon-q6a`) |
| **Dragon Q8B** | Snapdragon 8cx Gen 3 (SC8280XP) | Experimental: Fedora's kernel supports the chip (it runs the ThinkPad X13s), but has no device tree for this board, so it relies on the one from Radxa's firmware |

1. Update the board's firmware to Radxa's latest first (see Radxa's
   [Dragon docs](https://docs.radxa.com/en/dragon); newer firmware is what generic
   distributions need).
2. Write the **ARM64 ISO** to a USB stick, pick it in the firmware's Boot Manager,
   and choose **Start TermOS 0.1 on a Qualcomm board**. That entry adds
   `clk_ignore_unused pd_ignore_unused`, which Qualcomm boards need, and the
   installer keeps them on the installed system. Install to the board's NVMe, UFS
   or eMMC.
3. Or write the **board image** to a microSD card, UFS module or NVMe drive. Its boot
   entries don't have those two arguments; if it stops during boot, press `e` in the
   GRUB menu, add them to the `linux` line, and once booted make them permanent:

```bash
sudo grubby --update-kernel=ALL --args="clk_ignore_unused pd_ignore_unused"
```

These boards haven't been tested on hardware with TermOS yet; the ISO and board
image are tested in an emulated ARM machine.

**The phone edition** is different underneath: phones need kernels and drivers
made for each phone, which Fedora doesn't have, so it's built on
**[Nura](https://nura.eco/)** (formerly postmarketOS) with **KDE Plasma Mobile**,
plus TermOS's Matrix wallpaper (phone sizes), `termos-fetch` (Matrix and termite
modes) and the TermOS fortunes. Each phone's file has its image(s) and a
`FLASHING.txt`; log in as `termos` with the PIN `837667` (TERMOS on a phone keypad)
and change it afterwards. Flashing erases the phone. Check the phone's page on the
[Nura wiki](https://wiki.nura.eco/) first. Phones marked "testing" in
`phone/devices.txt` work, but with rough edges.

Not possible: **iPhones** (Apple locks the bootloader, so no Linux runs on them)
and the **Samsung Galaxy Z Fold** series (there's no Linux port for them).

## The three parts

| Part       | What TermOS takes from it                                                   |
| ---------- | --------------------------------------------------------------------------- |
| **Fedora** | The base system: kernel, `dnf` and RPM packages, `systemd`, SELinux, Btrfs, `firewalld`, and the six-month release cycle. |
| **Ubuntu** | Friendly defaults, an easy first boot, and access to Ubuntu/Debian software (`.deb` packages run in a Distrobox Ubuntu container). |
| **Nix**    | The Nix package manager, installed alongside `dnf`, for declarative and reproducible per-user setups, plus nixpkgs' huge package set. |

Because Fedora is the base, `dnf` is the system package manager. Nix and the Ubuntu
container are extra layers you can install software from, and they don't replace it.

```bash
sudo dnf install htop                    # Fedora (system)
nix profile install nixpkgs#ripgrep      # Nix (per-user, reproducible)
distrobox enter ubuntu -- sudo apt install cowsay   # Ubuntu (container)
```

## Running apps from anywhere

`termos-run` runs **Windows**, **macOS**, **BSD**, **Nix**, **Ubuntu** and **Linux**
apps. It checks what you gave it and sends it to the right place:

| App type                                  | How TermOS runs it                                   |
| ----------------------------------------- | ---------------------------------------------------- |
| Windows (`.exe`, `.msi`)                  | [Wine](https://www.winehq.org/), in its own prefix at `~/.local/share/termos/wine` |
| Windows games                             | Steam with Proton, or Bottles (Flatpak)              |
| macOS (Mach-O binaries, `.app` bundles)   | [Darling](https://www.darlinghq.org/) if installed, otherwise a Mac over SSH |
| macOS installers (`.pkg`, `.dmg`)         | Darling                                              |
| BSD (FreeBSD, NetBSD, OpenBSD, DragonFly) | Copied to a BSD virtual machine and run there over SSH |
| Nix (`nix:hello`, `nixpkgs#hello`, a folder with `flake.nix`) | `nix run`, with nothing installed permanently |
| Ubuntu (`.deb`)                           | Installed in the Ubuntu Distrobox container          |
| Linux                                     | Run directly                                         |

```bash
termos-run notepad++.exe
termos-run ./SomeTool.app
termos-run ./freebsd-tool --help
termos-run nix:cowsay moo
termos-run github:owner/repo
```

**About macOS:** Darling is a compatibility layer for macOS apps, much like Wine is
for Windows apps. The TermOS ISO comes with it preinstalled (from the community
`medzik/darling` COPR, since Darling isn't in Fedora's own repos). It's still experimental: command-line tools work best, and most
graphical apps don't run yet. If Darling isn't installed, `termos-run` copies the
app to a real Mac and runs it there over SSH. Set `TERMOS_MAC_HOST` to that Mac's
SSH host (default: `termos-mac`). TermOS doesn't ship a macOS virtual machine,
because Apple's license only allows macOS to run on Apple hardware.

**About BSD:** BSD programs can't run on the Linux kernel. Linux has no
compatibility layer for them, so TermOS runs them on a real BSD system in a VM.
Create a FreeBSD (or other BSD) guest in virt-manager (preinstalled on the ISO), enable SSH,
and set `TERMOS_BSD_HOST` to its SSH host (default: `termos-bsd`). Many BSD tools
are also packaged for Linux, so check `dnf search` or nixpkgs first.

**About Nix:** `termos-run nix:<name>` runs any package from nixpkgs without
installing it, and any flake reference (`nixpkgs#hello`, `github:owner/repo`) or
local folder with a `flake.nix` works too. To install Nix on Fedora, see
[nixos.org/download](https://nixos.org/download).

```bash
sudo dnf install wine distrobox openssh-clients
```

## The logo

TermOS has two logos, and which one you see depends on how you run the system-info tool.

### Matrix (default)

`fastfetch`, `neofetch` and `termos-fetch` all show TermOS's logo, which is green
Matrix-style digital rain:

```
 1   0 1    0   1  0    1
 0 1 1 0  1 1 0 1  1  0 1
 1 0 0 1  0 0 1 0  0  1 1
 0 1   0  1   0 1  1  0 0
 1 0 1 1  0 1 1 0  0  1 0
   1 0 0  1 0   1  1  0 1
 0 0 1 1  0 1 0 0  1    1
 1 1 0    1 0 1 1  0  1 0
 0   1 0  0 1 0    1  0 1
 1 0 0 1    1 1 0  0  1
   1 1 0  1 0   1  1    0
 0     1    0   0     1
```

### Termite (fortune mode)

Pipe `fortune` into it and TermOS turns into a termite, and every stat becomes a fortune:

```bash
fortune | termos-fetch
```

```
        \     /       termite@TermOS
         \___/        -----------------
       .-(o o)-.      OS: You will be fortunate.
      /  `-^-'  \     Host: Beware of low-flying butterflies.
     /|  (___)  |\    Kernel: A closed mouth gathers no foot.
    / |  (   )  | \   Uptime: You will soon meet a termite.
      |  (___)  |     Packages: Today is a good day to compile.
     /   (   )   \    Shell: The bug is in the other file.
    /    (___)    \   Terminal: Nothing is as permanent as a temporary fix.
          ( )         CPU: Your lucky number is 0x1F.
          `-'         Memory: You forgot something. You'll remember later.
```

The fortunes above are examples. `termos-fetch --fortune` does the same thing and
runs `fortune` itself. If you pipe in fewer fortunes than there are stats, it gets
more from `fortune` (or repeats yours if `fortune` isn't installed).

## Wallpaper and boot splash

TermOS has its own wallpaper, boot splash and GRUB theme, all green Matrix-style
rain behind the TermOS logo.

- **Wallpaper:** comes in desktop sizes (3840×2160 and 1920×1080) and phone sizes
  (1440×3200 and 1080×2400). On the ISO it's the default for the KDE desktop and
  the lock screen, and KDE picks the right size for each screen, including
  portrait ones. The phone sizes in `branding/wallpaper/contents/images/` work
  as phone wallpapers too.
- **Boot splash:** a Plymouth theme where the rain keeps falling while the system
  boots, with a progress bar under the logo and a matching prompt for encrypted
  disks.

- **GRUB theme:** the boot menu gets the same look, with the TermOS logo over the
  rain, a framed green menu and a countdown bar. The theme turns on GRUB's
  graphical mode and keeps the menu visible for 5 seconds, since Fedora normally
  hides it.

The images are generated by `branding/make-art.py`. Run `make art` to rebuild them
after changing it.

To use them on an existing Fedora install:

```bash
sudo dnf install plymouth-plugin-script plymouth-plugin-label
```

```bash
sudo make install install-splash
```

```bash
sudo dnf install grub2-tools-extra dejavu-sans-mono-fonts
```

```bash
sudo make install-grub
```

Then choose **TermOS** in System Settings → Wallpaper.

## Easter eggs

TermOS has a few easter eggs hidden around the system. Hint: follow the white
rabbit, and don't forget to check the date.

<details>
<summary>Spoilers</summary>

- `termos-fetch --rain`: green digital rain in your terminal. Press any key to stop.
- `termos-fetch --red-pill` (or `termos-run red-pill`): wake up, Neo... then the rain.
- `termos-fetch --blue-pill`: the story ends.
- `termos-fetch --spoon`: there isn't one.
- `termos-run termite`, `termos-run teapot`, `termos-run termos-run`, `termos-run rabbit`:
  try them.
- `fortune termos`: TermOS's own fortunes. They also turn up now and then in
  termite mode (`fortune | termos-fetch`).
- On **April 1**, `termos-fetch` shows the termite instead of the Matrix logo.
- On **November 5**, TermOS's birthday, `termos-fetch` wishes it a happy birthday.
  (Set `TERMOS_TODAY=04-01` or `11-05` to see them any day.)
- At the **GRUB boot menu**, press `c` for the command line and type `rabbit`.

</details>

## Building the ISO

TermOS builds a bootable live ISO from Fedora with a kickstart file
(`iso/termos.ks.in`) and Fedora's `livemedia-creator`. The live session boots
into **KDE Plasma**. To install TermOS to disk, double-click **Install TermOS** on
the desktop.

## The installer

TermOS installs with Fedora's own installer, Anaconda, using its web UI (on KDE
it runs in Slitherer, a small Qt web view). Double-click **Install TermOS** on the
live desktop. It walks you through language, disks (including encryption) and
creating your user, then copies the live system to disk.

Anaconda takes care of the details that make an install boot on any machine: the
disk layout (with a BIOS boot partition on BIOS machines and an EFI partition on
UEFI ones), boot menu entries that match the installed disk, and SELinux labels.
The installed system keeps the TermOS boot splash, GRUB theme, wallpaper, name and
preinstalled apps, and the temporary live user isn't copied to it.

Preinstalled on the ISO:

| For             | Preinstalled                                                       |
| --------------- | ------------------------------------------------------------------ |
| Desktop         | Fedora with KDE Plasma and the KDE apps                            |
| Windows apps    | Wine (with Mono, Gecko and DXVK), Winetricks, Bottles, Lutris, Protontricks |
| macOS apps      | Darling                                                            |
| BSD apps        | QEMU/KVM and virt-manager, for running a BSD VM                    |
| Ubuntu apps     | Distrobox and Podman                                               |
| Nix apps        | Nix, with the Nix daemon enabled                                   |
| Everything else | Flatpak with Flathub                                               |
| TermOS          | `termos-fetch`, `termos-run`, fastfetch (Matrix logo) and fortune  |
| Look            | The TermOS wallpaper, boot splash and GRUB theme                   |
| Installer       | Anaconda (Fedora's installer) with its web UI                      |

Darling is built by the community, not Fedora. If it can't be installed when the
ISO is built, the build carries on without it and prints a warning. To leave it
out on purpose, set `TERMOS_DARLING=0`.

**On Fedora:**

```bash
sudo dnf install lorax anaconda-tui
```

```bash
make iso
```

**On any Linux with Podman or Docker** (builds inside a Fedora container):

```bash
make iso-container
```

The ISO is written to `build/out/TermOS-<version>-x86_64.iso` (for v0.1,
`TermOS-0.1-x86_64.iso`). A build needs
root (or a privileged container), about 15 GB of free disk space and a network
connection to the Fedora mirrors. The build machine's kernel also needs loop
devices and FAT (vfat) support, which normal Fedora installs and GitHub's runners
have; some minimal VMs and sandboxes don't, and the build then fails at the
`mkefiboot` step.

TermOS v0.1 is based on Fedora 45. To try a different Fedora release, set
`TERMOS_RELEASE`:

```bash
TERMOS_RELEASE=46 make iso-container
```

To write the ISO to a USB stick, use Fedora Media Writer, or `dd` (this erases the
stick, so double-check the device name):

```bash
sudo dd if=build/out/TermOS-0.1-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

You can also build ISOs from GitHub: run the **Build ISO** workflow from the
Actions tab, and it uploads the ISO as a workflow artifact.

### ARM64

The same script builds the ARM editions. The build runs natively, so run it on an
ARM64 machine (GitHub's `ubuntu-24.04-arm` runners work):

```bash
TERMOS_ARCH=aarch64 make iso-container
```

```bash
make board
```

The first writes `build/out/TermOS-0.1-aarch64.iso`; the second (`TERMOS_IMAGE=disk`)
writes the board image, `build/out/TermOS-0.1-aarch64-board.raw.xz`. The board
image is a 22 GB disk (write it to a 32 GB card or bigger) with an MBR partition table, the Raspberry Pi firmware and
U-Boot on its EFI partition, and GRUB.

### Phones

```bash
make phone DEVICE=oneplus-enchilada
```

`phone/build-phone.sh` builds one phone's image with Nura's `pmbootstrap`. It
packages TermOS's files as `termos-phone`, an Alpine package added to Nura's
package tree. It runs as a normal user with `sudo`, on an ARM64 machine, and
writes `build/out/TermOS-0.1-phone-<codename>.tar.xz`. The phone list and each
phone's Nura codename are in `phone/devices.txt`.

### The Build ISO workflow

**Build ISO** (Actions tab) builds the editions you pick (`all`, `pc`, `arm` or
`phones`). It installs each live ISO with Anaconda and boots it in QEMU (BIOS and
UEFI on x86-64, UEFI on ARM), and boots the board image as it is. With **publish**,
it uploads everything to the release only if all of that passed. Phone images are
built, but can't be boot-tested without the phones.

## Installing the tools without the ISO

**On Fedora** (or any Linux):

```bash
sudo dnf install fastfetch fortune-mod file
```

```bash
sudo make install
```

This installs `termos-fetch` and `termos-run` to `/usr/local/bin` and the logos and
configs to `/usr/local/share/termos`. Use `PREFIX=` to install somewhere else, and
`sudo make uninstall` to remove them.

**With Nix:**

```bash
nix run github:developer1-vd/TermOS
```

```bash
nix profile install github:developer1-vd/TermOS
```

The Nix package brings fastfetch, fortune and its other helpers with it.

## Development

```bash
make lint      # bash -n, shellcheck and ksvalidator
make ks        # write the generated kickstart to build/termos.ks
make clean     # remove build/
```

`nix develop` opens a shell with the lint tools. CI runs `make lint` and builds the
Nix package on every push.

### Install test

`tests/install-test.sh` installs TermOS onto a virtual disk with its installer,
Anaconda, running unattended from a kickstart (automatic partitioning, like the web
UI's "use the entire disk"). Then it boots the disk in QEMU and passes when the
system reaches a login prompt with no failed services:

```bash
sudo tests/install-test.sh build/out/lmc-disk-*.img build/itest/disk.img
```

The first argument is the live system's root filesystem, such as the disk image
`livemedia-creator` leaves in `build/out/`. An optional fourth argument, `bios`
(the default) or `uefi`, picks the firmware to install for and boot with; `uefi`
needs a machine that boots with UEFI. On an ARM64 machine it tests the ARM ISO the
same way (UEFI only). Given the board image (`.raw` or `.raw.xz`) instead, it
checks the image and boots it as it is. Run it in a Fedora container or VM; the
script's header lists the packages it needs. The Build ISO workflow runs all of
these. It tests Anaconda's install engine, not the web UI's screens.

## Repository layout

```
bin/termos-fetch               fetch wrapper (matrix mode / termite mode)
bin/termos-run                 run Windows, macOS, BSD, Nix, Ubuntu or Linux apps
branding/logo-matrix.txt       Matrix logo
branding/logo-termite.txt      termite logo
config/fastfetch/config.jsonc  fastfetch config using the Matrix logo
config/neofetch/config.conf    neofetch config using the Matrix logo
branding/wallpaper/            KDE wallpaper package (desktop + phone sizes)
branding/plymouth/termos/      Plymouth boot splash theme
branding/grub/                 GRUB theme, its install script and a GRUB easter egg
branding/icons/                TermOS logo icon, installed in place of Fedora's logo
branding/os-release/           keeps /etc/os-release branded as TermOS (Fedora's ID kept)
branding/kde/                  KDE defaults (wallpaper, lock screen)
branding/installer/            "Install TermOS" icon on the live desktop
branding/fortune/termos        TermOS fortunes (easter egg)
branding/make-art.py           generates the wallpaper, splash, GRUB and icon images
iso/termos.ks.in               kickstart template for the live ISOs and the ARM board image
iso/build-iso.sh               ISO and board image builder
phone/build-phone.sh           phone edition builder (Nura + Plasma Mobile)
phone/devices.txt              the phones the phone edition is built for
flake.nix                      Nix package, apps and dev shell
docs/                          the GitHub Pages website
tests/install-test.sh          install onto a virtual disk and boot it in QEMU
Makefile                       install, iso, board, phone, lint and clean targets
VERSION                        the TermOS version (0.1)
CHANGELOG.md                   what changed in each release
.github/workflows/             CI (lint, Nix build) and the manual build of every edition
```

## License

TermOS is licensed under the GNU General Public License v3.0. See
[LICENSE](LICENSE) for details.
