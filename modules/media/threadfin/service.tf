resource kubernetes_service_v1 service {
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
      port = var.service_port
      target_port = var.service_port
    }
  }
}

resource kubernetes_ingress_v1 ingress {
  metadata {
    name      = var.name
    namespace = var.namespace
    annotations = {
      "cert-manager.io/cluster-issuer" = local.issuer
      "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
      "nginx.org/websocket-services" = local.svc_name
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
                number = var.service_port
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
