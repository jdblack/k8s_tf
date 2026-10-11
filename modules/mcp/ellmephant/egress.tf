# The mcp namespace's baseline egress governs this pod too (it excludes only the connector), so
# this adds the one direction the server needs beyond it: the Hub, for the embedding weights.
# `allow_internet` is 0.0.0.0/0 minus the LAN, so the pod still cannot reach internal services.
module "egress_internet" {
  source = "../../network/firewalls/policy"

  count        = var.allow_internet ? 1 : 0
  direction    = "egress"
  namespace    = var.namespace
  name         = "${var.name}-internet-egress"
  pod_selector = local.selector_labels

  allow_internet = true
}
