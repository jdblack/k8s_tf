# HTTPS listener on the shared PRIVATE gateway + HTTPRoute to the app Service,
# via the standard `expose` pairing. Two deliberate choices:
#
#   - cert_issuer is the PUBLIC issuer (letsencrypt) though the gateway is
#     private: its only solver is dns01/route53, so issuance needs no inbound
#     reachability and phones need no private CA installed. Moving to the public
#     gateway later is a one-line change with zero client reconfiguration
#     (Bitwarden clients pin the server URL).
#   - NO authentik outpost in front: the clients are not browsers (token POSTs,
#     bearer-token APIs, a /notifications/hub websocket), and an outpost's 302
#     to a login page breaks every one of them. /admin is disabled instead --
#     see secret.tf.
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
