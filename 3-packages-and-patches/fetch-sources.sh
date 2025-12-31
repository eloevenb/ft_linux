#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'


if [ ! -d "$LFS/sources" ]; then
	echo -e "${GREEN}[Creating sources directory]${NC}"
	mkdir -v $LFS/sources
	chmod -v a+wt $LFS/sources
fi

rm -rf $LFS/sources/wget-list
rm -rf $LFS/sources/md5sums

echo -e "${GREEN}[Fetching wget-list]${NC}"
wget "https://raw.githubusercontent.com/eloevenb/ft_linux/refs/heads/main/wget-list" --continue --directory-prefix=$LFS/sources
wget "https://raw.githubusercontent.com/eloevenb/ft_linux/refs/heads/main/md5sums" --continue --directory-prefix=$LFS/sources
cd $LFS/sources
pushd $LFS/sources
md5sum -c md5sums
if [ $? -ne 0 ]; then
    echo "Some checksums failed, downloading packages..."
	wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
    # run wget or your download script here
else
    echo "All source checksums OK, skipping download."
fi
popd


chown root:root $LFS/sources/*

echo -e "${GREEN}[Verifying source file checksums]${NC}"
pushd $LFS/sources
md5sum -c md5sums
popd

