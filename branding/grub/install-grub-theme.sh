#!/bin/sh
# install-grub-theme.sh: install the TermOS GRUB theme and turn it on.
#
#   install-grub-theme.sh [THEME_SRC_DIR] [--mkconfig]
#
# Copies the theme to /boot/grub2/themes/termos, generates its fonts with
# grub2-mkfont, and sets GRUB_THEME (plus a graphical terminal and a visible
# menu, which the theme needs) in /etc/default/grub. With --mkconfig it also
# regenerates /boot/grub2/grub.cfg. Needs root, grub2-tools-extra and
# dejavu-sans-mono-fonts.
set -eu

src="${1:-/usr/share/termos/grub/termos}"
dest=/boot/grub2/themes/termos
fonts=/usr/share/fonts/dejavu-sans-mono-fonts
defaults=/etc/default/grub

mkdir -p "$dest"
cp "$src"/* "$dest"/

# GRUB needs its own .pf2 fonts; the names in theme.txt come from these.
grub2-mkfont -s 16 -o "$dest/dejavu-mono-16.pf2"      "$fonts/DejaVuSansMono.ttf"
grub2-mkfont -s 14 -o "$dest/dejavu-mono-14.pf2"      "$fonts/DejaVuSansMono.ttf"
grub2-mkfont -s 16 -o "$dest/dejavu-mono-bold-16.pf2" "$fonts/DejaVuSansMono-Bold.ttf"

# Set KEY=VALUE in /etc/default/grub, replacing an existing line or adding one.
set_key() {
    if grep -q "^$1=" "$defaults"; then
        sed -i "s|^$1=.*|$1=$2|" "$defaults"
    else
        echo "$1=$2" >> "$defaults"
    fi
}

if [ ! -f "$defaults" ]; then
    # Fedora's installer normally writes this file; start from its defaults.
    cat > "$defaults" <<'DEFAULTS'
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="TermOS"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_CMDLINE_LINUX="rhgb quiet"
GRUB_DISABLE_RECOVERY=true
GRUB_ENABLE_BLSCFG=true
DEFAULTS
fi

set_key GRUB_THEME '"/boot/grub2/themes/termos/theme.txt"'
set_key GRUB_TERMINAL_OUTPUT '"gfxterm"'
set_key GRUB_GFXMODE '"auto"'
set_key GRUB_TIMEOUT_STYLE 'menu'
set_key GRUB_TIMEOUT '5'

# Fedora hides the menu after a successful boot; show it, or the theme
# would never be seen.
if command -v grub2-editenv >/dev/null && [ -f /boot/grub2/grubenv ]; then
    grub2-editenv - unset menu_auto_hide || true
fi

if [ "${2:-}" = "--mkconfig" ]; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
fi
echo "TermOS: GRUB theme installed"
