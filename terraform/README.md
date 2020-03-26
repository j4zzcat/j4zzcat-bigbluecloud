## Creating a vm on IBM Cloud with Terraform
See https://cloud.ibm.com/docs/terraform for more info.

## The Yellow Brick Road
Use the supplied Dockerfile to build an image with the IBM Cloud CLI + Terraform (this may take a few minutes):
```
docker build --rm -t icctf -f Dockerfile . 
```

Run the image and map the current dir to /cwd inside the container:
```
docker run -it --rm -v $(pwd):/cwd icctf
```

Now run the sample terraform script within the container:
```
cd /cwd
terraform init
terraform apply -var username=YOUR_CLASSIC_USERNAME -var apikey=YOUR_CLASSIC_APIKEY
```
`YOUR_CLASSIC_USERNAME` is in the form of `AccountId_Email`, ie: `9873331_joe@example.com`, and `YOUR_CLASSIC_APIKEY` is the classic infra apikey. Both can be seen (or generated) in IAM | Users | View my classic infrastructure users | Manage user. The classic username can be seen in the 'VPN Password' section and the API Key in the 'API Keys' section.  
