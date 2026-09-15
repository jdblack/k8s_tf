# NGINX Gateway Fabric control plane. The caller owns the namespace.
#
# Every NGF instance needs a unique GatewayClass and release name: the chart's
# ClusterRoles are cluster-scoped, so two releases cannot share a name.
#
# PREREQUISITE: the Gateway API CRDs come from
# modules/network/api_gateway_config.tf in the core stack.
resource "helm_release" "ngf" {
  name       = var.release_name
  repository = "oci://ghcr.io/nginx/charts"
  chart      = "nginx-gateway-fabric"
  version    = var.helm_version
  namespace  = var.namespace

  wait    = true
  timeout = 600
  values  = [yamlencode(local.helm_values)]
}
