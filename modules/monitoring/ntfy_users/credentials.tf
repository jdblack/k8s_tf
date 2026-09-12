# One generated password per human user.
#
# Deliberately a plaintext password in a Secret rather than a bcrypt hash fed to
# the CLI via NTFY_PASSWORD_HASH: the CLI's plaintext path (NTFY_PASSWORD) lets
# ntfy do the bcrypting with its own cost, and the user actually needs the
# *password* -- ntfy never stores it, so this Secret is the only place it can be
# read from (for the web UI, or to configure the phone).
resource "random_password" "this" {
  for_each = var.users

  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "users" {
  # No users configured -> create nothing (an empty Secret would be noise).
  count = length(var.users) > 0 ? 1 : 0

  metadata {
    name      = var.secret_name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "ntfy"
      "app.kubernetes.io/component" = "user-credentials"
    }
  }

  data = {
    for username, _ in var.users : username => random_password.this[username].result
  }
}
