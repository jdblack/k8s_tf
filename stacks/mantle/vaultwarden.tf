# Vaultwarden on the shared PRIVATE gateway, reached as `vaultwarden.linuxguru.net`.
#
# The private gateway's VIP is MetalLB-assigned (nothing pins it), so read it off the
# live data-plane Service instead of copying it into tfvars: the A record then follows
# the VIP if it ever moves. NGF names that Service `<gatewayClassName>-<gatewayName>`;
# kube-network is core's, applied first.
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

  # Literal zone id: the deployment's AWS key is denied route53:GetHostedZone, and the
  # A record is managed here because external-dns owns vn.linuxguru.net only while the
  # linuxguru.net wildcard points at the WAN IP.
  zone_id            = var.deployment.cert.R53_ZONEID
  private_gateway_ip = data.kubernetes_service_v1.private_gateway.status[0].load_balancer[0].ingress[0].ip

  # Pinned; there is no CI that resolves ":latest" here.
  image_tag = "1.37.3"

  # TEMPORARY: first-account bootstrap. signups stay open just long enough to register
  # in the web vault. FLIP THIS BACK TO false once registered -- while true anyone on
  # the LAN can sign up.
  signups_allowed = true
}
