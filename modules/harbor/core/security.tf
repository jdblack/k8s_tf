
# Egress firewall for the Harbor namespace.
#
# Harbor components (portal/core/registry/jobservice/trivy + bundled postgres &
# redis) only need: same-namespace traffic, DNS, public internet (registry
# proxy pulls, trivy DB updates, replication), and egress to the kube-network
# gateways so harbor-core can reach the Authentik OIDC issuer for the
# login flow (auth.vn.linuxguru.net terminates at the private gateway).
# No k8s API access.
#
# kubelet image pulls originate from the nodes (host traffic) and are not
# subject to pod NetworkPolicies, so this does not affect node pulls from the
# registry.
module "firewall" {
  source            = "../../network/firewalls/basic_internet"
  namespace         = var.namespace
  allow_to_services = true

  depends_on = [kubernetes_namespace_v1.namespace]
}
