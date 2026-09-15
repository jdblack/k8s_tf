# The chart ships its own NetworkPolicies, which admit only Longhorn's own components, so
# Prometheus scraping app=longhorn-manager:9500 through the chart's ServiceMonitor hits the
# end-of-tier deny. Netpols can't be extended from chart values, so union in the monitoring
# namespace here (NetworkPolicies are additive).
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
