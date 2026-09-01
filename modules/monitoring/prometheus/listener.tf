# Exposure via the shared private gateway (kube-network): HTTPS listener
# (grafana.vn.linuxguru.net, linuxguru-ca cert) + HTTPRoute to the
# prometheus-grafana ClusterIP service. TLS terminated at the gateway.
module "listener_set" {
  source            = "../../network/gateway/listener_set"
  name              = var.grafana_name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

module "http_route" {
  source       = "../../network/gateway/http_route"
  name         = var.grafana_name
  namespace    = var.namespace
  domain       = var.domain
  backend_name = "prometheus-grafana"
  backend_port = 80
}
