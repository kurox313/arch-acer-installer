#!/bin/bash
set -e

# Confirm device
DISK="/dev/mmcblk1"
HOSTNAME="arch-linux"
USERNAME="kuro"
PASSWORD="1111"
LOCALE="en_US.UTF-8"
TIMEZONE="Asia/Bangkok"
MIRROR_COUNTRY="Singapore"

# Partition
echo "Partitioning $DISK..."
sgdisk -Z "$DISK"
sgdisk -n1:1M:+300M -t1:ef00 -c1:EFI "$DISK"
sgdisk -n2:0:0 -t2:8300 -c2:ROOT "$DISK"
mkfs.fat -F32 "${DISK}p1"
mkfs.ext4 "${DISK}p2"

# Mounting
mount "${DISK}p2" /mnt
mkdir -p /mnt/boot/efi
mount "${DISK}p1" /mnt/boot/efi

# Mirror list
reflector --country "$MIRROR_COUNTRY" --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

# Base install
pacstrap /mnt base linux linux-firmware grub efibootmgr sudo networkmanager \
    plasma kde-applications sddm nano zram-generator

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot setup
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i 's/#$LOCALE/$LOCALE/' /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# User setup
echo "root:$PASSWORD" | chpasswd
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Enable services
systemctl enable NetworkManager
systemctl enable sddm
systemctl enable zramd

# Bootloader for 32-bit UEFI
mkdir -p /boot/efi/EFI/BOOT
cp /boot/grub/i386-efi/grub.efi /boot/efi/EFI/BOOT/BOOTIA32.EFI
grub-install --target=i386-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

echo "Done! You can now reboot."
