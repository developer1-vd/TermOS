#!/usr/bin/env bash
# install-test.sh: install TermOS onto a virtual disk with its installer,
# Anaconda, then boot the disk in QEMU and check that it starts.
#
#   sudo tests/install-test.sh ROOTFS DISK.img [TIMEOUT_SECONDS] [bios|uefi]
#
# ROOTFS is the live system's root filesystem image, such as the
# lmc-disk-*.img livemedia-creator leaves in build/out/ (or the ISO's
# LiveOS/squashfs.img).
#
# Anaconda runs unattended from a kickstart, installing from ROOTFS (the
# liveimg payload, as the live installer does) onto DISK.img with automatic
# partitioning, which is what the web UI's "use the entire disk" does. The
# disk is then booted in QEMU, with KVM when available. The test passes when
# the serial console shows a login prompt and no service failed.
#
# Firmware (default bios): Anaconda installs the boot loader for the firmware
# of the machine it runs on. For "bios" the test hides this machine's EFI
# firmware from it (if it has one) and boots the disk with SeaBIOS; for
# "uefi" the machine must boot with UEFI, and the disk boots with OVMF.
#
# Test-only changes to the installed system: a serial console and visible
# boot messages on the kernel command line, GRUB's output on the serial port
# too, and a user "tester" (password "termos").
#
# Where the machine running the test has no SELinux (containers, CI), the
# installer's restorecon can't label files, so the test labels the installed
# system with setfiles afterwards; on a real TermOS live system, which runs
# SELinux, the installer does this itself.
#
# Needs root, loop devices, device-mapper, anaconda (anaconda-tui), the tools
# to make file systems (e2fsprogs, xfsprogs, btrfs-progs, dosfstools; without
# them Anaconda's storage module won't start), rsync, qemu-system-x86_64 and,
# for uefi, edk2-ovmf. Anaconda also needs the btrfs kernel module: in a
# container, load it on the host and share the host's /lib/modules.
# Run it in a Fedora container or VM of TermOS's release.
set -euo pipefail

src="$(realpath "$1")"
disk="$(realpath -m "$2")"
timeout="${3:-1800}"
firmware="${4:-bios}"
ovmf=/usr/share/edk2/ovmf

die() { echo "install-test: $*" >&2; exit 1; }
step() { echo "install-test: == $*"; }

[[ $EUID -eq 0 ]] || die "run as root"
[[ -f "$src" ]] || die "no such root filesystem image: $1"
for tool in anaconda losetup qemu-system-x86_64; do
    command -v "$tool" >/dev/null || die "missing tool: $tool"
done
case "$firmware" in
    bios) ;;
    uefi)
        [[ -d /sys/firmware/efi ]] || die "uefi: this machine doesn't boot with UEFI"
        [[ -f $ovmf/OVMF_CODE.fd ]] || die "uefi: missing $ovmf/OVMF_CODE.fd (edk2-ovmf)"
        ;;
    *) die "firmware must be bios or uefi, not $firmware" ;;
esac

# In containers there's no udev; let device-mapper create its device nodes.
export DM_DISABLE_UDEV=1

work="$(mktemp -d)"
loop=""
cleanup() {
    set +e
    for m in "$work"/target/{dev,proc,sys,boot,home} "$work"/target "$work"/top \
             /sys/firmware; do
        mountpoint -q "$m" && umount -l "$m"
    done
    [[ -n "$loop" ]] && losetup -d "$loop"
}
trap cleanup EXIT

# ---- Install with Anaconda --------------------------------------------------
step "anaconda: install from $(basename "$src") onto $(basename "$disk")"
rm -f "$disk"
truncate -s 30G "$disk"
cat > "$work/install.ks" <<KS
# Unattended version of the web UI's "use the entire disk".
lang en_US.UTF-8
keyboard us
timezone UTC
liveimg --url=file://$src
# In --image mode Anaconda only uses the disk image (it calls it "disk").
zerombr
clearpart --all --initlabel
autopart
bootloader --append="console=tty0 console=ttyS0,115200 systemd.show_status=1"
rootpw --lock
user --name=tester --password=termos --plaintext --groups=wheel
shutdown

