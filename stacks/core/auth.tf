
resource "kubernetes_namespace_v1" "auth" {
  metadata {
    name = "kube-auth"
  }
}

module "authentik" {
  source    = "../../modules/auth/authentik/core"
  namespace = "kube-auth"
  domain    = var.deployment.common.domain
  fqdn      = "auth.${var.deployment.common.domain}"
  # Public issuer: auth.vn must be trusted by browsers AND by every in-cluster
  # consumer without shipping them a CA.
  cert_issuer = var.deployment.cert_authorities.default
  # Read in core.tf's root because the depends_on below would otherwise defer the
  # firewall modules' own read to apply time and abort the apply.
  api_peer_ips = local.api_peer_ips
  depends_on   = [module.cert_man, module.storage, kubernetes_namespace_v1.auth]

}

