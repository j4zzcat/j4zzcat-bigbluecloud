KEY_FILE=${1}
NETWORK_SERVER_FIP=${2}
DOMAIN=${3}
shift; shift

TMP_FILE=$(mktemp /tmp/XXX)
for TUPLE in ${@}; do
  HOSTNAME=$(echo ${TUPLE} | awk -F ':' '{print $1}')
  IP=$(echo ${TUPLE} | awk -F ':' '{print $2}')
  echo ${IP} ${HOSTNAME}.${DOMAIN} >> ${TMP_FILE}
done

cat ${TMP_FILE} | ssh -oStrictHostKeyChecking=no -i ${KEY_FILE} root@${NETWORK_SERVER_FIP} "cat >> /etc/hosts"
ssh -i ${KEY_FILE} root@${NETWORK_SERVER_FIP} "systemctl restart dnsmasq"
