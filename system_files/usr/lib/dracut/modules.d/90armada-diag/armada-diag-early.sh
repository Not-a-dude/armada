#!/bin/bash
# Early setup: locate exaid, setup USB gadget network for debug if available.

EXAID=""
for dev in /dev/disk/by-partlabel/exaid /dev/sda14 /dev/block/by-name/exaid; do
    if [ -b "$dev" ]; then
        EXAID="$dev"
        break
    fi
done

if [ -n "$EXAID" ]; then
    {
        echo "=== ARMADA EARLY DIAG START ==="
        echo "date: $(date 2>/dev/null || true)"
        echo "cmdline: $(cat /proc/cmdline 2>/dev/null || true)"
        echo "=== INITIAL DMESG ==="
        dmesg 2>/dev/null || true
        echo "=== END INITIAL DMESG ==="
    } | dd of="$EXAID" bs=1M conv=fsync status=none 2>/dev/null || true
fi

# Try bringing up USB gadget network in initrd
gadget=/sys/kernel/config/usb_gadget/armada-diag
if [ -d /sys/kernel/config ] && [ ! -d "$gadget" ]; then
    mount -t configfs configfs /sys/kernel/config 2>/dev/null || true
    if [ -d /sys/kernel/config ]; then
        mkdir -p "$gadget/strings/0x409" "$gadget/configs/c.1/strings/0x409" 2>/dev/null || true
        echo 0x1d6b > "$gadget/idVendor" 2>/dev/null || true
        echo 0x0100 > "$gadget/idProduct" 2>/dev/null || true
        echo "Armada" > "$gadget/strings/0x409/manufacturer" 2>/dev/null || true
        echo "Armada Diag" > "$gadget/strings/0x409/product" 2>/dev/null || true
        echo "diag001" > "$gadget/strings/0x409/serialnumber" 2>/dev/null || true

        mkdir -p "$gadget/functions/ecm.usb0" 2>/dev/null || true
        echo "02:00:00:00:00:01" > "$gadget/functions/ecm.usb0/dev_addr" 2>/dev/null || true
        echo "02:00:00:00:00:02" > "$gadget/functions/ecm.usb0/host_addr" 2>/dev/null || true
        ln -s "$gadget/functions/ecm.usb0" "$gadget/configs/c.1/" 2>/dev/null || true

        # Bind to UDC
        for udc in /sys/class/udc/*; do
            if [ -e "$udc" ]; then
                echo "${udc##*/}" > "$gadget/UDC" 2>/dev/null || true
                break
            fi
        done

        # Configure network interface if it appeared
        ip link set usb0 up 2>/dev/null || true
        ip addr add 192.168.7.2/24 dev usb0 2>/dev/null || true
    fi
fi

exit 0
