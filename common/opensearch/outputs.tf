
output "host" {
  value = local.fqdn
}

output "user" {
  value = "admin"
}

output "password" {
  value = random_password.open_pass.result
}
