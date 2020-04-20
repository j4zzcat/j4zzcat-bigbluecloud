KEY_FILE=${1}
REMOTE_HOST=${2}
MAX_WAIT=${3}

# wait for host to become available
echo "Waiting for ${REMOTE_HOST}:22..."
START_TIME=$(date +%s)
nc -w ${MAX_WAIT} -z ${REMOTE_HOST} 22 \
  || return 1

WAITED_TIME=$(($(date +%s) - ${START_TIME}))
echo "Waited ${WAITED_TIME}s"

REMAINING_TIME=$(( ${MAX_WAIT} - ${WAITED_TIME} ))

if [ "${REMAINING_TIME}" -le "0" ]; then
  return 1
fi

echo "Waiting for cloud-init on ${REMOTE_HOST}..."
START_TIME=$(date +%s)
ssh \
  -oStrictHostKeyChecking=no \
  -i ${KEY_FILE} \
  root@${REMOTE_HOST} \
  "timeout ${REMAINING_TIME}s cloud-init status --wait" \
    || return 1

WAITED_TIME=$(($(date +%s) - ${START_TIME}))
echo "Waited ${WAITED_TIME}s"
