resource "kubernetes_secret_v1" "api_keys" {
  metadata {
    name      = "${var.name}-api-keys"
    namespace = var.namespace
  }

  data = {
    SONARR_API_KEY = var.sonarr_api_key
    RADARR_API_KEY = var.radarr_api_key
  }
}

resource "kubernetes_deployment_v1" "unpackerr" {
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
          "checksum/config" = sha256(jsonencode(kubernetes_secret_v1.api_keys.data))
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
            name  = "UN_SONARR_0_URL"
            value = var.sonarr_url
          }
          env {
            name = "UN_SONARR_0_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.api_keys.metadata[0].name
                key  = "SONARR_API_KEY"
              }
            }
          }
          env {
            name  = "UN_SONARR_0_PATHS_0"
            value = local.downloads_path
          }

          env {
            name  = "UN_RADARR_0_URL"
            value = var.radarr_url
          }
          env {
            name = "UN_RADARR_0_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.api_keys.metadata[0].name
                key  = "RADARR_API_KEY"
              }
            }
          }
          env {
            name  = "UN_RADARR_0_PATHS_0"
            value = local.downloads_path
          }

          volume_mount {
            name       = "media"
            mount_path = var.mount_path
          }
        }

        volume {
          name = "media"
          persistent_volume_claim {
            claim_name = var.movies_pvc
          }
        }
      }
    }
  }
}
