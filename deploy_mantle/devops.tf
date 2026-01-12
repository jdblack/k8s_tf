
module harbor_setup {
  source = "../modules/harbor/mantle"
  projects = var.harbor_projects
  domain = var.deployment.common.domain
  cert_issuer = var.deployment.cert.cert_issuer
}

module argo_setup {
  source = "../modules/argo/mantle"
  namespace = var.deployment.argocd_devops.namespace
  oauth2_server = "auth.vn.linuxguru.net"
  domain = var.deployment.common.domain
  cert_issuer = var.deployment.cert.cert_issuer
  deploy_key =  var.deployment.argocd_devops.deploy_key
  repo = var.deployment.argocd_devops.deploy_repo
}