%post
# Test-only: don't list the test machine's own systems (the container sees
# its disks), and on BIOS put GRUB on the serial port too, so a GRUB error
# shows in the log. (UEFI firmware copies the console there already, and
# Fedora's signed EFI GRUB has no serial terminal.)
echo 'GRUB_DISABLE_OS_PROBER=true' >> /etc/default/grub
if [ ! -d /sys/firmware/efi ]; then
    cat >> /etc/default/grub <<'GRUB'
GRUB_TERMINAL_OUTPUT="console serial"
GRUB_SERIAL_COMMAND="serial --unit=0 --speed=115200"
GRUB
fi
grub2-mkconfig -o /boot/grub2/grub.cfg
%end
KS
if [[ $firmware == bios ]]; then
    # grub2-install, run in the new system, picks EFI when its /sys (a fresh
    # sysfs, not the one hidden below) shows EFI firmware. On a real BIOS
    # machine there's none; here, hide it while Anaconda installs.
    cat >> "$work/install.ks" <<'KS'

%pre-install --interpreter=/bin/bash
if [[ -d /mnt/sysroot/sys/firmware/efi ]]; then
    mount -t tmpfs -o size=1m,mode=0755 termos-no-efi /mnt/sysroot/sys/firmware
fi
%end

%post --nochroot --interpreter=/bin/bash
if mountpoint -q /mnt/sysroot/sys/firmware; then
    umount /mnt/sysroot/sys/firmware
fi
%end
KS
fi
# Anaconda's own logs (anaconda.log, storage.log, program.log, ...) go to
# /tmp; keep a copy next to the disk image, and show them if it fails.
logs="$(dirname "$disk")/anaconda-logs"
save_logs() {
    mkdir -p "$logs"
    cp /tmp/*.log "$work/anaconda.out" "$logs"/ 2>/dev/null || true
    chmod -R a+rX "$logs"   # readable outside the container (CI artifacts)
}
# Anaconda installs for EFI when /sys/firmware/efi exists; hide it for bios.
if [[ $firmware == bios && -d /sys/firmware/efi ]]; then
    mount -t tmpfs -o size=1m,mode=0755 termos-no-efi /sys/firmware
fi
if ! anaconda --image "$disk:disk" --kickstart "$work/install.ks" --cmdline --nosave=all \
        > "$work/anaconda.out" 2>&1; then
    save_logs
    tail -n 40 "$work/anaconda.out"
    for log in "$logs"/*.log; do
        echo "install-test: ---- $(basename "$log") (last 40 lines)"
        tail -n 40 "$log"
    done
    die "anaconda failed (logs in $logs)"
fi
save_logs
tail -n 5 "$work/anaconda.out"
mountpoint -q /sys/firmware && umount /sys/firmware

# ---- Look at what the installer made ---------------------------------------
step "inspect: partitions, boot entries, SELinux labels"
loop="$(losetup -fP --show "$disk")"
partx -u "$loop" 2>/dev/null || true
udevadm settle 2>/dev/null || sleep 2
blkid "$loop"p* | sed 's/^/  /'
mkdir -p "$work/top" "$work/target"
# Without udev, lsblk doesn't know file system types; ask blkid.
fstype() { blkid -o value -s TYPE "$1" 2>/dev/null || true; }
rootpart="" bootpart=""
for part in "$loop"p*; do
    case "$(fstype "$part")" in
        btrfs) [[ -n $rootpart ]] || rootpart="$part" ;;
        ext4)  [[ -n $bootpart ]] || bootpart="$part" ;;
    esac
done
[[ -n "$rootpart" ]] || die "no btrfs root partition found"
mount "$rootpart" "$work/top"
rootvol="$(btrfs subvolume list "$work/top" | awk '$NF == "root" || $NF == "@root" || $NF == "@" { print $NF; exit }')"
umount "$work/top"
t="$work/target"
mount -o "subvol=${rootvol:-root}" "$rootpart" "$t"
[[ -n "$bootpart" ]] && mount "$bootpart" "$t/boot"
echo "install-test: boot entries:"
grep -h -E '^(title|linux|initrd)' "$t"/boot/loader/entries/*.conf | sed 's/^/  /'

# Without udev, Anaconda can't read the new partitions' UUIDs, so fstab names
# them by the installer's own device names (/dev/mapper/diskN, partition N of
# the image), which don't exist at boot. On a real install udev runs; here,
# put in the UUIDs.
while read -r dev; do
    uuid="$(blkid -o value -s UUID "${loop}p${dev##*/disk}")"
    [[ -n $uuid ]] || die "no UUID for $dev"
    echo "install-test: fstab: $dev -> UUID=$uuid (no udev in the test)"
    sed -i "s|^$dev[[:space:]]|UUID=$uuid |" "$t/etc/fstab"
