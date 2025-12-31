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
tarball="ncurses-6.1"

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
sed -i 's/mawk//g' configure

./configure --prefix=/tools           \
			--with-shared              \
			--without-debug            \
			--without-ada              \
			--enable-widec             \
			--enable-overwrite

make

make install

#########################
# Generic cleanup steps #
#########################
cd $LFS/sources
rm -rf $tarball
