output "namespace" {
  value = kubernetes_namespace_v1.home.metadata[0].name
}

output "service" {
  value = kubernetes_service_v1.hello.metadata[0].name
}

output "shared_claim" {
  value = kubernetes_persistent_volume_claim_v1.shared.metadata[0].name
}
