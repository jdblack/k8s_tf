module "whisker" {
  source = "../../modules/network/whisker"

  namespace   = "calico-system"
  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  gateway_name      = "private"
  gateway_namespace = "kube-network"

  group_name = "platform"
}
