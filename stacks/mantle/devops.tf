
module "harbor_setup" {
  source        = "../../modules/harbor/mantle"
  projects      = var.deployment.harbor.projects
  domain        = var.deployment.common.domain
  oauth2_server = "auth.${var.deployment.common.domain}"
}

module "argo_setup" {
  source        = "../../modules/argo/mantle"
  namespace     = var.deployment.argocd_devops.namespace
  oauth2_server = "auth.${var.deployment.common.domain}"
  domain        = var.deployment.common.domain
  # Leaf cert only (argo-wf.vn's ListenerSet). The SSO clients in this module
  # validate authentik against the container's public roots -- no CA injection.
  cert_issuer = var.deployment.cert_authorities.public
  deploy_key  = var.deployment.argocd_devops.deploy_key
  repo        = var.deployment.argocd_devops.deploy_repo
}

