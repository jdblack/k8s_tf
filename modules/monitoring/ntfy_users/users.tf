locals {
  # One `ntfy access` line per grant, spliced into the in-pod script below. The
  # indentation is cosmetic (shells ignore it).
  grants = {
    for username, cfg in var.users :
    username => join("\n        ", [for g in cfg.access : "ntfy access ${username} ${g.topic} ${g.permission}"])
  }
}

# One terraform_data per user, so the lifecycle maps cleanly onto ntfy:
#   create/replace -> idempotent provision
#   destroy        -> remove the user (dropping it from tfvars really deletes it)
#
# `triggers_replace` is the guard that keeps this a create-time action: a
# provisioner on terraform_data runs on create and on replace, never on a
# steady-state apply. So an ordinary `tofu apply` never touches the server.
#
# Everything else idempotent comes from the CLIs themselves, not from a check:
#   --ignore-exists      : no-op when the user already exists
#   change-pass/-role    : idempotent setters, so a rotated password in tfvars
#                          actually lands (--ignore-exists alone would skip it)
#   ntfy access --reset  : wipes that user's grants first, so a grant REMOVED
#                          from tfvars really disappears (grants would otherwise
#                          accumulate; `ntfy access` upserts one at a time)
resource "terraform_data" "user" {
  for_each = var.users

  triggers_replace = {
    username     = each.key
    namespace    = var.namespace
    release_name = var.release_name
    role         = each.value.role
    access       = jsonencode(each.value.access)
    # A hash, not the password: a rotation re-runs the provisioner without
    # keeping a second cleartext copy of the secret in this resource's state.
    password = nonsensitive(sha256(random_password.this[each.key].result))
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      # The CLI edits /data/user.db directly (no admin credential needed -- it is
      # the server's own tool), but the pod has to exist first.
      kubectl -n ${var.namespace} rollout status deploy/${var.release_name} --timeout=90s

      # Read the password from the Secret created above and pipe it into the
      # pod's stdin, where it is read into a shell variable. The plaintext never
      # appears in kubectl's argv, in ps, or in the API audit log.
      PW="$(kubectl -n ${var.namespace} get secret ${kubernetes_secret_v1.users[0].metadata[0].name} -o go-template='{{index .data "${each.key}" | base64decode}}')"
      printf '%s\n' "$PW" | kubectl -n ${var.namespace} exec -i deploy/${var.release_name} -- sh -eu -c '
        read -r PW
        NTFY_PASSWORD="$PW" ntfy user add --ignore-exists --role=${each.value.role} ${each.key}
        NTFY_PASSWORD="$PW" ntfy user change-pass ${each.key}
        ntfy user change-role ${each.key} ${each.value.role}
        ntfy access --reset ${each.key}
        ${local.grants[each.key]}
      '
    EOT
  }

  # Best effort: on a full teardown the pod (and namespace) are already gone, and
  # a failing destroy-time provisioner would fail `tofu destroy` itself.
  provisioner "local-exec" {
    when    = destroy
    command = "kubectl -n ${self.triggers_replace.namespace} exec deploy/${self.triggers_replace.release_name} -- ntfy user remove ${self.triggers_replace.username} || true"
  }
}
