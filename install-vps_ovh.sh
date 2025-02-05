#!/bin/bash
#
# install_gentoo.sh - Automate Gentoo installation on OVH VPS
#
# Copyright (C) 2025 Major_Ghz
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Contact: jean-christophe@blues-softwares.net
#

# This script automates the installation of Gentoo Linux on an OVH virtual server
# with an AMD EPYC processor, 4 cores, 4GB RAM, and 80GB SSD.
# It prepares disk partitions, installs the base system, configures the kernel,
# and sets up networking and services.
# Debug option is included for troubleshooting.

DEBUG=true  # Set to false to disable debug mode
STAGE3_URL="http://gentoo.mirrors.ovh.net/gentoo-distfiles/releases/arm64/autobuilds/current-stage3-arm64-openrc/stage3-arm64-openrc-20250202T230326Z.tar.xz"
HOSTNAME="yapyap-server_01"
TIMEZONE="Europe/Paris"
CONFIG_FILE="/usr/src/linux/.config"

log() {
    if [ "$DEBUG" = true ]; then
        echo "[DEBUG] $1"
    fi
}

log "Starting Gentoo installation..."

# ----------------------------
# Prepare disk volumes
# ----------------------------
log "Partitioning disk..."
umount /mnt/sda* || true
echo -e "o\nn\np\n1\n\n+128M\nn\np\n2\n\n+1024M\nn\np\n3\n\n\nt\n2\n82\na\n1\nw" | fdisk /dev/sda
mkfs.xfs /dev/sda1
mkfs.xfs /dev/sda3
mkswap /dev/sda2
swapon /dev/sda2

# ----------------------------
# Install Gentoo stage 3
# ----------------------------
log "Downloading and extracting stage3..."
mkdir -p /mnt/gentoo
mount /dev/sda3 /mnt/gentoo
cd /mnt/gentoo
wget "$STAGE3_URL"
tar xvJpf stage3-*.tar.xz --xattrs --numeric-owner
rm stage3-*.tar.xz

# ----------------------------
# Initial configuration
# ----------------------------
log "Configuring Portage..."
echo 'MAKEOPTS="-j2"' >> /mnt/gentoo/etc/portage/make.conf
echo 'GENTOO_MIRRORS="http://gentoo.mirrors.ovh.net/gentoo-distfiles/"' >> /mnt/gentoo/etc/portage/make.conf
sed -i 's/CFLAGS="/CFLAGS="-march=native /g' /mnt/gentoo/etc/portage/make.conf
echo 'USE="-X -gtk -systemd -qt -gnome -kde -alsa -pulseaudio -doc -nls bash-completion"' >> /mnt/gentoo/etc/portage/make.conf
mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

# ----------------------------
# Chroot to new environment
# ----------------------------
log "Entering chroot environment..."
cp -L /etc/resolv.conf /mnt/gentoo/etc/
mount -t proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev

chroot /mnt/gentoo /bin/bash <<'EOF'
# Define a local log function in the chroot environment.
log() {
    echo "[CHROOT] $1"
}

source /etc/profile
export PS1="(chroot) \$PS1"

# ----------------------------
# Sync system
# ----------------------------
mount /dev/sda1 /boot
emerge-webrsync
emerge --sync
emerge --update --deep --newuse --ask @world

# ----------------------------
# Regional settings
# ----------------------------
log "Configuring regional settings..."
echo "'"$TIMEZONE"'" > /etc/timezone
emerge --config sys-libs/timezone-data
echo 'en_US ISO-8859-1' >> /etc/locale.gen
echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
echo 'LANG="en_US.utf8"' > /etc/env.d/02locale
env-update
source /etc/profile

# ----------------------------
# Kernel configuration and compilation
# ----------------------------
log "Installing kernel sources..."
emerge sys-kernel/gentoo-sources --ask
cd /usr/src/linux
cp .config .config.back

log "Configuring kernel using AWK..."
awk '
BEGIN {
    print "# Processing kernel configuration for OVH virtual server with AMD EPYC..."
}
# Function to enable a config option
function enable_option(option) {
    printf "%s=y\n", option
}
# Function to enable a module
function enable_module(option) {
    printf "%s=m\n", option
}
{
    if (\$1 ~ /^#/ || NF == 0) next;
}
# Virtualization options
enable_option("CONFIG_PARAVIRT")
enable_option("CONFIG_HYPERVISOR_GUEST")
enable_option("CONFIG_VIRTIO_PCI")
enable_option("CONFIG_VIRTIO_BALLOON")
enable_option("CONFIG_VIRTIO_MMIO")
enable_option("CONFIG_VIRTIO_BLK")
enable_option("CONFIG_VIRTIO_PCI_LEGACY")
enable_option("CONFIG_SCSI_VIRTIO")
enable_option("CONFIG_VIRTIO_NET")
enable_option("CONFIG_VHOST_NET")
enable_option("CONFIG_VIRT_DRIVERS")
# Filesystem support
enable_option("CONFIG_EXT2_FS")
enable_option("CONFIG_XFS_FS")
# KVM support
enable_option("CONFIG_KVM")
enable_option("CONFIG_KVM_AMD")
# Enable real-time audio support for QEMU (Jackd, real-time kernel modules)
enable_module("CONFIG_SND_VIRTIO")
enable_module("CONFIG_SND")
enable_module("CONFIG_SND_TIMER")
enable_module("CONFIG_SND_PCM")
enable_module("CONFIG_SND_JACK")
enable_module("CONFIG_SND_HRTIMER")
END {
    print "# Kernel configuration updated successfully."
}' "$CONFIG_FILE" > "${CONFIG_FILE}.new"

mv "${CONFIG_FILE}.new" "$CONFIG_FILE"

log "Compiling kernel..."
make -j2
make modules_install
make install

# ----------------------------
# Networking configuration
# ----------------------------
log "Configuring networking..."
echo "hostname=\"'"$HOSTNAME"'\"" > /etc/conf.d/hostname
echo 'config_eth0="dhcp"' > /etc/conf.d/net
ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
rc-update add net.eth0 default

# ----------------------------
# Additional tools and services
# ----------------------------
log "Installing additional tools..."
emerge syslog-ng cronie dhcpcd --ask
rc-update add syslog-ng default
rc-update add cronie default
rc-update add sshd default

# ----------------------------
# Bootloader installation
# ----------------------------
log "Installing GRUB2..."
emerge --verbose sys-boot/grub:2 --ask
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

# ----------------------------
# Set root password and finalize
# ----------------------------
log "Setting root password..."
passwd
EOF

log "Unmounting and finalizing installation..."
umount -l /mnt/gentoo
echo "Installation complete. Reboot from OVH panel."
