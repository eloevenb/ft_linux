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
tarball="dejagnu-1.6.1"

########################
# Generic build steps  #
########################
cd $LFS/sources
tar -xvzf $tarball.tar.gz
if [ ! -d $LFS/sources/$tarball ]; then
  echo "ERROR: Unable to extract tarball named $tarball, check the file extensions"
  exit 1
fi
cd $tarball

########################
# Specific build steps #
########################
./configure --prefix=/tools

make install

make check

#########################
# Generic cleanup steps #
#########################
cd $LFS/sources
rm -rf $tarball
