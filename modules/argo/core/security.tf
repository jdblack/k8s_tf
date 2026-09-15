
# Egress firewall, OPT-IN (var.enable_egress_firewall). Argo CD needs same-ns + DNS +
# internet (git/helm remotes) + the k8s API + the kube-network gateways (OIDC
# discovery against the Authentik issuer).
#
# CAUTION: Argo Workflows runs arbitrary user pods in this namespace. A step that
# reaches another namespace directly (not via a gateway URL) is denied. Audit the
# workflows before flipping this on.
module "firewall" {
  count = var.enable_egress_firewall ? 1 : 0

  source            = "../../network/firewalls/basic_internet"
  namespace         = var.namespace
  allow_to_services = true
  allow_to_k8sapi   = true

  depends_on = [kubernetes_namespace_v1.namespace]
}

