# Egress: cluster DNS only. No internet -- the favicon/icon proxy is the only thing that ever
# dialled out (mobile and desktop clients fetch their own icons; the web vault falls back),
# and nothing else in here has business beyond the namespace. No API, no other service.
module "firewall" {
  source    = "../network/firewalls/basic_egress"
  namespace = kubernetes_namespace_v1.this.metadata[0].name

  allow_namespaces = [kubernetes_namespace_v1.this.metadata[0].name]
}

# Ingress: same namespace + the gateway data plane, and NO CIDRs -- there is no
# LoadBalancer here, so the gateway is the only path in.
module "firewall_ingress" {
  source = "../network/firewalls/limited_ingress"

  namespace = kubernetes_namespace_v1.this.metadata[0].name
  # basic_egress above already owns "namespace-firewall"; NetPol names are per-namespace.
  policy_name = "namespace-ingress"

  allowed_ingress_namespaces = [
    var.namespace,
    var.gateway_namespace,
  ]
}
