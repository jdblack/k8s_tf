output "fqdn" {
  value       = var.expose ? local.fqdn : null
  description = "The doorbell's hostname, or null when the door is not published."
}

output "service" {
  value       = "${var.name}.${var.namespace}.svc.cluster.local"
  description = "In-namespace name the brain and the roster use."
}
