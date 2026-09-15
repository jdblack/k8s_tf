# ConfigMap Grafana finds cluster-wide: the chart's sidecar watches every
# namespace for `grafana_dashboard: "1"`, so narrowing that sidecar to its own
# namespace makes this disappear silently.
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
