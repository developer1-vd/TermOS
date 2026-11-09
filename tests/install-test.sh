#!/usr/bin/env bash
# install-test.sh: install TermOS onto a virtual disk the way the Calamares
# installer does, then boot it in QEMU and check that it starts.
#
#   sudo tests/install-test.sh ROOTFS DISK.img [TIMEOUT_SECONDS]
#
# ROOTFS is the live system's root filesystem: a directory, a filesystem
# image (livemedia-creator's lmc-disk-*.img) or a squashfs image.
#
# This repeats Calamares' install ("exec") steps with TermOS's settings,
# for a BIOS machine with "Erase disk":
#   partition  MBR; 1 GiB ext4 /boot + btrfs / (branding/calamares/modules/partition.conf)
#   mount      btrfs subvolumes /@root and /@home; no /@boot, since /boot
#              has its own partition (Fedora's Calamares mount.conf)
#   unpackfs   rsync -aHAXSr --filter='-x trusted.overlay.*', like Calamares
#   machineid, fstab, users, dracut, grubcfg, bootloader (grub2-install
#              --target=i386-pc --recheck --force, then grub2-mkconfig),
#              shellprocess@bootentries (termos-fix-boot-entries)
# It doesn't run Calamares itself (Calamares has no unattended mode), so it
# tests TermOS's layout, GRUB and boot, not Calamares' own code.
#
# Then it boots the disk (BIOS) in QEMU, with KVM when available, and
# passes when the serial console shows systemd's "Welcome to TermOS" and a
# login prompt. Test-only changes to the installed system: a serial console
# and visible boot messages on the kernel command line, so the boot can be
# watched, and a user "tester" (password "termos").
#
# Needs root, loop devices, ext4 and btrfs support, parted, btrfs-progs,
# e2fsprogs, rsync and qemu-system-x86_64.
set -euo pipefail

src="$1"
disk="$2"
timeout="${3:-1200}"

die() { echo "install-test: $*" >&2; exit 1; }
step() { echo "install-test: == $*"; }

[[ $EUID -eq 0 ]] || die "run as root"
for tool in parted mkfs.ext4 mkfs.btrfs btrfs rsync losetup blkid qemu-system-x86_64; do
    command -v "$tool" >/dev/null || die "missing tool: $tool"
done

work="$(mktemp -d)"
loop=""
uuid_links=()
cleanup() {
    set +e
    for l in "${uuid_links[@]}"; do rm -f "$l"; done
    for m in "$work"/target/{dev/pts,dev,proc,sys,run,home,boot} "$work"/target "$work"/top "$work"/src; do
        mountpoint -q "$m" && umount -l "$m"
    done
    [[ -n "$loop" ]] && losetup -d "$loop"
}
trap cleanup EXIT

# ---- Source: the live root filesystem (what Calamares copies from /run/rootfsbase)
if [[ -d "$src" ]]; then
    srcdir="$src"
else
    mkdir -p "$work/src"
    mount -o loop,ro "$src" "$work/src"
    srcdir="$work/src"
fi
[[ -x "$srcdir/usr/bin/bash" ]] || die "$src doesn't look like a root filesystem"

# ---- partition (MBR on BIOS, layout from partition.conf)
step "partition: MBR, 1 GiB ext4 /boot, btrfs /"
rm -f "$disk"
truncate -s 30G "$disk"
loop="$(losetup -fP --show "$disk")"
parted -s "$loop" mklabel msdos \
    mkpart primary ext4 1MiB 1025MiB set 1 boot on \
    mkpart primary btrfs 1025MiB 100%
partx -u "$loop" 2>/dev/null || true
udevadm settle 2>/dev/null || sleep 2
mkfs.ext4 -q -L boot "${loop}p1"
mkfs.btrfs -q -f -L root "${loop}p2"

# ---- mount (subvolumes from mount.conf; /@boot skipped: /boot is a partition)
step "mount: btrfs subvolumes /@root and /@home"
mkdir -p "$work/top" "$work/target"
mount "${loop}p2" "$work/top"
btrfs -q subvolume create "$work/top/@root"
btrfs -q subvolume create "$work/top/@home"
umount "$work/top"
opts="compress=zstd:1"
mount -o "subvol=/@root,$opts" "${loop}p2" "$work/target"
mkdir -p "$work/target/boot" "$work/target/home"
mount "${loop}p1" "$work/target/boot"
mount -o "subvol=/@home,$opts" "${loop}p2" "$work/target/home"

# ---- unpackfs
step "unpackfs: copy the live system"
rsync -aHAXSr --filter='-x trusted.overlay.*' "$srcdir"/ "$work/target"/

