#cloud-config
runcmd:
  - /bin/bash -c "$(curl -fsSL http://172.18.0.11:8070/bootstrap)"
