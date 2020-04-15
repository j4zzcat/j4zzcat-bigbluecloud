variable name              {}
variable vpc_name          {}
variable subnet_id         {}
variable key_id            {}
variable resource_group_id {}
variable security_groups   {}

variable floating_ip       {
  default = true
}

variable profile           {
  default = "bx2-2x8"
}

variable user_data         {
  default = ""
}
