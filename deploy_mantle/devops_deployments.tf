

module argo_deployment {
  count = 0
  name = "ai"
  namespace = "ai"
  source = "../modules/argocd/app_deployment/"
  deployment_path = "deployments/ai"
  repo = var.deployment.argocd_devops.deploy_repo
  depends_on = [ module.argocd_setup ]
}
