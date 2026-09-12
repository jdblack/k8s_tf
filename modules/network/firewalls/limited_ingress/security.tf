# Ingress firewall: pods in this namespace accept connections only from the
# listed namespaces and source CIDRs. Everything else is dropped.
#
# This is the "namespace_only" posture with a guest list: same-namespace-only
# is just allowed_ingress_namespaces = [var.namespace]. It is the natural
# profile for anything served through the shared kube-network gateways, which
# must appear in the list (e.g. ["kube-storage", "kube-network"] for
# gateway-fronted storage) plus "monitoring" if Prometheus scrapes it.
#
# Services reached directly from OUTSIDE the cluster via a LoadBalancer (LAN
# clients, node/host traffic) can never match a namespaceSelector -- their
# source is not a pod -- so those sources are allowed via allowed_ingress_cidrs
# (typically the LAN CIDR, which also covers node IPs).
#
# Rendering is delegated to the shared `policy` module (see ../policy). The
# `moved` block migrates the inline resource into the submodule with no
# destroy/create.
locals {
  # One ingress rule: the namespace peers + the CIDR peers. An ingress rule
  # with NO peers would mean "allow from anywhere", so emit the rule only when
  # at least one guest is configured -- both lists empty = deny all ingress
  # (nothing to allow, default-deny applies).
  ingresses = length(var.allowed_ingress_namespaces) > 0 || length(var.allowed_ingress_cidrs) > 0 ? [{
    peers = concat(
      [for ns in toset(var.allowed_ingress_namespaces) : {
        namespace_selector = { "kubernetes.io/metadata.name" = ns }
      }],
      # Non-pod sources (LAN clients, internet clients/peers hitting a
      # LoadBalancer, or the node hosting the packet after kube-proxy SNAT).
      # ip_block peers match the packet's source IP regardless of whether it is
      # a workload; `except` subtracts the cluster's own ranges so those
      # sources stay denied while the rest of the CIDR is allowed.
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
