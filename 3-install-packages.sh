#!/bin/bash

set -e

LFS=/mnt/lfs
LFS_TGT=$(uname -m)-eloevenb
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

echo -e "${GREEN}[Binutils installed]${NC}"

echo -e "${GREEN}[Installing packages]${NC}"
# Binutils
{
	tar -xf binutils-2.30.tar.xz > /dev/null
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
	mv -v mpc-1.1.0 mpc && \
	create_build_dir
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