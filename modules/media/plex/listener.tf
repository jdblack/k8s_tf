# Web UI exposure via the shared public gateway (kube-network): HTTPS listener
# (plex.linuxguru.net, letsencrypt cert) + HTTPRoute to the same PMS service
# the chart's LoadBalancer exposes (32400). DNS keeps publishing both IPs:
# 192.168.0.104 (direct PMS via the LoadBalancer service) and 192.168.0.101
# (web UI via the gateway).
module "listener_set" {
  source            = "../../network/gateway/listener_set"
  name              = var.plex_name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

module "http_route" {
  source       = "../../network/gateway/http_route"
  name         = var.plex_name
  namespace    = var.namespace
  domain       = var.domain
  backend_name = "${var.plex_name}-plex-media-server"
  backend_port = 32400
}
