resource "random_password" "access_key" {
  length  = 20
  special = false
}

resource "random_password" "secret_key" {
  length  = 40
  special = false
}

resource "kubernetes_secret_v1" "credentials" {
  type = "Opaque"

  metadata {
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
    name      = "velero-credentials"
  }

  data = {
    cloud = local.credentials
  }
}
