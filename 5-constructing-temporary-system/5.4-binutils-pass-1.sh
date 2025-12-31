
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

../configure --prefix=/tools \
  --with-sysroot=$LFS \
  --with-lib-path=/tools/lib \
  --target=$LFS_TGT \
  --disable-nls \
  --disable-werror

make

case $(uname -m) in
x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
esac

make install

#########################
# Generic cleanup steps #
#########################
cd $LFS/sources
rm -rf $tarball