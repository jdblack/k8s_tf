# HTTPS listener via the shared private gateway (kube-network). The HTTPRoute
# is rendered by the argo-cd chart itself (server.httproute), so this module
# only declares the ListenerSet (which provisions the linuxguru-ca cert); the
# listener_set submodule creates the cross-namespace ReferenceGrants for both
# ListenerSet and HTTPRoute attachment.
module "expose" {
  source            = "../../../network/gateway/expose"
  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

# The HTTPRoute is rendered by the argo-cd chart (server.httproute), so no
# backend_* here -- the listener is all this module declares.
moved {
  from = module.listener_set
  to   = module.expose.module.listener_set
}
