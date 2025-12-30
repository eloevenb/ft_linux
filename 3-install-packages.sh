#!/bin/bash

set -e

LFS=/mnt/lfs
export MAKEFLAGS='-j$(nproc)'
cd $LFS/sources

create_build_dir() {
	if [ -d build ]; then
		rm -rf build
	fi
	mkdir -pv build
	cd build
}

# LFS says unless specified, extracted sources should be deleted after installation
clean_up() {
	folder=$1
	cd $LFS/sources
	if [ -d "$folder" ]; then
		rm -rf $folder
	fi
}

echo -e "${GREEN}[Installing packages]${NC}"
# Binutils
tar -xf binutils-2.30.tar.xz
cd binutils-2.30
create_build_dir
../configure --prefix=/tools            \
             --with-sysroot=$LFS        \
             --with-lib-path=/tools/lib \
             --target=$LFS_TGT          \
             --disable-nls              \
             --disable-werror
make
make install
clean_up binutils-2.30