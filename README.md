# TermOS

TermOS is a terminal-focused Linux distribution based on **Fedora Linux**.

It uses Fedora as its foundation (packages, release cycle, kernel and tooling) and
adds a curated, keyboard-driven, terminal-first experience on top.

## Why Fedora?

- **Up-to-date and stable** – recent kernels, compilers and libraries, with a
  predictable ~6 month release cycle.
- **Upstream-first** – Fedora ships software close to upstream, so TermOS does too.
- **Solid tooling** – `dnf` for packages, `systemd` for services, SELinux for
  security, and Btrfs as the default filesystem.
- **Reproducible images** – Fedora's Kickstart and image-building tools make it
  straightforward to build custom spins.

## Base system

| Component        | TermOS (Fedora-based)           |
| ---------------- | ------------------------------- |
| Package manager  | `dnf` (RPM packages)            |
| Extra software   | Flatpak (Flathub), COPR repos   |
| Init system      | `systemd`                       |
| Security         | SELinux (enforcing)             |
| Filesystem       | Btrfs                           |
| Firewall         | `firewalld`                     |

## Getting started

TermOS is in early development and no installable images are published yet.
Until then, you can get close to the TermOS experience on a standard Fedora
install:

```bash
sudo dnf upgrade --refresh
```

```bash
sudo dnf install zsh tmux neovim git htop fzf ripgrep
```

## Influences

TermOS is built on Fedora, but borrows ideas from other distributions:

- **Ubuntu** – approachable defaults and a friendly first-run experience.
- **Nix** – an emphasis on declarative, reproducible configuration.

## License

TermOS is licensed under the GNU General Public License v3.0. See
[LICENSE](LICENSE) for details.
