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
tarball="gettext-0.19.8.1"

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
cd gettext-tools
EMACS="no" ./configure --prefix=/tools --disable-shared

make -C gnulib-lib
make -C intl pluralx.c
make -C src msgfmt
make -C src msgmerge
make -C src xgettext

cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin

#########################
# Generic cleanup steps #
#########################
cd $LFS/sources
rm -rf $tarball
