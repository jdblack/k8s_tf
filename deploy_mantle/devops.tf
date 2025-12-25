
module harbor_setup {
  source = "../modules/harbor/mantle"
  projects = var.harbor_projects
  domain = var.deployment.common.domain
  oidc_url = module.keycloak.realm_url
  realm = var.deployment.keycloak.realm
  depends_on = [ module.keycloak ]
}

module argocd_setup {
  source = "../modules/argocd/mantle"
  namespace = var.deployment.argocd_devops.namespace
  deploy_key =  var.deployment.argocd_devops.deploy_key
  repo = var.deployment.argocd_devops.deploy_repo
  domain = var.deployment.common.domain
  ca_cert_cm = "${var.deployment.cert.cert_issuer}.crt"
  depends_on = [ module.keycloak ]
}

