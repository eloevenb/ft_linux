#!/bin/bash
export LFS=/mnt/lfs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[Creating LFS directory structure]${NC}"
mkdir -pv $LFS/{etc,var,tools,scripts,sources,usr/{bin,lib,sbin}}
ln -sfv $LFS/tools /

for i in bin lib sbin; do
    ln -sfv usr/$i $LFS/$i
done

case $(uname -m) in
    x86_64) ln -sfv lib $LFS/lib64 ;;
esac