# The room's baseline. Same idiom as `mcp`: everything in the namespace may talk to everything in it
# (the hand and the brain ARE the same self), DNS and the apiserver come with the module, and the
# INTERNET is granted per workload — the hand keeps its own policy, so the baseline excludes it.
module "egress_baseline" {
  source    = "../../network/firewalls/policy"
  direction = "egress"

  namespace      = kubernetes_namespace_v1.room.metadata[0].name
  name           = "${var.name}-baseline-egress"
  allow_internet = false

  pod_selector_expressions = [{
    key      = "app.kubernetes.io/name"
    operator = "NotIn"
    values   = ["${var.name}-hand"]
  }]
}

# Baseline admit: the namespace talks to itself and the controller reaches every pod. Node IPs come
# with the module, so probes and CNI health checks survive the default-deny.
#
# ★ NAMED `-baseline-ingress`, NOT `<name>-ingress`: the brain's own ingress policy already takes
# `<name>-ingress` (it is the rule that admits the gateway on the MCP port). Two policies in one
# namespace cannot share a name, and the collision only surfaced in the first FULL apply — a targeted
# apply of the room alone would have looked clean and failed later.
module "ingress_baseline" {
  source    = "../../network/firewalls/policy"
  direction = "ingress"

  namespace = kubernetes_namespace_v1.room.metadata[0].name
  name      = "${var.name}-baseline-ingress"
}
