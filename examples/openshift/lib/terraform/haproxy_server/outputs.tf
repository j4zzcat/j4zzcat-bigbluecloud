output "name" {
  value = module.haproxy_server.name
}

output "private_ip" {
  value = module.haproxy_server.private_ip
}

output "public_ip" {
  value = module.haproxy_server.public_ip
}
