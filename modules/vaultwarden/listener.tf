# HTTPS listener on the shared PRIVATE gateway + HTTPRoute to the app Service.
#
# No authentik outpost in front of this host: Bitwarden clients are not browsers
# (token POSTs, bearer-token APIs, a /notifications/hub websocket) and an outpost's
# 302 to a login page breaks every one of them. /admin is disabled instead -- see
# secret.tf.
#
# The cert uses the default public issuer despite the private gateway: DNS-01 is its
# only solver, so issuance needs no inbound reachability and clients need no CA
# installed, and moving to the public gateway later becomes a one-line change with
# zero client reconfiguration.
module "expose" {
  source = "../network/gateway/expose"

  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace

  backend_name = var.name
  backend_port = var.port
}
