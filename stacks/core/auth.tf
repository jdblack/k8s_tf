
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
  cert_issuer = var.deployment.cert_authorities.public
  depends_on  = [module.cert_man, module.storage, kubernetes_namespace_v1.auth]

}

