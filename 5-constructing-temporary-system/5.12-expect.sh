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
tarball="expect5.45.4"

########################
# Generic build steps  #
########################
cd $LFS/sources
tar -xvf $tarball.tar.gz
if [ ! -d $LFS/sources/$tarball ]; then
  echo "ERROR: Unable to extract tarball named $tarball, check the file extensions"
  exit 1
fi
cd $tarball

########################
# Specific build steps #
########################
cp -v configure{,.orig}
sed 's:/usr/local/bin:/tools/bin:g' configure.orig > configure

./configure --prefix=/tools --with-tcl=/tools/lib --with-tclinclude=/tools/include

make

make test

make SCRIPTS="" install

#########################
# Generic cleanup steps #
#########################
cd $LFS/sources
rm -rf $tarball
