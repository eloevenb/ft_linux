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

groupadd lfs

useradd -s /bin/bash -g lfs -m -k /dev/null lfs

# -g lfs : primary group lfs
# -m : create home directory
# -k /dev/null : do not copy any files into home directory

passwd lfs << EOF
lfs
lfs
EOF
echo -e "${GREEN}Created user lfs:lfs${NC}"

chown -v lfs $LFS/tools
chown -v lfs $LFS/sources

echo -e "You can now login as the lfs user using: ${YELLOW}su - lfs${NC}"