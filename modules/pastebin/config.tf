resource "kubernetes_secret_v1" "config" {
  metadata {
    name      = "${var.name}-config"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
    labels    = local.labels
  }

  data = {
    "config.yaml" = yamlencode(local.config)
  }
}
