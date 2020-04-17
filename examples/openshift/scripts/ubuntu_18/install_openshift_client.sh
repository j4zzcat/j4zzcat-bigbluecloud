DEBIAN_FRONTEND=noninteractive apt-get install -y \
  apache2

# install openshift client and files
cd /tmp
for file in openshift-client-linux.tar.gz openshift-install-linux.tar.gz sha256sum.txt sha256sum.txt.sig; do
  curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.3/${file}
done

# TODO verify sha and sig
gzip -d openshift*

mkdir -p /opt/openshift
cd /opt/openshift
tar -xvf /tmp/openshift-install*.tar
tar -xvf /tmp/openshift-client*.tar

mkdir -p /var/www/html/images/rhcos
cd /var/www/html/images/rhcos
for file in installer-kernel-x86_64 installer-initramfs.x86_64.img installer.x86_64.iso metal.x86_64.raw.gz; do
  curl -LO https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.3/4.3.8/rhcos-4.3.8-x86_64-${file}
done

mkdir -p /var/www/html/config
