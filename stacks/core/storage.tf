module "seaweedfs" {
  source      = "../../modules/storage/seaweedfs"
  namespace   = "kube-storage"
  cert_issuer = var.deployment.cert_manager.external_issuer
  domains     = var.deployment.cluster.domains
  data_center = var.deployment.storage.data_center
}
