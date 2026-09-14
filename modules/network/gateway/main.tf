# NGINX Gateway Fabric control plane for THIS gateway instance. The caller owns
# the namespace and must ensure it exists before apply (depends_on).
#
# The chart creates a GatewayClass named var.name; every NGF instance needs a
# unique GatewayClass + controller name, so each gateway passes a distinct name
# (media-private / private / public) and unique release_name (their ClusterRoles
# are cluster-scoped). watch_namespaces scopes the controller; its own namespace
# is always included. The data-plane Service is pinned to
# var.load_balancer_ip when set, else the LoadBalancer provider assigns one.
#
# PREREQUISITE: the cluster-scoped Gateway API CRDs are installed once by
# modules/network/api_gateway_config.tf from the core stack -- apply that first
# on a fresh cluster.
resource "helm_release" "ngf" {
  # release_name defaults to "ngf" (single-gateway-per-namespace callers like
  # media), but shared gateways in the same namespace (public/private in
  # kube-network) pass unique names so the chart's ClusterRoles/CRD-scoped
  # objects don't collide.
  name       = var.release_name
  repository = "oci://ghcr.io/nginx/charts"
  chart      = "nginx-gateway-fabric"
  version    = "2.6.7"
  namespace  = var.namespace

  values = [yamlencode(local.helm_values)]
}
