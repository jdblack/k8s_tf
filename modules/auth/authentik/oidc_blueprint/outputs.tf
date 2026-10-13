output "client_id" {
  value     = var.name
  sensitive = true
}

output "client_secret" {
  value     = random_password.client_secret.result
  sensitive = true
}

output "discovery_url" {
  value = local.discovery_url
}

# Consumed by the authentik module's extra_blueprints input, which is a list of Secret *names*.
output "blueprint_secret" {
  value = kubernetes_secret_v1.blueprint.metadata[0].name
}
