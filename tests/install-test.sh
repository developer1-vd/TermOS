#!/usr/bin/env bash
# install-test.sh: install TermOS onto a virtual disk with its installer,
# Anaconda, then boot the disk in QEMU and check that it starts. Or, for the
# ARM board image, just boot that.
#
#   sudo tests/install-test.sh ROOTFS DISK.img [TIMEOUT_SECONDS] [bios|uefi]
#   sudo tests/install-test.sh BOARD.raw[.xz] DISK.img [TIMEOUT_SECONDS]
#
# ROOTFS is the live system's root filesystem image, such as the
# lmc-disk-*.img livemedia-creator leaves in build/out/ (or the ISO's
# LiveOS/squashfs.img). The test runs for this machine's architecture
# (x86_64 or aarch64), so test an aarch64 ISO on an ARM64 machine.
#
# BOARD.raw[.xz] is the ARM board image (TERMOS_IMAGE=disk). It has no
# installer: the test copies it to DISK.img, checks its fstab, and boots it
# as it is (UEFI), as a board's U-Boot or firmware would.
#
# Anaconda runs unattended from a kickstart, installing from ROOTFS (the
# liveimg payload, as the live installer does) onto DISK.img with automatic
# partitioning, which is what the web UI's "use the entire disk" does. The
# disk is then booted in QEMU, with KVM when available. The test passes when
# the serial console shows a login prompt and no service failed.
#
# Firmware (default bios on x86_64, uefi on aarch64): Anaconda installs the
# boot loader for the firmware of the machine it runs on. For "bios" the test
# hides this machine's EFI firmware from it (if it has one) and boots the
# disk with SeaBIOS; for "uefi" the machine must boot with UEFI, and the disk
# boots with OVMF (AAVMF on aarch64). ARM has only uefi.
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
# them Anaconda's storage module won't start), rsync, and QEMU with its UEFI
# firmware: qemu-system-x86-core and edk2-ovmf on x86_64,
# qemu-system-aarch64-core and edk2-aarch64 on aarch64. Anaconda also needs
# the btrfs kernel module: in a container, load it on the host and share the
# host's /lib/modules.
# Run it in a Fedora container or VM of TermOS's release.
set -euo pipefail

src="$(realpath "$1")"
disk="$(realpath -m "$2")"
timeout="${3:-1800}"
arch="$(uname -m)"
slow_boot_args=""

die() { echo "install-test: $*" >&2; exit 1; }
step() { echo "install-test: == $*"; }

case "$src" in
    *.raw|*.raw.xz) mode=board ;;
    *)              mode=install ;;
esac
# Per architecture: QEMU, its UEFI firmware (code + a template for the
# variables), and the serial console's name in Linux.
case "$arch" in
    x86_64)
        qemu_bin=qemu-system-x86_64 console=ttyS0
        fw_code=/usr/share/edk2/ovmf/OVMF_CODE.fd fw_vars=/usr/share/edk2/ovmf/OVMF_VARS.fd
        firmware="${4:-bios}"
        ;;
    aarch64)
        qemu_bin=qemu-system-aarch64 console=ttyAMA0
        # Without KVM (GitHub's ARM runners) QEMU emulates the CPU, and udev
        # can take longer than systemd's 45 s to show the disks; that's the
        # emulation, not the system, so the test gives it more time.
        [[ -w /dev/kvm ]] || slow_boot_args="systemd.default_device_timeout_sec=600"
        fw_code=/usr/share/edk2/aarch64/QEMU_EFI-pflash.raw
        fw_vars=/usr/share/edk2/aarch64/vars-template-pflash.raw
        firmware="${4:-uefi}"
        [[ $firmware == uefi ]] || die "ARM machines boot with UEFI only, not $firmware"
        ;;
    *) die "unsupported architecture: $arch" ;;
esac
[[ $mode == install ]] || firmware=uefi

[[ $EUID -eq 0 ]] || die "run as root"
[[ -f "$src" ]] || die "no such image: $1"
tools=(losetup "$qemu_bin")
[[ $mode == install ]] && tools+=(anaconda)
for tool in "${tools[@]}"; do
    command -v "$tool" >/dev/null || die "missing tool: $tool"
