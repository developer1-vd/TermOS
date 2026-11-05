# TermOS

TermOS is a Linux distribution that combines **Fedora**, **Ubuntu** and **Nix**.

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

## Repository layout

```
bin/termos-fetch               fetch wrapper (matrix mode / termite mode)
branding/logo-matrix.txt       Matrix logo
branding/logo-termite.txt      termite logo
config/fastfetch/config.jsonc  fastfetch config using the Matrix logo
config/neofetch/config.conf    neofetch config using the Matrix logo
```

## Trying it on Fedora

TermOS is in early development and no installable images exist yet. You can try
the logos on a normal Fedora install:

```bash
sudo dnf install fastfetch fortune-mod
```

```bash
sudo mkdir -p /usr/share/termos && sudo cp branding/*.txt /usr/share/termos/
```

```bash
mkdir -p ~/.config/fastfetch && cp config/fastfetch/config.jsonc ~/.config/fastfetch/
```

```bash
fastfetch
```

```bash
fortune | bin/termos-fetch
```

## License

TermOS is licensed under the GNU General Public License v3.0. See
[LICENSE](LICENSE) for details.
