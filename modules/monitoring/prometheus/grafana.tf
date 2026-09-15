# The OIDC Secret OBJECT, created in core so that it (and the $__file{} mount Grafana
# hard-fails without) exists before the helm release waits on the pod -- mantle, which
# writes the real credentials, applies later. `ignore_changes = [data]` leaves them alone.
resource "kubernetes_secret_v1" "grafana_oidc" {
  metadata {
    name      = "${var.grafana_name}-oidc"
    namespace = var.namespace
  }

  # Placeholders, not secrets: the mount has to resolve before mantle's values arrive.
  data = {
    client_id     = "unset"
    client_secret = "unset"
  }

  lifecycle {
    # `wait_for_service_account_token` is a provider-3.x default the imported object
    # predates; ignoring it avoids an in-place update re-sending core's stale `data`.
    ignore_changes = [data, wait_for_service_account_token]
  }
}
