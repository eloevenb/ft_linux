#!/bin/bash

set -e 

NC='\033[0m'
DISK="/dev/sdb"

fuser -k ${DISK}* 2>/dev/null || true
umount ${DISK}* 2>/dev/null || true
sleep 1
dd if=/dev/zero of=$DISK bs=512 count=1
swapoff /dev/sdb3
partprobe $DISK

rm -rf /mnt/lfs