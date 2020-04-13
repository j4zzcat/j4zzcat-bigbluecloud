# proper upgrade
apt update

rm /boot/grub/menu.lst
ucf --purge /var/run/grub/menu.lst
update-grub-legacy-ec2 -y
ucf --purge /etc/ssh/sshd_config

export DEBIAN_FRONTEND=noninteractive
apt-get \
  -o Dpkg::Options::=--force-confnew \
  -o Dpkg::Options::=--force-confdef \
  --allow-downgrades \
  --allow-remove-essential \
  --allow-change-held-packages \
  -y dist-upgrade

# install ipxe prereqs
apt-get install -y mc vim ruby2.5-dev apache2 gcc g++ make binutils liblzma-dev mtools mkisofs syslinux isolinux xorriso qemu-kvm

# install and build ipxe
mkdir -p /usr/local/src
git clone https://github.com/ipxe/ipxe /usr/local/src/ipxe
cd /usr/local/src/ipxe/src
make

# install sinatra
gem install --no-document bundle sinatra thin

# install openshift client and files
cd /tmp
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.3/openshift-client-linux-4.3.9.tar.gz
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.3/openshift-install-linux-4.3.9.tar.gz

mkdir -p /opt/openshift
cd /opt/openshift
tar -xzvf /tmp/openshift-install*.tar.gz
tar -xzvf /tmp/openshift-client*.tar.gz

mkdir -p /var/www/html/images/rhcos
cd /var/www/html/images/rhcos
for file in installer-kernel-x86_64 installer-initramfs.x86_64.img installer.x86_64.iso metal.x86_64.raw.gz; do
  curl -LO https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.3/4.3.8/rhcos-4.3.8-x86_64-${file}
done

mkdir -p /var/www/html/config
