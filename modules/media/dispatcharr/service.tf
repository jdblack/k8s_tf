resource "kubernetes_service" "dispatcharr" {
  metadata {
    namespace = var.namespace
    name      = local.svc_name
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
      name = "service"
      port = 9191
      target_port = 9191 
    }
  }
}

resource kubernetes_ingress_v1 dispatcharr {
  metadata {
    name      = var.name
    namespace = var.namespace
    annotations = {
      "cert-manager.io/cluster-issuer" = local.issuer
      "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
    }
  }

  spec {
    ingress_class_name = var.ingress_class
    rule {
      host = local.fqdn
      http {
        path {
          path = "/"
          backend {
            service {
              name = local.svc_name
              port {
                number = 9191
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
