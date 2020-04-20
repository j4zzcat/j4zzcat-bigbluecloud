KEY_FILE=${1}
REMOTE_HOST=${2}
MAX_WAIT=${3}

START_TIME=$(date +%s)

echo "Waiting for ${REMOTE_HOST}:22..."
nc -w ${MAX_WAIT} -z ${REMOTE_HOST} 22 \
  || return 1

REMAINING_TIME=$(( ${MAX_WAIT} - $(($(date +%s) - ${START_TIME})) ))

if [ "${REMAINING_TIME}" -gt "0" ]; then
  echo "Waiting for cloud-init on ${REMOTE_HOST}..."
  ssh \
    -oStrictHostKeyChecking=no \
    -i ${KEY_FILE} \
    root@${REMOTE_HOST} \
    "timeout ${REMAINING_TIME}s cloud-init status --wait" \
    || return 1
else
  return 1
fi
