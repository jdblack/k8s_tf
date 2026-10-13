output "fqdn" {
  value = local.fqdn
}

output "name" {
  value = var.name
}

output "namespace" {
  value = kubernetes_namespace_v1.namespace.metadata[0].name
}

output "ssh_fqdn" {
  value = local.ssh_fqdn
}
