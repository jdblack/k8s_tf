
resource kubernetes_deployment_v1 deployment {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = var.name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"    = var.name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = var.name
        }
      }

      spec {
        container {
          name  = var.name
          image = "${local.image.repository}/${local.image.tag}"
          image_pull_policy = "Always"

          port {
            name = "webui"
            container_port = 8265
          }
          port {
            name = "server"
            container_port = 8266
          }
          volume_mount {
            mount_path = "/media"
            name = var.movies_pvc
          }
        }

        volume {
          name = var.movies_pvc

          persistent_volume_claim {
            claim_name = var.movies_pvc
          }
        }

      }
    }
  }
}

