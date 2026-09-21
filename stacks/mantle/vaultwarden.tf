data "kubernetes_service_v1" "private_gateway" {
  metadata {
    name      = "private-private"
    namespace = "kube-network"
  }
}

module "vaultwarden" {
  source = "../../modules/vaultwarden"

  namespace   = "vaultwarden"
  domain      = var.deployment.cluster.domains.public
  cert_issuer = var.deployment.cert_manager.external_issuer

  zone_id            = var.deployment.cert_manager.dns01.zone_id
  private_gateway_ip = data.kubernetes_service_v1.private_gateway.status[0].load_balancer[0].ingress[0].ip

  image_tag = "1.37.3"

  signups_allowed = true
}
