# Read off the resources, so the app cannot render before the broker exists.
output "host" {
  value = kubernetes_service_v1.valkey.metadata[0].name
}

output "port" {
  value = var.port
}
