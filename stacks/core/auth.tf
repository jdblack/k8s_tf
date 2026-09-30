resource "kubernetes_namespace_v1" "auth" {
  metadata {
    name = "kube-auth"
  }
}

module "authentik" {
  source      = "../../modules/auth/authentik/core"
  namespace   = "kube-auth"
  domain      = var.deployment.cluster.domains.private
  fqdn        = "auth.${var.deployment.cluster.domains.private}"
  cert_issuer = var.deployment.cert_manager.external_issuer
  pod_cidr    = var.deployment.network.pod_cidr
  depends_on  = [kubernetes_namespace_v1.auth]
}
