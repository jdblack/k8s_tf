# HTTPS listener via the shared private gateway (kube-network). The HTTPRoute
# is rendered by the argo-cd chart itself (server.httproute), so this module
# only declares the ListenerSet (which provisions the linuxguru-ca cert); the
# listener_set submodule creates the cross-namespace ReferenceGrants for both
# ListenerSet and HTTPRoute attachment.
module "listener_set" {
  source            = "../../../network/gateway/listener_set"
  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}
