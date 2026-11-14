#!/bin/bash
# Installs early USB gadget network and emergency logging to exaid (/dev/sda14).

check() {
    return 255
}

depends() {
    return 0
}

install() {
    inst_multiple sh bash mkdir mount umount dmesg dd sync ip cat ls sleep cut head tail date

    inst_script "$moddir/armada-diag-early.sh" /usr/libexec/armada/armada-diag-early
    inst_script "$moddir/armada-diag-log.sh" /usr/libexec/armada/armada-diag-log

    # Systemd service running in early initrd
    mkdir -p "$initdir/$systemdsystemunitdir"
    mkdir -p "$initdir/$systemdsystemunitdir/initrd.target.wants"

    cat << 'EOF' > "$initdir/$systemdsystemunitdir/armada-diag-early.service"
[Unit]
Description=Armada Early Diag & USB Gadget
DefaultDependencies=no
Before=dracut-pre-mount.service
After=systemd-modules-load.service

[Service]
Type=oneshot
ExecStart=/usr/libexec/armada/armada-diag-early
RemainAfterExit=yes

[Install]
WantedBy=initrd.target
EOF

    cat << 'EOF' > "$initdir/$systemdsystemunitdir/armada-diag-logger.service"
[Unit]
Description=Armada Continuous Diag Logger to exaid
DefaultDependencies=no
After=armada-diag-early.service
Before=initrd-switch-root.target

[Service]
Type=simple
ExecStart=/usr/libexec/armada/armada-diag-log
Restart=always
RestartSec=1

[Install]
WantedBy=initrd.target
EOF

    ln -s "../armada-diag-early.service" "$initdir/$systemdsystemunitdir/initrd.target.wants/armada-diag-early.service"
    ln -s "../armada-diag-logger.service" "$initdir/$systemdsystemunitdir/initrd.target.wants/armada-diag-logger.service"
}
