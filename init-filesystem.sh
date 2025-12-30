#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
DISK="/dev/sda"
SWAP_PART="/dev/sda3"
BOOT_PART="/dev/sda1"
ROOT_PART="/dev/sda2"

# Calculate in megabytes
DISK_SIZE=$(blockdev --getsize64 /dev/sda | awk '{print int($1/1048576 - 1)""}')
BOOT_SIZE=$((1024))      # 1 GiB
SWAP_SIZE=$((4 * 1024))	 # 4 GiB
ROOT_SIZE=$((DISK_SIZE - BOOT_SIZE - SWAP_SIZE))

BOOT_START=1
BOOT_END=$((BOOT_START + BOOT_SIZE))
ROOT_START=$BOOT_END
ROOT_END=$((ROOT_START + ROOT_SIZE))
SWAP_START=$ROOT_END
SWAP_END=$((DISK_SIZE))

# Check if running as root
if [ "$EUID" -ne 0 ]; then
	echo -e "${RED}Please run as root${NC}"
	exit 1
fi

echo -e "${YELLOW}[Creating GPT partition table on ${DISK}]${NC}"
parted "${DISK}" --script -- mklabel gpt

echo -e "${YELLOW}[Creating boot partition: ${BOOT_START}MiB - ${BOOT_END}MiB (${BOOT_SIZE}MiB)]${NC}"
parted "${DISK}" --script -- mkpart primary ext4 ${BOOT_START}MiB ${BOOT_END}MiB

echo -e "${YELLOW}[Creating root partition: ${ROOT_START}MiB - ${ROOT_END}MiB (${ROOT_SIZE}MiB)]${NC}"
parted "${DISK}" --script -- mkpart primary ext4 ${ROOT_START}MiB ${ROOT_END}MiB

echo -e "${YELLOW}[Creating swap partition: ${SWAP_START}MiB - ${SWAP_END}MiB (${SWAP_SIZE}MiB)]${NC}"
parted "${DISK}" --script -- mkpart primary linux-swap ${SWAP_START}MiB ${SWAP_END}MiB

echo -e "${YELLOW}[Setting boot flag on partition 1]${NC}"
parted "${DISK}" --script -- set 1 boot on

echo -e "${GREEN}[Formatting boot partition as ext4]${NC}"
mkfs.ext4 -L "BOOT" "${DISK}1"

echo -e "${GREEN}[Formatting root partition as ext4]${NC}"
mkfs.ext4 -L "ROOT" "${DISK}2"

echo -e "${GREEN}[Creating swap on partition 3]${NC}"
mkswap -L "SWAP" "${DISK}3"

echo -e "${GREEN}[Partition table:]${NC}"
parted "${DISK}" print

echo -e "${GREEN}[Filesystem information:]${NC}"
blkid "${DISK}1" "${DISK}2" "${DISK}3"

mkdir -p /mnt/lfs

export LFS=/mnt/lfs

echo -e "${YELLOW}[Mounting LFS partitions]${NC}"
mount -v -t ext4 "${ROOT_PART}" $LFS
mkdir -v $LFS/boot
mount -v -t ext4 "${BOOT_PART}" $LFS/boot
swapon -v "${SWAP_PART}"

if [ ! -d "$LFS/sources" ]; then
	echo -e "${GREEN}[Creating sources directory]${NC}"
	mkdir -v $LFS/sources
	chmod -v a+wt $LFS/sources
fi

if [ ! -f "$LFS/sources/wget-list" ]; then
	echo -e "${GREEN}[Fetching wget-list]${NC}"
	wget --input-file="https://raw.githubusercontent.com/eloevenb/ft_linux/refs/heads/main/wget-list" --continue --directory-prefix=$LFS/sources
	wget "https://www.linuxfromscratch.org/museum/lfs-museum/8.2/md5sums" --continue --directory-prefix=$LFS/sources
	echo -e "${YELLOW}[Patching ftp.gnu.org URLs to ftpmirror.gnu.org]${NC}"
	sed -i 's|ftp.gnu.org|ftpmirror.gnu.org|g' $LFS/sources/wget-list
	cd $LFS/sources
	wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
fi

chown root:root $LFS/sources/*

echo -e "${GREEN}[Verifying source file checksums]${NC}"
pushd $LFS/sources
md5sum -c md5sums
popd


