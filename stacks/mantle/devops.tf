module "harbor_setup" {
  source        = "../../modules/harbor/mantle"
  projects      = var.deployment.harbor.projects
  domain        = var.deployment.cluster.domains.private
  oauth2_server = "auth.${var.deployment.cluster.domains.private}"
}

module "argo_setup" {
  source        = "../../modules/argo/mantle"
  namespace     = var.deployment.argo.namespace
  oauth2_server = "auth.${var.deployment.cluster.domains.private}"
  domain        = var.deployment.cluster.domains.private
  cert_issuer   = var.deployment.cert_manager.external_issuer
  deploy_key    = var.deployment.argo.deploy_key
  repo          = var.deployment.argo.repo
}
