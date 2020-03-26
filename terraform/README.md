Use the supplied Dockerfile to build an image with the IBM Cloud CLI + Terraform.
```
docker build --rm -t icctf -f Dockerfile . 
```

Run the image
```
docker run -it --rm -v $(pwd):/cwd icctf
```

Run the sample within the container
```
cd /cwd
terraform init
terraform apply -var username=YOUR_USERNAME -var apikey=YOUR_APIKEY
```

