variable username {}
variable apikey   {}

provider "ibm" {
  iaas_classic_username = var.username
  iaas_classic_api_key  = var.apikey
}

resource "ibm_compute_vm_instance" "vm1" {
 hostname          = "vm1"
 domain            = "example.com"
 os_reference_code = "DEBIAN_8_64"
 datacenter        = "dal09"
 network_speed     = 10
 hourly_billing    = true

 cores             = 1
 memory            = 1024
 disks             = [ 25 ]
 local_disk        = false
}
