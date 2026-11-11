#!/usr/bin/env bash
# flash-board.sh: write the TermOS ARM board image to an SD card or disk,
# and put a board's U-Boot on it where the board needs one there.
#
#   sudo iso/flash-board.sh IMAGE DEVICE [BOARD]
#   sudo iso/flash-board.sh --list IMAGE
#
# IMAGE is TermOS-VERSION-aarch64-board.raw or .raw.xz; DEVICE is the card or
# disk (e.g. /dev/sdX, /dev/mmcblk0; everything on it is erased).
#
#   --grow   afterwards, grow the root partition and its file system to fill
#            the card (the image itself is about 22 GB)
#   --yes    don't ask before erasing DEVICE
#
# BOARD is a U-Boot board name, such as orangepi_zero3. Give one for boards
# that load U-Boot from the card: the Allwinner Orange Pi boards (and other
# Allwinner boards). Leave it out for a Raspberry Pi (its U-Boot is already in
# the image) and for boards with their firmware in SPI flash. --list shows
# the boards the image has U-Boot for.
#
# The U-Boot comes from the image itself (Fedora's uboot-images-armv8, in
# /usr/share/uboot), so this works on any Linux. It goes into the gap before
# the first partition. A U-Boot too big for that gap (Rockchip's: 9 MB at
# 32 KiB) is refused rather than written over the partition: put those
# boards' U-Boot in their SPI flash instead.
#
# Needs root, xz, util-linux (losetup, sfdisk, blkid), coreutils and, for
# --grow, e2fsprogs. On Fedora, arm-image-installer --target=BOARD --resizefs
# does the same job.
set -euo pipefail

die() { echo "flash-board: $*" >&2; exit 1; }
step() { echo "flash-board: == $*"; }

yes=0 list=0 grow=0 args=()
for a in "$@"; do
    case "$a" in
        --yes)     yes=1 ;;
        --list)    list=1 ;;
        --grow)    grow=1 ;;
        -h|--help) sed -n '2,30s/^# \{0,1\}//p' "$0"; exit 0 ;;
        -*)        die "unknown option: $a (see --help)" ;;
        *)         args+=("$a") ;;
    esac
done
image="${args[0]:-}"
[[ -n "$image" && -f "$image" ]] || die "usage: flash-board.sh IMAGE DEVICE [BOARD]  (or --list IMAGE)"
[[ $EUID -eq 0 ]] || die "run as root (sudo)"
for tool in losetup sfdisk blkid dd; do
    command -v "$tool" >/dev/null || die "missing tool: $tool"
done

work="$(mktemp -d)"
loop=""
cleanup() {
    set +e
    mountpoint -q "$work/root" && umount "$work/root"
    [[ -n "$loop" ]] && losetup -d "$loop"
    rm -rf "$work"
}
trap cleanup EXIT

# Attach DISK (a device or an image file) and mount its root file system,
# the one with /usr/share/uboot, read-only at $work/root.
mount_root() {
    local disk="$1" part
    loop="$(losetup -fP --show "$disk")"
    partx -u "$loop" 2>/dev/null || true
    udevadm settle 2>/dev/null || sleep 2
    mkdir -p "$work/root"
    for part in "$loop"p*; do
        [[ "$(blkid -o value -s TYPE "$part" 2>/dev/null)" == ext4 ]] || continue
        # noload: don't replay the journal; nothing may be written here.
        mount -o ro,noload "$part" "$work/root" 2>/dev/null || continue
        [[ -d "$work/root/usr/share/uboot" ]] && return 0
        umount "$work/root"
    done
    die "no root file system with /usr/share/uboot in $disk"
}

# The U-Boot file a board loads from the card, and where it goes (bytes).
uboot_file=""
uboot_offset=0
find_uboot() {
    local dir="$work/root/usr/share/uboot/$1"
    [[ -d "$dir" ]] || die "the image has no U-Boot for '$1' (see --list)"
    if [[ -f "$dir/u-boot-sunxi-with-spl.bin" ]]; then
        uboot_file="$dir/u-boot-sunxi-with-spl.bin"; uboot_offset=$((8 * 1024))
    elif [[ -f "$dir/u-boot-rockchip.bin" ]]; then
        uboot_file="$dir/u-boot-rockchip.bin"; uboot_offset=$((64 * 512))
    else
        die "'$1' doesn't load U-Boot from the card this way (Raspberry Pi needs no BOARD)"
    fi
}

# Where the first partition starts, in bytes.
first_partition_start() {
    sfdisk -d "$1" | awk -F'start= *' '/start=/ { split($2, a, ","); if (min == "" || a[1] + 0 < min) min = a[1] + 0 }
        END { if (min == "") exit 1; printf "%d\n", min * 512 }'
}

