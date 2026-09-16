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

# Egress: this namespace only -- longhorn-manager <-> instance-manager gRPC, engine replica
# proxies, csi-plugin/attacher/provisioner/resizer/snapshotter -> manager and API -- plus
# cluster DNS. Nothing outbound beyond that: no internet (the upgrade checker is off in
# longhorn.tf) and no other namespace. The chart ships Ingress-only policies, so this is the
# namespace's first egress restriction.
module "firewall_egress" {
  source           = "../network/firewalls/basic_egress"
  namespace        = var.longhorn_namespace
  allow_namespaces = [var.longhorn_namespace]
  allow_k8s_api    = true

  # This module is called under a module-level `depends_on` (stacks/core/core.tf), which
  # defers the firewall's own endpoints read -- see basic_egress/variables.tf.
  api_peer_ips = var.api_peer_ips

  depends_on = [kubernetes_namespace_v1.longhorn]
}
