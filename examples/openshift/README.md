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
The rest of the guide has to be executed within the docker container.

### Test that you can login
```
ibmcloud login
```

### Change to the OpenShift example dir
```
cd /repo/examples/openshift
```

### Update the configuration
Generate a new ssh key. This key will be provisioned onto every server allowing you to remotely login to the server.
```
mkdir ./keys
ssh-keygen -t rsa -b 4096 -N "" -f ./keys/admin_key.rsa
```

Edit the file `./main.auto.tfvars` and set the name of the openshift cluster, location, the resource group etc. Note that the specified resource group should exist already. For example:
```
# file main.auto.tfvars
name                = "grapefruit"
region_name         = "eu-gb"
zone_name           = "eu-gb-1"
resource_group_name = "peto"
admin_key           = "./keys/admin_key.rsa"
```

Update the openshift configuration file <TBD>

### Provision OpenShift
First, provision the basic infrastructure: vpc, security groups, ssh key, network server (provides dns) and the installation server (provides pxe services):
```
terraform init
terraform apply -auto-approve -target=module.vpc
terraform apply -auto-approve \
  -target=module.security_groups \
  -target=module.network_server \
  -target=module.installation_server \
  -target=module.haproxy_masters \
  -target=module.haproxy_workers \
  -target=null_resource.register_with_nameserver

  <!-- -target=module.master_1 \
  -target=module.master_2 \
  -target=module.master_3 \
  -target=module.worker_1 \
  -target=module.worker_2 -->

```

Next, configure the naming service:
```
terraform apply -auto-approve -target=module.configure_network_server
```

And finally, install OpenShift:
```
terraform apply -auto-approve -target=module.install_openshift
```

### Test the installation
<TBD>