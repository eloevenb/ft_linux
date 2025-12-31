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
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
	`dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h

for file in gcc/config/{linux,i386/linux{,64}}.h
do
	cp -uv $file{,.orig}
	sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
		-e 's@/usr@/tools@g' $file.orig > $file
	echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
	touch $file.orig
done

case $(uname -m) in
x86_64)
sed -e '/m64=/s/lib64/lib/' \
-i.orig gcc/config/i386/t-linux64
;;
esac

tar -xf ../mpfr-4.0.1.tar.xz
mv -v mpfr-4.0.1 mpfr
tar -xf ../gmp-6.1.2.tar.xz
mv -v gmp-6.1.2 gmp
tar -xf ../mpc-1.1.0.tar.gz
mv -v mpc-1.1.0 mpc

mkdir -v build
cd build

CC=$LFS_TGT-gcc \
CXX=$LFS_TGT-g++ \
AR=$LFS_TGT-ar \
RANLIB=$LFS_TGT-ranlib \
../configure \
	--prefix=/tools \
	--with-local-prefix=/tools \
	--with-native-system-header-dir=/tools/include \
	--enable-languages=c,c++ \
	--disable-libstdcxx-pch \
	--disable-multilib \
	--disable-bootstrap \
	--disable-libgomp

make
make install

ln -sv gcc /tools/bin/cc

echo 'int main(){}' > dummy.c
cc dummy.c
readelf -l a.out | grep ': /tools'
rm -v dummy.c a.out

#########################
# Generic cleanup steps #
#########################
cd $LFS/sources
rm -rf $tarball