done
case "$firmware" in
    bios) ;;
    uefi)
        if [[ $mode == install ]]; then
            [[ -d /sys/firmware/efi ]] || die "uefi: this machine doesn't boot with UEFI"
        fi
        [[ -f $fw_code && -f $fw_vars ]] || die "uefi: missing QEMU's UEFI firmware ($fw_code)"
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
install_and_inspect() {
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
bootloader --append="console=tty0 console=$console,115200 systemd.show_status=1${slow_boot_args:+ $slow_boot_args}"
rootpw --lock
user --name=tester --password=termos --plaintext --groups=wheel
shutdown

%post
# Test-only: don't list the test machine's own systems (the container sees
# its disks), and on BIOS put GRUB on the serial port too, so a GRUB error
# shows in the log. (UEFI firmware copies the console there already, and
# Fedora's signed EFI GRUB has no serial terminal.)
echo 'GRUB_DISABLE_OS_PROBER=true' >> /etc/default/grub
if [ "$firmware" = bios ]; then
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
    sed -i "s|^${dev}[[:space:]]|UUID=$uuid |" "$t/etc/fstab"
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
}

# ---- Board image: use it as it is -------------------------------------------
board_inspect() {
    # Write the image the way users do, with iso/flash-board.sh, and check
    # that putting a board's U-Boot on the card can't damage the image:
    #  - every Allwinner board's U-Boot (the Orange Pi boards) fits in the
    #    gap before the first partition;
    #  - a U-Boot that doesn't fit (Rockchip's) is refused, image intact;
    #  - with an Orange Pi U-Boot written, everything from the first
    #    partition on is unchanged. That disk is the one booted below.
    local flash ref="$work/ref.bin" uboot_board=orangepi_zero2 big_board=orangepi-rk3399
    flash="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/iso/flash-board.sh"
    step "board image: flash-board.sh must refuse $big_board (U-Boot too big for the card)"
    rm -f "$disk"
    if "$flash" --yes "$src" "$disk" "$big_board" > "$work/flash.out" 2>&1; then
        cat "$work/flash.out"; die "flash-board.sh wrote a U-Boot that overlaps the first partition"
    fi
    grep -q "would overwrite the first partition" "$work/flash.out" \
        || { cat "$work/flash.out"; die "flash-board.sh failed for another reason"; }
    # The image's first 64 MiB as flash-board.sh wrote them without a U-Boot.
    head -c $((64 * 1024 * 1024)) "$disk" > "$ref"
    step "board image: boards with U-Boot in the image"
    "$flash" --list "$disk" | tee "$work/boards.txt" | sed 's/^/  /'
    grep -q "^  $uboot_board\$" "$work/boards.txt" || die "no U-Boot for $uboot_board in the image"
    if grep -E '^  [a-z0-9_]+ +\(too big' "$work/boards.txt" | grep -q orangepi_; then
        die "an Allwinner Orange Pi U-Boot no longer fits before the first partition"
    fi
    step "board image: write it with the $uboot_board U-Boot"
    "$flash" --yes "$src" "$disk" "$uboot_board" 2>&1 | grep '^flash-board' | sed 's/^/  /'
    cmp <(head -c 8192 "$ref") <(head -c 8192 "$disk") \
        || die "writing U-Boot changed the partition table"
    cmp <(tail -c +$((1024 * 1024 + 1)) "$ref") <(head -c $((64 * 1024 * 1024)) "$disk" | tail -c +$((1024 * 1024 + 1))) \
        || die "writing U-Boot changed data from the first partition on"
    if cmp -s <(head -c $((1024 * 1024)) "$ref") <(head -c $((1024 * 1024)) "$disk"); then
        die "no U-Boot was written"
    fi
    echo "install-test: U-Boot written; partition table and partitions unchanged"
    step "inspect: partitions and fstab"
    loop="$(losetup -fP --show "$disk")"
    partx -u "$loop" 2>/dev/null || true
    udevadm settle 2>/dev/null || sleep 2
    blkid "$loop"p* | sed 's/^/  /'
    local part root=""
    for part in "$loop"p*; do
        mkdir -p "$work/top"
        mount -o ro "$part" "$work/top" 2>/dev/null || continue
        if [[ -f "$work/top/etc/fstab" ]]; then root="$part"; fi
        umount "$work/top"
        [[ -n $root ]] && break
    done
    [[ -n $root ]] || die "no root file system (with /etc/fstab) in the image"
    mount -o ro "$root" "$work/top"
    echo "install-test: fstab:"
    grep -v '^#' "$work/top/etc/fstab" | sed '/^$/d; s/^/  /'
    # The board has none of the build machine's device names.
    if grep -qE '^/dev/(mapper|loop)' "$work/top/etc/fstab"; then
        die "fstab names build-time devices; the board couldn't mount them"
    fi
    umount "$work/top"
    # Nor may the boot entries (root=) on the /boot partition. (On this
    # test copy only, give an emulated boot more time; see slow_boot_args.)
    for part in "$loop"p*; do
        mount "$part" "$work/top" 2>/dev/null || continue
        if [[ -d "$work/top/loader/entries" ]]; then
            echo "install-test: boot entries:"
            grep -h -E '^(title|options)' "$work"/top/loader/entries/*.conf | sed 's/^/  /'
            if grep -qs '/dev/mapper/\|/dev/loop' "$work"/top/loader/entries/*.conf; then
                umount "$work/top"
                die "the boot entries name build-time devices; the board couldn't find its root"
            fi
            if [[ -n $slow_boot_args ]]; then
                sed -i "s|^options .*|& $slow_boot_args|" "$work"/top/loader/entries/*.conf
            fi
        fi
        umount "$work/top"
    done
    # The EFI partition (vfat) has GRUB, and U-Boot for the Raspberry Pi.
    local esp=""
    for part in "$loop"p*; do
        [[ "$(blkid -o value -s TYPE "$part" 2>/dev/null)" == vfat ]] && { esp="$part"; break; }
    done
    [[ -n $esp ]] || die "no EFI partition in the image"
    mount -o ro "$esp" "$work/top"
    echo "install-test: EFI partition:"
    (cd "$work/top" && find . -maxdepth 3 \( -name '*.efi' -o -name 'rpi-u-boot.bin' -o -name config.txt \) | sort | sed 's/^/  /')
    [[ -f "$work/top/rpi-u-boot.bin" ]] || die "no rpi-u-boot.bin: the image won't boot on a Raspberry Pi"
    ls "$work"/top/EFI/*/grubaa64.efi >/dev/null 2>&1 || die "no GRUB (grubaa64.efi) on the EFI partition"
    umount "$work/top"
}

