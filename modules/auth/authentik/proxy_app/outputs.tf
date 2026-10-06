output "app" {
  value = {
    provider_id      = authentik_provider_proxy.app.id
    application_uuid = authentik_application.app.uuid
  }
}

output "admin_group_id" {
  value = authentik_group.admin.id
}

output "user_group_id" {
  value = authentik_group.user.id
}
