resource "kubernetes_config_map_v1" "dashboard" {
  metadata {
    name      = "${var.name}-dashboard"
    namespace = var.namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "seaweedfs.json" = file("${path.module}/dashboards/seaweedfs.json")
  }
}
