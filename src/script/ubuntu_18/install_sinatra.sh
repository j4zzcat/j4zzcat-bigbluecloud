#!/usr/bin/env bash

echo "install_sinatra.sh is starting..."

DEBIAN_FRONTEND=noninteractive apt-get install -qq -y \
  ruby2.5-dev gcc g++ make

sintra_public_dir=/var/sinatra/www
mkdir -p ${sintra_public_dir}

gem install -q --no-document bundle sinatra thin ipaddress
