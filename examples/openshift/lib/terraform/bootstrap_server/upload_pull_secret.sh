KEY_FILE=${1}
BOOTSTRAP_SERVER_FIP=${2}
PULL_SECRET_FILE=${3}

scp \
  -oStrictHostKeyChecking=no \
  -i ${KEY_FILE} \
  ${PULL_SECRET_FILE} \
  root@${BOOTSTRAP_SERVER_FIP}:/opt/openshift/pull-secret.txt
