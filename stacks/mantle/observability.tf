module "whisker" {
  source = "../../modules/network/whisker"

  namespace   = "calico-system"
  domain      = var.deployment.domains.private
  cert_issuer = var.deployment.cert_authorities.default

  gateway_name      = "private"
  gateway_namespace = "kube-network"

  group_name = "platform"
}
