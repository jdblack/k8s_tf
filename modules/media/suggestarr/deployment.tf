resource "kubernetes_deployment_v1" "suggestarr" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = var.name
    }
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        "app.kubernetes.io/name" = var.name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = var.name
        }

        annotations = {
          "backup.velero.io/backup-volumes" = local.config_pvc
        }
      }

      spec {
        security_context {
          run_as_user            = 1000
          run_as_group           = 1000
          run_as_non_root        = true
          fs_group               = 1000
          fs_group_change_policy = "OnRootMismatch"
        }

        container {
          name              = var.name
          image             = "${var.image}:${var.image_tag}"
          image_pull_policy = "IfNotPresent"

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            seccomp_profile {
              type = "RuntimeDefault"
            }
          }

          env {
            name  = "SUGGESTARR_PORT"
            value = var.web_port
          }
          env {
            name  = "LOG_LEVEL"
            value = "INFO"
          }

          env {
            name  = "AUTH_MODE"
            value = "trusted_header"
          }
          env {
            name  = "AUTH_TRUSTED_HEADER"
            value = var.auth_trusted_header
          }
          env {
            name  = "AUTH_TRUSTED_CIDRS"
            value = local.auth_trusted_cidrs
          }

          env {
            name  = "AUTH_TRUSTED_HEADER_AUTO_CREATE"
            value = "true"
          }
          env {
            name  = "ALLOW_REGISTRATION"
            value = "false"
          }

          port {
            name           = "webui"
            container_port = var.web_port
          }

          volume_mount {
            name       = local.config_pvc
            mount_path = local.config_dir
          }
        }

        volume {
          name = local.config_pvc
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "config" {
  metadata {
    name      = local.config_pvc
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = var.config_size
      }
    }

    storage_class_name = "longhorn"
  }
}
