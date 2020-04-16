KEY_FILE=${1}
NETWORK_SERVER_FIP=${2}
shift; shift
for TUPLE in ${@}; do echo ${TUPLE}; done
exit

TMP_FILE=$(mktemp /tmp/XXX)

function get_public_ip {
  local TERRAFORM_NAME=${1}
  terraform state show module.${TERRAFORM_NAME}.module.${TERRAFORM_NAME}.ibm_is_floating_ip.server_fip \
    | awk '/address/{print $3}' \
    | awk -F '"' '{print $2}'
}

function get_private_ip {
  local TERRAFORM_NAME=${1}
  terraform state show module.${TERRAFORM_NAME}.module.${TERRAFORM_NAME}.ibm_is_instance.server \
    | awk '/primary_ipv4_address/{print $3}' \
    | awk -F '"' '{print $2}'
}

# --- main ---

NETWORK_SERVER_FIP=$(get_public_ip 'network_server')

for SERVER in \
  network_server  \
  installation_server \
  haproxy_masters \
  haproxy_workers \
  master_1 \
  master_2 \
  master_3 \
  worker_1 \
  worker_2; do

  echo $(get_private_ip ${SERVER}) ${SERVER} >> ${TMP_FILE}
done

ssh -i ${KEY_FILE} root@${NETWORK_SERVER_FIP} ls /
