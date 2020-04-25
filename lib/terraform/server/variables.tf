variable name              {}
variable profile           {}
variable vpc_name          {}
variable subnet_id         {}
variable keys              {}
variable security_groups   {}
variable resource_group_id {}

variable fip {
  default = false
}

variable user_data {
  default = null
}

variable post_provision {
  default = null
}
