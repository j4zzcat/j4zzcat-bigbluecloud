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
  -v <absolute path to repo dir>:/repo \
  -e IBMCLOUD_API_KEY=<your IBM Cloud API key> \
  -e IAAS_CLASSIC_USERNAME=<your IBM Cloud API key> \
  -e IAAS_CLASSIC_API_KEY=<your IBM Cloud classic infra API key> \
  -e IC_TIMEOUT=120 \
  -e IAAS_CLASSIC_TIMEOUT=120 \
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
Get your pull secret from `https://cloud.redhat.com/openshift/install/pull-secret` and place it in `./keys/pull-secret.txt`

### Update the infrastructure configuration
Generate some ssh keys, these will allow you to ssh into the servers:
```
ssh-keygen -t rsa -b 4096 -N "" -f ./keys/bastion-key.rsa
ssh-keygen -t rsa -b 4096 -N "" -f ./keys/fortress-key.rsa
```

Edit the file `./main.auto.tfvars` and set the name of the openshift cluster, domain, location, profile of the infra/masters/workers machine, the resource group etc.
* Note that the specified resource group should be an existing resource group
* Note that the only supported regions are: **eu-gb**, **us-south**, **us-east**

```
# file main.auto.tfvars
cluster_name        = "blinki"
domain_name         = "local"
region_name         = "eu-gb"
zone_name           = "eu-gb-1"
resource_group_name = "blackforest"
bastion_key         = "./keys/bastion-key.rsa"
fortress_key        = "./keys/fortress-key.rsa"
pull_secret         = "./key/pull-secret.txt"
```

### Provision the infrastructure
Provision the infrastructure, this usually takes a few minutes:
```

terraform init
terraform apply -auto-approve -target=module.vpc

terraform apply -auto-approve \
  -target=module.ssh_keys \
  -target=module.security_groups \
  -target=module.bootstrap_server \
  -target=module.network_server \
  -target=module.haproxy_server

terraform apply -auto-approve \
  -target=module.master_1 \
  -target=module.master_2 \
  -target=module.master_3 \
  -target=module.worker_1 \
  -target=module.worker_2
```
Next, continue with this part:
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

### When things go wrong
Sometimes things go wrong and the terraform script fails or hangs (i.e., never finishes). This could be because of a user error, bug in the script, bug in terraform or a glitch in (god forbid) IBM Cloud (all have known to happen before). If this does happen, try the following:
* Understand what went wrong and fix it.

* For hanged scripts, stop terraform by pressing CTRL+C **one time**. Terraform should stop gracefully. Afterwards, run the command again (terraform should recover).

* If terraform fails to stop gracefully, press CTRL+C **twice**. Terraform stops immediately but the state could get corrupted. Run `terraform destroy -auto-approve` to delete all the previously provisioned resources, then start over from the beginning. However, if the `destroy` fails, first clean the terraform state by running `rm -rf .terraform terraform.tfstate*`, next delete the remaining resources using the IBM Cloud console (or CLI), and finally start over - but this time crossing your fingers behind your back.
