#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

set -e

LFS=/mnt/lfs
LFS_TGT=$(uname -m)-lfs-linux-gnu
export MAKEFLAGS='-j$(nproc)'
cd $LFS/sources

BUILD_MARKERS="$LFS/sources/.build_markers"
mkdir -p "$BUILD_MARKERS"

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
if [ -f "$BUILD_MARKERS/binutils" ]; then
	echo -e "${YELLOW}[Skipping Binutils: already built]${NC}"
else
	{
		tar -xf binutils-2.30.tar.xz
		cd binutils-2.30
		create_build_dir
		../configure --prefix=/tools \
			--with-sysroot=$LFS \
			--with-lib-path=/tools/lib \
			--target=$LFS_TGT \
			--disable-nls \
			--disable-werror
		make
		make install
		clean_up binutils-2.30
		touch "$BUILD_MARKERS/binutils"
	}
	echo -e "${GREEN}[Binutils installed]${NC}"
fi

# Cross GCC
if [ -f "$BUILD_MARKERS/gcc" ]; then
	echo -e "${YELLOW}[Skipping GCC: already built]${NC}"
else
	{
		tar -xf gcc-7.3.0.tar.xz
		cd gcc-7.3.0 && \
		tar -xf ../mpfr-4.0.1.tar.xz
		mv -v mpfr-4.0.1 mpfr && \
		tar -xf ../gmp-6.1.2.tar.xz
		mv -v gmp-6.1.2 gmp && \
		tar -xf ../mpc-1.1.0.tar.gz
		mv -v mpc-1.1.0 mpc

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
		create_build_dir
		../configure \
			--target=$LFS_TGT \
			--prefix=/tools \
			--with-glibc-version=2.11 \
			--with-sysroot=$LFS \
			--with-newlib \
			--without-headers \
			--with-local-prefix=/tools \
			--with-native-system-header-dir=/tools/include \
			--disable-nls \
			--disable-shared \
			--disable-multilib \
			--disable-decimal-float \
			--disable-threads \
			--disable-libatomic \
			--disable-libgomp \
			--disable-libmpx \
			--disable-libquadmath \
			--disable-libssp \
			--disable-libvtv \
			--disable-libstdcxx \
			--enable-languages=c,c++
		make
		make install
		clean_up gcc-7.3.0
		touch "$BUILD_MARKERS/gcc"
	}
	echo -e "${GREEN}[GCC installed]${NC}"
fi

# Linux API headers
if [ -f "$BUILD_MARKERS/linux-headers" ]; then
	echo -e "${YELLOW}[Skipping Linux API headers: already built]${NC}"
