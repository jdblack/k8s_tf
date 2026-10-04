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

# The offsite BSL's own key, so neither store's credential can reach the other.
resource "kubernetes_secret_v1" "offsite_credentials" {
  type = "Opaque"

  metadata {
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
    name      = "velero-b2-credentials"
  }

  data = {
    cloud = local.offsite_credentials
  }
}
