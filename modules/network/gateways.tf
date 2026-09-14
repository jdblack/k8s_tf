# Shared, cluster-wide NGINX Gateway Fabric gateways (they replaced the old
# public/private ingress-nginx controllers; ingress.tf removed).
#
# In kube-network (var.namespace, owned by this module), open to ListenerSets from
# ANY namespace (routes_namespace = null -> allowedListeners from: All) and
# watching every namespace. Each app owns its exposure from its own namespace via
# the listener_set submodule + an HTTPRoute; that submodule creates the
# cross-namespace ReferenceGrant.
#
# Data-plane LoadBalancer Services are pinned to the IPs the old controllers held
# (gateway_ips) so DNS / NAT / firewall rules keep working. MetalLB frees those IPs
# once the old ingress-nginx releases are gone, so the new Services may sit Pending
# until then (re-apply if they don't converge).
module "gateway_public" {
  source           = "./gateway"
  namespace        = var.namespace
  name             = "public"
  release_name     = "ngf-public"
  load_balancer_ip = var.gateway_ips.public
  routes_namespace = null
  watch_namespaces = []

  depends_on = [kubernetes_namespace_v1.namespace]
}

module "gateway_private" {
  source           = "./gateway"
  namespace        = var.namespace
  name             = "private"
  release_name     = "ngf-private"
  load_balancer_ip = var.gateway_ips.private
  routes_namespace = null
  watch_namespaces = []

  depends_on = [kubernetes_namespace_v1.namespace]
}
