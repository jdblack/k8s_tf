resource "kubernetes_service_v1" "hello" {
  metadata {
    name      = "cline-hello"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.hello_labels
  }

  spec {
    type     = "ClusterIP"
    selector = local.hello_labels

    port {
      name        = "http"
      port        = 80
      target_port = "http"
    }
  }
}
