# NGINX Gateway Fabric control plane; the caller owns the namespace. Every instance needs a unique
# GatewayClass and release name (the chart's ClusterRoles are cluster-scoped). PREREQUISITE: the
# Gateway API CRDs come from modules/network/api_gateway_config.tf.
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
