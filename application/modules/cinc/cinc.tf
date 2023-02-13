locals {
  cinc_name = "cinc"
  cinc_port = 443
  cinc_labels = {
    name = "cinc"
  }
}
resource "kubernetes_deployment" "cinc" {
  metadata {
    name = local.cinc_name
    namespace = var.namespace
    labels = local.cinc_labels
  }
  spec {
    replicas = 1

    selector { match_labels = local.cinc_labels }

    template {
      metadata { labels = local.cinc_labels }
      spec {
        automount_service_account_token = true
        container {
          name = local.cinc_name
          image = "${module.registry-puller.server}/cinc_k8s"
          resources  {
            requests = {
              memory = "2Gi"
            }
          }

          port { container_port = local.cinc_port }
          env {
            name = "NAMESPACE"
            value = var.namespace
          }

          env {
            name = "BACKEND_KEYS"
            value = "${local.cinc_name}-backend"
          }
          env_from {
            secret_ref {
              name = kubernetes_secret.cinc.metadata[0].name
            }

          }
          volume_mount {
            name = "certs"
            mount_path = "/var/local/certs"
          }
        }
        image_pull_secrets {
          name = local.registry_secret
        }
        volume {
          name = "certs"
          secret {
            secret_name = local.lb_cert
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "cinc" {
  metadata {
    namespace = var.namespace
    name = local.cinc_name
    annotations = {
      "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
    }
  }
  spec {
    type = "LoadBalancer"
    selector = local.cinc_labels
    port {
      port        = local.cinc_port
      target_port = local.cinc_port
    }
  }
}
