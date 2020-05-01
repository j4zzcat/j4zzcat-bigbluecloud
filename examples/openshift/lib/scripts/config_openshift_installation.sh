#!/usr/bin/env bash

cluster_name=${1}
domain_name=${2}

echo "config_openshift_installation.sh is starting..."

openshift_home=/opt/openshift
openshift_bin=${openshift_home}/bin
openshift_etc=${openshift_home}/etc
openshift_shared=${openshift_home}/shared
openshift_rhcos=${openshift_share}/rhcos
openshift_install=${openshift_home}/install

mkdir -p ${openshift_install}

sintra_public_dir=/var/sinatra/www
mkdir -p ${sintra_public_dir}/openshift/install

# cluster key
openshift_key=${openshift_install}/openshift-key.rsa
rm -f ${openshift_key}
ssh-keygen -t rsa -b 4096 -N '' -f ${openshift_key}
eval "$(ssh-agent -s)"
ssh-add ${openshift_key}
openshift_public_key=$(cat ${openshift_key}.pub)

# pull secret
openshift_pull_secret=$(cat ${openshift_etc}/pull_secret.txt)

# install config
cat <<EOT >${openshift_install}/install-config.yaml
apiVersion: v1
baseDomain: ${domain_name}
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
metadata:
  name: ${cluster_name}
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
fips: false
pullSecret: '${openshift_pull_secret}'
sshKey: '${openshift_public_key}'
EOT

# create manifests
${openshift_bin}/openshift-install create manifests --dir=${openshift_install}
sed --in-place -e 's/\(mastersSchedulable:\).*/\1 False/' ${openshift_install}/manifests/cluster-scheduler-02-config.yml

# create ign files
${openshift_bin}/openshift-install create ignition-configs --dir=${openshift_install}

# link to http dir
ln -s ${openshift_install}/*.ign ${sintra_public_dir}/openshift/install
