# Simple OpenShift 4.3 cluster on IBM Cloud

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

The following commands should be executed within the ibmcloud cli docker container.

### Test that you can login
```
ibmcloud login
```

### Prep dir structure
```
cd /repo/examples/openshift
mkdir ./keys
```

### Pull Secret
Get your pull secret from `https://cloud.redhat.com/openshift/install/pull-secret` and place it in `./keys/pull_secret.txt`

### Update the infrastructure configuration
Generate a new ssh key. This key will be provisioned onto every server allowing you to remotely login to the server.
```
ssh-keygen -t rsa -b 4096 -N "" -f ./keys/admin_key.rsa
```

Edit the file `./main.auto.tfvars` and set the name of the openshift cluster, domain, location, the resource group etc. Note that the specified resource group should exist already. For example:
```
# file main.auto.tfvars
cluster_name        = "grapefruit"
domain_name         = "fruits"
region_name         = "eu-gb"
zone_name           = "eu-gb-1"
resource_group_name = "blackforest"
admin_key           = "./keys/admin_key.rsa"
pull_secret         = "./key/pull_secret.txt"
```

### Provision the infrastructure
Provision the infrastructure, this usually takes a few minutes:
```
terraform init
terraform apply -auto-approve -target=module.vpc

terraform apply -auto-approve \
  -target=module.security_groups \
  -target=module.network_server \
  -target=module.bootstrap_server \
  -target=module.haproxy_server \
  -target=module.master_1 \
  -target=module.master_2 \
  -target=module.master_3 \
  -target=module.worker_1 \
  -target=module.worker_2
```
Note the although the terraform script finishes, the provisioning continues in the background on each and every server. Wait for **at least 5 minutes** for the provisioning to finish. Suggestion: go get a cup of coffee (this will be replaced in the future with proper automatic 'phone home' callbacks).

Next continue with this part:
```
terraform apply -auto-approve \
  -target=null_resource.network_server_post_provision \
  -target=null_resource.haproxy_server_post_provision \
  -target=null_resource.bootstrap_server_post_provision
```

### Provision OpenShift
TBD

### Test the installation
TBD

### If things go wrong
Sometimes things go wrong and the terraform script fails or never finishes. This could be because of a user error, bug in the script, bug in terraform or a glitch in (god forbid) IBM Cloud (all have known to happen before). If this does happen, try the following:
* If the scripts still runs after 15m (usually spitting a 'Still creating...' message for one specific vm):
  * Stop the terraform script by typing CTRL+C **one time**. Terraform should stop gracefully. Afterwards, run the command again and terraform should be able to recover.
  * If it fails to stop gracefully, type CTRL+C **twice**. Terraform stops immediately but the state might get corrupted. Run `terraform destroy` to delete all the previously provisioned resources, then start over from the beginning.
