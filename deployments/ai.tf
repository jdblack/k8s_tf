module ai_deployment {
  source = "../modules/argo/aoa_deployment"
  name = "ai"
  argo_namespace = "argo"
  create_namespace = true
  deployer_repo = "git@github.com:jdblack/argo-linuxguru.git"
  deployer_path = "deployments/ai"
}
