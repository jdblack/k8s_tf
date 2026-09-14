# Ingress firewall: accept connections only from the listed namespaces and
# source CIDRs, drop everything else. `namespace_only` is just this with
# allowed_ingress_namespaces = [var.namespace].
#
# Gateway-fronted namespaces must list kube-network (the data plane that
# proxies to them), plus monitoring if Prometheus scrapes them. Sources reached
# directly from outside the cluster (LAN clients, peers hitting a LoadBalancer,
# traffic SNAT'd to a node IP) are never pods, so they go in the CIDR list.
#
# Rendering is delegated to the shared `policy` module (see ../policy); the
# `moved` block migrates the old inline resource with no destroy/create.
locals {
  # One ingress rule with the namespace + CIDR peers. Emitted only when at
  # least one guest is configured: an ingress rule with NO peers means "allow
  # from anywhere", so empty lists must render deny-all instead.
  ingresses = length(var.allowed_ingress_namespaces) > 0 || length(var.allowed_ingress_cidrs) > 0 ? [{
    peers = concat(
      [for ns in toset(var.allowed_ingress_namespaces) : {
        namespace_selector = { "kubernetes.io/metadata.name" = ns }
      }],
      # Non-pod sources: LoadBalancer clients, or node-sourced traffic after
      # kube-proxy SNAT. `except` subtracts the cluster's own ranges so those
      # stay denied while the rest of the CIDR is allowed.
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

moved {
  from = kubernetes_network_policy_v1.limit_ingresses
  to   = module.policy.kubernetes_network_policy_v1.this
}
