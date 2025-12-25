
locals {
  devops_namespace = "devops"
}


module argocd {
  namespace = "devops-argo"
  source = "../modules/argocd/core"
  domain = var.deployment.common.domain
  ssl_ca = var.deployment.cert.cert_issuer
  ssl_ca_namespace = "kube-certificates" 
  devops_deploy_repo = var.deployment.argocd_devops.deploy_repo
  devops_deploy_key = var.deployment.argocd_devops.deploy_key
  depends_on = [ module.network, module.storage, module.cert_man ]
}
output "argo_pass" {
  value = module.argocd.admin_pass
  sensitive=true
}



module harbor {
  namespace = var.deployment.harbor.namespace
  auth_secret = var.deployment.harbor.auth_secret
  source = "../modules/harbor/core" 
  certca = var.deployment.cert.cert_issuer
  ssl_ca = var.deployment.cert.cert_issuer
  ssl_ca_namespace = "kube-certificates" 
  domain = var.deployment.common.domain
  keycloak_endpoint = module.keycloak.url
  depends_on = [ module.network, module.storage, module.cert_man ]
}


output "harbor_admin_pass" {
  value = module.harbor.admin_pass
  sensitive=true
}

output "harbor_url" {
  value = module.harbor.registry_url
}
