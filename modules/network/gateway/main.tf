resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }
}

# NGINX Gateway Fabric control plane. The chart also creates the GatewayClass
# `nginx` (controller gateway.nginx.org/nginx-gateway-controller). The data
# plane Service (created per-Gateway) is pinned to var.load_balancer_ip.
#
# NOTE: the Gateway API + NGF CRDs must be installed BEFORE this apply
# (see TODO Phase 3): they are cluster-wide and installed via kubectl.
resource "helm_release" "ngf" {
  name       = "ngf"
  repository = "oci://ghcr.io/nginx/charts"
  chart      = "nginx-gateway-fabric"
  version    = "2.6.7"
  namespace  = var.namespace

  values = [yamlencode({
    nginx = {
      service = {
        type           = "LoadBalancer"
        loadBalancerIP = var.load_balancer_ip
      }
    }
  })]

  depends_on = [
    kubernetes_namespace_v1.this,
    terraform_data.gateway_api_crds
  ]
}
