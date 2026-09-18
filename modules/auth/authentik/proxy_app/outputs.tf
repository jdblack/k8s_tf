output "app" {
  value = {
    provider_id      = authentik_provider_proxy.app.id
    application_uuid = authentik_application.app.uuid
  }
}
