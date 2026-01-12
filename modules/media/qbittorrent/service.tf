resource kubernetes_service_v1 service {
  metadata {
    namespace = var.namespace
    name      = var.name
    labels = {
      "app.kubernetes.io/name"    = var.name
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      "app.kubernetes.io/name"    = var.name
    }

    port {
      name = "webui"
      port = var.web_port
      target_port = var.web_port
    }
    port {
      name = "torrent"
      port = var.torrent_port
      target_port = var.torrent_port
    }
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations
    ]
  }
}

resource kubernetes_ingress_v1 ingress {
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
              name = var.name
              port {
                number = var.web_port
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
