data "kubernetes_service_v1" "private_gateway" {
  metadata {
    name      = "private-private"
    namespace = "kube-network"
  }
}

module "vaultwarden" {
  source = "../../modules/vaultwarden"

  namespace   = "vaultwarden"
  domain      = var.deployment.domains.public
  cert_issuer = var.deployment.cert_authorities.default

  zone_id            = var.deployment.cert.R53_ZONEID
  private_gateway_ip = data.kubernetes_service_v1.private_gateway.status[0].load_balancer[0].ingress[0].ip

  image_tag = "1.37.3"

  signups_allowed = true
}
