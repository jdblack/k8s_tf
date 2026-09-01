module "listener_set" {
  source            = "../../network/gateway/listener_set"
  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

# App HTTPRoute: routes HTTPS host traffic from the ListenerSet to the backend Service.
module "http_route" {
  source       = "../../network/gateway/http_route"
  name         = var.name
  namespace    = var.namespace
  domain       = var.domain
  backend_name = local.svc_name
  backend_port = var.service_port
}


