
module harbor_setup {
  source = "./devops/harbor"
  projects = var.harbor_projects
  domain = var.deployment.common.domain
  oidc_url = module.keycloak.realm_url
  realm = var.deployment.keycloak.realm
}

module argocd_setup {
  source = "./devops/argocd"
  realm = var.deployment.keycloak.realm
  namespace = var.deployment.argocd_devops.namespace
  deploy_key =  var.deployment.argocd_devops.deploy_key
  repo = var.deployment.argocd_devops.deploy_repo
  argo_host = var.deployment.argocd_devops.server
  domain = var.deployment.common.domain
  ca_cert_cm = "${var.deployment.cert.cert_issuer}.crt"
  keycloak_url = module.keycloak.realm_url
}

