resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = 1

    # RWO volume holding the SQLite DB: a rolling update would deadlock waiting
    # for the old pod to release it, so take the pod down and back up.
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels

        # redeploy if the config changes
        annotations = {
          "checksum/config" = sha256(jsonencode(kubernetes_secret_v1.config.data))
        }
      }

      spec {
        container {
          name  = var.name
          image = "${var.image}:${var.image_tag}"

          # The whole configuration (see secret.tf).
          env_from {
            secret_ref {
              name = kubernetes_secret_v1.config.metadata[0].name
            }
          }

          port {
            name           = "http"
            container_port = var.port
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }

        volume {
          name = "data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "data" {
  metadata {
    name      = local.data_pvc_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    # Deliberately unlabelled: Longhorn snapshot enrolment is cluster policy and
    # lives on the Volume CR (modules/storage/snapshot_labeler.tf). A recurring
    # job label here would REPLACE the volume's whole group set instead of
    # merging with it.
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}
