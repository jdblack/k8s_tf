resource kubernetes_service_v1 service {
  metadata {
    namespace = var.namespace
    name      = var.name
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
      name = "webui"
      port = 8265
      target_port = 8265 
    }
    port {
      name = "server"
      port = 8266
      target_port = 8266 
    }
  }
}

resource kubernetes_ingress_v1 ingress {
  metadata {
    name      = var.name
    namespace = var.namespace
    annotations = {
      "cert-manager.io/cluster-issuer" = var.cert_issuer
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
              name = var.name
              port {
                number = 8265
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
