IBMCLOUD_COLOR=false


# VPCs
echo 'VPCs Subnets'

# regions=$(ibmcloud is regions | tail -n +3 | awk '{print $1}' | xargs echo)
regions="us-south us-east eu-gb"
for region in ${regions}; do
  ibmcloud target -r ${region} >/dev/null

  echo "Listing ${region}/gen1"
  ibmcloud is target --gen 1 >/dev/null
  ibmcloud is subnets | tail -n +2

  echo "Listing ${region}/gen2"
  ibmcloud is target --gen 2 >/dev/null
  ibmcloud is subnets | tail -n +2
done

# Classic infra
echo
echo 'Classic Infra Subnets'
ibmcloud sl subnet list

echo
echo 'Classic Infra Global IPs'
ibmcloud sl globalip list

echo
echo 'Classic Infra VLANs'
ibmcloud sl vlan list

echo
echo 'Classic Infra VS'
ibmcloud sl vs list

echo
echo 'Kubernetes Classic'
ibmcloud ks subnets --provider=classic

echo
echo 'Kubernetes VPC-Classic'
vpcs=$(ibmcloud ks vpcs --provider=vpc-classic | tail -n +4 | awk '{print $2}' | xargs echo)
zones=$(ibmcloud ks zone ls --provider=vpc-classic | tail -n +3 | awk '{print $1}' | tac | xargs echo)

for vpc in ${vpcs}; do
  for zone in ${zones}; do
    echo ${vpc}:${zone} >/dev/stderr
    ibmcloud ks subnets --provider=vpc-classic --vpc-id=${vpc} --zone=${zone}
  done
done
