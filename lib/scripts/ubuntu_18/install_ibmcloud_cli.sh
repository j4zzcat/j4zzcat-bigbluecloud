#!/usr/bin/env bash

echo "install_ibmcloud_cli.sh is starting..."

curl -sL https://ibm.biz/idt-installer | bash
ibmcloud plugin install vpc-infrastructure
