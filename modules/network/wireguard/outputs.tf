output "peer_config_secret" {
  value = "${var.wireguard_name}-peer-configs"
}

output "namespace" {
  value = var.namespace
}
