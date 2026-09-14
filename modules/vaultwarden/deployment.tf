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

        # Roll the pod when the config changes: k8s does not restart pods for a
        # Secret update, so a SIGNUPS_ALLOWED flip would otherwise appear to do
        # nothing. The whole configuration lives in that Secret, so this is the
        # only checksum needed.
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

# The vault itself: SQLite DB, attachments, RSA keys.
#
# Both labels are required. `recurring-job.longhorn.io/source: enabled` is the
# opt-in that makes this PVC a "recurring job label source"; without it Longhorn
# ignores the group label and keeps the VOLUME's labels as truth, so the
# RecurringJob in backup.tf would never fire. Note the value is "enabled"
# (types.LonghornLabelValueEnabled in longhorn-manager) -- Longhorn's own
# enhancement doc says "enable", which is silently ignored.
#
# Owning the PVC ourselves (rather than letting a chart create it) is one reason
# this module is hand-rolled.
resource "kubernetes_persistent_volume_claim_v1" "data" {
  metadata {
    name      = local.data_pvc_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      "recurring-job.longhorn.io/source"                        = "enabled"
      "recurring-job-group.longhorn.io/${local.snapshot_group}" = "enabled"
    }
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
