# The Longhorn chart ships its own NetworkPolicies (networkPolicies.enabled).
# The longhorn-manager DaemonSet also carries the admission-webhook and
# recovery-backend labels, so the manager pods are selected by THREE chart
# policies (longhorn-manager, longhorn-webhook, longhorn-recovery-backend)
# whose union admits only Longhorn's own components. Prometheus -- via the
# chart's longhorn-prometheus-servicemonitor, which scrapes
# app=longhorn-manager on TCP 9500 -- then hits the end-of-tier deny (visible
# in Whisker/Goldmane as monitoring -> longhorn-system:9500 Deny). Chart
# netpols can't be extended from values, so union in the monitoring namespace
# here (Kubernetes NetworkPolicies are additive).
module "firewall_metrics" {
  source = "../network/firewalls/policy"

  name         = "longhorn-manager-metrics"
  namespace    = var.longhorn_namespace
  pod_selector = { "app" = "longhorn-manager" }
  policy_types = ["Ingress"]

  ingress_rules = [{
    peers = [{ namespace_selector = { "kubernetes.io/metadata.name" = "monitoring" } }]
    ports = [{ protocol = "TCP", port = 9500 }]
  }]

  depends_on = [kubernetes_namespace_v1.longhorn]
}