else
	{
		tar -xf linux-4.15.0.tar.xz
		cd linux-4.15.0
		make mrproper
		make INSTALL_HDR_PATH=dest headers_install
		cp -rv dest/include/* /tools/include
		clean_up linux-4.15.0
		touch "$BUILD_MARKERS/linux-headers"
	}
	echo -e "${GREEN}[Linux API headers installed]${NC}"
fi

# Glibc

# Glibc
if [ -f "$BUILD_MARKERS/glibc" ]; then
	echo -e "${YELLOW}[Skipping Glibc: already built]${NC}"
else
	{
		tar -xf glibc-2.27.tar.xz
		cd glibc-2.27
		create_build_dir
		../configure --prefix=/tools \
			--host=$LFS_TGT \
			--build=$(../scripts/config.guess) \
			--with-headers=/tools/include \
			--enable-kernel=3.2 \
			--disable-multilib \
			libc_cv_forced_unwind=yes \
			libc_cv_c_cleanup=yes
		make
		make install
		clean_up glibc-2.27
		touch "$BUILD_MARKERS/glibc"
	}
	echo -e "${GREEN}[Glibc installed]${NC}"
fi

echo -e "${YELLOW}[Performing toolchain sanity check]${NC}"
echo 'int main(){}' > dummy.c
$LFS_TGT-gcc dummy.c > /dev/null 2>&1
if readelf -l a.out | grep -q '/tools/'; then
    echo -e "${GREEN}[Toolchain sanity check PASSED]${NC}"
    rm -v dummy.c a.out
else
    echo -e "${RED}[Toolchain sanity check FAILED]${NC}"
    rm -f dummy.c a.out
    exit 1
fi

## Glibc

tar -xf $LFS/sources/glibc-*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'glibc-*' | head -n 1)
create_build_dir

../configure                             \
      --prefix=/tools                    \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=3.2             \
      --with-headers=/tools/include      \
      libc_cv_forced_unwind=yes          \
      libc_cv_c_cleanup=yes

make
make install

echo 'int main(){}' > dummy.c
$LFS_TGT-gcc dummy.c
if readelf -l a.out | grep ': /tools'; then
    echo "Glibc compilation OK"
    rm -v dummy.c a.out
else
    echo "Glibc compilation failed"
    exit 1
fi



## Libstdc++

cd $LFS/sources
cd $(find . -maxdepth 1 -type d -name 'gcc-*' | head -n 1)
create_build_dir
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --prefix=/tools                 \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-threads     \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/7.3.0

make
make install

clean_up "gcc-*"


## Binutils (again)


tar -xf $LFS/sources/binutils-*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'binutils-*' | head -n 1)
create_build_dir
CC=$LFS_TGT-gcc
AR=$LFS_TGT-ar
RANLIB=$LFS_TGT-ranlib

../configure                   \
    --prefix=/tools            \
    --disable-nls              \
    --disable-werror           \
    --with-lib-path=/tools/lib \
    --with-sysroot

make
make install
make -C ld clean
make -C ld LIB_PATH=/usr/lib:/lib
cp -v ld/ld-new /tools/bin
clean_up "binutils-*"

## GCC (again)

cat gcc/limitx.h gcc/glimits.h gcc/limity.h >  `dirname \
  $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h

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

tar -xf $LFS/sources/gcc-*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'gcc-*' | head -n 1)

tar -xf ../mpfr-4.0.1.tar.xz
mv -v mpfr-4.0.1 mpfr
tar -xf ../gmp-6.1.2.tar.xz
mv -v gmp-6.1.2 gmp
tar -xf ../mpc-1.1.0.tar.gz
mv -v mpc-1.1.0 mpc


create_build_dir
CC=$LFS_TGT-gcc
CXX=$LFS_TGT-g++
AR=$LFS_TGT-ar
RANLIB=$LFS_TGT-ranlib
../configure                                       \
    --prefix=/tools                                \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --enable-languages=c,c++                       \
    --disable-libstdcxx-pch                        \
    --disable-multilib                             \
    --disable-bootstrap                            \
    --disable-libgomp


make
make install
ln -sv gcc /tools/bin/cc

echo 'int main(){}' > dummy.c
$LFS_TGT-gcc dummy.c
if readelf -l a.out | grep ': /tools'; then
    echo "Glibc compilation OK"
    rm -v dummy.c a.out
else
    echo "Glibc compilation failed"
    exit 1
fi

clean_up "gcc-*"

## Tcl-core

tar -xf $LFS/sources/tcl-core*.tar.gz
cd $(find . -maxdepth 1 -type d -name 'tcl-core-*' | head -n 1)
./configure --prefix=/tools
make

TZ=UTC make test

make install
chmod -v u+w /tools/lib/libtcl8.6.so
make install-private-headers
ln -sv tclsh8.6 /tools/bin/tclsh


clean_up "tcl-*"

## Expect

tar -xf $LFS/sources/expect*.tar.gz
cd $(find . -maxdepth 1 -type d -name 'expect-*' | head -n 1)
cp -v configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure

./configure --prefix=/tools       \
            --with-tcl=/tools/lib \
            --with-tclinclude=/tools/include

make
make test
make SCRIPTS="" install
clean_up "expect-*"

## Dejagnu

tar -xf $LFS/sources/dejagnu*.tar.gz
cd $(find . -maxdepth 1 -type d -name 'dejagnu-*' | head -n 1)
./configure --prefix=/tools
make install
make check
clean_up "dejagnu-*"

## M4

tar -xf $LFS/sources/m4*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'm4-*' | head -n 1)
./configure --prefix=/tools
make
make check
make install
clean_up "m4-*"

## Ncurses

tar -xf $LFS/sources/ncurses*.tar.gz
cd $(find . -maxdepth 1 -type d -name 'ncurses-*' | head -n 1)
if sed -i s/mawk// configure; then
    echo "Mawk removed"
else
    echo "Mawk not removed"
fi

./configure --prefix=/tools \
            --with-shared   \
            --without-debug \
            --without-ada   \
            --enable-widec  \
            --enable-overwrite

make
make install
clean_up "ncurses-*"

## Bash

tar -xf $LFS/sources/bash*.tar.gz
cd $(find . -maxdepth 1 -type d -name 'bash-*' | head -n 1)
./configure --prefix=/tools --without-bash-malloc
make
make tests
make install
ln -sv bash /tools/bin/sh

clean_up "bash-*"

## Bison

tar -xf $LFS/sources/bison*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'bison-*' | head -n 1)
./configure --prefix=/tools
make
make check
make install
clean_up "bison-*"

## Bzip2

tar -xf $LFS/sources/bzip2*.tar.gz
cd $(find . -maxdepth 1 -type d -name 'bzip2-*' | head -n 1)
make
make PREFIX=/tools install

clean_up "bzip2-*"


## Coreutils

tar -xf $LFS/sources/coreutils*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'coreutils-*' | head -n 1)
./configure --prefix=/tools --enable-install-program=hostname
make
make install

clean_up "coreutils-*"


## Diffutils

tar -xf $LFS/sources/diffutils*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'diffutils-*' | head -n 1)
./configure --prefix=/tools
make
make install

clean_up "diffutils-*"


## File 

tar -xf $LFS/sources/file*.tar.gz
cd $(find . -maxdepth 1 -type d -name 'file-*' | head -n 1)
./configure --prefix=/tools
make
make install

clean_up "file-*"

## Findutils

tar -xf $LFS/sources/findutils*.tar.gz
cd $(find . -maxdepth 1 -type d -name 'findutils-*' | head -n 1)
./configure --prefix=/tools
make
make install

clean_up "findutils-*"

## Gawk

tar -xf $LFS/sources/gawk*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'gawk-*' | head -n 1)
./configure --prefix=/tools
make
make install

clean_up "gawk-*"

## Gettext

tar -xf $LFS/sources/gettext*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'gettext-*' | head -n 1)
cd gettext-tools
EMACS="no" ./configure --prefix=/tools --disable-shared

make -C gnulib-lib
make -C intl pluralx.c
make -C src msgfmt
make -C src msgmerge
make -C src xgettext

cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin

clean_up "gettext-*"

## Grep

tar -xf $LFS/sources/grep*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'grep-*' | head -n 1)
./configure --prefix=/tools
make
make install

clean_up "grep-*"

## Gzip

tar -xf $LFS/sources/gzip*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'gzip-*' | head -n 1)
./configure --prefix=/tools
make
make install

clean_up "gzip-*"

## Make

tar -xf $LFS/sources/make*.tar.bz2
cd $(find . -maxdepth 1 -type d -name 'make-*' | head -n 1)
sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
./configure --prefix=/tools --without-guile
make
make install

clean_up "make-*"

## Patch

tar -xf $LFS/sources/patch*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'patch-*' | head -n 1)
./configure --prefix=/tools
make
make install

clean_up "patch-*"

## Perl

tar -xf $LFS/sources/perl*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'perl-*' | head -n 1)
sh Configure -des -Dprefix=/tools -Dlibs=-lm
make
cp -v perl cpan/podlators/scripts/pod2man /tools/bin
mkdir -pv /tools/lib/perl5/5.26.1
cp -Rv lib/* /tools/lib/perl5/5.26.1

clean_up "perl-*"

## Sed

tar -xf $LFS/sources/sed*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'sed-*' | head -n 1)
./configure --prefix=/tools
make
make install

clean_up "sed-*"

## Tar

tar -xf $LFS/sources/tar*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'tar-*' | head -n 1)
./configure --prefix=/tools
make
make install

clean_up "tar-*"

## Texinfo 

tar -xf $LFS/sources/texinfo*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'texinfo-*' | head -n 1)
./configure --prefix=/tools
make
make install

clean_up "texinfo-*"

## Util-linux

tar -xf $LFS/sources/util-linux*.tar.xz
cd $(find . -maxdepth 1 -type d -name 'util-linux-*' | head -n 1)
./configure --prefix=/tools               \
            --without-python               \
            --disable-makeinstall-chown    \
            --without-systemdsystemunitdir \
            --without-ncurses              \
            PKG_CONFIG=""

make
make install
clean_up "util-linux-*"

## Xz

tar -xf $LFS/sources/xz*.tar.xz 
cd $(find . -maxdepth 1 -type d -name 'xz-*' | head -n 1)
./configure --prefix=/tools
make
make install

clean_up "xz-*"

## Delete useless files

strip --strip-debug /tools/lib/*
/usr/bin/strip --strip-unneeded /tools/{,s}bin/*

rm -rf /tools/{,share}/{info,man,doc}
find /tools/{lib,libexec} -name \*.la -delete

chown -R root:root $LFS/tools
	# Optional: make check
	make install
	cd ..
	clean_up sed-4.4
	touch "$BUILD_MARKERS/sed"
	echo -e "${GREEN}[Sed installed]${NC}"
fi

# Tar
if [ -f "$BUILD_MARKERS/tar" ]; then
	echo -e "${YELLOW}[Skipping Tar: already built]${NC}"
else
	tar -xf tar-1.30.tar.xz
	cd tar-1.30
	./configure --prefix=/tools
	make
	# Optional: make check
	make install
	cd ..
	clean_up tar-1.30
	touch "$BUILD_MARKERS/tar"
	echo -e "${GREEN}[Tar installed]${NC}"
fi

# Texinfo
if [ -f "$BUILD_MARKERS/texinfo" ]; then
	echo -e "${YELLOW}[Skipping Texinfo: already built]${NC}"
else
	tar -xf texinfo-6.5.tar.xz
	cd texinfo-6.5
	./configure --prefix=/tools
	make
	# Optional: make check
	make install
	cd ..
	clean_up texinfo-6.5
	touch "$BUILD_MARKERS/texinfo"
	echo -e "${GREEN}[Texinfo installed]${NC}"
fi

# Util-linux
if [ -f "$BUILD_MARKERS/util-linux" ]; then
	echo -e "${YELLOW}[Skipping Util-linux: already built]${NC}"
else
	tar -xf util-linux-2.31.1.tar.xz
	cd util-linux-2.31.1
	./configure --prefix=/tools \
		--without-python \
		--disable-makeinstall-chown \
		--without-systemdsystemunitdir \
		--without-ncurses \
		PKG_CONFIG=""
	make
	make install
	cd ..
	clean_up util-linux-2.31.1
	touch "$BUILD_MARKERS/util-linux"
	echo -e "${GREEN}[Util-linux installed]${NC}"
fi

# Xz
if [ -f "$BUILD_MARKERS/xz" ]; then
	echo -e "${YELLOW}[Skipping Xz: already built]${NC}"
else
	tar -xf xz-5.2.3.tar.xz
	cd xz-5.2.3
	./configure --prefix=/tools
	make
	# Optional: make check
	make install
	cd ..
	clean_up xz-5.2.3
	touch "$BUILD_MARKERS/xz"
	echo -e "${GREEN}[Xz installed]${NC}"
fi

# Stripping and cleanup
echo -e "${YELLOW}[Stripping binaries and cleaning up]${NC}"
strip --strip-debug /tools/lib/*
/usr/bin/strip --strip-unneeded /tools/{,s}bin/*
rm -rf /tools/{,share}/{info,man,doc}
find /tools/{lib,libexec} -name \*.la -delete

# Change ownership
echo -e "${YELLOW}[Changing ownership of /tools to root:root]${NC}"
chown -R root:root $LFS/tools
