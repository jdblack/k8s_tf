locals {
  # Render order is part of the rendered spec, so it is also part of every plan diff: any
  # reordering here rewrites every policy built on this module. Keep it: namespaces, DNS,
  # API, internet, CIDRs.
  #
  # DNS is unconditional -- it is the floor a namespace needs to resolve anything at all.
  egresses = concat(
    local.egress.to_namespaces,
    [local.egress.to_dns],
    var.allow_k8s_api ? [local.egress.to_k8s_api] : [],
    var.allow_internet ? [local.egress.to_internet] : [],
    local.egress.to_cidrs,
  )
}

module "policy" {
  source       = "../policy"
  name         = var.policy_name
  namespace    = var.namespace
  pod_selector = var.pod_selector
  policy_types = ["Egress"]
  egress_rules = local.egresses
}
