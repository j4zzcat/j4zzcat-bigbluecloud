DEBIAN_FRONTEND=noninteractive apt-get install -y \
  gcc g++ make binutils liblzma-dev mtools mkisofs syslinux isolinux xorriso qemu-kvm

# install and build ipxe
mkdir -p /usr/local/src
git clone https://github.com/ipxe/ipxe /usr/local/src/ipxe
cd /usr/local/src/ipxe/src
make
