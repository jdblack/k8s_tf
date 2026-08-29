module "ai_deployment" {
  source           = "../../modules/argo/aoa_deployment"
  name             = var.ai_namespace
  argo_namespace   = var.ai_argo_namespace
  create_namespace = var.ai_create_namespace
  deployer_repo    = var.ai_deployer_repo
  deployer_path    = var.ai_deployer_path
}
