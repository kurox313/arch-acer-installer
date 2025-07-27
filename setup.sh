#!/bin/bash
set -e

# Set up variables
DISK="/dev/mmcblk2"
HOSTNAME="arch-linux"
USERNAME="kuro"
PASSWORD="1111"
LOCALE="en_US.UTF-8"
TIMEZONE="Asia/Bangkok"
KEYMAP="us"
MIRROR_REGION="Singapore"

# Partition the disk
echo "[+] Partitioning $DISK..."
sgdisk -Z $DISK
sgdisk -n1:0:+512M -t1:ef00 -c1:EFI $DISK
sgdisk -n2:0:0 -t2:8300 -c2:ROOT $DISK
EFI_PART="${DISK}p1"
ROOT_PART="${DISK}p2"

mkfs.vfat -F32 $EFI_PART
mkfs.ext4 $ROOT_PART

# Mount
mount $ROOT_PART /mnt
mkdir -p /mnt/boot/efi
mount $EFI_PART /mnt/boot/efi

# Set mirrors
echo "[+] Setting mirror to Singapore..."
reflector --country "$MIRROR_REGION" --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Install base system
echo "[+] Installing base system..."
pacstrap /mnt base linux linux-firmware grub efibootmgr networkmanager sudo plasma kde-applications xorg sddm nano

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot and configure system
arch-chroot /mnt /bin/bash <<EOF

ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "$HOSTNAME" > /etc/hostname
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

useradd -m -G wheel $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "root:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

systemctl enable NetworkManager
systemctl enable sddm

# Zram swap using archinstall style (zram-generator)
pacman -Sy --noconfirm zram-generator

cat > /etc/systemd/zram-generator.conf <<ZRAMCONF
[zram0]
zram-size = ram
compression-algorithm = zstd
ZRAMCONF

# Bootloader setup (32-bit UEFI)
mkdir -p /boot/efi/EFI/BOOT
grub-install --target=i386-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg

EOF

echo "[+] Installation complete! You can now reboot."
