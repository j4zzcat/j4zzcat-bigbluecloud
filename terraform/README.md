## Creating a vm on IBM Cloud with Terraform
See https://cloud.ibm.com/docs/terraform for more info.

## The Yellow Brick Road
Use the supplied cli.dockerfile to build an image with the IBM Cloud CLI + Terraform (this may take a few minutes):

Run the image and map the current dir to /cwd inside the container:
```
docker run -it --rm -v $(pwd):/cwd ibm-cloud-cli
```

To create a vm on the classic infra IaaS, run the sample terraform script from within the container:
```
cd /cwd
terraform init
terraform apply -var username=YOUR_CLASSIC_USERNAME -var apikey=YOUR_CLASSIC_APIKEY
```
Note that `YOUR_CLASSIC_USERNAME` and `YOUR_CLASSIC_APIKEY` can both be seen (or generated) in *IAM | Users | View my classic infrastructure users | Manage user*. The classic username can be seen in the 'VPN Password' section (it's in the form of `AccountId_Email`, ie: `9873331_joe@example.com`) and the API Key in the 'API Keys' section.  
