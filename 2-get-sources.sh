#!/bin/bash

if [ ! -d "$LFS/sources" ]; then
	echo -e "${GREEN}[Creating sources directory]${NC}"
	mkdir -v $LFS/sources
	chmod -v a+wt $LFS/sources
fi

if [ ! -f "$LFS/sources/wget-list" ]; then
    echo -e "${GREEN}[Fetching wget-list]${NC}"
    wget "https://raw.githubusercontent.com/eloevenb/ft_linux/refs/heads/main/wget-list" --continue --directory-prefix=$LFS/sources
    wget "https://raw.githubusercontent.com/eloevenb/ft_linux/refs/heads/main/md5sums" --continue --directory-prefix=$LFS/sources
    cd $LFS/sources
    wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
fi

chown root:root $LFS/sources/*

echo -e "${GREEN}[Verifying source file checksums]${NC}"
pushd $LFS/sources
md5sum -c md5sums
popd