done < <(grep -oE '^/dev/mapper/disk[0-9]+' "$t/etc/fstab" | sort -u)
echo "install-test: fstab:"
grep -v '^#' "$t/etc/fstab" | sed '/^$/d; s/^/  /'

# Label files the installer wrote (see the note at the top).
if [[ ! -e /sys/fs/selinux/enforce ]]; then
    step "selinux: label the installed system (no SELinux on this machine)"
    for d in dev proc sys; do mount --bind "/$d" "$t/$d"; done
    chroot "$t" setfiles -F -e /proc -e /sys -e /dev \
        /etc/selinux/targeted/contexts/files/file_contexts / \
        || die "setfiles failed"
fi
sync
cleanup
trap - EXIT
loop=""

# ---- Boot it -------------------------------------------------------------------
step "boot: QEMU, $firmware, serial console (timeout ${timeout}s)"
accel=tcg
[[ -w /dev/kvm ]] && accel=kvm
firmware_args=()
if [[ $firmware == uefi ]]; then
    cp "$ovmf/OVMF_VARS.fd" "${disk%.img}.vars.fd"
    firmware_args=(
        -drive "if=pflash,format=raw,readonly=on,file=$ovmf/OVMF_CODE.fd"
        -drive "if=pflash,format=raw,file=${disk%.img}.vars.fd"
    )
fi
serial="${disk%.img}.serial.log"
rm -f "$serial"
qemu-system-x86_64 -machine "accel=$accel" -m 4096 -smp 4 \
    "${firmware_args[@]}" \
    -drive "file=$disk,format=raw,if=virtio" \
    -display none -serial "file:$serial" -no-reboot &
qemu=$!
result=timeout
for (( i = 0; i < timeout; i += 5 )); do
    sleep 5
    if grep -aqE "Kernel panic|not found\.|you need to load the kernel|Entering emergency mode|You are in emergency mode|^error: " "$serial" 2>/dev/null; then
        result=fail; break
    fi
    if grep -aq "login:" "$serial" 2>/dev/null; then
        sleep 30   # let late services start (or fail) before judging
        result=pass; break
    fi
    kill -0 "$qemu" 2>/dev/null || { result=exited; break; }
done
kill "$qemu" 2>/dev/null || true
wait "$qemu" 2>/dev/null || true
chmod a+r "$serial"

failed="$(sed 's/\x1b\[[0-9;]*m//g' "$serial" | grep -a '\[FAILED\]' | sort -u || true)"
if [[ "$result" == pass && -n "$failed" ]]; then
    result="fail (services failed)"
fi
echo "install-test: failed services:"
# shellcheck disable=SC2001  # indent each line of a multi-line list
echo "${failed:-none}" | sed 's/^/  /'
echo "install-test: serial console (welcome line and the end):"
grep -a "Welcome to" "$serial" | sed 's/\x1b\[[0-9;]*m//g; s/^/  /'
tail -n 5 "$serial" | sed 's/\x1b\[[0-9;]*m//g; s/^/  /'
echo "install-test: result: $result (accel: $accel; full log: $serial)"
[[ "$result" == pass ]]
