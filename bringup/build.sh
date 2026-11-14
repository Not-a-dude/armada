#!/bin/bash
set -euxo pipefail

# Keep the hostname stable so the USB-Ethernet link is easy to spot.
echo armada-bringup >/etc/hostname

pkgs=(
    btrfs-progs
    curl
    dracut
    dracut-config-generic
    dosfstools
    e2fsprogs
    gdisk
    google-noto-sans-mono-fonts
    iproute
    jq
    libdrm
    libX11
    openssh-server
    podman
    skopeo
    sudo
    systemd-networkd
    util-linux
    NetworkManager-wifi
    wpa_supplicant
)

dnf -y install --setopt=install_weak_deps=False "${pkgs[@]}"
dnf -y install /splash/*.rpm /umtp/*.rpm

# bootc expects exactly one kernel under /usr/lib/modules; fedora-bootc ships
# its own.
dnf -y remove kernel kernel-core kernel-modules kernel-modules-core 2>/dev/null || true
rm -rf /usr/lib/modules/*

# Kernel, modules and the DTB set (ootree copies lib/modules/$KVER/dtb onto the
# ESP and writes fdtdir into the BLS entry).
tar --extract --zstd --keep-directory-symlink -f /kernel/armada-kernel-*.tar.zst -C /
KVER="$(ls /usr/lib/modules)"
depmod -a "${KVER}" -b /

# miatoll firmware ships in system_files (usr/lib/firmware/qcom/sm7125/miatoll);
# the a615 zap shader and touch firmware are requested before switch-root on
# this board, so they are also pinned into the initramfs below.

# Armada's boot-side configuration. Services whose packages are absent here stay
# installed-but-disabled; only the splash, sshd and the MTP/ECM gadget run.
cp -a /ctx/system_files/. /

# armada-splash falls back to its embedded bitmap font, but the full build links
# the real face; keep both images consistent.
splash_font="$(rpm -ql google-noto-sans-mono-fonts | grep -m1 '/NotoSansMono-SemiBold\.ttf$')"
[ -n "${splash_font}" ]
ln -sf "${splash_font}" /usr/share/armada/splash/font.ttf

systemd-sysusers
install -d -m 0700 -o armada -g armada /var/home/armada
echo 'armada:armada' | chpasswd
chmod 0755 /usr/libexec/armada/*

# NetworkManager ignores connection files with group/other access.
find /etc/NetworkManager/system-connections -name '*.nmconnection' \
    -exec chmod 0600 {} + -exec chown root:root {} + 2>/dev/null || true

# fedora-bootc ships /root -> var/roothome, absent in the build container.
mkdir -p /var/roothome

dracut \
    --force \
    --no-hostonly \
    --reproducible \
    --kver "${KVER}" \
    --add ostree \
    --add armada-splash \
    --install "/usr/lib/firmware/qcom/sm7125/miatoll/a615_zap.mbn /usr/lib/firmware/qcom/sm7125/miatoll/ipa_fws.mbn /usr/lib/firmware/focaltech_ts_fw_huaxing.bin /usr/lib/firmware/novatek_ts_tianma_fw.bin" \
    "/usr/lib/modules/${KVER}/initramfs.img" "${KVER}"

# Debug hatch: SSH over the ECM function of the MTP gadget at 192.168.7.2.
systemctl enable sshd.service
systemctl enable armada-mtp.service
# bootc install is driven from the ESP by armada-efi-update; the stock unit
# tries to run `bootctl` against a bootloader we never installed.
systemctl mask bootloader-update.service
# usb0 is configured by networkd (10-usb0.network); NM keeps it unmanaged.
systemctl enable systemd-networkd.service

# The sail is the whole point of this image: it runs in the initramfs and
# stays up through switch-root until something else paints the screen.
systemctl enable armada-splash-early.service
systemctl enable armada-splash-reboot-screen.service
systemctl enable armada-splash-poweroff-screen.service

# No desktop in this image; the initramfs splash outlives switch-root.
systemctl set-default multi-user.target

# The sail owns the framebuffer: a tty1 getty would print the login prompt on
# top of it. Log in over the USB-Ethernet link instead (armada/armada).
systemctl mask getty@tty1.service

lsinitrd "/usr/lib/modules/${KVER}/initramfs.img" | grep -E 'armada-splash$|a615_zap|focaltech' || {
    echo "ERROR: splash binary or miatoll firmware missing from initramfs" >&2
    exit 1
}
