resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels

        annotations = {
          "checksum/config" = sha256(jsonencode(kubernetes_secret_v1.config.data))
        }
      }

      spec {
        container {
          name  = var.name
          image = "${var.image}:${var.image_tag}"

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.config.metadata[0].name
            }
          }

          port {
            name           = "http"
            container_port = var.port
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }

        volume {
          name = "data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "data" {
  metadata {
    name      = local.data_pvc_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}
