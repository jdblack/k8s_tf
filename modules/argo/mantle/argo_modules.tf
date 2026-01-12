module argocd {
  source = "./argo-cd"
  namespace = var.namespace
  domain = var.domain
  cert_issuer = var.cert_issuer
  oauth2_server =  var.oauth2_server
  deploy_key = var.deploy_key
  repo = var.repo
}

module argo_workflows {
  source = "./argo-workflows"
  namespace = var.namespace
  domain = var.domain
  cert_issuer = var.cert_issuer
  sso_server =  var.oauth2_server
}

