
module seaweedfs {
  source = "../../modules/storage/seaweedfs"
  namespace = "kube-storage"
  cert_issuers = var.deployment["cert_authorities"]
  domains = var.deployment["domains"]
  data_center = var.deployment.storage.data_center
  admin_password = var.deployment.storage.admin_password
}
