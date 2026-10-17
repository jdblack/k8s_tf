locals {
  fqdn       = coalesce(var.hostname, "${var.name}.${var.domain}")
  labels     = { "app.kubernetes.io/name" = var.name, "app.kubernetes.io/part-of" = "agent" }
  health_url = coalesce(one([for u in [var.brain_health_url] : u if u != ""]), replace(var.brain_url, "/mcp", "/health"))
}

# The finger's MCP config: the SAME store as the hand, reached in-namespace. One brain per room is the
# whole point of the move; a config pointing at another namespace would undo it quietly.
resource "kubernetes_config_map_v1" "mcp" {
  metadata {
    name      = "${var.name}-mcp"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    "cline_mcp_settings.json" = jsonencode({
      mcpServers = { ellmephant = { transport = { type = "streamableHttp", url = var.brain_url } } }
    })
  }
}

resource "kubernetes_service_v1" "door" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    type     = "ClusterIP"
    selector = local.labels

    port {
      name        = "door"
      port        = 80
      target_port = "door"
    }
  }
}

resource "kubernetes_deployment_v1" "hand" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    # ONE, serial by design: one hand, one data dir, one hub port. The cross-machine serialization is
    # the store claim; the local lock is the same-machine fast path.
    replicas = 1

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        security_context {
          fs_group = 1000
        }

        container {
          name  = "door"
          image = "${var.image_repository}:${var.image_tag}"

          # A moving tag + IfNotPresent is a restart that silently runs the old build.
          image_pull_policy = "Always"

          resources {
            requests = { cpu = var.cpu_request, memory = var.memory_request }
            limits   = { memory = var.memory_limit }
          }

          port {
            name           = "door"
            container_port = var.port
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = "door"
            }

            initial_delay_seconds = 3
            period_seconds        = 10
          }

          env {
            name  = "HOME"
            value = "/home/node"
          }

          env {
            name  = "CLINE_HOME"
            value = "/home/node/cline-home"
          }

          env {
            name  = "HANDS_DOOR_PORT"
            value = tostring(var.port)
          }

          # ★ bin/store and bin/hands read the store from THIS, not from the MCP config. Without it a
          # hand in a new room banks and claims against the old one — which is exactly the split-brain
          # the move exists to avoid.
          env {
            name  = "ELLMEPHANT_URL"
            value = var.brain_url
          }

          env {
            name  = "ELLMEPHANT_HEALTH_URL"
            value = local.health_url
          }

          env {
            name = "DEEPSEEK_API_KEY"

            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = var.model_key_field
              }
            }
          }

          env {
            name = "HANDS_DOOR_TOKEN"

            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = var.door_token_field
              }
            }
          }

          volume_mount {
            name       = "mcp-config"
            mount_path = "/home/node/.cline/hands/settings/cline_mcp_settings.json"
            sub_path   = "cline_mcp_settings.json"
          }

          # Transcripts, logs and sessions live in RAM: they die with the pod and never touch a volume.
          volume_mount {
            name       = "ephemeral"
            mount_path = "/home/node/cline-home/.tmp"
          }

          volume_mount {
            name       = "ephemeral"
            mount_path = "/home/node/.cline/hands/logs"
          }

          volume_mount {
            name       = "ephemeral"
            mount_path = "/home/node/.cline/hands/sessions"
          }

          volume_mount {
            name       = "ephemeral"
            mount_path = "/home/node/.cline/hands/db"
          }
        }

        volume {
          name = "mcp-config"

          config_map {
            name = kubernetes_config_map_v1.mcp.metadata[0].name
          }
        }

        volume {
          name = "ephemeral"

          empty_dir {
            medium     = "Memory"
            size_limit = "512Mi"
          }
        }
      }
    }
  }
}
