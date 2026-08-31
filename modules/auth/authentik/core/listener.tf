# HTTPS listener via the shared private gateway (kube-network). The HTTPRoute
# is rendered by the authentik chart itself (server.route.main), so this module
# only declares the ListenerSet (which provisions the linuxguru-ca cert); the
# listener_set submodule creates the cross-namespace ReferenceGrants for both
# ListenerSet and HTTPRoute attachment.
module "listener_set" {
  source            = "../../../network/gateway/listener_set"
  name              = "auth"
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}
