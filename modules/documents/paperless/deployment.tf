resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
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
          "checksum/config" = sha256(jsonencode(kubernetes_config_map_v1.config.data))
          "checksum/secret" = sha256(jsonencode(kubernetes_secret_v1.config.data))

          # Only the database claim travels with a backup; media rides the SeaweedFS s3sync.
          "backup.velero.io/backup-volumes" = "data"
        }
      }

      spec {
        # No run_as_user: the entrypoint installs the extra tesseract pack with apt, then every
        # service drops to uid 1000 itself (s6-setuidgid). The claims stay group-writable.
        security_context {
          fs_group = var.gid
        }

        # Kubernetes injects a Service's coordinates as <SVCNAME>_PORT for every service in the
        # namespace, and this app's own settings all start with PAPERLESS_: the `paperless`
        # Service would arrive as PAPERLESS_PORT=tcp://... and break the webserver's port.
        enable_service_links = false

        init_container {
          name    = "trash-dir"
          image   = "${var.image}:${var.image_tag}"
          command = ["sh", "-c", "mkdir -p /data/trash"]

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }

        container {
          name  = var.name
          image = "${var.image}:${var.image_tag}"

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.config.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.config.metadata[0].name
            }
          }

          port {
            name           = "http"
            container_port = var.port
          }

          dynamic "port" {
            for_each = var.flower_enabled ? [1] : []

            content {
              name           = "flower"
              container_port = var.flower_port
            }
          }

          readiness_probe {
            http_get {
              path = "/accounts/login/"
              port = "http"

              # The kubelet reaches the pod by IP, and ALLOWED_HOSTS is the public name.
              http_header {
                name  = "Host"
                value = var.hostname
              }
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 12
          }

          liveness_probe {
            http_get {
              path = "/accounts/login/"
              port = "http"

              http_header {
                name  = "Host"
                value = var.hostname
              }
            }
            initial_delay_seconds = 120
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          # OCR is the CPU-heavy part and shares the pod with the web server and its workers.
          resources {
            requests = {
              cpu    = "250m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "2"
              memory = "3Gi"
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/usr/src/paperless/data"
          }

          volume_mount {
            name       = "media"
            mount_path = "/usr/src/paperless/media"
          }

          volume_mount {
            name       = "consume"
            mount_path = "/usr/src/paperless/consume"
          }
        }

        volume {
          name = "data"

          persistent_volume_claim {
            claim_name = var.data_pvc
          }
        }

        volume {
          name = "media"

          persistent_volume_claim {
            claim_name = var.media_pvc
          }
        }

        volume {
          name = "consume"

          persistent_volume_claim {
            claim_name = var.consume_pvc
          }
        }
      }
    }
  }
}
