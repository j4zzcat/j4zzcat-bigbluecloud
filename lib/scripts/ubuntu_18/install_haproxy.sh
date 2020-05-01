#!/usr/bin/env bash

echo "install_haproxy.sh is starting..."

DEBIAN_FRONTEND=noninteractive apt install -qq -y \
  haproxy
