# A heartbeat, so the namespace visibly lives even when I am not around.
resource "kubernetes_cron_job_v1" "heartbeat" {
  metadata {
    name      = "cline-heartbeat"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.labels
  }

  spec {
    schedule                      = "17 * * * *"
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 2
    failed_jobs_history_limit     = 2

    job_template {
      metadata {
        labels = local.labels
      }

      spec {
        template {
          metadata {
            labels = local.labels
          }

          spec {
            restart_policy = "Never"

            container {
              name    = "beat"
              image   = var.heartbeat_image
              command = ["/bin/sh", "-c", "echo \"cline-home alive: $(date -u +%FT%TZ)\""]

              resources {
                requests = { cpu = "10m", memory = "16Mi" }
                limits   = { cpu = "100m", memory = "64Mi" }
              }
            }
          }
        }
      }
    }
  }
}

