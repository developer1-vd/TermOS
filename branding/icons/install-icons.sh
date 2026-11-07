#!/bin/sh
# install-icons.sh: install the TermOS logo icon and use it in place of
# Fedora's logo.
#
#   install-icons.sh [SRC_HICOLOR_DIR] [DEST_HICOLOR_DIR]
#
# Installs termos-logo in every size, plus copies named start-here (the app
# menu icon) and fedora-logo-icon (the logo KDE shows for the distro, e.g. in
# the Welcome Center), into DEST (default /usr/local/share/icons/hicolor).
#
# /usr/local/share comes before /usr/share in the icon search path, so these
# override the fedora-logos package's icons of the same name and size
# without touching any packaged file. Every size fedora-logos ships is
# covered: KDE prefers an exact size match over search order.
set -eu

src="${1:-/usr/share/termos/icons/hicolor}"
dest="${2:-/usr/local/share/icons/hicolor}"

for dir in "$src"/*/apps; do
    size="$(basename "$(dirname "$dir")")"
    ext=png
    [ "$size" = scalable ] && ext=svg
    for sub in apps places; do
        mkdir -p "$dest/$size/$sub"
    done
    cp "$dir/termos-logo.$ext" "$dest/$size/apps/termos-logo.$ext"
    cp "$dir/termos-logo.$ext" "$dest/$size/apps/fedora-logo-icon.$ext"
    cp "$dir/termos-logo.$ext" "$dest/$size/apps/start-here.$ext"
    cp "$dir/termos-logo.$ext" "$dest/$size/places/start-here.$ext"
done

# Let caches notice the new icons (harmless if the tool isn't installed).
if command -v gtk-update-icon-cache >/dev/null; then
    gtk-update-icon-cache -q -t -f "$dest" 2>/dev/null || true
fi
echo "TermOS: logo icons installed in $dest"
