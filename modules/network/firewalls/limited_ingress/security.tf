# Ingress firewall: accept only the listed namespaces and source CIDRs. Sources reached
# from outside the cluster (LAN clients, peers hitting a LoadBalancer, node-SNAT'd
# traffic) are never pods, so they go in the CIDR list.
#
# Gateway-fronted namespaces must list kube-network, plus monitoring if scraped.
locals {
  # Only emitted when a guest is configured: an ingress rule with NO peers means "allow
  # from anywhere", so empty lists must render deny-all.
  ingresses = length(var.allowed_ingress_namespaces) > 0 || length(var.allowed_ingress_cidrs) > 0 ? [{
    peers = concat(
      [for ns in toset(var.allowed_ingress_namespaces) : {
        namespace_selector = { "kubernetes.io/metadata.name" = ns }
      }],
      # Clients outside the cluster: `except` subtracts the cluster's own ranges.
      [for c in var.allowed_ingress_cidrs : {
        ip_block = merge({ cidr = c.cidr }, length(c.except) > 0 ? { except = c.except } : {})
      }],
    )
  }] : []
}

module "policy" {
  source        = "../policy"
  name          = var.policy_name
  namespace     = var.namespace
  pod_selector  = var.pod_selector
  policy_types  = ["Ingress"]
  ingress_rules = local.ingresses
}
