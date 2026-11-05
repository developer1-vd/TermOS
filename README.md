# TermOS

TermOS is a Linux distribution that combines **Fedora**, **Ubuntu** and **Nix**, and also runs **Windows**, **macOS** and **BSD** apps.

> The name doesn't mean anything. It's not a terminal OS. TermOS is just a cool name.

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

TermOS has its own wallpaper and boot splash, both green Matrix-style rain
behind the TermOS logo.

- **Wallpaper:** comes in desktop sizes (3840×2160 and 1920×1080) and phone sizes
  (1440×3200 and 1080×2400). On the ISO it's the default for the KDE desktop and
  the lock screen, and KDE picks the right size for each screen, including
  portrait ones. The phone sizes in `branding/wallpaper/contents/images/` work
  as phone wallpapers too.
- **Boot splash:** a Plymouth theme where the rain keeps falling while the system
  boots, with a progress bar under the logo and a matching prompt for encrypted
  disks.

The images are generated by `branding/make-art.py`. Run `make art` to rebuild them
after changing it.

To use them on an existing Fedora install:

```bash
sudo dnf install plymouth-plugin-script plymouth-plugin-label
```

```bash
sudo make install install-splash
```

Then choose **TermOS** in System Settings → Wallpaper.

## Building the ISO

TermOS builds a bootable live ISO from Fedora with a kickstart file
(`iso/termos.ks.in`) and Fedora's `livemedia-creator`. The live session boots
into **KDE Plasma**. To install TermOS to disk, double-click **Install TermOS** on
the desktop.

## The installer

TermOS installs with [Calamares](https://calamares.io/) instead of Fedora's
Anaconda. Calamares walks you through language, keyboard, disk partitioning
(including encryption) and creating your user, then copies the live system to
disk. While it installs, it shows a TermOS slideshow.

The setup lives in `branding/calamares/`:

```
settings.conf          the install steps (based on Fedora's own Calamares setup)
modules/welcome.conf   requirements check: 25 GB disk, 2 GB RAM
modules/packages.conf  removes live-only packages after installing
branding/termos/       TermOS logo, colours and slideshow
```

Anything not set there uses the defaults from Fedora's Calamares package. The
installed system keeps the TermOS boot splash, wallpaper and preinstalled apps,
and the temporary live user isn't copied to it.

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
| Look            | The TermOS wallpaper and boot splash                               |
| Installer       | Calamares, with TermOS branding                                    |

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

The ISO is written to `build/out/TermOS-<release>-x86_64.iso`. A build needs
root (or a privileged container), about 15 GB of free disk space and a network
connection to the Fedora mirrors. It's based on Fedora 44 by default; set
`TERMOS_RELEASE` to change that:

```bash
TERMOS_RELEASE=45 make iso-container
```

To write the ISO to a USB stick, use Fedora Media Writer, or `dd` (this erases the
stick, so double-check the device name):

```bash
sudo dd if=build/out/TermOS-44-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

You can also build ISOs from GitHub: run the **Build ISO** workflow from the
Actions tab, and it uploads the ISO as a workflow artifact.

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
branding/kde/                  KDE defaults (wallpaper, lock screen)
branding/calamares/            Calamares installer settings and branding
branding/make-art.py           generates the wallpaper, splash and installer images
iso/termos.ks.in               kickstart template for the live ISO
iso/build-iso.sh               ISO builder
flake.nix                      Nix package, apps and dev shell
Makefile                       install, iso, lint and clean targets
.github/workflows/             CI (lint, Nix build) and the manual ISO build
```

## License

TermOS is licensed under the GNU General Public License v3.0. See
[LICENSE](LICENSE) for details.
