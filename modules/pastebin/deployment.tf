resource "kubernetes_deployment_v1" "pastebin" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
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
          "checksum/config"                 = sha256(kubernetes_secret_v1.config.data["config.yaml"])
          "backup.velero.io/backup-volumes" = "data"
        }
      }

      spec {
        # The image starts as root; create-user.sh chowns the mounts and drops to PUID/PGID
        # via su-exec, so runAsUser must stay unset.
        security_context {
          fs_group = 1000
        }

        # A subPath mount has to exist before the container starts. Both mounts share one
        # claim, so the share store and the branding travel as a single backup unit.
        init_container {
          name    = "mk-images"
          image   = "${var.image}:${var.image_tag}"
          command = ["sh", "-c", "mkdir -p /data/images"]

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }

        container {
          name  = var.name
          image = "${var.image}:${var.image_tag}"

          # The gateway sets X-Forwarded-For; trusting it is what makes session cookies and
          # rate limits see the real client. Not the internet: pingvin never reads it otherwise.
          env {
            name  = "TRUST_PROXY"
            value = "true"
          }

          # Entrypoint user/group; the chown walk in create-user.sh runs as these ids.
          env {
            name  = "PUID"
            value = "1000"
          }
          env {
            name  = "PGID"
            value = "1000"
          }

          env {
            name  = "CONFIG_FILE"
            value = "/opt/app/config.yaml"
          }

          port {
            name           = "http"
            container_port = var.port
          }

          readiness_probe {
            http_get {
              path = "/api/health"
              port = "http"
            }

            initial_delay_seconds = 30
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/api/health"
              port = "http"
            }

            initial_delay_seconds = 60
            period_seconds        = 30
          }

          volume_mount {
            name       = "data"
            mount_path = "/opt/app/backend/data"
          }

          volume_mount {
            name       = "data"
            mount_path = "/opt/app/frontend/public/img"
            sub_path   = "images"
          }

          volume_mount {
            name       = "config"
            mount_path = "/opt/app/config.yaml"
            sub_path   = "config.yaml"
          }
        }

        volume {
          name = "data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.data.metadata[0].name
          }
        }

        volume {
          name = "config"

          secret {
            secret_name = kubernetes_secret_v1.config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "data" {
  metadata {
    name      = local.data_pvc_name
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
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
