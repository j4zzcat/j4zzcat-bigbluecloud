#!/usr/bin/env bash

echo "install_openshift_client.sh is starting..."

openshift_home=/opt/openshift
openshift_bin=${openshift_home}/bin
openshift_etc=${openshift_home}/etc
openshift_shared=${openshift_home}/shared
openshift_rhcos=${openshift_shared}/rhcos

mkdir -p ${openshift_home} ${openshift_bin} ${openshift_etc} ${openshift_shared} ${openshift_rhcos}

sintra_public_dir=/var/sinatra/www
mkdir -p ${sintra_public_dir}/openshift/rhcos

# download openshift client and files
cd /tmp
for file in openshift-client-linux.tar.gz openshift-install-linux.tar.gz; do
  curl -sSLO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.3/${file}
done

gzip -d openshift*

cd ${openshift_bin}
tar -xvf /tmp/openshift-install*.tar
tar -xvf /tmp/openshift-client*.tar
rm -rf /tmp/openshift*.tar

# download rhcos
cd ${openshift_rhcos}
for file in installer-kernel-x86_64 installer-initramfs.x86_64.img installer.x86_64.iso metal.x86_64.raw.gz; do
  curl -sSLO https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.3/4.3.8/rhcos-4.3.8-x86_64-${file}
done

ln -s ${openshift_rhcos}/* ${sintra_public_dir}/openshift/rhcos
