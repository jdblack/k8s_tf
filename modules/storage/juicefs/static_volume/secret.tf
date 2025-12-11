locals {
  secret_name = "juicefs-${var.name}"
}

resource kubernetes_secret secret {
  metadata {
    name      = local.secret_name
    namespace = var.metadata_namespace
    labels = {
      "juicefs.com/validate-secret" = "true"
    }
  }

  data = {
    name        = var.name
    metaurl     = "redis://${local.db_name}.${var.metadata_namespace}"
    storage     = "s3"
    bucket      = var.bucket_url
    access-key  = var.access_key
    secret-key  = var.secret_key
  }
}
