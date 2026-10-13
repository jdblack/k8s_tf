resource "kubernetes_deployment_v1" "hello" {
  metadata {
    name      = "cline-hello"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.hello_labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.hello_labels
    }

    template {
      metadata {
        labels = local.hello_labels
      }

      spec {
        container {
          name  = "web"
          image = var.hello_image

          # Explicit requests/limits so the quota always sees a well-formed pod.
          resources {
            requests = { cpu = "50m", memory = "128Mi" }
            limits   = { cpu = "250m", memory = "256Mi" }
          }

          port {
            name           = "http"
            container_port = 80
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "http"
            }

            initial_delay_seconds = 3
            period_seconds        = 10
          }

          volume_mount {
            name       = "page"
            mount_path = "/usr/share/nginx/html"
            read_only  = true
          }
        }

        volume {
          name = "page"

          config_map {
            name = kubernetes_config_map_v1.hello_page.metadata[0].name
          }
        }
      }
    }
  }
}
