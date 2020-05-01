#!/usr/bin/env bash

echo "install_client.sh is starting..."
echo "Installing OpenShift Client..."

OPENSHIFT_HOME=/opt/openshift
RHCOS_DIR=${OPENSHIFT_HOME}/rhcos

mkdir -p ${OPENSHIFT_HOME}
mkdir -p ${OPENSHIFT_HOME}/etc
mkdir -p ${RHCOS_DIR}

# download openshift client and files
cd /tmp
for FILE in openshift-client-linux.tar.gz openshift-install-linux.tar.gz sha256sum.txt sha256sum.txt.sig; do
  curl -sSLO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.3/${FILE}
done

# TODO verify sha and sig
gzip -d openshift*

# untar openshift files
cd ${OPENSHIFT_HOME}
tar -xvf /tmp/openshift-install*.tar
tar -xvf /tmp/openshift-client*.tar
rm -rf /tmp/openshift*.tar

echo "Downloading RHCOS images..."

# download rhcos
cd ${RHCOS_DIR}
for FILE in installer-kernel-x86_64 installer-initramfs.x86_64.img installer.x86_64.iso metal.x86_64.raw.gz; do
  curl -sSLO https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.3/4.3.8/rhcos-4.3.8-x86_64-${FILE}
done
