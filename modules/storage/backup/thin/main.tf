resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }
}

# Read the chains, ask for deletions; the velero controller does the deleting.
resource "kubernetes_role_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  rule {
    api_groups = ["velero.io"]
    resources  = ["backups"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["velero.io"]
    resources  = ["deletebackuprequests"]
    verbs      = ["create", "get", "list"]
  }
}

resource "kubernetes_role_binding_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.this.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.this.metadata[0].name
    namespace = var.namespace
  }
}

resource "kubernetes_config_map_v1" "script" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  data = {
    "thin.sh" = file("${path.module}/thin.sh")
  }
}

resource "kubernetes_cron_job_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    schedule                      = var.schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 3

    job_template {
      metadata {}
      spec {
        backoff_limit              = 1
        ttl_seconds_after_finished = 86400

        template {
          metadata {}

          spec {
            service_account_name = kubernetes_service_account_v1.this.metadata[0].name
            restart_policy       = "Never"

            container {
              name    = "thin"
              image   = var.image
              command = ["/bin/sh", "/scripts/thin.sh"]

              env {
                name  = "VELERO_NAMESPACE"
                value = var.namespace
              }

              env {
                name  = "DRY_RUN"
                value = tostring(var.dry_run)
              }

              env {
                name  = "MAX_DELETIONS"
                value = tostring(var.max_deletions)
              }

              volume_mount {
                name       = "script"
                mount_path = "/scripts"
                read_only  = true
              }
            }

            volume {
              name = "script"

              config_map {
                name         = kubernetes_config_map_v1.script.metadata[0].name
                default_mode = "0755"
              }
            }
          }
        }
      }
    }
  }
}
