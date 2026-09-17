# The chart ships its own ingress policies for this namespace: six of them, rendered by
# `networkPolicies.restrictInternalTraffic` (chart default true, and nothing here overrides it). They
# select by `longhorn.io/component=…` / `app=longhorn-manager`, i.e. **only the pods they name** -- the
# four `csi-*` sidecars, `longhorn-csi-plugin`, `longhorn-driver-deployer`, the `engine-image-ei-*` pods
# and the snapshot Jobs are selected by nothing and sat on the namespace's default-allow. The
# namespace-wide curtain below is what closes them.
#
# Read the chart's two shapes before assuming what it gives (live, 2026-09-17): `longhorn-webhook` is
# `from` **omitted** on TCP 9501/9502, i.e. from anything, which is what admits the apiserver and the
# kubelet's `/v1/healthz` probe on `:9502`; `longhorn-manager` and `instance-manager` are `from`
# **podSelectors with no namespaceSelector**, i.e. this namespace only, and a short list of them --
# manager, ui, csi-plugin, the recurring-job and `longhorn.io/job-task` pods. So `namespaces` here
# means "the pods the chart listed", never "the namespace", and the curtain's self rule genuinely adds:
# it widens those two to any pod in `longhorn-system` on any port (upstream's own list omits, for one,
# `csi-plugin -> instance-manager`, which the CSI node plugin needs). Confined to the namespace, and the
# module's default for exactly this reason (`../network/firewalls/ingress/README.md`).
#
# `networkPolicies.enabled` is the chart's other gate and renders only the ui-frontend policy -- absent
# because longhornUI.replicas is 0, which is why the count is six and not seven.
#
# Live evidence, 2026-09-17: the only cross-namespace inbound peer this namespace has is Prometheus on
# `longhorn-manager:9500` (Whisker `dest_namespace=longhorn-system`, keep-alive scrape included via
# `up`), the `longhorn-prometheus-servicemonitor` selects `app=longhorn-manager` and no other Service,
# and no pod here is hostNetwork -- so every pod in the namespace is subject to pod policy, including the
# host's own iSCSI initiator, which arrives as a node address and is what the node floor is for.

# Namespace-wide, floor only: own namespace plus the node addresses, nothing else. `pod_selector` omitted
# on purpose -- the leftovers are exactly the pods a pod-scoped call would have to enumerate, and "per-pod
# closing is not namespace closing" (`../network/firewalls/README.md`).
module "ingress_longhorn_system" {
  source = "../network/firewalls/ingress"

  namespace = var.longhorn_namespace
  name      = "longhorn-system-ingress"
}

# Calico policies only union, so this call can open a door and never close one. The curtain above is not
# that door: it renders the self and node rules, and Prometheus is neither. It is the same shape as the
# `:9327` peer in ingress.tf, and the reason it is written down is that the scrape reads `up` today off a
# connection opened before the chart policies landed, and a connection that never ends is never emitted
# into the flow log. The next reconnect is a deny, i.e. six targets down with no other symptom.
#
# `pod_selector` is the pod that owns :9500 rather than the namespace, because the chart's mesh rules
# already cover everything else and the rest of this namespace has no outside guest. `allow_namespace`
# and `allow_nodes` are off for the same reason -- the chart allows the in-namespace peers, and its
# webhook policy (from: any, TCP 9501/9502) is what admits the node paths, including the kubelet's
# /v1/healthz probe on :9502 that keeps these pods Ready. The curtain above is what supplies those two
# rules now, so this call is only the scrape. Constraint: if `restrictInternalTraffic` is ever set false,
# the chart's policies vanish and the curtain's floor becomes the namespace's only authority -- fine for
# these pods, and the switches stay off on purpose.
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
