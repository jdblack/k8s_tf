output "secret_name" {
  value = kubernetes_secret_v1.credentials.metadata[0].name
}

output "secret_namespace" {
  value = kubernetes_secret_v1.credentials.metadata[0].namespace
}

output "user" {
  value = var.user
}

output "bucket" {
  value = var.bucket
}
