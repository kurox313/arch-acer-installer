#!/bin/bash

set -e

# Configs
HOSTNAME="arch-linux"
USERNAME="kuro"
PASSWORD="1111"
LOCALE="en_US.UTF-8"
TIMEZONE="Asia/Bangkok"
DRIVE="/dev/mmcblk2"

# Partitions
EFI="${DRIVE}p1"
ROOT="${DRIVE}p2"

echo "==> Setting timezone and locale..."
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc
echo "${LOCALE} UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

# Hostname and network
echo "$HOSTNAME" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOF

echo "==> Setting root password..."
echo "root:$PASSWORD" | chpasswd

echo "==> Creating user $USERNAME..."
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

echo "==> Installing base system..."
pacman -Syu --noconfirm grub efibootmgr sudo networkmanager linux linux-firmware \
    base-devel vim nano network-manager-applet zramd \
    plasma kde-applications sddm

echo "==> Enabling services..."
systemctl enable NetworkManager
systemctl enable sddm
systemctl enable zramd || echo "zramd not available, skipping..."

echo "==> Setting up GRUB for i386-efi..."
grub-install --target=i386-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

echo "==> Done! Reboot to finish."
