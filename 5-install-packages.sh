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
}
echo -e "${GREEN}[Binutils installed]${NC}"

# Cross GCC
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
}
echo -e "${GREEN}[GCC installed]${NC}"

# Linux API headers
{
	tar -xf linux-4.15.0.tar.xz
	cd linux-4.15.0
	make mrproper
	make INSTALL_HDR_PATH=dest headers_install
	cp -rv dest/include/* /tools/include
	clean_up linux-4.15.0
}
echo -e "${GREEN}[Linux API headers installed]${NC}"

# Glibc
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
}

# Toolchain sanity check

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
