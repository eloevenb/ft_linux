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
tarball="tcl8.6.8"

########################
# Generic build steps  #
########################
cd $LFS/sources
mv $tarball-src.tar.gz $tarball.tar.gz
tar -xvzf $tarball.tar.gz
if [ ! -d $LFS/sources/$tarball ]; then
  echo "ERROR: Unable to extract tarball named $tarball, check the file extensions"
  exit 1
fi
cd $tarball

########################
# Specific build steps #
########################
cd unix
./configure --prefix=/tools
make
TZ=UTC make test

make install
chmod -v u+w /tools/lib/libtcl8.6.so
make install-private-headers

ln -sv tclsh8.6 /tools/bin/tclsh

#########################
# Generic cleanup steps #
#########################
cd $LFS/sources
rm -rf $tarball
