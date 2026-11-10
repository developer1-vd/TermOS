#!/usr/bin/env bash
# build-phone.sh: build the TermOS phone edition for one phone.
#
#   phone/build-phone.sh DEVICE [OUT_DIR]
#
# DEVICE is a Nura codename from phone/devices.txt (e.g. oneplus-enchilada).
# The phone edition is Nura (formerly postmarketOS) with KDE Plasma Mobile,
# plus TermOS's look and tools: the Matrix wallpaper (phone sizes),
# termos-fetch with its Matrix and termite modes, and the TermOS fortunes.
# It is not Fedora: phones need Nura's kernels and device support.
#
# Output (OUT_DIR, default build/out): TermOS-VERSION-phone-DEVICE.tar.xz,
# with the image(s) to flash and FLASHING.txt saying how.
#
# Environment:
#   TERMOS_NURA_CHANNEL   Nura release (default: v26.06)
#   TERMOS_PMB_VERSION    pmbootstrap release (default: 3.12.1)
#   TERMOS_PHONE_PIN      the user's PIN/password (default: 837667, TERMOS
#                         on a phone keypad; Plasma Mobile's lock screen
#                         takes digits)
#   TERMOS_PHONE_WORK     work directory (default: build/phone); several GB
#
# Runs as a normal user with sudo (pmbootstrap refuses root), on a machine of
# the phone's architecture (aarch64 for every phone listed), with git,
# python3 and a network connection.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
die() { echo "build-phone: $*" >&2; exit 1; }
step() { echo "build-phone: == $*"; }

device="${1:-}"
out="$(realpath -m "${2:-$repo/build/out}")"
[[ -n "$device" ]] || die "usage: build-phone.sh DEVICE [OUT_DIR] (devices: phone/devices.txt)"
grep -qE "^${device}[[:space:]]" "$repo/phone/devices.txt" \
    || die "$device isn't in phone/devices.txt"
category="$(awk -v d="$device" '$1 == d { print $2 }' "$repo/phone/devices.txt")"
model="$(awk -v d="$device" '$1 == d { $1 = $2 = ""; sub(/^ +/, ""); print }' "$repo/phone/devices.txt")"

version="$(tr -d '[:space:]' < "$repo/VERSION")"
channel="${TERMOS_NURA_CHANNEL:-v26.06}"
pmb_version="${TERMOS_PMB_VERSION:-3.12.1}"
pin="${TERMOS_PHONE_PIN:-837667}"
work="$(realpath -m "${TERMOS_PHONE_WORK:-$repo/build/phone}")"
[[ "$pin" =~ ^[0-9]{4,}$ ]] || die "TERMOS_PHONE_PIN must be at least 4 digits"
[[ $EUID -ne 0 ]] || die "run as a normal user with sudo (pmbootstrap refuses root)"
for tool in git python3 sudo tar xz; do
    command -v "$tool" >/dev/null || die "missing tool: $tool"
done

# Nura's git repositories. pmbootstrap expects pmaports to come from
# gitlab.postmarketos.org (it checks the remote's URL); that address now
# forwards to Nura's GitLab, gitlab.nura.eco.
pmb_git=https://gitlab.nura.eco/nura/pmbootstrap.git
pmaports_git=https://gitlab.postmarketos.org/postmarketOS/pmaports.git

mkdir -p "$work" "$out"
pmb() {
    python3 "$work/pmbootstrap/pmbootstrap.py" \
        --config "$work/pmbootstrap.cfg" --work "$work/pmb-work" "$@"
}
# pmbootstrap keeps the failing command's output in its own log; show it.
pmb_or_log() {
    pmb "$@" && return
    echo "build-phone: ---- pmbootstrap log (last 120 lines)" >&2
    tail -n 120 "$work/pmb-work/log.txt" >&2 || true
    die "pmbootstrap $1 failed"
}

# ---- pmbootstrap and pmaports ------------------------------------------------
if [[ ! -d "$work/pmbootstrap/.git" ]]; then
    step "get pmbootstrap $pmb_version"
    git clone -q --depth 1 --branch "$pmb_version" "$pmb_git" "$work/pmbootstrap"
