# Placeholder Grafana OIDC secret. Grafana's $__file{} expander hard-fails when
# the referenced file is MISSING (verified on 13.2.1-distroless: the container
# exits), so the Secret OBJECT must exist before the helm upgrade waits on the
# pod -- hence core creating it, since mantle (which writes the real
# credentials) runs later. Without `ignore_changes = [data]` every core apply
# would see mantle's credentials, call it drift and blank them back.
resource "random_uuid" "grafana_oidc_client_id" {}

resource "random_password" "grafana_oidc_client_secret" {
  length  = 40
  special = false
}

resource "kubernetes_secret_v1" "grafana_oidc" {
  metadata {
    name      = "${var.grafana_name}-oidc"
    namespace = var.namespace
  }
  data = {
    client_id     = random_uuid.grafana_oidc_client_id.result
    client_secret = random_password.grafana_oidc_client_secret.result
  }

  lifecycle {
    # `data`: mantle owns the real credentials, so core must never plan a diff
    # on it. `wait_for_service_account_token` is a provider-3.x default the
    # imported object predates -- ignoring it avoids an in-place update, which
    # would re-send core's stale `data` over mantle's.
    ignore_changes = [data, wait_for_service_account_token]
  }
}
