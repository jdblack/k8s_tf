module "expose" {
  source            = "../../network/gateway/expose"
  name              = var.plex_name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
  backend_name      = "${var.plex_name}-plex-media-server"
  backend_port      = 32400
}
