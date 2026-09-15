# The Grafana OIDC Secret OBJECT, created in core so that it (and the $__file{} mount
# Grafana hard-fails without) exists before the helm release waits on the pod --
# mantle, which writes the real credentials, applies later. `ignore_changes = [data]`
# leaves those values alone.
resource "kubernetes_secret_v1" "grafana_oidc" {
  metadata {
    name      = "${var.grafana_name}-oidc"
    namespace = var.namespace
  }

  # Placeholders, not secrets: the mount has to resolve to a file before mantle's
  # credentials arrive.
  data = {
    client_id     = "unset"
    client_secret = "unset"
  }

  lifecycle {
    # `wait_for_service_account_token` is a provider-3.x default the imported object
    # predates -- ignoring it avoids an in-place update, which would re-send core's
    # stale `data` over mantle's.
    ignore_changes = [data, wait_for_service_account_token]
  }
}
