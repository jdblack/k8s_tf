
# Egress firewall for the Argo namespace (OPT-IN -- see variable below).
#
# Argo CD (server/application-controller/repo-server) needs: same-namespace
# traffic, DNS, public internet (git/helm remotes), the Kubernetes API server,
# and egress to the kube-network gateways (OIDC SSO discovery against the
# Authentik issuer terminates at the private gateway).
#
# CAUTION: Argo Workflows (installed into this namespace by the mantle stack)
# runs arbitrary user pods. A workflow step that needs to reach a service in
# another namespace directly -- not via a gateway URL -- will be denied by this
# policy. Audit the workflows (modules/argo/mantle/argo-workflows) first, then
# set enable_egress_firewall = true on the module.argo call in the core stack.
module "firewall" {
  count = var.enable_egress_firewall ? 1 : 0

  source            = "../../network/firewalls/basic_internet"
  namespace         = var.namespace
  allow_to_services = true
  allow_to_k8sapi   = true

  depends_on = [kubernetes_namespace_v1.namespace]
}

