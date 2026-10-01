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

  gateway_name      = module.network.gateway_name
  gateway_namespace = module.network.gateway_namespace

  # oCIS resolves every account over LDAP, so it has to be allowed in at the outpost.
  ldap_client_namespaces = ["documents"]

  depends_on = [kubernetes_namespace_v1.auth]
}
