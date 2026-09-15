
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
  # consumer (harbor, grafana, argo-wf, argo-cd) without shipping them a CA.
  cert_issuer = var.deployment.cert_authorities.default
  # api_peer_ips: read in core.tf's root (the APISERVER endpoints data source),
  # because the depends_on below would otherwise defer the firewall modules'
  # own read to apply time and abort the apply with "inconsistent final plan".
  api_peer_ips = local.api_peer_ips
  depends_on   = [module.cert_man, module.storage, kubernetes_namespace_v1.auth]

}

