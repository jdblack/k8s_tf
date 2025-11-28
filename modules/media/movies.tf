module movies {
  name = var.movies_name
  source = "../storage/juicefs/static_volume/"
  namespace = var.namespace
  bucket_url = local.bucket_url
  access_key = var.s3["access_key"]
  secret_key = var.s3["secret_key"]
}

resource kubernetes_persistent_volume_claim  downloads {
  metadata {
    name = var.downloads_name
    namespace = var.namespace
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "20Gi"
      }
    }
  }
}

