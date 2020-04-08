apt update
rm /boot/grub/menu.lst; ucf --purge /var/run/grub/menu.lst; update-grub-legacy-ec2 -y
ucf --purge /etc/ssh/sshd_config
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confnew -o Dpkg::Options::=--force-confdef --allow-downgrades --allow-remove-essential --allow-change-held-packages -y dist-upgrade
DEBIAN_FRONTEND=noninteractive apt install -y ruby2.5-dev apache2 gcc g++ make binutils liblzma-dev mtools mkisofs syslinux isolinux xorriso qemu-kvm
gem install --no-document bundle sinatra thin
mkdir -p /var/network-server/images
cd /var/network-server/images; for file in installer-kernel-x86_64 installer-initramfs.x86_64.img installer.x86_64.iso metal.x86_64.raw.gz; do curl -LO https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.3/4.3.8/rhcos-4.3.8-x86_64-${file}; done 
systemctl stop systemd-resolved; systemctl disable systemd-resolved; rm /etc/resolv.conf; echo -e "nameserver 161.26.0.10\nnameserver 161.26.0.11" > /etc/resolv.conf
apt install -y dnsmasq