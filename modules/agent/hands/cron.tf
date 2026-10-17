# THE ROSTER. A CronJob is a BELL, nothing more: it runs `bin/hands --activity <name>`, whose
# predicate costs nothing, so a bell with no grounds spends nothing. The activities themselves live in
# CODE (`ACTIVITIES` in bin/hands) — never in the store, because an activity declared in data would be
# a prompt with extra steps and nothing arbitrary may ever be dispatched.
resource "kubernetes_cron_job_v1" "activity" {
  for_each = var.activities

  metadata {
    name      = "${var.name}-${each.key}"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    schedule = each.value.schedule
    suspend  = each.value.suspend

    # A bell that fires while the previous one is still running must not stack up. (For one self this
    # is also the mutual exclusion the store claim enforces across hands.)
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 1
    starting_deadline_seconds     = 300

    job_template {
      metadata {
        labels = local.labels
      }

      spec {
        backoff_limit = 0 # a missed bell is not worth retrying; the next one is coming

        # LONGER than the finger's own budget (`-t 3600` + 120s grace), or the pod dies mid-thought
        # and takes the finger's conclusions with it. The finger must always be the first to stop.
        active_deadline_seconds = 3900

        template {
          metadata {
            labels = local.labels
          }

          spec {
            restart_policy = "Never"

            security_context {
              fs_group = 1000
            }

            container {
              name    = "bell"
              image   = "${var.image_repository}:${var.image_tag}"
              command = ["/home/node/cline-home/bin/hands", "--activity", each.key]

              resources {
                requests = { cpu = var.cpu_request, memory = var.memory_request }
                limits   = { memory = var.memory_limit }
              }

              env {
                name  = "HOME"
                value = "/home/node"
              }

              env {
                name  = "CLINE_HOME"
                value = "/home/node/cline-home"
              }

              env {
                name  = "ELLMEPHANT_URL"
                value = var.brain_url
              }

              env {
                name  = "ELLMEPHANT_HEALTH_URL"
                value = local.health_url
              }

              # ★ A BELL ASKS THE MAILBOX TOO, and it is the FIRST thing it does — the predicate has to
              # read `unread_mail` before it can decide whether to spend a finger. Pointing that at the
              # public name made every tick answer "COULD NOT ASK", which is a predicate that can never
              # be satisfied: autonomy silently stops, and the log says nothing is wrong.
              env {
                name  = "MAIL_URL"
                value = local.brain_root
              }

              env {
                name  = "MAIL_ME"
                value = local.mail_me
              }

              env {
                name = "DEEPSEEK_API_KEY"

                value_from {
                  secret_key_ref {
                    name = var.secret_name
                    key  = var.model_key_field
                  }
                }
              }

              # ★ A BELL MUST PROVE ITSELF TOO. The CronJobs write as the same self: without the pair
              # a scheduled activity banks, mails and claims as `anonymous`, and its leases are refused.
              dynamic "env" {
                for_each = var.identity == "" ? [] : [var.identity]

                content {
                  name  = "ELLMEPHANT_IDENTITY"
                  value = env.value
                }
              }

              dynamic "env" {
                for_each = var.identity == "" ? [] : [1]

                content {
                  name = "ELLMEPHANT_IDENTITY_SECRET"

                  value_from {
                    secret_key_ref {
                      name = var.secret_name
                      key  = var.identity_secret_field
                    }
                  }
                }
              }

              volume_mount {
                name       = "mcp-config"
                mount_path = "/home/node/.cline/hands/settings/cline_mcp_settings.json"
                sub_path   = "cline_mcp_settings.json"
              }

              # ★ NO HOME MOUNT HERE, ON PURPOSE. A bell is an ephemeral job: it runs the IMAGE's
              # `bin/` and talks to the brain over HTTP. If a bell needed the self's files, it would
              # make the home multi-reader — which is exactly the constraint that put an S3 gateway in
              # the boot path. A bell that needs the home is a bell that should not be ephemeral.
              volume_mount {
                name       = "ephemeral"
                mount_path = "/home/node/cline-home/.tmp"
              }

              volume_mount {
                name       = "ephemeral"
                mount_path = "/home/node/.cline/hands/logs"
              }

              volume_mount {
                name       = "ephemeral"
                mount_path = "/home/node/.cline/hands/sessions"
              }

              volume_mount {
                name       = "ephemeral"
                mount_path = "/home/node/.cline/hands/db"
              }
            }

            volume {
              name = "mcp-config"

              config_map {
                name = kubernetes_config_map_v1.mcp.metadata[0].name
              }
            }

            volume {
              name = "ephemeral"

              empty_dir {
                medium     = "Memory"
                size_limit = "512Mi"
              }
            }
          }
        }
      }
    }
  }
}
