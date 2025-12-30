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
SWAP_SIZE=$((4 * 1024))  # 4 GiB
ROOT_SIZE=$((DISK_SIZE - BOOT_SIZE - SWAP_SIZE))

BOOT_START=1
BOOT_END=$((BOOT_START + BOOT_SIZE))
ROOT_START=$BOOT_END
ROOT_END=$((ROOT_START + ROOT_SIZE))
SWAP_START=$ROOT_END
SWAP_END=$DISK_SIZE

# Check if running as root
if [ "$EUID" -ne 0 ]; then
	echo -e "${RED}Please run as root${NC}"
	exit 1
fi

echo -e "${YELLOW}[Unmounting all /dev/sda partitions and disabling swap]${NC}"
for mnt in $(mount | grep '^/dev/sda' | awk '{print $3}' | sort -r); do
    umount -l "$mnt" || true
done
if swapon --show=NAME | grep -q '^/dev/sda3'; then
    swapoff /dev/sda3
fi



# Idempotent partitioning and formatting
NEED_PARTITIONING=false

# Check boot partition
if ! blkid ${BOOT_PART} | grep -q 'TYPE="ext4"'; then
	NEED_PARTITIONING=true
fi
# Check root partition
if ! blkid ${ROOT_PART} | grep -q 'TYPE="ext4"'; then
	NEED_PARTITIONING=true
fi
# Check swap partition
if ! blkid ${SWAP_PART} | grep -q 'TYPE="swap"'; then
	NEED_PARTITIONING=true
fi

if $NEED_PARTITIONING; then
	echo -e "${YELLOW}[WIPING AND RECREATING PARTITIONS ON ${DISK} - DATA LOSS WARNING]${NC}"
	sgdisk --zap-all ${DISK}
	parted "${DISK}" --script -- mklabel gpt

	echo -e "${YELLOW}[Creating boot partition: ${BOOT_START}MiB - ${BOOT_END}MiB (${BOOT_SIZE}MiB)]${NC}"
	parted "${DISK}" --script -- mkpart primary ext4 ${BOOT_START}MiB ${BOOT_END}MiB
	echo -e "${YELLOW}[Setting boot flag on partition 1]${NC}"
	parted "${DISK}" --script -- set 1 boot on
	echo -e "${GREEN}[Formatting boot partition as ext4]${NC}"
	mkfs.ext4 -L "BOOT" "${DISK}1"

	echo -e "${YELLOW}[Creating root partition: ${ROOT_START}MiB - ${ROOT_END}MiB (${ROOT_SIZE}MiB)]${NC}"
	parted "${DISK}" --script -- mkpart primary ext4 ${ROOT_START}MiB ${ROOT_END}MiB
	echo -e "${GREEN}[Formatting root partition as ext4]${NC}"
	mkfs.ext4 -L "ROOT" "${DISK}2"

	echo -e "${YELLOW}[Creating swap partition: ${SWAP_START}MiB - ${SWAP_END}MiB (${SWAP_SIZE}MiB)]${NC}"
	parted "${DISK}" --script -- mkpart primary linux-swap ${SWAP_START}MiB ${SWAP_END}MiB
	echo -e "${GREEN}[Creating swap on partition 3]${NC}"
	mkswap -L "SWAP" "${DISK}3"
	partprobe ${DISK}
	sleep 2
else
	echo -e "${GREEN}[Partitions and filesystems already set up, skipping partitioning]${NC}"
fi

echo -e "${GREEN}[Partition table:]${NC}"
parted "${DISK}" print

echo -e "${GREEN}[Filesystem information:]${NC}"
blkid "${DISK}1" "${DISK}2" "${DISK}3"

mkdir -p /mnt/lfs

export LFS=/mnt/lfs


# Unmount all existing /mnt/lfs and /mnt/lfs/boot mountpoints to avoid duplicate mounts
while mount | grep -q "on $LFS "; do
	echo -e "${YELLOW}Unmounting duplicate $LFS...${NC}"
	umount -l $LFS
done
while mount | grep -q "on $LFS/boot "; do
	echo -e "${YELLOW}Unmounting duplicate $LFS/boot...${NC}"
	umount -l $LFS/boot
done

echo -e "${YELLOW}[Mounting LFS partitions]${NC}"
if ! mountpoint -q $LFS; then
	mount -v -t ext4 "${ROOT_PART}" $LFS
else
	echo -e "${GREEN}[Root partition already mounted]${NC}"
fi

mkdir -pv $LFS/boot

if ! mountpoint -q $LFS/boot; then
	mount -v -t ext4 "${BOOT_PART}" $LFS/boot
else
	echo -e "${GREEN}[Boot partition already mounted]${NC}"
fi

if ! swapon -s | grep -q "${SWAP_PART}"; then
	swapon -v "${SWAP_PART}"
else
	echo -e "${GREEN}[Swap already active]${NC}"
fi

mkdir -pv $LFS/{etc,var,tools,scripts,sources,usr/{bin,lib,sbin}}
ln -sfv $LFS/tools /

for i in bin lib sbin; do
    ln -sfv usr/$i $LFS/$i
done

case $(uname -m) in
    x86_64) ln -sfv lib $LFS/lib64 ;;
esac

if ! getent group lfs > /dev/null 2>&1; then
	groupadd lfs
fi

if ! id -u lfs > /dev/null 2>&1; then
	useradd -s /bin/bash -g lfs -m -k /dev/null lfs
	echo "lfs:lfs" | chpasswd
	echo -e "${GREEN}Created user lfs:lfs${NC}"
else
	echo -e "${GREEN}User lfs already exists${NC}"
fi

echo -e "${GREEN}[Configuring lfs user environment]${NC}"
cat > /home/lfs/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

cat > /home/lfs/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF

chown lfs:lfs /home/lfs/.bash_profile /home/lfs/.bashrc

chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac

if [ ! -d "$LFS/scripts/.git" ]; then
	cd $LFS/scripts
	git clone https://github.com/eloevenb/ft_linux.git .
	cd -
else
	echo -e "${GREEN}[Scripts already cloned, updating...]${NC}"
fi

chown -R lfs:lfs /mnt/lfs/

chown -v lfs $LFS/tools
chown -v lfs $LFS/sources
chown -v lfs $LFS/scripts

git config --global --add safe.directory $LFS/scripts

cd $LFS/scripts
git pull
cd -

# Check md5sums before downloading packages
echo -e "${YELLOW}[Verifying source file checksums before download]${NC}"
pushd $LFS/sources
if md5sum -c md5sums | grep -q 'FAILED'; then
    echo -e "${YELLOW}[Some checksums failed, downloading packages...]${NC}"
    bash $LFS/scripts/2-get-sources.sh
else
    echo -e "${GREEN}[All source checksums OK, skipping download]${NC}"
fi
popd

bash $LFS/scripts/3-install-packages.sh