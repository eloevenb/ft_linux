#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ensure this is run as lfs user
if [ "$(id -u)" -eq 0 ]; then
	echo -e "${RED}Please run as the lfs user, not as root${NC}"
	exit 1
fi

# ensure LFS variable is set
if [ -z "$LFS" ]; then
	echo -e "${RED}LFS variable is not set. Please set LFS to the mount point of your LFS partition.${NC}"
	exit 1
fi

cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
MAKEFLAGS='-j8'
export LFS LC_ALL LFS_TGT PATH MAKEFLAGS
EOF

source ~/.bash_profile