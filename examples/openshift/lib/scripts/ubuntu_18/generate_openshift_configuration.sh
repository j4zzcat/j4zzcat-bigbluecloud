CLUSTER_NAME=coppermine
DOMAIN_NAME=dollar

HOME_DIR=/opt/openshift
INSTALL_DIR=${HOME_DIR}/install/${CLUSTER_NAME}.${DOMAIN_NAME}
SECRET_KEY_FILE=${INSTALL_DIR}/${CLUSTER_NAME}-key.rsa
PUBLIC_KEY_FILE=${INSTALL_DIR}/${CLUSTER_NAME}-key.rsa.pub

HTTP_HOME=/var/www/html/openshift
HTTP_INSTALL_DIR=${HTTP_HOME}/install/${CLUSTER_NAME}.${DOMAIN_NAME}

mkdir -p ${HTTP_HOME}
mkdir -p ${HTTP_INSTALL_DIR}
mkdir -p ${INSTALL_DIR}
cd ${HOME_DIR}

ssh-keygen -t rsa -b 4096 -N '' -f ${SECRET_KEY_FILE}
eval "$(ssh-agent -s)"
ssh-add ${SECRET_KEY_FILE}
PUBLIC_KEY=$(cat ${PUBLIC_KEY_FILE})

# copy pull-secret.txt to /opt/openshift/install/${CLUSTER_NAME}
PULL_SECRET=$(cat ${INSTALL_DIR}/pull-secret.txt)

cat <<EOT >${INSTALL_DIR}/install-config.yaml
apiVersion: v1
baseDomain: ${DOMAIN_NAME}
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
metadata:
  name: ${CLUSTER_NAME}
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
pullSecret: '${PULL_SECRET}'
sshKey: '${PUBLIC_KEY}'
EOT

# create manifests
${HOME_DIR}/openshift-install create manifests --dir=${INSTALL_DIR}
sed --in-place -e 's/\(mastersSchedulable:\).*/\1 False/' ${INSTALL_DIR}/manifests/cluster-scheduler-02-config.yml

# create ign files
${HOME_DIR}/openshift-install create ignition-configs --dir=${INSTALL_DIR}

# link to http dir
ln -s ${INSTALL_DIR}/*.ign ${HTTP_INSTALL_DIR}
