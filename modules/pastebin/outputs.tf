output "fqdn" {
  value = local.fqdn
}

output "client_id" {
  value     = module.oidc.client_id
  sensitive = true
}

output "admin_group_id" {
  value = module.oidc.admin_group_id
}

output "user_group_id" {
  value = module.oidc.user_group_id
}
