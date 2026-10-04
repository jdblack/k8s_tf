# SeaweedFS stores the app data as S3 buckets; the CSI driver has no snapshot capability, so the
# offsite copy is an S3 -> B2 mirror. Movies is the big, slow-moving one, hence the weekly slot.

locals {
  # Weekly, one bucket per day so the three uploads never contend; deadline caps a hung run.
  offsite_buckets = {
    "owncloud-storage" = { schedule = "0 2 * * 0", deadline = 86400 }
    "photos"           = { schedule = "0 2 * * 3", deadline = 172800 }
    "movies-archive"   = { schedule = "0 2 * * 6", deadline = 518400 }
  }

  offsite_labels = { "app.kubernetes.io/name" = "offsite-backup" }
}

# A read-only identity per bucket, so one leaked key cannot read the others.
module "offsite_source" {
  for_each = local.offsite_buckets
  source   = "../seaweedfs/s3_user"

  user      = "offsite-${each.key}"
  bucket    = each.key
  role      = "readonly"
  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
}

# The destination key, kept apart from the per-bucket source keys.
resource "kubernetes_secret_v1" "offsite_dest" {
  type = "Opaque"

  metadata {
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
    name      = "offsite-b2"
  }

  data = {
    accessKey = var.buckets_access_key
    secretKey = var.buckets_secret_key
  }
}

# Plain mirror: sync makes the destination match the bucket. With the bucket set to keep only the
# last version, B2 holds a single copy -- so a delete on the source deletes on B2 too.
resource "kubernetes_cron_job_v1" "offsite" {
  for_each = local.offsite_buckets

  metadata {
    name      = "offsite-${each.key}"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
    labels    = local.offsite_labels
  }

  spec {
    schedule                      = each.value.schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {
        labels = local.offsite_labels
      }

      spec {
        active_deadline_seconds    = each.value.deadline
        backoff_limit              = 1
        ttl_seconds_after_finished = 86400

        template {
          metadata {
            labels = local.offsite_labels
          }

          spec {
            restart_policy = "Never"

            security_context {
              run_as_non_root = true
              run_as_user     = 65534
              run_as_group    = 65534

              seccomp_profile {
                type = "RuntimeDefault"
              }
            }

            container {
              name  = "rclone"
              image = var.rclone_image

              args = [
                "sync",
                "src:${each.key}",
                "dst:${var.buckets_dest_bucket}/${each.key}",
                "--create-empty-src-dirs",
                # The bucket is made out-of-band and the key has no writeBuckets, so never try.
                "--s3-no-check-bucket",
                "--transfers", "8",
                "--checkers", "16",
                "--log-level", "INFO",
              ]

              # rclone caches under $HOME; the read-only root filesystem only allows /tmp.
              env {
                name  = "HOME"
                value = "/tmp"
              }

              # Config comes entirely from the RCLONE_CONFIG_* vars below, so no conf file.
              env {
                name  = "RCLONE_CONFIG"
                value = "/tmp/rclone.conf"
              }

              env {
                name  = "RCLONE_CONFIG_SRC_TYPE"
                value = "s3"
              }
              env {
                name  = "RCLONE_CONFIG_SRC_PROVIDER"
                value = "Other"
              }
              env {
                name  = "RCLONE_CONFIG_SRC_ENDPOINT"
                value = var.endpoint
              }
              env {
                name  = "RCLONE_CONFIG_SRC_REGION"
                value = var.region
              }
              env {
                name  = "RCLONE_CONFIG_SRC_FORCE_PATH_STYLE"
                value = "true"
              }
              env {
                name = "RCLONE_CONFIG_SRC_ACCESS_KEY_ID"
                value_from {
                  secret_key_ref {
                    name = module.offsite_source[each.key].secret_name
                    key  = "accessKey"
                  }
                }
              }
              env {
                name = "RCLONE_CONFIG_SRC_SECRET_ACCESS_KEY"
                value_from {
                  secret_key_ref {
                    name = module.offsite_source[each.key].secret_name
                    key  = "secretKey"
                  }
                }
              }

              env {
                name  = "RCLONE_CONFIG_DST_TYPE"
                value = "s3"
              }
              env {
                name  = "RCLONE_CONFIG_DST_PROVIDER"
                value = "Other"
              }
              env {
                name  = "RCLONE_CONFIG_DST_ENDPOINT"
                value = var.buckets_endpoint
              }
              env {
                name  = "RCLONE_CONFIG_DST_REGION"
                value = var.buckets_region
              }
              env {
                name  = "RCLONE_CONFIG_DST_FORCE_PATH_STYLE"
                value = "true"
              }
              env {
                name = "RCLONE_CONFIG_DST_ACCESS_KEY_ID"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.offsite_dest.metadata[0].name
                    key  = "accessKey"
                  }
                }
              }
              env {
                name = "RCLONE_CONFIG_DST_SECRET_ACCESS_KEY"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.offsite_dest.metadata[0].name
                    key  = "secretKey"
                  }
                }
              }

              resources {
                requests = {
                  cpu    = "100m"
                  memory = "128Mi"
                }
                limits = {
                  memory = "1Gi"
                }
              }

              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = true

                capabilities {
                  drop = ["ALL"]
                }
              }

              volume_mount {
                name       = "tmp"
                mount_path = "/tmp"
              }
            }

            volume {
              name = "tmp"

              empty_dir {}
            }
          }
        }
      }
    }
  }
}
