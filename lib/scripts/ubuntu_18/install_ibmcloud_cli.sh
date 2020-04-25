#!/usr/bin/env bash

echo "Installing IBM Cloud CLI..."
curl -sL https://ibm.biz/idt-installer | bash >/dev/null
ibmcloud plugin install vpc-infrastructure >/dev/null
