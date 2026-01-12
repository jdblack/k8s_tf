resource argocd_repository devops_repo {
  repo = var.repo
  name = "linuxguru github repo"
  username = "git"
  ssh_private_key = var.deploy_key
  type = "git"
  depends_on = [ module.auth ]

}

resource argocd_repository devops_helm {
  name = "Linuxguru Helm Repo"
  type = "helm"
  repo = "harbor.vn.linuxguru.net/linuxguru"
  enable_oci = true
  depends_on = [ module.auth ]
}
  
  
