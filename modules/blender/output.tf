
output "samba_pass" {
  value     = random_password.password.result
  sensitive = true
}

