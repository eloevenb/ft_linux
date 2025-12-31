#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ensure this is run as root
if [ "$EUID" -ne 0 ]; then
	echo -e "${RED}Please run as root${NC}"
	exit 1
fi

# ensure LFS variable is set
if [ -z "$LFS" ]; then
	echo -e "${RED}LFS variable is not set. Please set LFS to the mount point of your LFS partition.${NC}"
	exit 1
fi


mkdir -v $LFS/tools

ln -sv $LFS/tools /

chmod -R a+rx /root/ft_linux
