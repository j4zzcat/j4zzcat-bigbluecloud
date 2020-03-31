IBMCLOUD_COLOR=false

# VPCs
echo 'VPCs Subnets'
ibmcloud is target --gen 1 >/dev/null
ibmcloud is subnets | tail -n +3 | awk '{print "vpc1 "$2" "$4}'
ibmcloud is target --gen 2 >/dev/null
ibmcloud is subnets | tail -n +3 | awk '{print "vpc2 "$2" "$4}'

# Classic infra
echo
echo 'Classic Infra Subnets'
ibmcloud sl subnet list | tail -n +2

echo
echo 'Classic Infra Global IPs'
ibmcloud sl globalip list | tail -n +2

echo
echo 'Classic Infra VLANs'
ibmcloud sl vlan list | tail -n +2

echo
echo 'Classic Infra VS'
ibmcloud sl vs list | tail -n +2

echo
echo 'Kubernetes Classic'
ibmcloud ks subnets --provider=classic | tail -n +3

echo
echo 'Kubernetes VPC-Classic'
vpcs=$(ibmcloud ks vpcs --provider=vpc-classic | tail -n +4 | awk '{print $2}' | xargs echo)
zones=$(ibmcloud ks zone ls --provider=vpc-classic | tail -n +3 | awk '{print $1}' | tac | xargs echo)

for vpc in ${vpcs}; do
  for zone in ${zones}; do
    echo ${vpc}:${zone} >/dev/stderr
    ibmcloud ks subnets --provider=vpc-classic --vpc-id=${vpc} --zone=${zone} | tail -n +3
  done
done
