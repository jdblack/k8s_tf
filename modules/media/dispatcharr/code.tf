resource "kubernetes_service" "dispatcharr" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = var.name
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"    = var.name
    }

    port {
      port        = 80
      target_port = 9191
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress" "dispatcharr" {
  metadata {
    name      = var.name
    namespace = var.namespace
      annotations = {
      "cert-manager.io/cluster-issuer" = local.issuer
      "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
    }
  }

    spec {
      rule {
        host = local.fqdn
        http {
          path {
            path = "/"
            backend {
              service_name = kubernetes_service.dispatcharr.metadata[0].name
              service_port = 80
            }
          }
        }
      }
    }
}
