resource "kubernetes_secret_v1" "config" {
  metadata {
    name      = "${var.name}-config"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    DOMAIN      = "https://${local.fqdn}"
    DATA_FOLDER = "/data"

    ROCKET_PORT = tostring(var.port)

    ENABLE_WEBSOCKET = "true"

    SIGNUPS_ALLOWED = tostring(var.signups_allowed)

    INVITATIONS_ALLOWED      = "false"
    SENDS_ALLOWED            = "false"
    PASSWORD_HINTS_ALLOWED   = "false"
    EMERGENCY_ACCESS_ALLOWED = "false"

    LOGIN_RATELIMIT_SECONDS   = "60"
    LOGIN_RATELIMIT_MAX_BURST = "10"
  }
}
