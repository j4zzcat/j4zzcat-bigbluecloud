KEY_FILE=${1}
BOOTSTRAP_SERVER_FIP=${2}
CLUSTER_NAME=${3}
DOMAIN_NAME=${4}
PULL_SECRET_FILE=${5}

HOME_DIR=/opt/openshift
INSTALL_DIR=${HOME_DIR}/install/${CLUSTER_NAME}.${DOMAIN_NAME}

scp \
  -oStrictHostKeyChecking=no \
  -i ${KEY_FILE} \
  ${PULL_SECRET_FILE} \
  root@${BOOTSTRAP_SERVER_FIP}:/opt/openshift/pull-secret.${CLUSTER_NAME}.${DOMAIN_NAME}
