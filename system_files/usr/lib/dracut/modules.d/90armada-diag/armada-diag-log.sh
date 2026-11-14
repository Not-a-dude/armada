#!/bin/bash
# Continuous logger writing kernel & initrd logs to /dev/sda14 (exaid).

EXAID=""
for dev in /dev/disk/by-partlabel/exaid /dev/sda14 /dev/block/by-name/exaid; do
    if [ -b "$dev" ]; then
        EXAID="$dev"
        break
    fi
done

[ -n "$EXAID" ] || exit 0

while true; do
    {
        echo "=== ARMADA SNAPSHOT $(date 2>/dev/null || true) ==="
        echo "uptime: $(cat /proc/uptime 2>/dev/null || true)"
        echo "cmdline: $(cat /proc/cmdline 2>/dev/null || true)"
        echo "=== MOUNTPOINTS ==="
        cat /proc/mounts 2>/dev/null || true
        echo "=== DMESG ==="
        dmesg 2>/dev/null || true
        echo "=== END SNAPSHOT ==="
    } | dd of="$EXAID" bs=1M conv=fsync status=none 2>/dev/null || true
    sleep 3
done
