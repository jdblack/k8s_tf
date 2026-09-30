module "seaweedfs" {
  source      = "../../modules/storage/seaweedfs"
  namespace   = "kube-storage"
  cert_issuer = var.deployment.cert_manager.external_issuer
  domains     = var.deployment.cluster.domains
  data_center = var.deployment.storage.data_center

  gateway_name      = module.network.gateway_name
  gateway_namespace = module.network.gateway_namespace
}

module "ai_models" {
  source     = "../../modules/storage/ai_models"
  depends_on = [module.seaweedfs]
}
