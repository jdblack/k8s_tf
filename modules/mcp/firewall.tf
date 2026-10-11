module "egress_baseline" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace      = kubernetes_namespace_v1.namespace.metadata[0].name
  name           = "mcp-baseline-egress"
  allow_internet = false

  # NotIn, so the connector keeps its own internet egress instead of inheriting this one.
  pod_selector_expressions = [{
    key      = "app.kubernetes.io/name"
    operator = "NotIn"
    values   = [local.connector]
  }]
}

# Baseline admit: the namespace talks to itself and the controller reaches every pod. Node IPs
# come with the module, so kubelet probes and CNI health checks survive the default-deny.
module "ingress_baseline" {
  source    = "../network/firewalls/policy"
  direction = "ingress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "mcp-ingress"
}
