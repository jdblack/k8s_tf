output "registry_url" { value = local.url }
output "admin_pass" { value = random_password.admin_password.result }
