# Egress: cluster DNS + the public internet, nothing else. Vaultwarden fetches
# icons/CDN assets and (if push were ever enabled) talks to bitwarden.com; it
# has no business reaching the Kubernetes API or any other in-cluster service.
module "firewall" {
  source = "../network/firewalls/basic_internet"

  namespace         = kubernetes_namespace_v1.this.metadata[0].name
  allow_to_services = false
  allow_to_k8sapi   = false
}

# Ingress: same namespace + the gateway data plane, and NO CIDRs.
#
# Unlike media there is no LoadBalancer here, so the gateway is the only path
# in: every other pod in the cluster is denied, and so is the LAN reaching a pod
# directly (there is nothing to reach). The gateway proxies from kube-network.
module "firewall_ingress" {
  source = "../network/firewalls/limited_ingress"

  namespace = kubernetes_namespace_v1.this.metadata[0].name
  # module.firewall above (basic_internet) already owns "namespace-firewall" in
  # this namespace; NetworkPolicy names are per-namespace.
  policy_name = "namespace-ingress"

  allowed_ingress_namespaces = [
    var.namespace,
    var.gateway_namespace,
  ]
}
