#!/bin/bash

# Ensure user is lfs
if ! whoami | grep -q "lfs"; then
  echo "ERROR: Please become lfs: 'su - lfs'"
  exit 1
fi
# Ensure $LFS is set
if ! echo $LFS | grep -q "/mnt/lfs"; then
  echo 'ERROR: Please set the "$LFS" variable before continuing'
  exit 1
fi

################
# Tarball name #
################
tarball="binutils-2.30"

########################
# Generic build steps  #
########################
cd $LFS/sources
tar -xvf $tarball.tar.xz
if [ ! -d $LFS/sources/$tarball ]; then
  echo "ERROR: Unable to extract tarball named $tarball, check the file extensions"
  exit 1
fi
cd $tarball

########################
# Specific build steps #
########################
mkdir -v build
cd build
CC=$LFS_TGT-gcc \
AR=$LFS_TGT-ar \
RANLIB=$LFS_TGT-ranlib \
../configure \
	--prefix=/tools \
	--disable-nls \
	--disable-werror \
	--with-lib-path=/tools/lib \
	--with-sysroot

make
make install

make -C ld clean
make -C ld LIB_PATH=/user/lib:/lib
cp -v ld/ld-new /tools/bin

#########################
# Generic cleanup steps #
#########################
cd $LFS/sources
rm -rf $tarball
