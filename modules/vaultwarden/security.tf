# Egress: cluster DNS + the public internet, nothing else. Vaultwarden fetches icons/CDN
# assets and has no business reaching the API or any other in-cluster service.
module "firewall" {
  source = "../network/firewalls/basic_internet"

  namespace         = kubernetes_namespace_v1.this.metadata[0].name
  allow_to_services = false
  allow_to_k8sapi   = false
}

# Ingress: same namespace + the gateway data plane, and NO CIDRs -- there is no
# LoadBalancer here, so the gateway is the only path in.
module "firewall_ingress" {
  source = "../network/firewalls/limited_ingress"

  namespace = kubernetes_namespace_v1.this.metadata[0].name
  # basic_internet above already owns "namespace-firewall"; NetPol names are per-namespace.
  policy_name = "namespace-ingress"

  allowed_ingress_namespaces = [
    var.namespace,
    var.gateway_namespace,
  ]
}