fi
if [[ ! -d "$work/pmaports/.git" ]]; then
    step "get pmaports ($channel)"
    # Every branch's tip, not just the channel's: pmbootstrap reads the list
    # of channels from origin/main.
    git clone -q --depth 1 --no-single-branch --branch "$channel" "$pmaports_git" "$work/pmaports"
fi
deviceinfo="$(find "$work/pmaports/device" -path "*/device-$device/deviceinfo" | head -1)"
[[ -f "$deviceinfo" ]] || die "Nura $channel has no device $device"

# ---- The termos-phone package ------------------------------------------------
# TermOS's files go into an Alpine package that pmbootstrap builds from a
# folder in pmaports, then installs on the phone.
step "package TermOS's files (termos-phone)"
pkg="$work/pmaports/main/termos-phone"
rm -rf "$pkg"
mkdir -p "$pkg"
root="$work/termos-phone-root/root"
rm -rf "${root%/root}"
mkdir -p "$root"/usr/bin "$root"/usr/share/termos/fastfetch "$root"/usr/share/termos/neofetch \
    "$root"/usr/share/wallpapers "$root"/usr/share/fortune "$root"/etc \
    "$root"/usr/share/plasma/shells/org.kde.plasma.mobileshell/contents/updates
install -m 0755 "$repo/bin/termos-fetch" "$root/usr/bin/termos-fetch"
install -m 0644 "$repo/branding/logo-matrix.txt" "$repo/branding/logo-termite.txt" "$root/usr/share/termos/"
install -m 0644 "$repo/config/fastfetch/config.jsonc" "$root/usr/share/termos/fastfetch/"
install -m 0644 "$repo/config/neofetch/config.conf" "$root/usr/share/termos/neofetch/"
cp -r "$repo/branding/wallpaper" "$root/usr/share/wallpapers/TermOS"
find "$root/usr/share/wallpapers/TermOS" -name '*.py' -delete
# Plasma Mobile runs this once per user: the TermOS wallpaper on the home
# screen (the same script the desktop uses, for the mobile shell).
install -m 0644 "$repo/branding/kde/zz-termos-wallpaper.js" \
    "$root/usr/share/plasma/shells/org.kde.plasma.mobileshell/contents/updates/"
# TermOS fortunes (`fortune termos`); the package indexes them with strfile.
install -m 0644 "$repo/branding/fortune/termos" "$root/usr/share/fortune/termos"
cat > "$root/etc/termos-release" <<REL
NAME=TermOS
VERSION_ID=$version
PRETTY_NAME="TermOS $version Phone"
BASE="Nura $channel"
DESKTOP="KDE Plasma Mobile"
REL
tar -C "${root%/root}" --owner=0 --group=0 --numeric-owner -czf "$pkg/termos-phone-files.tar.gz" root

cat > "$pkg/APKBUILD" <<APKBUILD
# Generated by TermOS's phone/build-phone.sh.
pkgname=termos-phone
pkgver=$version
pkgrel=0
pkgdesc="TermOS look and tools for the TermOS phone edition"
url="https://github.com/developer1-vd/TermOS"
arch="noarch"
license="GPL-3.0-only"
depends="bash fastfetch fortune"
makedepends="fortune"
options="!check"
source="termos-phone-files.tar.gz"
builddir="\$srcdir"

package() {
	mkdir -p "\$pkgdir"
	cp -a "\$srcdir"/root/. "\$pkgdir"/
	strfile "\$pkgdir"/usr/share/fortune/termos >/dev/null
}

sha512sums="
$(cd "$pkg" && sha512sum termos-phone-files.tar.gz)
"
APKBUILD

# ---- Configure and build -------------------------------------------------------
# What "pmbootstrap init" would ask for, written directly (init is
# interactive): the config file, and the work folder with its version stamp.
step "configure pmbootstrap for $device ($model)"
mkdir -p "$work/pmb-work"
cat > "$work/pmbootstrap.cfg" <<CFG
[pmbootstrap]
aports = $work/pmaports
work = $work/pmb-work
device = $device
ui = plasma-mobile
extra_packages = termos-phone
hostname = termos
user = termos
timezone = UTC
locale = en_US.UTF-8
CFG
if [[ ! -f "$work/pmb-work/version" ]]; then
    (cd "$work/pmbootstrap" && python3 -c 'import pmb.config; print(pmb.config.work_version)') \
        > "$work/pmb-work/version"
