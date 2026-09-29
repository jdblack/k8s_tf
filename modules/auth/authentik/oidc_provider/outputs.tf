output "client_id" {
  value     = authentik_provider_oauth2.oauth2.client_id
  sensitive = true
}

output "client_secret" {
  value     = authentik_provider_oauth2.oauth2.client_secret
  sensitive = true
}

output "admin_group_id" {
  value = authentik_group.admin.id
}

output "user_group_id" {
  value = authentik_group.user.id
}
