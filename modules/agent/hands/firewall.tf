# The model API is the only thing a hand needs OUTSIDE its own room: the brain is a same-namespace
# ClusterIP, so the baseline egress already covers it. `allow_internet` is 0.0.0.0/0 minus the LAN,
# so the pod still cannot reach internal services or the cluster API's VIPs.
module "egress_internet" {
  source = "../../network/firewalls/policy"

  direction      = "egress"
  namespace      = var.namespace
  name           = "${var.name}-internet-egress"
  pod_selector   = local.labels
  allow_internet = true
}