t="$work/target"
for d in dev dev/pts proc sys run; do mkdir -p "$t/$d"; done
mount --bind /dev "$t/dev"
mount --bind /dev/pts "$t/dev/pts"
mount -t proc proc "$t/proc"
mount -t sysfs sys "$t/sys"
mount -t tmpfs tmpfs "$t/run"
in_target() { chroot "$t" /usr/bin/env -i PATH=/usr/sbin:/usr/bin HOME=/root LANG=C.UTF-8 "$@"; }

# ---- machineid
step "machineid"
rm -f "$t/etc/machine-id"
in_target systemd-machine-id-setup >/dev/null

# ---- fstab
step "fstab"
root_uuid="$(blkid -s UUID -o value "${loop}p2")"
boot_uuid="$(blkid -s UUID -o value "${loop}p1")"
cat > "$t/etc/fstab" <<FSTAB
UUID=$root_uuid /     btrfs subvol=/@root,$opts 0 0
UUID=$boot_uuid /boot ext4  defaults              1 2
UUID=$root_uuid /home btrfs subvol=/@home,$opts 0 0
FSTAB

# ---- users (test user)
step "users: tester"
in_target useradd -m -G wheel -c Tester tester
echo 'tester:termos' | in_target chpasswd

# ---- grubcfg (test-only: serial console and visible boot messages)
step "grubcfg"
# Test-only: GRUB on the serial port too, so a GRUB error shows in the log.
cat >> "$t/etc/default/grub" <<'GRUB'
GRUB_TERMINAL_OUTPUT="console serial"
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200"
GRUB
grep -q '^GRUB_CMDLINE_LINUX=' "$t/etc/default/grub" || echo 'GRUB_CMDLINE_LINUX="rhgb quiet"' >> "$t/etc/default/grub"
sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 console=tty0 console=ttyS0,115200 systemd.show_status=1"/' \
    "$t/etc/default/grub"
sed -i 's/ rhgb//; s/ quiet//' "$t/etc/default/grub"
grep '^GRUB_CMDLINE_LINUX=' "$t/etc/default/grub"

# ---- dracut
step "dracut: regenerate the initramfs"
in_target dracut -f --regenerate-all

# ---- bootloader (BIOS)
# On a real install udev makes /dev/disk/by-uuid links, and grub2-mkconfig
# uses them to write root=UUID=...; this container has no udev, so make them.
mkdir -p /dev/disk/by-uuid
for p in "${loop}p1" "${loop}p2"; do
    link="/dev/disk/by-uuid/$(blkid -s UUID -o value "$p")"
    ln -sf "$p" "$link"
    uuid_links+=("$link")
done
step "bootloader: grub2-install --target=i386-pc --recheck --force $loop"
in_target grub2-install --target=i386-pc --recheck --force "$loop"
in_target grub2-mkconfig -o /boot/grub2/grub.cfg

# ---- shellprocess@bootentries (TermOS's step after the bootloader)
step "shellprocess@bootentries: fix kernel paths for the separate /boot"
fix="$(dirname "$(realpath "$0")")/../branding/calamares/termos-fix-boot-entries"
install -Dm755 "$fix" "$t/usr/libexec/termos/termos-fix-boot-entries"
in_target /usr/libexec/termos/termos-fix-boot-entries
echo "install-test: boot entries:"
grep -h -E '^(title|linux|initrd|options)' "$t"/boot/loader/entries/*.conf | sed 's/^/  /'

sync
cleanup
trap - EXIT
loop=""

# ---- boot it
step "boot: QEMU, BIOS, serial console (timeout ${timeout}s)"
accel=tcg
[[ -w /dev/kvm ]] && accel=kvm
serial="${disk%.img}.serial.log"
rm -f "$serial"
qemu-system-x86_64 -machine "accel=$accel" -m 4096 -smp 4 \
    -drive "file=$disk,format=raw,if=virtio" \
    -display none -serial "file:$serial" -no-reboot &
qemu=$!
result=timeout
for (( i = 0; i < timeout; i += 5 )); do
    sleep 5
    if grep -aqE "Kernel panic|not found\.|you need to load the kernel|Entering emergency mode|^error: " "$serial" 2>/dev/null; then
        result=fail; break
    fi
    if grep -aq "login:" "$serial" 2>/dev/null; then
        result=pass; break
    fi
    kill -0 "$qemu" 2>/dev/null || { result=exited; break; }
done
kill "$qemu" 2>/dev/null || true
wait "$qemu" 2>/dev/null || true

echo "install-test: serial console (welcome line and the end):"
grep -a "Welcome to" "$serial" | sed 's/\x1b\[[0-9;]*m//g; s/^/  /'
tail -n 5 "$serial" | sed 's/\x1b\[[0-9;]*m//g; s/^/  /'
echo "install-test: result: $result (accel: $accel; full log: $serial)"
[[ "$result" == pass ]]
