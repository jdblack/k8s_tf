

resource kubernetes_deployment_v1 deployment {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = var.name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"    = var.name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = var.name
        }
      }

      spec {
        container {
          name  = var.name
          image = "fyb3roptik/threadfin"
          image_pull_policy = "Always"

          port {
            name = "service"
            container_port = var.service_port
          }

          volume_mount {
            mount_path = "/home/threadfin/conf"
            name = local.volume_name
          }
        }

        volume {
          name = local.volume_name
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.data_volume.metadata[0].name
          }
        }
      }
    }
  }
}

resource kubernetes_persistent_volume_claim_v1 data_volume {
  metadata {
    name      = "${var.name}-data"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteMany"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}
