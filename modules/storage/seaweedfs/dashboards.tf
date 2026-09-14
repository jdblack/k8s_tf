# SeaweedFS Grafana dashboard: a ConfigMap in this namespace that Grafana finds
# cluster-wide (the chart's sidecar watches every namespace for
# `grafana_dashboard: "1"` and hot-loads the data keys -- see README.md,
# "Dashboards"). Coupling to know: narrowing that sidecar to its own namespace
# makes this disappear silently. Grafana keys provisioned dashboards off `uid`,
# so re-applying updates in place; dashboards/seaweedfs.json is the source of
# truth (paste Grafana's export straight back over it).
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
