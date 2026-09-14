
# Egress: same-ns + DNS + internet + the kube-network gateways (harbor-core
# calls the Authentik OIDC issuer at auth.<domain>, which terminates at the
# private gateway). No k8s API. Node image pulls are host traffic, so they are
# unaffected by this policy.
module "firewall" {
  source            = "../../network/firewalls/basic_internet"
  namespace         = var.namespace
  allow_to_services = true

  depends_on = [kubernetes_namespace_v1.namespace]
}
