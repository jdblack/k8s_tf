# Read off the resources, so the chart's release cannot render before the database exists.
output "host" {
  value = kubernetes_service_v1.postgres.metadata[0].name
}

output "user" {
  value = var.user
}

output "database" {
  value = var.user
}

output "password_secret" {
  value = kubernetes_secret_v1.postgres.metadata[0].name
}
