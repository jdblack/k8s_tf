output "service_name" {
  value = kubernetes_service_v1.outpost.metadata[0].name
}

output "namespace" {
  value = var.namespace
}

# host:port a client dials, i.e. what goes into an LDAP URL.
output "host" {
  value = local.server_name
}

output "uri" {
  value       = "ldaps://${local.server_name}:${var.ldaps_port}"
  description = "LDAPS URL for in-cluster clients."
}

output "ldap_port" {
  value = var.ldap_port
}

output "ldaps_port" {
  value = var.ldaps_port
}

output "base_dn" {
  value = var.base_dn
}

output "users_dn" {
  value = local.users_dn
}

output "groups_dn" {
  value = local.groups_dn
}

output "bind_dn" {
  value = local.bind_dn
}

output "bind_password_secret" {
  value = kubernetes_secret_v1.bind.metadata[0].name
}

output "bind_password_secret_key" {
  value = var.bind_password_key
}

output "provider_id" {
  value = authentik_provider_ldap.provider.id
}

output "application_slug" {
  value = authentik_application.app.slug
}

# Published as a value as well as a Secret: the consumer runs in another namespace and
# cannot read this one's Secrets.
output "bind_password" {
  value     = random_password.bind_password.result
  sensitive = true
}
