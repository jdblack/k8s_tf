resource "kubernetes_secret_v1" "grafana_oidc" {
  metadata {
    name      = "${var.grafana_name}-oidc"
    namespace = var.namespace
  }

  data = {
    client_id     = "unset"
    client_secret = "unset"
  }

  # grafana_oidc owns `data`; this resource only creates the Secret first.
  lifecycle {
    ignore_changes = [data, wait_for_service_account_token]
  }
}
