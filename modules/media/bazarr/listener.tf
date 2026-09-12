module "expose" {
  source            = "../../network/gateway/expose"
  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  # Fronted by the authentik outpost (same namespace): the route targets the
  # outpost Service, named "<app>-auth" so it can't collide with the
  # chart-generated "<app>" route during the disable/apply transition.
  backend_name = var.auth_backend
  backend_port = 9000
  route_name   = "${var.name}-auth"
}

moved {
  from = module.listener_set
  to   = module.expose.module.listener_set
}

moved {
  from = module.http_route
  to   = module.expose.module.http_route[0]
}



