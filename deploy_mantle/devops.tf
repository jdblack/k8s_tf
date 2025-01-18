
module harbor_setup {
  source = "./devops/harbor"
  projects = var.harbor_projects
}

module argocd_setup {
  source = "./devops/argocd"
  namespace = var.deployment.argocd_devops.namespace
  deploy_key =  var.deployment.argocd_devops.deploy_key
  repo = var.deployment.argocd_devops.deploy_repo
}

