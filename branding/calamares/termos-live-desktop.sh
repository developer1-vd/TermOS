#!/bin/sh
# Live session only: put an "Install TermOS" icon on the desktop.
# Run at login from /etc/xdg/autostart/termos-live-desktop.desktop.
grep -qw rd.live.image /proc/cmdline || exit 0
desktop="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
mkdir -p "$desktop"
cp /usr/share/applications/termos-install.desktop "$desktop/"
chmod +x "$desktop/termos-install.desktop"
