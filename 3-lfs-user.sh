#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
export LFS=/mnt/lfs

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

chown -R lfs:lfs /mnt/lfs/

chown -v lfs $LFS/tools
chown -v lfs $LFS/sources
chown -v lfs $LFS/scripts

cp -R /root/ft_linux/* /mnt/lfs/scripts/
chown -R lfs:lfs /mnt/lfs/scripts/