
module seaweedfs {
  source = "../modules/storage/seaweedfs"
  namespace = "kube-storage"
  cert_issuers = var.deployment["cert_authorities"]
}
