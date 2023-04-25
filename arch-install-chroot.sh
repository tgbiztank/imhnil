#!/bin/bash

# Declare variables
packages="ark bluez bluez-utils code discover dolphin efibootmgr git gnome-themes-extra go grub kde-gtk-config konsole kvantum latte-dock libdbusmenu-glib obs-backgroundremoval obs-studio os-prober packagekit-qt5 plasma-browser-integration plasma-desktop plasma-nm plasma-pa plasma5-applets-window-buttons qbittorrent sddm sddm-kcm spectacle thefuck touchegg xorg-xkill zsh"
bootloader_id="MacOS"
efi_directory="/boot"
grub_disable_os_prober="false"
timezone="Asia/Ho_Chi_Minh"
locale="en_US.UTF-8"
hostname="MacOS"
username="tgbiztank"
nopasswd="true"

# Enable sudo without password
echo '%wheel ALL=(ALL) ALL' >>/etc/sudoers
if [ "$nopasswd" = "true" ]; then
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers
else
    sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers
fi

# Install packages
pacman -S -q --noconfirm "$packages"

# Enable services
systemctl enable bluetooth NetworkManager sddm touchegg

# Set system locale
echo "$locale" >/etc/locale.gen
locale-gen
echo "LANG=$locale
LANGUAGE=en_US" >/etc/locale.conf

# Set system timezone
ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
hwclock --systohc

# Set hostname
echo "$hostname" >/etc/hostname
echo "# Static table lookup for hostnames.
# See hosts(5) for details.
127.0.0.1    localhost
::1          localhost
127.0.1.1    $hostname.localdomain    $hostname" >/etc/hosts

# Add user and set passwords
useradd -m -g users -G audio,video,storage,wheel,power,optical,input -s /bin/zsh "$username"
clear
echo "Enter password for user $username:"
passwd $username

# Set root password
echo "Enter password for root:"
passwd

# Install and configure GRUB bootloader
grub-install --efi-directory="$efi_directory" --bootloader-id="$bootloader_id"
echo "GRUB_DISABLE_OS_PROBER=$grub_disable_os_prober" >>/etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