fi

step "build and install (Nura $channel, Plasma Mobile)"
pmb_or_log -y build termos-phone --force
pmb_or_log -y install --password "$pin"

# ---- Collect the images ------------------------------------------------------
step "collect the images"
export_dir="$work/export-$device"
rm -rf "$export_dir"
pmb_or_log export "$export_dir" >/dev/null
stage="$work/stage/TermOS-$version-phone-$device"
rm -rf "$stage"
mkdir -p "$stage"
shopt -s nullglob
for f in "$export_dir/$device.img" "$export_dir"/{boot,vendor_boot,dtbo,lk2nd}.img; do
    [[ -e "$f" ]] || continue
    name="$(basename "$f")"
    [[ "$name" == "$device.img" ]] && name="TermOS-$version-phone-$device.img"
    cp -L --sparse=always "$f" "$stage/$name"
done
shopt -u nullglob
[[ -f "$stage/TermOS-$version-phone-$device.img" ]] || die "pmbootstrap made no $device.img"

# How to flash it, from the device's own deviceinfo.
di() { sed -n "s/^deviceinfo_$1=\"\(.*\)\"/\1/p" "$deviceinfo" | head -1; }
method="$(di flash_method)"
rootfs_part="$(di flash_fastboot_partition_rootfs)"; rootfs_part="${rootfs_part:-userdata}"
kernel_part="$(di flash_fastboot_partition_kernel)"; kernel_part="${kernel_part:-boot}"
img="TermOS-$version-phone-$device.img"
{
    echo "TermOS $version phone edition for the $model ($device)."
    echo "Based on Nura $channel (formerly postmarketOS) with KDE Plasma Mobile."
    [[ "$category" == testing ]] && echo "This phone is in Nura's \"testing\" category: expect rough edges."
    echo
    echo "Log in as \"termos\" with the PIN $pin (TERMOS on a phone keypad); change it"
    echo "in Settings afterwards."
    echo
    echo "Flashing replaces the phone's operating system and erases its data."
    echo "Check your phone's page on the Nura wiki first (https://wiki.nura.eco/,"
    echo "search for \"$device\"): it says how to unlock the bootloader and what works."
    echo
    case "$method" in
        fastboot)
            echo "Unlock the bootloader, boot the phone into fastboot mode, and run:"
            echo
            if [[ -f "$stage/lk2nd.img" ]]; then
                echo "  fastboot flash $kernel_part lk2nd.img"
                echo "  fastboot reboot bootloader     # now in lk2nd's fastboot"
            fi
            echo "  fastboot erase dtbo            # only if the phone has a dtbo partition"
            echo "  fastboot flash $rootfs_part $img"
            [[ -f "$stage/boot.img" && ! -f "$stage/lk2nd.img" ]] && echo "  fastboot flash $kernel_part boot.img"
            [[ -f "$stage/vendor_boot.img" ]] && echo "  fastboot flash vendor_boot vendor_boot.img"
            echo "  fastboot reboot"
            ;;
        heimdall-bootimg|heimdall-isorec|odin)
            echo "Samsung phone: flash $img to the userdata partition and boot.img to"
            echo "boot with Heimdall (or Odin), as the Nura wiki page describes."
            ;;
        *)
            echo "Write $img to an SD card (or the phone's internal storage, see the wiki):"
            echo
            echo "  sudo dd if=$img of=/dev/sdX bs=4M status=progress conv=fsync"
            echo
            echo "where /dev/sdX is the card (check with lsblk; everything on it is erased)."
            ;;
    esac
} > "$stage/FLASHING.txt"

step "compress"
rm -f "$out/TermOS-$version-phone-$device.tar.xz"
tar -C "$(dirname "$stage")" -cf - "$(basename "$stage")" | xz -T0 -6 > "$out/TermOS-$version-phone-$device.tar.xz"
ls -l "$out/TermOS-$version-phone-$device.tar.xz"
cat "$stage/FLASHING.txt"

# Free the device's chroot and image for the next build.
pmb -y zap >/dev/null 2>&1 || true
echo "build-phone: done: $out/TermOS-$version-phone-$device.tar.xz"
