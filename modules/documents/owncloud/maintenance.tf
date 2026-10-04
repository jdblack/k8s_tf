# The chart ships this purge as a CronJob that mounts the ReadWriteOnce metadata claim, so a run
# on the wrong node dies on Multi-Attach and, under the chart's hardcoded Forbid, then blocks
# every later run. Exec'ing into the pod that already holds the claim keeps the purge off the
# volume: this job only ever talks to the API server.

resource "kubernetes_service_account_v1" "trash_purge" {
  metadata {
    name      = local.trash_purge
    namespace = var.namespace
    labels    = local.trash_purge_labels
  }
}

# Just the verbs kubectl exec needs to resolve storageusers and open the exec.
resource "kubernetes_role_v1" "trash_purge" {
  metadata {
    name      = local.trash_purge
    namespace = var.namespace
    labels    = local.trash_purge_labels
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create"]
  }

  # A Deployment's pods have generated names, so only the Deployment can be pinned by name.
  rule {
    api_groups     = ["apps"]
    resources      = ["deployments"]
    resource_names = ["storageusers"]
    verbs          = ["get"]
  }
}

resource "kubernetes_role_binding_v1" "trash_purge" {
  metadata {
    name      = local.trash_purge
    namespace = var.namespace
    labels    = local.trash_purge_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.trash_purge.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.trash_purge.metadata[0].name
    namespace = var.namespace
  }
}

# DNS and the API server only; the baseline is told to skip this pod so nothing else leaks in.
module "trash_purge_egress" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace       = var.namespace
  name            = "${local.trash_purge}-egress"
  pod_selector    = local.trash_purge_labels
  allow_namespace = false
  allow_k8s_api   = true
}

# Hand-rolled: the policy helper always leaves the node IPs admitted, and nothing connects in.
resource "kubernetes_network_policy_v1" "trash_purge" {
  metadata {
    name      = "${local.trash_purge}-ingress"
    namespace = var.namespace
    labels    = local.trash_purge_labels
  }

  spec {
    pod_selector {
      match_labels = local.trash_purge_labels
    }

    policy_types = ["Ingress"]
  }
}

resource "kubernetes_cron_job_v1" "trash_purge" {
  metadata {
    name      = local.trash_purge
    namespace = var.namespace
    labels    = local.trash_purge_labels
  }

  spec {
    schedule                      = var.trash_purge_schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {
        labels = local.trash_purge_labels
      }

      spec {
        # Bound a run that cannot reach the pod, so it fails instead of holding Forbid forever.
        active_deadline_seconds    = var.trash_purge_deadline
        backoff_limit              = 1
        ttl_seconds_after_finished = 86400

        template {
          metadata {
            labels = local.trash_purge_labels
          }

          spec {
            restart_policy       = "Never"
            service_account_name = kubernetes_service_account_v1.trash_purge.metadata[0].name

            security_context {
              run_as_non_root = true
              run_as_user     = 65534
              run_as_group    = 65534

              seccomp_profile {
                type = "RuntimeDefault"
              }
            }

            container {
              name    = "purge"
              image   = "${var.kubectl_image}:${var.kubectl_image_tag}"
              command = ["kubectl"]

              # The chart's disabled job, minus the mount; the target pod's own env is the config.
              args = [
                "-n", var.namespace,
                "exec", "deploy/storageusers",
                "-c", "storageusers",
                "--",
                "ocis", "storage-users", "trash-bin", "purge-expired",
              ]

              # kubectl caches discovery under $HOME, which the read-only root filesystem denies.
              env {
                name  = "HOME"
                value = "/tmp"
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

  depends_on = [helm_release.ocis]
}
