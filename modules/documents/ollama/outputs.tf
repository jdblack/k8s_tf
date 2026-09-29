output "host" {
  value = kubernetes_service_v1.ollama.metadata[0].name
}

output "port" {
  value = var.port
}

output "endpoint" {
  value = "http://${kubernetes_service_v1.ollama.metadata[0].name}:${var.port}"
}
