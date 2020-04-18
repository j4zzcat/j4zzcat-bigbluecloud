KEY_FILE=${1}
NETWORK_SERVER_FIP=${2}
CLUSTER_NAME=${3}
DOMAIN_NAME=${4}
HAPROXY_MASTERS_PIP=${5}
HAPROXY_WORKERS_PIP=${6}
MASTER_1_PIP=${7}
MASTER_2_PIP=${8}
MASTER_3_PIP=${9}

echo -e "\
  host-record=api.${CLUSTER_NAME}.${DOMAIN_NAME}.,${HAPROXY_MASTERS_PIP}\n\
  host-record=api-int.${CLUSTER_NAME}.${DOMAIN_NAME}.,${HAPROXY_MASTERS_PIP}\n\
  host-record=*.apps.${CLUSTER_NAME}.${DOMAIN_NAME}.,${HAPROXY_WORKERS_PIP}\n\
  host-record=etcd-0.${CLUSTER_NAME}.${DOMAIN_NAME}.,${MASTER_1_PIP}\n\
  host-record=etcd-1.${CLUSTER_NAME}.${DOMAIN_NAME}.,${MASTER_2_PIP}\n\
  host-record=etcd-2.${CLUSTER_NAME}.${DOMAIN_NAME}.,${MASTER_3_PIP}\n\
  srv-host=_etcd-server-ssl._tcp.${CLUSTER_NAME}.${DOMAIN_NAME}.,etcd-0.${CLUSTER_NAME}.${DOMAIN_NAME},2380,0,10\n\
  srv-host=_etcd-server-ssl._tcp.${CLUSTER_NAME}.${DOMAIN_NAME}.,etcd-1.${CLUSTER_NAME}.${DOMAIN_NAME},2380,0,10\n\
  srv-host=_etcd-server-ssl._tcp.${CLUSTER_NAME}.${DOMAIN_NAME}.,etcd-2.${CLUSTER_NAME}.${DOMAIN_NAME},2380,0,10\n\
" | ssh \
  -oStrictHostKeyChecking=no \
  -i ${KEY_FILE} \
  root@${NETWORK_SERVER_FIP} \
  "cat >> /etc/dnsmasq.conf"
