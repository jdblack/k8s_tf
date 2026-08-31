# NGINX Gateway Fabric control plane for THIS gateway instance. The caller owns
# the namespace (this module never creates one) and must ensure it exists before
# apply -- e.g. via `depends_on` on the caller's namespace resource.
#
# The chart creates a GatewayClass named var.name (controller
# gateway.nginx.org/<var.name>-controller). Every NGF instance must have a
# unique GatewayClass + controller name, so each gateway passes a distinct
# name (e.g. media-private / private / public). watch_namespaces scopes this
# controller to the namespaces it serves (its own namespace is always
# included).
#
# The data plane Service (created per-Gateway) is pinned to var.load_balancer_ip
# when set; null lets the LoadBalancer provider assign an IP.
#
# PREREQUISITE: the standard Gateway API CRDs (gateway.networking.k8s.io/*) are
# CLUSTER-SCOPED and installed exactly once by
# modules/network/api_gateway_config.tf (run from the core stack). Apply that
# before this module on a fresh cluster.
resource "helm_release" "ngf" {
  name       = "ngf"
  repository = "oci://ghcr.io/nginx/charts"
  chart      = "nginx-gateway-fabric"
  version    = "2.6.7"
  namespace  = var.namespace

  values = [yamlencode({
    nginx = {
      service = merge(
        { type = "LoadBalancer" },
        # yamlencode renders null as "null" (not omits it), so only set the
        # key when the caller pinned an IP.
        var.load_balancer_ip != null ? { loadBalancerIP = var.load_balancer_ip } : {}
      )
    }
    nginxGateway = {
      gatewayClassName      = var.name
      gatewayControllerName = "gateway.nginx.org/${var.name}-controller"
      watchNamespaces       = var.watch_namespaces
    }
  })]
}
