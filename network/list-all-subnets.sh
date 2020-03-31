ibmcloud is target --gen 1 >/dev/null
ibmcloud is subnets | tail -n 1 | awk '{print "vpc1 "$2" "$4}'
ibmcloud is target --gen 2 >/dev/null
ibmcloud is subnets | tail -n 2 | awk '{print "vpc2 "$2" "$4}'
