
resource kubernetes_namespace_v1 auth {
  metadata {
    name = "kube-auth"
  }
}

module authentik {
  source = "../modules/auth/authentik/core"
  namespace = "kube-auth"
  domain = var.deployment.common.domain
  fqdn = "auth.${var.deployment.common.domain}"
  cert_issuer = var.deployment.cert.cert_issuer
  depends_on = [ module.cert_man, module.storage, kubernetes_namespace_v1.auth ]

}

