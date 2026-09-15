# HTTPS listener on the shared private gateway + HTTPRoute to the app Service.
#
# No authentik outpost in front of this host: Bitwarden clients are not browsers
# (token POSTs, bearer-token APIs, a /notifications/hub websocket) and an outpost's
# 302 to a login page breaks every one of them; /admin is disabled instead -- see
# secret.tf.
#
# The cert uses the default public issuer despite the private gateway: DNS-01 is its
# only solver, so clients need no CA installed.
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
