

module argo_deployment {
  source = "../modules/argocd/deployment/"
  namespace = "ai"
  deployment_path = "deployments/ai"
  realm = var.deployment.keycloak.realm
  repo = var.deployment.argocd_devops.deploy_repo
  depends_on = [ module.argocd_setup ]
}
