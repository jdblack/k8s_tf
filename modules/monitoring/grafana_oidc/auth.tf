# Authentik OIDC client for Grafana's SSO, plus the secret data the grafana.ini
# `$__file{}` references resolve to.
#
# In mantle (the only stack with the authentik provider) while Grafana is in
# core: core owns the release + grafana.ini and only *references* this secret by
# name, so neither stack can drag the other into a diff.
module "auth" {
  source       = "../../auth/authentik/oidc_provider"
  name         = var.name
  redirect_uri = "https://${var.name}.${var.domain}/login/generic_oauth"

  # Bookmark tile (dashboard-icons via jsDelivr -- no dependency on Grafana's
  # build-hashed asset path) + open in a new tab.
  meta_icon       = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/grafana.svg"
  open_in_new_tab = true
}

# The Secret OBJECT is created by core (see modules/monitoring/prometheus/
# grafana.tf) so Grafana's $__file{} mount always resolves -- Grafana refuses to
# start when the file is missing. Because core owns the object, this resource
# must not manage it: it patches only the data, and core's
# `ignore_changes = [data]` keeps it from reverting these credentials.
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

# Grafana reads grafana.ini (and its $__file{} refs) only at startup, so bounce
# the pod on credential change. Deleting pods rather than `rollout restart`
# leaves the Deployment untouched -- a rollout would stamp an annotation on it
# that core's helm release would then fight over.
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
