
#module minio {
#  source = "../modules/storage/minio"
#  namespace = "kube-storage"
#}

module juicefs {
  source = "../modules/storage/juicefs"
  namespace = "juicefs"
}

