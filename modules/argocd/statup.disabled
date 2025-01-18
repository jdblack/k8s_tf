module argocd_setup {
  source = "./startup"
  argocd_host = local.fqdn
  argocd_user = "admin"
  argocd_pass = data.kubernetes_secret.initial_admin_pass.data.password
  deploy_key =  var.devops_deploy_key
  repo = var.devops_deploy_repo
}

