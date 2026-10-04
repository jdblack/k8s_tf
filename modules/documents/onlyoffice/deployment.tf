# One all-in-one image: nginx, the editor services, postgres, rabbitmq and redis all sit
# in this container, so there is nothing to wire up beside the volume.
resource "kubernetes_deployment_v1" "onlyoffice" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = 1

    # The data dir is a ReadWriteOnce claim, so the old pod has to go before the new one.
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
          "backup.velero.io/backup-volumes" = "data"
        }
      }

      spec {
        # The entrypoint starts postgres, rabbitmq and redis as their own users, so the
        # container comes up as root and hands each service its own uid.
        container {
          name  = var.name
          image = "${var.image}:${var.image_tag}"

          # oCIS is the WOPI host and this is the client: the two only meet over WOPI.
          env {
            name  = "WOPI_ENABLED"
            value = "true"
          }

          # The WOPISrc oCIS hands out is the collaboration Service, a private ClusterIP,
          # and the outbound request filter blocks those by default.
          env {
            name  = "ALLOW_PRIVATE_IP_ADDRESS"
            value = "true"
          }

          port {
            name           = "http"
            container_port = var.port
          }

          readiness_probe {
            http_get {
              path = "/healthcheck"
              port = "http"
            }

            initial_delay_seconds = 30
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/healthcheck"
              port = "http"
            }

            initial_delay_seconds = 60
            period_seconds        = 30
          }

          # Holds the generated WOPI keypairs, the license and the fonts cache.
          volume_mount {
            name       = "data"
            mount_path = "/var/www/onlyoffice/Data"
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
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.data_size
      }
    }
  }
}
