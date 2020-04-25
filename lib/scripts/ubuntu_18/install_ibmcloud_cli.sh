#!/usr/bin/env bash

echo "Installing IBM Cloud CLI..." > /dev/stderr
curl -sL https://ibm.biz/idt-installer | bash
ibmcloud plugin install vpc-infrastructure
