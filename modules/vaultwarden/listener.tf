# HTTPS listener on the shared PRIVATE gateway (kube-network) + the HTTPRoute to
# the app Service, via the standard `expose` pairing.
#
# Two things to notice, both intentional:
#
#   - cert_issuer is the PUBLIC issuer (letsencrypt) while the gateway is
#     private. Its only solver is dns01/route53, so issuance needs no inbound
#     reachability, and phones then need no private-CA install. This is the only
#     value that differs from the other private-gateway apps; the mechanism
#     (cert-manager gateway-shim, secret `cert-<fqdn>`, ReferenceGrants) is
#     identical, so moving to the public gateway later is a one-line change with
#     ZERO client reconfiguration (Bitwarden clients pin the server URL).
#   - There is NO authentik proxy outpost in front of this. The clients are not
#     browsers: they POST to /identity/connect/token, call /api/* with bearer
#     tokens, and hold a /notifications/hub websocket. An outpost 302s
#     unauthenticated requests to a login page, which breaks every client
#     (and it would still not remove the master password). /admin is disabled
#     instead -- see secret.tf.
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
