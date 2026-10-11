resource "kubernetes_deployment_v1" "connector" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = 1

    # The connector holds its MCP clients in memory, so a rolling update would orphan every
    # session TypingMind is holding. One pod, replaced.
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
          "checksum/secret" = sha256(var.auth_token)
        }
      }

      spec {
        # This pod runs MCP servers chosen elsewhere; it gets no API credentials at all.
        automount_service_account_token = false

        # Nothing here needs privilege: the connector is a Go binary, and any stdio
        # server it spawns only needs the writable cache mounted at /tmp below.
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          run_as_group    = 1000
          fs_group        = 1000
        }

        container {
          name              = var.name
          image             = "${var.image}:${var.image_tag}"
          image_pull_policy = "IfNotPresent"

          # No command or args: the image entrypoint is the connector itself, and
          # it binds 0.0.0.0 rather than HOSTNAME -- Kubernetes sets HOSTNAME to
          # the pod name, a name only resolvable through the kubelet's hosts file.
          #
          # HOME and the npm cache are not for the connector; they are for stdio
          # servers, which remain `npx` style commands this container spawns.
          env {
            name  = "HOME"
            value = "/tmp"
          }
          env {
            name  = "npm_config_cache"
            value = "/tmp/.npm"
          }
          env {
            name  = "PORT"
            value = tostring(var.port)
          }
          env {
            name  = "TIMEOUT"
            value = tostring(var.timeout_ms)
          }
          env {
            name = "MCP_AUTH_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.auth.metadata[0].name
                key  = "MCP_AUTH_TOKEN"
              }
            }
          }

          port {
            name           = "http"
            container_port = var.port
          }

          # TCP, not /ping: every connector route is bearer-gated, so a headerless probe would
          # read 401 and the pod would never go Ready.
          readiness_probe {
            tcp_socket {
              port = "http"
            }

            initial_delay_seconds = 20
            period_seconds        = 10
          }

          liveness_probe {
            tcp_socket {
              port = "http"
            }

            initial_delay_seconds = 60
            period_seconds        = 30
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          security_context {
            read_only_root_filesystem  = true
            allow_privilege_escalation = false

            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp"

          empty_dir {}
        }
      }
    }
  }
}
