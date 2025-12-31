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


# Cross GCC


# Linux API headers
if [ -f "$BUILD_MARKERS/linux-headers" ]; then
	echo -e "${YELLOW}[Skipping Linux API headers: already built]${NC}"
else
	{
		tar -xf linux-4.15.3.tar.xz
		cd linux-4.15.3
		make mrproper
		make INSTALL_HDR_PATH=dest headers_install
		cp -rv dest/include/* /tools/include
		clean_up linux-4.15.3
		touch "$BUILD_MARKERS/linux-headers"
	}
	echo -e "${GREEN}[Linux API headers installed]${NC}"
fi

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


## Libstdc++

if [ -f "$BUILD_MARKERS/libstdc++" ]; then
    echo -e "${YELLOW}[Skipping Libstdc++: already built]${NC}"
else
    tar -xf gcc-7.3.0.tar.xz
    cd gcc-7.3.0
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
    clean_up "gcc-7.3.0"
    touch "$BUILD_MARKERS/libstdc++"
    echo -e "${GREEN}[Libstdc++ installed]${NC}"
fi


## Binutils Pass 2

if [ -f "$BUILD_MARKERS/binutils-pass2" ]; then
    echo -e "${YELLOW}[Skipping Binutils Pass 2: already built]${NC}"
else
    tar -xf $LFS/sources/binutils-2.30.tar.xz
    cd binutils-2.30
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
    clean_up "binutils-2.30"
    touch "$BUILD_MARKERS/binutils-pass2"
    echo -e "${GREEN}[Binutils Pass 2 installed]${NC}"
fi

## GCC Pass 2

if [ -f "$BUILD_MARKERS/gcc-pass2" ]; then
    echo -e "${YELLOW}[Skipping GCC Pass 2: already built]${NC}"
else
    tar -xf $LFS/sources/gcc-7.3.0.tar.xz
    cd gcc-7.3.0

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
        --disable-libgomp                              \
        --disable-debug


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

    clean_up "gcc-7.3.0"
    touch "$BUILD_MARKERS/gcc-pass2"
    echo -e "${GREEN}[GCC Pass 2 installed]${NC}"
fi

## Tcl-core

if [ -f "$BUILD_MARKERS/tcl-core" ]; then
    echo -e "${YELLOW}[Skipping Tcl-core: already built]${NC}"
else
    tar -xf $LFS/sources/tcl8.6.8-src.tar.gz
    cd tcl8.6.8
    ./configure --prefix=/tools
    make

    TZ=UTC make test

    make install
    chmod -v u+w /tools/lib/libtcl8.6.so
    make install-private-headers
    ln -sv tclsh8.6 /tools/bin/tclsh

    clean_up "tcl8.6.8"
    touch "$BUILD_MARKERS/tcl-core"
    echo -e "${GREEN}[Tcl-core installed]${NC}"
fi

## Expect

if [ -f "$BUILD_MARKERS/expect" ]; then
    echo -e "${YELLOW}[Skipping Expect: already built]${NC}"
else
    tar -xf $LFS/sources/expect5.45.4.tar.gz
    cd expect5.45.4
    cp -v configure{,.orig}
    sed 's:/usr/local/bin:/bin:' configure.orig > configure

    ./configure --prefix=/tools       \
                --with-tcl=/tools/lib \
                --with-tclinclude=/tools/include

    make
    make test
    make SCRIPTS="" install
    clean_up "expect5.45.4"
    touch "$BUILD_MARKERS/expect"
    echo -e "${GREEN}[Expect installed]${NC}"
fi

## Dejagnu

if [ -f "$BUILD_MARKERS/dejagnu" ]; then
    echo -e "${YELLOW}[Skipping Dejagnu: already built]${NC}"
else
    tar -xf $LFS/sources/dejagnu-1.6.1.tar.gz
    cd dejagnu-1.6.1
    ./configure --prefix=/tools
    make install
    make check
    clean_up "dejagnu-1.6.1"
    touch "$BUILD_MARKERS/dejagnu"
    echo -e "${GREEN}[Dejagnu installed]${NC}"
fi

## M4

if [ -f "$BUILD_MARKERS/m4" ]; then
    echo -e "${YELLOW}[Skipping M4: already built]${NC}"
else
    tar -xf $LFS/sources/m4-1.4.18.tar.xz
    cd m4-1.4.18
    ./configure --prefix=/tools
    make
    make check
    make install
    clean_up "m4-1.4.18"
    touch "$BUILD_MARKERS/m4"
    echo -e "${GREEN}[M4 installed]${NC}"
fi

## Ncurses

if [ -f "$BUILD_MARKERS/ncurses" ]; then
    echo -e "${YELLOW}[Skipping Ncurses: already built]${NC}"
else
    tar -xf $LFS/sources/ncurses-6.1.tar.gz
    cd ncurses-6.1
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
    clean_up "ncurses-6.1"
    touch "$BUILD_MARKERS/ncurses"
    echo -e "${GREEN}[Ncurses installed]${NC}"
fi

## Bash

if [ -f "$BUILD_MARKERS/bash" ]; then
    echo -e "${YELLOW}[Skipping Bash: already built]${NC}"
else
    tar -xf $LFS/sources/bash-4.4.18.tar.gz
    cd bash-4.4.18
    ./configure --prefix=/tools --without-bash-malloc
    make
    make tests
    make install
    ln -sv bash /tools/bin/sh

    clean_up "bash-4.4.18"
    touch "$BUILD_MARKERS/bash"
    echo -e "${GREEN}[Bash installed]${NC}"
fi

## Bison

if [ -f "$BUILD_MARKERS/bison" ]; then
    echo -e "${YELLOW}[Skipping Bison: already built]${NC}"
else
    tar -xf $LFS/sources/bison-3.0.4.tar.xz
    cd bison-3.0.4
    ./configure --prefix=/tools
    make
    make check
    make install
    clean_up "bison-3.0.4"
    touch "$BUILD_MARKERS/bison"
    echo -e "${GREEN}[Bison installed]${NC}"
fi

## Bzip2

if [ -f "$BUILD_MARKERS/bzip2" ]; then
    echo -e "${YELLOW}[Skipping Bzip2: already built]${NC}"
else
    tar -xf $LFS/sources/bzip2-1.0.6.tar.gz
    cd bzip2-1.0.6
    make
    make PREFIX=/tools install

    clean_up "bzip2-1.0.6"
    touch "$BUILD_MARKERS/bzip2"
    echo -e "${GREEN}[Bzip2 installed]${NC}"
fi


## Coreutils

if [ -f "$BUILD_MARKERS/coreutils" ]; then
    echo -e "${YELLOW}[Skipping Coreutils: already built]${NC}"
else
    tar -xf $LFS/sources/coreutils-8.29.tar.xz
    cd coreutils-8.29
    ./configure --prefix=/tools --enable-install-program=hostname
    make
    make install

    clean_up "coreutils-8.29"
    touch "$BUILD_MARKERS/coreutils"
    echo -e "${GREEN}[Coreutils installed]${NC}"
fi

## Diffutils

if [ -f "$BUILD_MARKERS/diffutils" ]; then
    echo -e "${YELLOW}[Skipping Diffutils: already built]${NC}"
else
    tar -xf $LFS/sources/diffutils-3.6.tar.xz
    cd diffutils-3.6
    ./configure --prefix=/tools
    make
    make install

    clean_up "diffutils-3.6"
    touch "$BUILD_MARKERS/diffutils"
    echo -e "${GREEN}[Diffutils installed]${NC}"
fi

## File

if [ -f "$BUILD_MARKERS/file" ]; then
    echo -e "${YELLOW}[Skipping File: already built]${NC}"
else
    tar -xf $LFS/sources/file-5.32.tar.gz
    cd file-5.32
    ./configure --prefix=/tools
    make
    make install

    clean_up "file-5.32"
    touch "$BUILD_MARKERS/file"
    echo -e "${GREEN}[File installed]${NC}"
fi

## Findutils

if [ -f "$BUILD_MARKERS/findutils" ]; then
    echo -e "${YELLOW}[Skipping Findutils: already built]${NC}"
else
    tar -xf $LFS/sources/findutils-4.6.0.tar.gz
    cd findutils-4.6.0
    ./configure --prefix=/tools
    make
    make install

    clean_up "findutils-4.6.0"
    touch "$BUILD_MARKERS/findutils"
    echo -e "${GREEN}[Findutils installed]${NC}"
fi

## Gawk

if [ -f "$BUILD_MARKERS/gawk" ]; then
    echo -e "${YELLOW}[Skipping Gawk: already built]${NC}"
else
    tar -xf $LFS/sources/gawk-4.2.0.tar.xz
    cd gawk-4.2.0
    ./configure --prefix=/tools
    make
    make install

    clean_up "gawk-4.2.0"
    touch "$BUILD_MARKERS/gawk"
    echo -e "${GREEN}[Gawk installed]${NC}"
fi

## Gettext

if [ -f "$BUILD_MARKERS/gettext" ]; then
    echo -e "${YELLOW}[Skipping Gettext: already built]${NC}"
else
    tar -xf $LFS/sources/gettext-0.19.8.1.tar.xz
    cd gettext-0.19.8.1
    cd gettext-tools
    EMACS="no" ./configure --prefix=/tools --disable-shared

    make -C gnulib-lib
    make -C intl pluralx.c
    make -C src msgfmt
    make -C src msgmerge
    make -C src xgettext

    cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin

    clean_up "gettext-0.19.8.1"
    touch "$BUILD_MARKERS/gettext"
    echo -e "${GREEN}[Gettext installed]${NC}"
fi

## Grep

if [ -f "$BUILD_MARKERS/grep" ]; then
    echo -e "${YELLOW}[Skipping Grep: already built]${NC}"
else
    tar -xf $LFS/sources/grep-3.1.tar.xz
    cd grep-3.1
    ./configure --prefix=/tools
    make
    make install

    clean_up "grep-3.1"
    touch "$BUILD_MARKERS/grep"
    echo -e "${GREEN}[Grep installed]${NC}"
fi

## Gzip

if [ -f "$BUILD_MARKERS/gzip" ]; then
    echo -e "${YELLOW}[Skipping Gzip: already built]${NC}"
else
    tar -xf $LFS/sources/gzip-1.9.tar.xz
    cd gzip-1.9
    ./configure --prefix=/tools
    make
    make install

    clean_up "gzip-1.9"
    touch "$BUILD_MARKERS/gzip"
    echo -e "${GREEN}[Gzip installed]${NC}"
fi

## Make

if [ -f "$BUILD_MARKERS/make" ]; then
    echo -e "${YELLOW}[Skipping Make: already built]${NC}"
else
    tar -xf $LFS/sources/make-4.2.1.tar.bz2
    cd make-4.2.1
    sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
    ./configure --prefix=/tools --without-guile
    make
    make install

    clean_up "make-4.2.1"
    touch "$BUILD_MARKERS/make"
    echo -e "${GREEN}[Make installed]${NC}"
fi

## Patch

if [ -f "$BUILD_MARKERS/patch" ]; then
    echo -e "${YELLOW}[Skipping Patch: already built]${NC}"
else
    tar -xf $LFS/sources/patch-2.7.6.tar.xz
    cd patch-2.7.6
    ./configure --prefix=/tools
    make
    make install

    clean_up "patch-2.7.6"
    touch "$BUILD_MARKERS/patch"
    echo -e "${GREEN}[Patch installed]${NC}"
fi

## Perl

if [ -f "$BUILD_MARKERS/perl" ]; then
    echo -e "${YELLOW}[Skipping Perl: already built]${NC}"
else
    tar -xf $LFS/sources/perl-5.26.1.tar.xz
    cd perl-5.26.1
    sh Configure -des -Dprefix=/tools -Dlibs=-lm
    make
    cp -v perl cpan/podlators/scripts/pod2man /tools/bin
    mkdir -pv /tools/lib/perl5/5.26.1
    cp -Rv lib/* /tools/lib/perl5/5.26.1

    clean_up "perl-5.26.1"
    touch "$BUILD_MARKERS/perl"
    echo -e "${GREEN}[Perl installed]${NC}"
fi

## Sed

if [ -f "$BUILD_MARKERS/sed" ]; then
    echo -e "${YELLOW}[Skipping Sed: already built]${NC}"
else
    tar -xf $LFS/sources/sed-4.4.tar.xz
    cd sed-4.4
    ./configure --prefix=/tools
    make
    make install
    clean_up "sed-4.4"
    touch "$BUILD_MARKERS/sed"
    echo -e "${GREEN}[Sed installed]${NC}"
fi

## Tar

if [ -f "$BUILD_MARKERS/tar" ]; then
    echo -e "${YELLOW}[Skipping Tar: already built]${NC}"
else
    tar -xf $LFS/sources/tar-1.30.tar.xz
    cd tar-1.30
    ./configure --prefix=/tools
    make
    make install
    clean_up "tar-1.30"
    touch "$BUILD_MARKERS/tar"
    echo -e "${GREEN}[Tar installed]${NC}"
fi

## Texinfo

if [ -f "$BUILD_MARKERS/texinfo" ]; then
    echo -e "${YELLOW}[Skipping Texinfo: already built]${NC}"
else
    tar -xf $LFS/sources/texinfo-6.5.tar.xz
    cd texinfo-6.5
    ./configure --prefix=/tools
    make
    make install
    clean_up "texinfo-6.5"
    touch "$BUILD_MARKERS/texinfo"
    echo -e "${GREEN}[Texinfo installed]${NC}"
fi

## Util-linux

if [ -f "$BUILD_MARKERS/util-linux" ]; then
    echo -e "${YELLOW}[Skipping Util-linux: already built]${NC}"
else
    tar -xf $LFS/sources/util-linux-2.31.1.tar.xz
    cd util-linux-2.31.1
    ./configure --prefix=/tools                \
                --without-python               \
                --disable-makeinstall-chown    \
                --without-systemdsystemunitdir \
                --without-ncurses              \
                PKG_CONFIG=""
    make
    make install
    clean_up "util-linux-2.31.1"
    touch "$BUILD_MARKERS/util-linux"
    echo -e "${GREEN}[Util-linux installed]${NC}"
fi

## Xz

if [ -f "$BUILD_MARKERS/xz" ]; then
    echo -e "${YELLOW}[Skipping Xz: already built]${NC}"
else
    tar -xf $LFS/sources/xz-5.2.3.tar.xz
    cd xz-5.2.3
    ./configure --prefix=/tools
    make
    make install
    clean_up "xz-5.2.3"
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
