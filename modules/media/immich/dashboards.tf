resource "kubernetes_config_map_v1" "dashboard" {
  count = var.metrics_enabled ? 1 : 0

  metadata {
    name      = "${var.name}-dashboard"
    namespace = var.namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "${var.name}.json" = file("${path.module}/dashboards/immich.json")
  }
}
