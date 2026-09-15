# HTTPS listener via the shared private gateway (kube-network). The HTTPRoute
# is rendered by the argo-cd chart itself (server.httproute), so this module
# only declares the ListenerSet (which provisions the listener cert); the
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

# The bare host intentionally serves the chart's own login page. A
# `redirect_route` hijacking `Exact /` into /auth/login was tried and removed:
# argocd-server's OIDC callback falls back to the base href (`/`) when no
# return_url is supplied (util/oidc verifyAppState), which is the hijacked path,
# so the rule loops the browser until ERR_TOO_MANY_REDIRECTS. Argo CD ships no
# setting to skip its login page -- the SSO button is the entrypoint. Rationale
# and failure mode: memory-bank/progress.md.
