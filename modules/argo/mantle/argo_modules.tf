module "argocd" {
  source        = "./argo-cd"
  namespace     = var.namespace
  domain        = var.domain
  oauth2_server = var.oauth2_server
  deploy_key    = var.deploy_key
  repo          = var.repo
}
