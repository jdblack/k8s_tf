# The chart ships its own ingress policies for this namespace: six of them, rendered by
# `networkPolicies.restrictInternalTraffic` (chart default true, and nothing here overrides it).
# `longhorn-manager` admits in-namespace peers on every port and *nothing else*, so `longhorn-system`
# is default-deny inbound and Prometheus was simply never a guest. `networkPolicies.enabled` is the
# chart's other gate and renders only the ui-frontend policy -- absent here because longhornUI.replicas
# is 0, which is why the count is six and not seven. Calico policies only union, so this call can open a
# door and never close one. It is the same shape as the `:9327` peer in ingress.tf: the scrape reads `up`
# today off a connection opened before the chart policies landed, and a connection that never ends is
# never emitted into the flow log. The next reconnect is a deny, i.e. six targets down with no other
# symptom.

# `pod_selector` is the pod that owns :9500 rather than the namespace, because the chart's mesh rules
# already cover everything else and the rest of this namespace has no outside guest. `allow_namespace`
# and `allow_nodes` are off for the same reason -- the chart allows the in-namespace peers, and its
# webhook policy (from: any, TCP 9501/9502) is what admits the node paths, including the kubelet's
# /v1/healthz probe on :9502 that keeps these pods Ready. Constraint: if `restrictInternalTraffic` is
# ever set false, both switches have to come back on -- it takes the webhook allow with it, and an
# unqualified deny would then take every manager pod NotReady.
module "ingress_longhorn_manager_metrics" {
  source = "../network/firewalls/ingress"

  namespace = var.longhorn_namespace
  name      = "longhorn-manager-metrics-ingress"

  pod_selector    = { "app" = "longhorn-manager" }
  allow_namespace = false
  allow_nodes     = false

  from_peers = [
    {
      namespace    = var.monitoring_namespace
      pod_selector = { "app.kubernetes.io/name" = "prometheus" }
      ports        = [{ port = 9500 }]
    },
  ]
}
