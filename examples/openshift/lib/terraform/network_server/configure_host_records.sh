KEY_FILE=${1}
NETWORK_SERVER_FIP=${2}
CLUSTER_NAME=${3}
DOMAIN_NAME=${4}

shift 4

TMP_FILE=$(mktemp /tmp/XXX)
for TUPLE in ${@}; do
  HOSTNAME=$(echo ${TUPLE} | awk -F ':' '{print $1}')
  PIP=$(echo ${TUPLE} | awk -F ':' '{print $2}')
  echo ${PIP} ${HOSTNAME}.${DOMAIN_NAME} >> ${TMP_FILE}
done

# trying to be idempotence
cat ${TMP_FILE} | ssh -oStrictHostKeyChecking=no -i ${KEY_FILE} root@${NETWORK_SERVER_FIP} "cat > /etc/dnsmasq.hosts.${DOMAIN_NAME}"
ssh -oStrictHostKeyChecking=no -i ${KEY_FILE} root@${NETWORK_SERVER_FIP} "systemctl restart dnsmasq" || true
