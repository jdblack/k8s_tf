# Vaultwarden's whole configuration, in Terraform rather than an admin panel: ADMIN_TOKEN unset
# disables /admin outright.
resource "kubernetes_secret_v1" "config" {
  metadata {
    name      = "${var.name}-config"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    # Cookies, attachment and websocket URLs are built from this: it must be the URL clients use.
    DOMAIN      = "https://${local.fqdn}"
    DATA_FOLDER = "/data"

    ROCKET_PORT = tostring(var.port)

    ENABLE_WEBSOCKET = "true"

    # No self-service: mail is off, so invitations and hints are moot. SIGNUPS_ALLOWED is a BOOTSTRAP
    # knob -- vaultwarden has no CLI user-create, so flip on, register, flip back.
    SIGNUPS_ALLOWED = tostring(var.signups_allowed)

    INVITATIONS_ALLOWED      = "false"
    SENDS_ALLOWED            = "false"
    PASSWORD_HINTS_ALLOWED   = "false"
    EMERGENCY_ACCESS_ALLOWED = "false"

    # NGF sets X-Real-IP (vaultwarden's default IP_HEADER), so this is per client.
    LOGIN_RATELIMIT_SECONDS   = "60"
    LOGIN_RATELIMIT_MAX_BURST = "10"
  }
}
