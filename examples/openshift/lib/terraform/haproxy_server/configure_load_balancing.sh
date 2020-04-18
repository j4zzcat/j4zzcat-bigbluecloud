KEY_FILE=${1}
HAPROXY_SERVER_FIP=${2}
CLUSTER_NAME=${3}
DOMAIN_NAME=${4}

TMP_FILE=$(mktemp /tmp/XXX)

cat <<EOT >${TMP_FILE}
global
  log 127.0.0.1 local2
  chroot /var/lib/haproxy
  pidfile /var/run/haproxy.pid
  maxconn 4000
  user haproxy
  group haproxy
  daemon
  stats socket /var/lib/haproxy/stats
  ssl-default-bind-ciphers PROFILE=SYSTEM
  ssl-default-server-ciphers PROFILE=SYSTEM

defaults
  mode http
  log global
  option httplog
  option dontlognull
  option http-server-close
  option forwardfor except 127.0.0.0/8
  option redispatch
  retries 3
  timeout http-request 10s
  timeout queue 1m
  timeout connect 10s
  timeout client 1m
  timeout server 1m
  timeout http-keep-alive 10s
  timeout check 10s
  maxconn 3000

frontend masters_api
  mode tcp
  option tcplog
  bind api.${DOMAIN_NAME}:6443
  default_backend masters_api

frontend masters_machine_config
  mode tcp
  option tcplog
  bind api.${DOMAIN_NAME}:22623
  default_backend masters_machine_config

frontend router_http
  mode tcp
  option tcplog
  bind apps.${DOMAIN_NAME}:80
  default_backend router_http

frontend router_https
  mode tcp
  option tcplog
  bind apps.${DOMAIN_NAME}:443
  default_backend router_https

backend masters_api
  mode tcp
  balance source
  server bootstrap-server.${DOMAIN_NAME}:6443 check
  server master-1.${DOMAIN_NAME}:6443 check
  server master-2.${DOMAIN_NAME}:6443 check
  server master-3.${DOMAIN_NAME}:6443 check

backend masters_machine_config
  mode tcp
  balance source
  server bootstrap-server.${DOMAIN_NAME}:22623 check
  server master-1.${DOMAIN_NAME}:22623 check
  server master-2.${DOMAIN_NAME}:22623 check
  server master-3.${DOMAIN_NAME}:22623 check

backend router_http
  mode tcp
  server worker-1.${DOMAIN_NAME}:80 check
  server worker-2.${DOMAIN_NAME}:80 check

backend router_https
  mode tcp
  server worker-1.${DOMAIN_NAME}:443 check
  server worker-2.${DOMAIN_NAME}:443 check
EOT

timeout 5m bash -c 'while :; do ping -c 1 '${HAPROXY_SERVER_FIP}' && break; done'
cat ${TMP_FILE} | ssh -oStrictHostKeyChecking=no -i ${KEY_FILE} root@${HAPROXY_SERVER_FIP} "cat > /etc/haproxy/haproxy.cfg"
