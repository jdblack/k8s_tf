

resource "kubernetes_deployment" "dispatcharr" {
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
          image = "harbor.vn.linuxguru.net/library/dispatcharr:dev"
          image_pull_policy = "Always"

          port {
            name = "http"
            container_port = 80
          }

          volume_mount {
            mount_path = "/data"
            name = local.volume_name
          }
        }

        volume {
          name = local.volume_name
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.dispatcharr_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "dispatcharr_data" {
  metadata {
    name      = "${var.name}-data"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }

    storage_class_name = "longhorn"
  }
}
