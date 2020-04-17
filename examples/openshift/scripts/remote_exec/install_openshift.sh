
NAME=maxi
DOMAIN=maxi

HOME_DIR=/opt/openshift
INSTALL_DIR=${HOME_DIR}/install/${NAME}
SECRET_KEY_FILE=${INSTALL_DIR}/${NAME}-key.rsa
PUBLIC_KEY_FILE=${INSTALL_DIR}/${NAME}-key.rsa.pub

mkdir -p ${INSTALL_DIR}
cd ${HOME_DIR}

ssh-keygen -t rsa -b 4096 -N '' -f ${SECRET_KEY_FILE}
eval "$(ssh-agent -s)"
ssh-add ${SECRET_KEY_FILE}
PUBLIC_KEY=$(cat ${PUBLIC_KEY_FILE})

# copy pull-secret.txt to /opt/openshift/install/${NAME}
PULL_SECRET=$(cat ${INSTALL_DIR}/pull-secret.txt)

cat <<EOT >${INSTALL_DIR}/install-config.yaml
apiVersion: v1
baseDomain: ${DOMAIN}
compute:
- hyperthreading: Enabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
metadata:
  name: ${NAME}
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

${HOME_DIR}/openshift-install create manifests --dir=${INSTALL_DIR}
sed --in-place -e 's/\(mastersSchedulable:\).*/\1 False/' ${INSTALL_DIR}/manifests/cluster-scheduler-02-config.yml

${HOME_DIR}/openshift-install create ignition-configs --dir=${INSTALL_DIR}
