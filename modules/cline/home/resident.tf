# The resident Cline: a Cline that lives in this namespace and remembers via `mempal`.
# OFF by default (`enable_resident`) -- it needs the DeepSeek credential as a Secret first, and
# creating that Secret is a HUMAN-GATED step (never copy a key without James's ok). Recon + image:
# see home note `notes/2026-10-14-resident-cline-recon.md` and memory `todo-cline-pod`.
resource "kubernetes_deployment_v1" "resident" {
  count = var.enable_resident ? 1 : 0

  metadata {
    name      = "resident-cline"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.resident_labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.resident_labels
    }

    template {
      metadata {
        labels = local.resident_labels
      }

      spec {
        # A subPath file mount needs its parent dir to exist first.
        init_container {
          name    = "mk-settings"
          image   = var.resident_image
          command = ["sh", "-c", "mkdir -p /home/node/.cline/data/settings"]

          volume_mount {
            name       = "cline-data"
            mount_path = "/home/node/.cline"
          }
        }

        container {
          name  = "cline"
          image = var.resident_image

          resources {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { cpu = "1", memory = "1Gi" }
          }

          env {
            name  = "HOME"
            value = "/home/node"
          }

          # The model credential, from a Secret created OUT OF BAND (human-gated).
          env {
            name = "DEEPSEEK_API_KEY"

            value_from {
              secret_key_ref {
                name = "resident-cline"
                key  = "deepSeekApiKey"
              }
            }
          }

          volume_mount {
            name       = "cline-data"
            mount_path = "/home/node/.cline"
          }

          # Its own MCP config: remember through `mempal`, not the shared ellmephant.
          volume_mount {
            name       = "mcp-config"
            mount_path = "/home/node/.cline/data/settings/cline_mcp_settings.json"
            sub_path   = "cline_mcp_settings.json"
          }

          # Prove the image first; the resident loop itself is a later decision.
          command = ["sh", "-c", "cline --version && sleep infinity"]
        }

        volume {
          name = "cline-data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.scratch.metadata[0].name
          }
        }

        volume {
          name = "mcp-config"

          config_map {
            name = kubernetes_config_map_v1.resident_mcp[0].metadata[0].name
          }
        }
      }
    }
  }
}

# The resident's MCP config. Points at `mempal` (in-cluster), NOT the shared ellmephant gateway.
resource "kubernetes_config_map_v1" "resident_mcp" {
  count = var.enable_resident ? 1 : 0

  metadata {
    name      = "resident-cline-mcp"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.resident_labels
  }

  data = {
    "cline_mcp_settings.json" = jsonencode({
      mcpServers = {
        mempal = {
          transport = {
            type = "streamableHttp"
            url  = "http://mempal:8888/mcp"
          }
        }
      }
    })
  }
}
