resource "kubernetes_secret_v1" "grafana_oidc" {
  metadata {
    name      = "${var.grafana_name}-oidc"
    namespace = var.namespace
  }

  data = {
    client_id     = "unset"
    client_secret = "unset"
  }

  lifecycle {
    ignore_changes = [data, wait_for_service_account_token]
  }
}
