# Create a simple OpenShift 4.3 cluster on IBM Cloud

### Clone this repository
```
mkdir repo
git clone https://github.com/j4zzcat/j4zzcat-ibmcloud repo
```

### Build the IBM Cloud cli docker image
```
cd repo/cli
docker build --rm -f ibmcloud-cli.dockerfile -t ibmcloud/cli:1.0 .
```

### Run the IBM Cloud cli docker image
```
docker run -it --rm \
  -v <abs path to repo dir>:/repo \
  -e IC_API_KEY=<your IBM Cloud API key> \
  -e IAAS_CLASSIC_USERNAME=<your IBM Cloud API key> \
  -e IAAS_CLASSIC_API_KEY=<your IBM Cloud classic infra API key> \
  -e IBMCLOUD_API_KEY=${IC_API_KEY} \
  -e IC_TIMEOUT=60 \
  -e IAAS_CLASSIC_TIMEOUT=60 \
  ibmcloud/cli:1.0
```

### Test that you can login
```
ibmcloud login
```

### Update configuration
Generate a new ssh key. This key will be provisioned onto every server allowing you to remotely login to the server.
```
mkdir /repo/openshift/keys
ssh-keygen -t rsa -b 4096 -N "" -f /repo/openshift/keys/admin_key.rsa
```

Edit the file /repo/openshift/main.auto.tfvars and set the cluster name, resource group and the admin ssh public key.
For example:
```
resource_group_name = "peto"
name                = "openshift-cluster"
region_name         = "eu-gb"
zone_name           = "eu-gb-1"
admin_public_key    = "/repo/openshift/keys/admin_key.rsa.pub"
```






Edit the file <root of repository>
