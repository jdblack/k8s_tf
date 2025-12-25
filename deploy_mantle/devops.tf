
module harbor_setup {
  source = "../modules/harbor/mantle"
  projects = var.harbor_projects
  domain = var.deployment.common.domain
  cert_issuer = var.deployment.cert.cert_issuer
}

module argocd_setup {
  source = "../modules/argocd/mantle"
  namespace = var.deployment.argocd_devops.namespace
  deploy_key =  var.deployment.argocd_devops.deploy_key
  repo = var.deployment.argocd_devops.deploy_repo
  domain = var.deployment.common.domain
  cert_issuer = var.deployment.cert.cert_issuer
}

