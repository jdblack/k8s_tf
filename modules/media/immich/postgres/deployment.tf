# Hand-rolled because no stock chart carries the VectorChord extension Immich requires.
resource "kubernetes_deployment_v1" "postgres" {
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
          "backup.velero.io/backup-volumes" = "data"
        }
      }

      spec {
        security_context {
          run_as_user  = var.uid
          run_as_group = var.gid
          fs_group     = var.gid
        }

        container {
          name  = "postgres"
          image = "${var.image}:${var.image_tag}"

          env {
            name  = "POSTGRES_USER"
            value = var.user
          }
          env {
            name  = "POSTGRES_DB"
            value = var.user
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres.metadata[0].name
                key  = "password"
              }
            }
          }
          # initdb refuses a non-empty data dir, and a longhorn volume root has lost+found.
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }
          env {
            name  = "POSTGRES_INITDB_ARGS"
            value = "--data-checksums"
          }

          port {
            name           = "postgres"
            container_port = var.port
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-q", "-U", var.user]
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-q", "-U", var.user]
            }
            initial_delay_seconds = 30
            period_seconds        = 20
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }

          # VectorChord index maintenance wants more shm than the 64Mi default.
          volume_mount {
            name       = "shm"
            mount_path = "/dev/shm"
          }
        }

        volume {
          name = "data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.postgres.metadata[0].name
          }
        }

        volume {
          name = "shm"

          empty_dir {
            medium     = "Memory"
            size_limit = var.shm_size
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "postgres" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.size
      }
    }
  }
}
