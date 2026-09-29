# The broker queue is disposable: a restart can lose an in-flight task, and the file it was
# chewing on is still in the consume directory waiting to be picked up again.
resource "kubernetes_deployment_v1" "valkey" {
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
      }

      spec {
        security_context {
          run_as_user  = var.uid
          run_as_group = var.gid
          fs_group     = var.gid
        }

        container {
          name  = "valkey"
          image = "${var.image}:${var.image_tag}"

          port {
            name           = "valkey"
            container_port = var.port
          }

          readiness_probe {
            exec {
              command = ["valkey-cli", "ping"]
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 3
            failure_threshold     = 6
          }

          liveness_probe {
            exec {
              command = ["valkey-cli", "ping"]
            }
            initial_delay_seconds = 15
            period_seconds        = 20
            timeout_seconds       = 3
            failure_threshold     = 6
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }

        volume {
          name = "data"

          empty_dir {}
        }
      }
    }
  }
}
