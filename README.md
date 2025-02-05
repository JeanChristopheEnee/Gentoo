# Gentoo GNU/Linux
Fichier de configuration et Script pour Gentoo/Linux


# Gentoo Automated Installation Script for OVH VPS

This repository contains an automated installation script for Gentoo Linux on an OVH virtual server. The script is designed to work on a VPS with the following specifications:

- **Processor:** AMD EPYC
- **Cores:** 4
- **Memory:** 4GB RAM
- **Storage:** 80GB SSD

## Features

- **Automated Disk Partitioning:** Creates partitions for boot, swap, and root.
- **Stage3 Installation:** Downloads and extracts the latest stage3 tarball (URL configurable).
- **Portage Configuration:** Sets `MAKEOPTS`, `GENTOO_MIRRORS`, `CFLAGS`, and `USE` flags.
- **Chroot Environment:** Configures the system within a chroot.
- **Regional Settings:** Configures timezone and locale.
- **Kernel Compilation:** Automatically applies optimizations for virtualization, file systems, and KVM with an AWK script. Supports real-time audio modules.
- **Networking Setup:** Configures hostname (configurable) and DHCP.
- **Additional Services:** Installs and configures syslog-ng, cronie, dhcpcd, and sshd.
- **Bootloader Installation:** Installs GRUB2.
- **GPLv3 Licensed:** See the script header for license details.

## Configuration Variables

You can modify the following variables at the top of the script to suit your needs:

- `DEBUG`: Set to `true` to enable debug logging.
- `STAGE3_URL`: URL for the Gentoo stage3 tarball.
- `HOSTNAME`: Hostname for your Gentoo system.
- `TIMEZONE`: Timezone setting for your system (e.g., `Europe/Paris`).

## Usage

1. **Download the script:**

   ```bash
   wget https://raw.githubusercontent.com/your-username/your-repo/main/install_gentoo.sh
   chmod +x install_gentoo.sh
