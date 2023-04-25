#!/bin/bash

# Find disk name and set to "sda" if not found
diskName=$(lsblk -o NAME | grep -m 1 "nvme")
diskName=${diskName:-sda}

# Remove filesystem signature from disk
wipefs -a "/dev/$diskName"

# Create partition table
parted "/dev/$diskName" --script mklabel gpt

# Create EFI partition
create_efi_partition() {
    parted --script "/dev/$diskName" \
        mkpart primary fat32 1MiB 512MiB \
        set 1 esp on
}
create_efi_partition

# Calculate swap partition size based on memory size
memorySize=$(free -m | awk '/^Mem:/{print $2}')
swapPartitionSize=$((memorySize * 2))

# Create swap partition
create_swap_partition() {
    parted --script "/dev/$diskName" \
        mkpart primary linux-swap 512MiB $((512 + swapPartitionSize))MiB
}
create_swap_partition

# Calculate available disk space for root and home partitions
diskSize=$(lsblk -o SIZE -b -d "/dev/$diskName" | tail -1 | awk '{ byte =$1 /1024/1024/1024 ; printf "%.0f", byte }')
availableDiskSize=$(bc <<<"$diskSize - 4 - $swapPartitionSize/1024")
clear
echo "Available disk space: $availableDiskSize GiB"

# Prompt user to input size for root and home partitions
read_partition_sizes() {
    read -r -p "Enter size for root partition (e.g. 20): " rootPartitionSizeGiB
    read -r -p "Enter size for home partition (e.g. 30): " homePartitionSizeGiB
}
read_partition_sizes

# Convert input sizes from GiB to MiB
rootPartitionSizeMiB=$(bc <<<"$rootPartitionSizeGiB * 1024")
homePartitionSizeMiB=$(bc <<<"$homePartitionSizeGiB * 1024")

# Create root partition
create_root_partition() {
    parted --script "/dev/$diskName" \
        mkpart primary ext4 $((512 + swapPartitionSize))MiB $((512 + swapPartitionSize + rootPartitionSizeMiB))MiB
}
create_root_partition

# Create home partition
create_home_partition() {
    parted --script "/dev/$diskName" \
        mkpart primary ext4 $((512 + swapPartitionSize + rootPartitionSizeMiB))MiB $((512 + swapPartitionSize + rootPartitionSizeMiB + homePartitionSizeMiB))MiB
}
create_home_partition

# Format partitions
format_partitions() {
    mkfs.fat -F32 "/dev/${diskName}1"
    mkswap "/dev/${diskName}2"
    mkfs.ext4 "/dev/${diskName}3"
    mkfs.ext4 "/dev/${diskName}4"
}
format_partitions

# Create mount points and mount partitions
create_mount_points() {
    mkdir /mnt
    mount "/dev/${diskName}3" /mnt
    mkdir /mnt/boot
    mount "/dev/${diskName}1" /mnt/boot
    mkdir /mnt/home
    mount "/dev/${diskName}4" /mnt/home
    swapon "/dev/${diskName}2"
}
create_mount_points

# Install base packages
pacstrap /mnt base base-devel fwupd intel-ucode linux linux-firmware mesa vim x86-video-intel
# Generate fstab file
genfstab -U /mnt >>/mnt/etc/fstab
# Chroot into new system
arch-chroot /mnt
