output "fqdn" {
  value = local.fqdn
}

# In-cluster publish endpoint for the alerting receiver. Alertmanager talks to
# the Service directly rather than hairpinning out through the gateway.
output "publish_url" {
  value = "http://${var.name}.${var.namespace}.svc.cluster.local/${var.alert_topic}"
}

output "token_secret_name" {
  value = kubernetes_secret_v1.ntfy_auth.metadata[0].name
}

# The secret key holding the bare `tk_...` (as opposed to NTFY_AUTH_TOKENS,
# which is the `<user>:<token>:<label>` provisioning form).
output "token_secret_key" {
  value = "publisher_token"
}

output "admin_user" {
  value = var.admin_user
}

# Break-glass admin password -- the web UI cannot create an admin and the admin
# API cannot create the first one, so this is the only way in besides the CLI:
#   tofu -chdir=stacks/core output -raw ntfy_admin_password
output "admin_password" {
  value     = random_password.admin.result
  sensitive = true
}