if [[ $mode == install ]]; then
    install_and_inspect
else
    board_inspect
fi
cleanup
trap - EXIT
loop=""

# ---- Boot it -------------------------------------------------------------------
step "boot: QEMU ($arch), $firmware, serial console (timeout ${timeout}s)"
accel=tcg
[[ -w /dev/kvm ]] && accel=kvm
machine_args=()
case "$arch" in
    x86_64)  machine_args=(-machine "accel=$accel") ;;
    aarch64)
        # The "virt" board; with KVM, the host's own CPU, otherwise emulated.
        if [[ $accel == kvm ]]; then
            machine_args=(-machine "virt,accel=kvm,gic-version=host" -cpu host)
        else
            machine_args=(-machine "virt,accel=tcg" -cpu max)
        fi
        ;;
esac
firmware_args=()
if [[ $firmware == uefi ]]; then
    cp "$fw_vars" "${disk%.img}.vars.fd"
    firmware_args=(
        -drive "if=pflash,format=raw,readonly=on,file=$fw_code"
        -drive "if=pflash,format=raw,file=${disk%.img}.vars.fd"
    )
fi
serial="${disk%.img}.serial.log"
rm -f "$serial"
"$qemu_bin" "${machine_args[@]}" -m 4096 -smp 4 \
    "${firmware_args[@]}" \
    -drive "file=$disk,format=raw,if=virtio" \
    -display none -serial "file:$serial" -no-reboot &
qemu=$!
result=timeout
for (( i = 0; i < timeout; i += 5 )); do
    sleep 5
    # GRUB errors fail the test, except about its serial terminal (the
    # test's console=ttyS0/ttyAMA0 makes Anaconda configure one, which EFI
    # GRUB on ARM doesn't have) and the boot partition's GPT UUID (an MBR
    # disk like the board image has none). GRUB carries on after both.
    if grep -aE "Kernel panic|not found\.|you need to load the kernel|Entering emergency mode|You are in emergency mode|^error: " "$serial" 2>/dev/null \
            | grep -aqvE "terminal \`serial' isn't found|serial port \`auto' isn't found|unable to determine partition UUID of boot device"; then
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
