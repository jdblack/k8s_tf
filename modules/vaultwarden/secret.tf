# Vaultwarden's entire configuration, in Terraform rather than an admin panel:
# there is deliberately NO ADMIN_TOKEN, and leaving it unset disables /admin
# outright (verified: it 404s). Nothing to configure in a panel means nothing to
# attack there, and no admin token to leak or rotate.
#
# Values are strings (Kubernetes Secrets are byte maps). All checked against the
# 1.37.3 .env template; note PROMETHEUS_ENABLED no longer exists (metrics support
# was dropped upstream) -- see the module README.
resource "kubernetes_secret_v1" "config" {
  metadata {
    name      = "${var.name}-config"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    # Cookies, attachment URLs and the websocket URL are all built from this, so
    # it must be the exact URL clients use.
    DOMAIN      = "https://${local.fqdn}"
    DATA_FOLDER = "/data"

    # Keep the app's listen port and the Service/container port in step.
    ROCKET_PORT = tostring(var.port)

    # Websocket notifications (live sync between clients) on the same port.
    ENABLE_WEBSOCKET = "true"

    # No self-service anything. Mail is off, so invitations and password hints are
    # moot; Sends and emergency access are off. Tightening these also removes
    # unauthenticated endpoints anyone who can resolve the host could reach.
    #
    # signups_allowed is a BOOTSTRAP knob: vaultwarden has no CLI user-create, so
    # the first account is made by temporarily flipping it on (see the README's
    # first-run bootstrap note), registering in the web vault, then flipping back.
    SIGNUPS_ALLOWED = tostring(var.signups_allowed)

    INVITATIONS_ALLOWED      = "false"
    SENDS_ALLOWED            = "false"
    PASSWORD_HINTS_ALLOWED   = "false"
    EMERGENCY_ACCESS_ALLOWED = "false"

    # Brute-force brake on /identity/connect/token. Traffic arrives from the
    # gateway data plane and NGF sets X-Real-IP (vaultwarden's default IP_HEADER),
    # so the limit is per client rather than per gateway.
    LOGIN_RATELIMIT_SECONDS   = "60"
    LOGIN_RATELIMIT_MAX_BURST = "10"
  }
}
