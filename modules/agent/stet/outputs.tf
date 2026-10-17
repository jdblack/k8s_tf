output "namespace" {
  value = var.namespace
}

output "fqdn" {
  value       = "${var.name}.${var.domain}"
  description = "The brain's address for clients. Deliberately a NEW name: the old store keeps answering at its old name as a reachable rollback."
}

output "brain_url" {
  value       = local.brain_url
  description = "In-namespace MCP endpoint a hand uses."
}

output "door" {
  value       = module.hands.fqdn
  description = "The doorbell's hostname, or null when it is not published."
}
