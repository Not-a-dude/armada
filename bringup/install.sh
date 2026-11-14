#!/usr/bin/bash
# Reinstall the bring-up image into `super` (sda17) and refresh the ESP entries.
# Run on the phone from Arch (the only system here with btrfs + podman):
#   sudo ./bringup/install.sh
# The ESP is the Arch /boot mount (sda7 = cust).
set -euo pipefail

IMG=localhost/armada-bringup:latest
TARGET=/mnt/armada
LOG=/tmp/bootc-install.log

echo "==> unmounting $TARGET (if any)"
umount "$TARGET" 2>/dev/null || true

echo "==> recreating btrfs on /dev/sda17"
wipefs -a /dev/sda17
mkfs.btrfs -f -L armada /dev/sda17 >/dev/null
mount /dev/sda17 "$TARGET"

echo "==> bootc install ($LOG)"
podman run --rm --privileged --pid=host --network=host \
    -v /var/lib/containers:/var/lib/containers \
    -v /dev:/dev \
    -v "$TARGET":/target \
    "$IMG" bootc install to-filesystem \
    --source-imgref "containers-storage:$IMG" \
    --target-imgref "$IMG" \
    --target-transport containers-storage \
    --bootloader none \
    --disable-selinux \
    --skip-fetch-check \
    --karg=clk_ignore_unused \
    --karg=pd_ignore_unused \
    --karg=regulator_ignore_unused \
    --karg=qcom_wdt.enable=0 \
    --karg=panic=0 \
    /target >"$LOG" 2>&1
tail -3 "$LOG"

echo "==> refreshing ESP entries"
mount -o remount,rw "$TARGET"
D="$(realpath "$TARGET"/ostree/boot.1/default/*/0)"
KVER="$(ls "$D"/usr/lib/modules | head -1)"
echo "deployment: $D (kernel $KVER)"

# sd-boot needs a PE image on the ESP; ostree copied the raw zboot Image.
cp --remove-destination "$D/usr/lib/modules/$KVER/vmlinuz.efi" \
    "$TARGET"/boot/ostree/*/vmlinuz-"$KVER"

env ESP=/boot BOOTROOT="$TARGET/boot" SYSROOT="$TARGET" \
    ARGS_FILE="$D/usr/lib/armada/bootimg-args" \
    "$D/usr/libexec/armada/armada-efi-update"

printf 'default armada-ostree-1.conf\ntimeout 5\neditor no\n' | tee /boot/loader/loader.conf >/dev/null

sync
umount "$TARGET"
echo "==> done; reboot into armada-ostree-1.conf"
