resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = 1

    # The data volume is ReadWriteOnce and holds the SQLite DB. A rolling update
    # would deadlock waiting for the old pod to release the volume, so take the
    # pod down and back up instead. (Same reason qbittorrent's PVC is RWO and
    # the app is single-replica.)
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
# Two labels, both required:
#   - recurring-job.longhorn.io/source: enabled  -- the OPT-IN that makes this
#     PVC a "recurring job label source" for its volume. Without it Longhorn
#     keeps the VOLUME's labels as the source of truth and IGNORES the group
#     label below (verified: the volume came up with only
#     recurring-job-group.longhorn.io/default, so the RecurringJob in backup.tf
#     would never have fired).
#     NOTE the value is "enabled", matching types.LonghornLabelValueEnabled in
#     longhorn-manager (hasRecurringJobSourceLabel compares against it).
#     Longhorn's own enhancement doc (20230517-set-recurring-job-to-pvc.md)
#     says "enable" -- that value is silently ignored (the volume controller
#     just debug-logs "Ignoring recurring job labels ... missing source label").
#   - recurring-job-group.longhorn.io/<group>: enabled  -- the group membership,
#     which Longhorn then syncs onto the volume so the job's spec.groups match.
#
# Owning the PVC (rather than letting a chart create it) is one reason this
# module is hand-rolled.
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
