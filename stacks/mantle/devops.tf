
module harbor_setup {
  source = "../../modules/harbor/mantle"
  projects = var.deployment.harbor.projects
  domain = var.deployment.common.domain
  cert_issuer = var.deployment.cert.cert_issuer
  oauth2_server = "auth.${var.deployment.common.domain}"
}

module argo_setup {
  source = "../../modules/argo/mantle"
  namespace = var.deployment.argocd_devops.namespace
  oauth2_server = "auth.${var.deployment.common.domain}"
  domain = var.deployment.common.domain
  cert_issuer = var.deployment.cert.cert_issuer
  deploy_key =  var.deployment.argocd_devops.deploy_key
  repo = var.deployment.argocd_devops.deploy_repo
}

