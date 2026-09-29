resource "kubernetes_deployment_v1" "ollama" {
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

        # `ollama pull` talks to a running server, so this starts one, waits for it, pulls, and
        # exits. Every later boot finds the blobs already on the claim and re-pulls nothing.
        init_container {
          name    = "pull"
          image   = "${var.image}:${var.image_tag}"
          command = ["sh", "-c", "ollama serve & pid=$!; until ollama list >/dev/null 2>&1; do sleep 1; done; ${local.pulls}; kill $pid"]

          env {
            name  = "HOME"
            value = local.models_dir
          }

          env {
            name  = "OLLAMA_MODELS"
            value = local.models_dir
          }

          volume_mount {
            name       = "models"
            mount_path = local.models_dir
          }
        }

        container {
          name  = "ollama"
          image = "${var.image}:${var.image_tag}"

          # The server binds loopback unless told otherwise, and the image's default CMD is
          # already `ollama serve`.
          env {
            name  = "OLLAMA_HOST"
            value = "0.0.0.0:${var.port}"
          }

          env {
            name  = "HOME"
            value = local.models_dir
          }

          env {
            name  = "OLLAMA_MODELS"
            value = local.models_dir
          }

          env {
            name  = "OLLAMA_KEEP_ALIVE"
            value = var.keep_alive
          }

          env {
            name  = "OLLAMA_MAX_LOADED_MODELS"
            value = tostring(var.max_loaded_models)
          }

          env {
            name  = "OLLAMA_NUM_PARALLEL"
            value = tostring(var.num_parallel)
          }

          port {
            name           = "http"
            container_port = var.port
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "http"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 12
          }

          liveness_probe {
            http_get {
              path = "/"
              port = "http"
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          volume_mount {
            name       = "models"
            mount_path = local.models_dir
          }
        }

        volume {
          name = "models"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.models.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "models" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.models_size
      }
    }
  }
}
