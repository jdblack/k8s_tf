output "fqdn" {
  value = local.fqdn
}

output "client_id" {
  value     = module.oidc.client_id
  sensitive = true
}
