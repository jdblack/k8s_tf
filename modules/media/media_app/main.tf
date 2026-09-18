resource "helm_release" "helm" {
  name       = var.name
  repository = var.helm_repo
  chart      = var.chart
  namespace  = var.namespace
  version    = var.helm_version
  wait       = true
  timeout    = 600
  values     = [yamlencode(var.helm_values)]
}

module "expose" {
  source = "../../network/gateway/expose"

  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  backend_name = var.backend_name
  backend_port = var.backend_port
  route_name   = var.route_name
}
