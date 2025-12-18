resource "kubernetes_service" "dispatcharr" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = var.name
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name"    = var.name
    }

    port {
      name = "http"
      port = 80
      target_port = "http"
    }
  }
}

resource "kubernetes_ingress_v1" "dispatcharr" {
  metadata {
    name      = var.name
    namespace = var.namespace
    annotations = {
      "cert-manager.io/cluster-issuer" = local.issuer
      "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
    }
  }

  spec {
    ingress_class_name = var.visibility
    rule {
      host = local.fqdn
      http {
        path {
          path = "/"
          backend {
            service {
              name = "http"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    tls {
      hosts = [ local.fqdn]
      secret_name = "cert-${local.fqdn}"
    }
  }
}
