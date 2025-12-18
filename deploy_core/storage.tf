
#module minio {
#  source = "../modules/storage/minio"
#  namespace = "kube-storage"
#}

module juicefs {
  count = 0
  source = "../modules/storage/juicefs"
  namespace = "juicefs"
}

module seaweedfs {
  source = "../modules/storage/seaweedfs"
  namespace = "kube-storage"
  cert_issuers = var.deployment["cert_authorities"]
}
