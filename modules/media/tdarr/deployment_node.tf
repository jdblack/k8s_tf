
resource kubernetes_deployment_v1 deployment_node {
  metadata {
    name      = var.name_node
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = var.name_node
    }
  }

  spec {
    replicas = 6

    selector {
      match_labels = {
        "app.kubernetes.io/name"    = var.name_node
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = var.name_node
        }
      }

      spec {
        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_labels = {
                  "app.kubernetes.io/name" = var.name
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }


        container {
          name  = var.name_node
          image = "${local.node.image.repository}:${local.node.image.tag}"
          image_pull_policy = "Always"

          env {
            name = "serverIP"
            value = "tdarr"
          }
          env {
            name = "serverPort"
            value = 8266
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


