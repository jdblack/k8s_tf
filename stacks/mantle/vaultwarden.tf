# Vaultwarden on the shared private gateway, reached as vaultwarden.linuxguru.net. The VIP is
# MetalLB-assigned, so read it off the live data-plane Service rather than copying it into tfvars: the
# A record then follows the VIP if it moves.
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

  # Literal zone id: this key is denied route53:GetHostedZone. The A record is managed here because
  # external-dns owns vn.linuxguru.net only while the wildcard points at the WAN IP.
  zone_id            = var.deployment.cert.R53_ZONEID
  private_gateway_ip = data.kubernetes_service_v1.private_gateway.status[0].load_balancer[0].ingress[0].ip

  # Pinned; there is no CI that resolves ":latest" here.
  image_tag = "1.37.3"

  # TEMPORARY first-account bootstrap: FLIP BACK TO false once registered -- while true, anyone on the
  # LAN can sign up.
  signups_allowed = true
}
