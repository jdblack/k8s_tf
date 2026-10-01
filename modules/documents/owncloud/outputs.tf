output "fqdn" {
  value = local.fqdn
}

output "s3_secret_name" {
  value = module.s3_user.secret_name
}

output "client_id" {
  value     = module.oidc.client_id
  sensitive = true
}
