# Exposure via the shared private gateway (kube-network): HTTPS listener
# (grafana.vn.linuxguru.net, linuxguru-ca cert) + HTTPRoute to the
# prometheus-grafana ClusterIP service. TLS terminated at the gateway.
module "expose" {
  source            = "../../network/gateway/expose"
  name              = var.grafana_name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = "prometheus-grafana"
  backend_port      = 80
}

moved {
  from = module.listener_set
  to   = module.expose.module.listener_set
}

moved {
  from = module.http_route
  to   = module.expose.module.http_route[0]
}
