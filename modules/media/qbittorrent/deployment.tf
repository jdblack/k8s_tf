resource "kubernetes_deployment_v1" "qbittorrent" {
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
          "backup.velero.io/backup-volumes" = local.app_data_name
        }
      }

      spec {
        container {
          name              = var.name
          image             = "${var.image}:${var.image_tag}"
          image_pull_policy = "IfNotPresent"

          env {
            name  = "PUID"
            value = 1000
          }
          env {
            name  = "PGID"
            value = 1000
          }

          port {
            name           = "webui"
            container_port = var.web_port
          }
          port {
            name           = "torrent"
            container_port = var.torrent_port
          }

          volume_mount {
            name       = local.app_data_name
            mount_path = "/config"
          }

          volume_mount {
            name       = var.movies_pvc
            mount_path = "/downloads"
          }
        }

        # Follow the Plex anchor node (shares its node-local SeaweedFS cache) and stay
        # off the controller node.
        affinity {
          pod_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_labels = { "movies-archive" = "anchor" }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "kubernetes.io/hostname"
                  operator = "NotIn"
                  values   = ["k8smaster"]
                }
              }
            }
          }
        }

        volume {
          name = local.app_data_name
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.app_data.metadata[0].name
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

resource "kubernetes_persistent_volume_claim_v1" "app_data" {
  metadata {
    name      = "${var.name}-data"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }

    storage_class_name = "longhorn"
  }
}
