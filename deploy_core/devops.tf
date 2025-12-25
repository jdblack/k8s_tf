
module argocd {
  name = "argocd"
  namespace = "devops-argocd"
  source = "../modules/argocd/core"
  domain = var.deployment.common.domain
  cert_issuer = var.deployment.cert_authorities.private
  devops_deploy_repo = var.deployment.argocd_devops.deploy_repo
  devops_deploy_key = var.deployment.argocd_devops.deploy_key
  depends_on = [ module.network, module.storage, module.cert_man ]
}

#output "argo_pass" {
#  value = module.argocd.admin_pass
#  sensitive=true
#}
#


module harbor {
  namespace = var.deployment.harbor.namespace
  auth_secret = var.deployment.harbor.auth_secret
  source = "../modules/harbor/core" 
  cert_issuer = var.deployment.cert.cert_issuer
  domain = var.deployment.common.domain
  depends_on = [ module.network, module.storage, module.cert_man ]
}

output "harbor_url" {
  value = module.harbor.registry_url
}
