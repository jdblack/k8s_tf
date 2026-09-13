# The SeaweedFS Grafana dashboard.
#
# Same shape as the ServiceMonitor above: the object lives in this namespace and
# the consumer finds it cluster-wide. kube-prometheus-stack's
# `grafana-sc-dashboard` sidecar watches EVERY namespace for ConfigMaps labelled
# `grafana_dashboard: "1"` (live env: LABEL=grafana_dashboard / LABEL_VALUE=1 /
# RESOURCE=both / NAMESPACE=ALL), copies each data key into Grafana's provisioner
# directory (/tmp/dashboards), then POSTs the provisioning-reload API. So no
# Grafana provider and no cross-namespace write is needed here -- a labelled
# ConfigMap in our own namespace shows up in Grafana within seconds.
#
# The one coupling worth knowing: if that sidecar is ever narrowed to its own
# namespace (`NAMESPACE: monitoring`), this dashboard quietly disappears. Either
# keep the sidecar cluster-wide, or move this ConfigMap into `monitoring`.
#
# Grafana keys provisioned dashboards off their `uid` (seaweedfs-overview), so
# re-applying replaces the panel set in place instead of piling up duplicates,
# and the JSON next to this file is the single source of truth -- paste the output
# of Grafana's "Export -> copy JSON" straight back over it.
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
