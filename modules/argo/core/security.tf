
# Egress firewall, OPT-IN (var.enable_egress_firewall). Argo CD needs same-ns + DNS +
# internet (git/helm remotes) + the API + the kube-network gateways (OIDC discovery).
#
# CAUTION: Argo Workflows runs arbitrary user pods here. A step that reaches another
# namespace directly (not via a gateway URL) is denied. Audit the workflows first.
module "firewall" {
  count = var.enable_egress_firewall ? 1 : 0

  source            = "../../network/firewalls/basic_internet"
  namespace         = var.namespace
  allow_to_services = true
  allow_to_k8sapi   = true

  depends_on = [kubernetes_namespace_v1.namespace]
}

