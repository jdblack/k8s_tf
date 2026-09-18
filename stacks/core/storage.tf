module "seaweedfs" {
  source      = "../../modules/storage/seaweedfs"
  namespace   = "kube-storage"
  cert_issuer = var.deployment.cert_authorities.default
  domains     = var.deployment["domains"]
  data_center = var.deployment.storage.data_center
}
