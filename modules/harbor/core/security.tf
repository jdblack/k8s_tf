# Egress: same-ns + DNS + internet + the kube-network gateways (harbor-core calls the
# Authentik OIDC issuer at auth.<domain>, which terminates at the private gateway). No
# k8s API. Node image pulls are host traffic, so they are unaffected by this policy.
module "firewall" {
  source    = "../../network/firewalls/basic_egress"
  namespace = var.namespace
  # kube-network first: that order is what the pre-rename policy rendered.
  allow_namespaces = ["kube-network", var.namespace]
  allow_internet   = true

  depends_on = [kubernetes_namespace_v1.namespace]
}