# Grow the last partition on DISK, which must be the ext4 root, and its file
# system, to the end of the disk.
grow_root() {
    local disk="$1" n part rc=0
    for tool in e2fsck resize2fs; do
        command -v "$tool" >/dev/null || die "--grow needs $tool (e2fsprogs)"
    done
    loop="$(losetup -fP --show "$disk")"
    partx -u "$loop" 2>/dev/null || true
    udevadm settle 2>/dev/null || sleep 2
    n="$(sfdisk -d "$loop" | awk -F'start= *' '/start=/ {
            split($2, a, ","); dev = $1; sub(/ *:.*/, "", dev); sub(/.*[^0-9]/, "", dev)
            if (a[1] + 0 > max) { max = a[1] + 0; num = dev } }
        END { print num }')"
    part="${loop}p$n"
    [[ -n "$n" && "$(blkid -o value -s TYPE "$part" 2>/dev/null)" == ext4 ]] \
        || die "--grow: the last partition isn't the ext4 root; nothing grown"
    step "grow partition $n and its file system to fill $disk"
    echo ", +" | sfdisk --no-reread -N "$n" "$loop" >/dev/null
    partx -u "$loop" 2>/dev/null || true
    udevadm settle 2>/dev/null || sleep 2
    e2fsck -fp "$part" >/dev/null || rc=$?
    (( rc <= 1 )) || die "--grow: e2fsck found problems on $part (exit $rc)"
    resize2fs "$part" >/dev/null
    losetup -d "$loop"; loop=""
}

if [[ $list == 1 ]]; then
    case "$image" in
        *.xz) command -v xz >/dev/null || die "missing tool: xz"
              xz -dc "$image" | dd of="$work/image.raw" bs=4M conv=sparse status=none
              image="$work/image.raw" ;;
    esac
    mount_root "$image"
    first="$(first_partition_start "$loop")"
    echo "Boards the image has U-Boot for (BOARD names):"
    for dir in "$work"/root/usr/share/uboot/*/; do
        b="$(basename "$dir")"
        if [[ -f "$dir/u-boot-sunxi-with-spl.bin" ]]; then
            f="$dir/u-boot-sunxi-with-spl.bin"; off=$((8 * 1024))
        elif [[ -f "$dir/u-boot-rockchip.bin" ]]; then
            f="$dir/u-boot-rockchip.bin"; off=$((64 * 512))
        else
            continue
        fi
        if (( off + $(stat -c %s "$f") <= first )); then
            echo "  $b"
        else
            echo "  $b   (too big for the card: use the board's SPI flash)"
        fi
    done
    exit 0
fi

device="${args[1]:-}"
board="${args[2]:-}"
[[ -n "$device" ]] || die "usage: flash-board.sh IMAGE DEVICE [BOARD]"
# A block device, or (for tests) an image file to create.
if [[ -b "$device" ]]; then
    if grep -qE "^$device(p?[0-9]+)? " /proc/mounts; then
        die "$device (or a partition on it) is mounted; unmount it first"
    fi
elif [[ -e "$device" && ! -f "$device" ]]; then
    die "$device is neither a disk nor a file"
fi
if [[ $yes != 1 ]]; then
    read -r -p "flash-board: erase everything on $device and write TermOS to it? [y/N] " answer
    [[ "$answer" == [yY]* ]] || die "nothing written"
fi

step "write $(basename "$image") to $device"
# On a real card every block is written, zeros included (skipping them would
# leave the card's old data in their place). A new image file can have holes.
conv=fsync
[[ -b "$device" ]] || conv=fsync,sparse
case "$image" in
    *.xz) command -v xz >/dev/null || die "missing tool: xz"
          xz -dc "$image" | dd of="$device" bs=4M conv="$conv" status=progress ;;
    *)    dd if="$image" of="$device" bs=4M conv="$conv" status=progress ;;
esac
sync
[[ $grow == 1 ]] && grow_root "$device"

if [[ -n "$board" ]]; then
    mount_root "$device"
    find_uboot "$board"
    size="$(stat -c %s "$uboot_file")"
    first="$(first_partition_start "$loop")"
    if (( uboot_offset + size > first )); then
        die "U-Boot for $board ($size bytes at $uboot_offset) would overwrite the first partition (at $first): not written. Put this board's U-Boot in its SPI flash instead; the image on $device is intact."
    fi
    step "write U-Boot for $board ($size bytes at $uboot_offset; first partition at $first)"
    cp "$uboot_file" "$work/uboot.bin"
    umount "$work/root"
    losetup -d "$loop"; loop=""
    dd if="$work/uboot.bin" of="$device" bs=512 seek=$((uboot_offset / 512)) conv=notrunc,fsync status=none
    sync
fi
if [[ $grow == 1 ]]; then
    echo "flash-board: done."
else
    echo "flash-board: done. (The root file system is the image's size; --grow makes it fill the card.)"
fi
