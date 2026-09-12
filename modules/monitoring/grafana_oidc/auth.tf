# Authentik OIDC client for Grafana's SSO, and the secret holding the client
# credentials that the grafana.ini `$__file{}` references resolve to.
#
# This lives in the mantle stack (the only stack with the authentik provider
# configured) while Grafana itself is deployed by the core stack. The split is
# clean: core owns the Grafana release + grafana.ini and only *references* this
# secret by name; nothing here writes anything core owns, so neither stack can
# drag the other into a diff.
module "auth" {
  source       = "../../auth/authentik/oidc_provider"
  name         = var.name
  redirect_uri = "https://${var.name}.${var.domain}/login/generic_oauth"

  # Bookmark tile (dashboard-icons via jsDelivr -- versionless, doesn't depend on
  # Grafana's own build-hashed asset path) + open in a new tab.
  meta_icon       = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/grafana.svg"
  open_in_new_tab = true
}

# The Secret OBJECT is created by the core stack (see
# modules/monitoring/prometheus/grafana.tf) so that Grafana's $__file{} mount
# always resolves -- Grafana refuses to start when the file is missing. Because
# the object lives in the core stack's state, this resource must NOT manage it:
# it patches only the data. core's `ignore_changes = [data]` keeps it from
# reverting these credentials, so neither stack drifts against the other.
resource "kubernetes_secret_v1_data" "oidc" {
  metadata {
    name      = "${var.name}-oidc"
    namespace = var.namespace
  }
  data = {
    client_id     = module.auth.client_id
    client_secret = module.auth.client_secret
  }
}

# Grafana resolves grafana.ini (and its $__file{} references) only at startup,
# so bounce the pod when the credentials change. Deleting pods rather than
# `rollout restart` leaves the Deployment untouched -- a rollout would stamp an
# annotation on it that the core stack's helm release would then fight over.
#
# triggers_replace is a hash, so steady-state applies are a no-op (no restart)
# and the secret value never lands in state in the clear.
resource "terraform_data" "reload" {
  triggers_replace = nonsensitive(sha256("${module.auth.client_id}:${module.auth.client_secret}"))

  provisioner "local-exec" {
    command = "kubectl -n ${var.namespace} delete pod -l app.kubernetes.io/name=${var.name} --ignore-not-found"
  }

  depends_on = [kubernetes_secret_v1_data.oidc]
}
