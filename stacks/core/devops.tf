locals {
  argocd_initial_pass = var.argo_enabled ? module.argo.0.argocd_initial_pass : null
  argocd_initial_user = var.argo_enabled ? module.argo.0.argocd_initial_user : null
  harbor_registry_url = var.harbor_enabled ? module.harbor.0.registry_url : null
  harbor_initial_pass = var.harbor_enabled ? module.harbor.0.admin_pass : null
}

module "harbor" {
  count       = var.harbor_enabled ? 1 : 0
  namespace   = var.deployment.harbor.namespace
  auth_secret = var.deployment.harbor.auth_secret
  source      = "../../modules/harbor/core"
  cert_issuer = var.deployment.cert.cert_issuer
  domain      = var.deployment.common.domain
  depends_on  = [module.network, module.storage, module.cert_man]
}

module "argo" {
  count  = var.argo_enabled ? 1 : 0
  source = "../../modules/argo/core"
  domain = var.deployment.common.domain
  # Leaf cert only: modules/argo/core uses cert_issuer for the listener
  # annotation and nothing in-cluster validates argo-cd.vn's own cert. Its SSO
  # CA ConfigMap lookups live in modules/argo/mantle and stay on linuxguru-ca
  # (they trust auth.vn, which is still signed by the private CA).
  cert_issuer = var.deployment.cert_authorities.public
}


output "harbor_pass" {
  value     = local.harbor_initial_pass
  sensitive = true
}

output "harbor_url" {
  value = local.harbor_registry_url
}

output "argocd_initial_pass" {
  value     = local.argocd_initial_pass
  sensitive = true
}

output "argocd_initial_user" {
  value = local.argocd_initial_user
}
